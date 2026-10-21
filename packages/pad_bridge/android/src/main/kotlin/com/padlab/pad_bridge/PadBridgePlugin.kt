package com.padlab.pad_bridge

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/**
 * Plugin Android de PadLab.
 *
 * Deux canaux :
 *  - MethodChannel : liste des manettes, capacités, batterie, vibration.
 *  - EventChannel  : flux d'événements **groupés** (~120 Hz) pour éviter de
 *    saturer le pont Dart quand une manette émet à 1000 Hz.
 *
 * La capture se fait dans l'Activity (voir `onKeyDown`/`onMotion` appelés par
 * `MainActivity`). Le plugin ne consomme **pas** les touches clavier.
 */
class PadBridgePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var reader: PadDeviceReader? = null
    private var battery: BatteryReader? = null
    private var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<Map<String, Any?>>()
    private var flushScheduled = false

    companion object {
        @Volatile
        private var instance: PadBridgePlugin? = null

        /** Appelé par MainActivity pour chaque KeyEvent de manette. */
        fun onKey(event: KeyEvent): Boolean = instance?.handleKey(event) ?: false

        /** Appelé par MainActivity pour chaque MotionEvent. */
        fun onMotion(event: MotionEvent, deviceId: Int): Boolean =
            instance?.handleMotion(event, deviceId) ?: false

        /** Appelé quand une manette est branchée ou débranchée. */
        fun onDevicesChanged() {
            instance?.enqueue(mapOf("type" to "devicesChanged"))
        }

        /**
         * `KeyEvent.eventTime` / `MotionEvent.eventTime` sont exprimés en
         * `uptimeMillis`. On les convertit en microsecondes d'époque pour que
         * Dart puisse mesurer la latence réelle (capture native → UI).
         */
        private fun epochUs(uptimeMs: Long): Long =
            uptimeMs * 1000L + (System.currentTimeMillis() - SystemClock.uptimeMillis()) * 1000L
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        reader = PadDeviceReader(binding.applicationContext)
        battery = BatteryReader(binding.applicationContext)
        methodChannel = MethodChannel(binding.binaryMessenger, "padlab/bridge")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "padlab/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        instance = null
        reader = null
        battery?.shutdown()
        battery = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- MethodChannel -----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val reader = reader
        if (reader == null) {
            result.error("no_engine", "Plugin non attaché", null)
            return
        }
        when (call.method) {
            "listDevices" -> result.success(reader.listGamepads())
            "capabilities" -> {
                val id = call.argument<Int>("deviceId") ?: return result.error("bad_args", "deviceId manquant", null)
                result.success(reader.descriptorFor(id))
            }
            "battery" -> {
                val id = call.argument<Int>("deviceId") ?: return result.error("bad_args", "deviceId manquant", null)
                // Jamais sur le thread principal : getBatteryState() peut
                // bloquer plusieurs secondes sur une manette Bluetooth.
                val battery = battery
                if (battery == null) {
                    result.success(BatteryReader.UNKNOWN)
                } else {
                    battery.read(id) { payload -> result.success(payload) }
                }
            }
            "batteryDiagnostics" -> result.success(battery?.diagnostics() ?: emptyMap<String, Any?>())
            "vibrate" -> {
                val id = call.argument<Int>("deviceId") ?: return result.error("bad_args", "deviceId manquant", null)
                val strong = call.argument<Double>("strong") ?: 1.0
                val weak = call.argument<Double>("weak") ?: 1.0
                val duration = call.argument<Int>("durationMs") ?: 300
                result.success(reader.vibrate(id, strong, weak, duration))
            }
            "stopVibration" -> {
                val id = call.argument<Int>("deviceId") ?: return result.error("bad_args", "deviceId manquant", null)
                reader.stopVibration(id)
                result.success(true)
            }
            "platformInfo" -> result.success(
                mapOf(
                    "sdkInt" to Build.VERSION.SDK_INT,
                    "hasBatteryApi" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
                    "hasLightsApi" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
                    "hasMotionApi" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                )
            )
            else -> result.notImplemented()
        }
    }

    // --- EventChannel ------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Les événements accumulés pendant qu'aucun Dart n'écoutait sont
        // périmés : les rejouer ferait sauter l'état d'un coup.
        synchronized(pending) { pending.clear() }
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // --- capture -----------------------------------------------------------

    private fun handleKey(event: KeyEvent): Boolean {
        val device = event.device ?: return false
        if (!isGamepadSource(device.sources)) return false
        val index = PadDeviceReader.buttonIndex(event.keyCode) ?: return false
        enqueue(
            mapOf(
                "type" to if (event.action == KeyEvent.ACTION_DOWN) "buttonDown" else "buttonUp",
                "deviceId" to device.id,
                "buttonIndex" to index,
                "code" to event.keyCode,
                "timestampUs" to epochUs(event.eventTime)
            )
        )
        return true
    }

    private fun handleMotion(event: MotionEvent, deviceId: Int): Boolean {
        val device = InputDevice.getDevice(deviceId) ?: return false
        if (!isGamepadSource(device.sources)) return false

        // Les événements historiques comptent : sans eux la fréquence réelle
        // d'une manette 1000 Hz serait sous-estimée.
        val history = event.historySize
        if (history > 0) {
            for (h in 0 until history) {
                emitAxes(event, deviceId, h)
            }
        }
        emitAxes(event, deviceId, -1)
        return true
    }

    private fun emitAxes(event: MotionEvent, deviceId: Int, historyIndex: Int) {
        val device = event.device ?: return
        val time = if (historyIndex >= 0) event.getHistoricalEventTime(historyIndex) else event.eventTime
        // On itère sur les plages réellement exposées par la manette : plus
        // rapide que de balayer tous les codes d'axe, et sans dépendre de
        // MotionEvent.AXIS_MAX qui n'est pas public.
        for (range in device.motionRanges) {
            val axis = range.axis
            val raw = if (historyIndex >= 0) {
                event.getHistoricalAxisValue(axis, historyIndex)
            } else {
                event.getAxisValue(axis)
            }
            if (raw == 0f && axis !in ACTIVE_AXES) continue
            val span = range.max - range.min
            if (span <= 0f) continue
            val unit = ((raw - range.min) / span).coerceIn(0f, 1f)
            val isTrigger = axis == MotionEvent.AXIS_LTRIGGER || axis == MotionEvent.AXIS_RTRIGGER ||
                axis == MotionEvent.AXIS_GAS || axis == MotionEvent.AXIS_BRAKE
            val normalized = if (isTrigger) unit else unit * 2f - 1f
            enqueue(
                mapOf(
                    "type" to "axis",
                    "deviceId" to deviceId,
                    "axis" to verticalAxisName(axis, raw, range.min, range.max),
                    "code" to axis,
                    "value" to normalized.toDouble(),
                    "rawValue" to raw.toDouble(),
                    "timestampUs" to epochUs(time)
                )
            )
        }
    }

    /**
     * Certaines manettes inversent Y. On garde la convention PadLab :
     * Y positif = vers le bas, comme Android pour les sticks.
     */
    private fun verticalAxisName(axis: Int, raw: Float, min: Float, max: Float): String? =
        PadDeviceReader.axisName(axis)

    private fun isGamepadSource(sources: Int): Boolean =
        (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
            (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK

    private fun enqueue(event: Map<String, Any?>) {
        synchronized(pending) {
            pending.add(event)
            // On borne la file : si l'UI est bloquée, on préfère perdre du
            // détail que saturer la mémoire.
            while (pending.size > 512) pending.poll()
        }
        if (!flushScheduled) {
            flushScheduled = true
            mainHandler.postDelayed({ flush() }, 8) // ~120 Hz
        }
    }

    private fun flush() {
        flushScheduled = false
        val sink = sink
        if (sink == null) {
            // Personne n'écoute : inutile de garder des événements qui
            // seraient de toute façon périmés au prochain abonnement.
            synchronized(pending) { pending.clear() }
            return
        }
        val batch = synchronized(pending) {
            val list = pending.toList()
            pending.clear()
            list
        }
        if (batch.isNotEmpty()) {
            sink.success(batch)
        }
    }

    private val ACTIVE_AXES = setOf(
        MotionEvent.AXIS_X, MotionEvent.AXIS_Y,
        MotionEvent.AXIS_Z, MotionEvent.AXIS_RZ,
        MotionEvent.AXIS_LTRIGGER, MotionEvent.AXIS_RTRIGGER,
        MotionEvent.AXIS_HAT_X, MotionEvent.AXIS_HAT_Y
    )
}
