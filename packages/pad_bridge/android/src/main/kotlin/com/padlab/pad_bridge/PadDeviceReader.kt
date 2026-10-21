package com.padlab.pad_bridge

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent

/**
 * Lecture des manettes via les API publiques Android.
 *
 * Tout ce qui dépend de la version d'Android est isolé ici, pour que le
 * plugin Dart ne voie qu'un modèle stable. Aucune API privée, aucun root :
 * si une capacité n'est pas exposée, on renvoie `false` plutôt qu'une
 * valeur inventée.
 */
class PadDeviceReader(@Suppress("unused") private val context: Context) {

    /** Appareils actuellement connectés, manettes et joysticks. */
    fun listGamepads(): List<Map<String, Any?>> {
        val ids = InputDevice.getDeviceIds()
        val result = mutableListOf<Map<String, Any?>>()
        for (id in ids) {
            val device = InputDevice.getDevice(id) ?: continue
            if (!isGamepad(device)) continue
            result.add(describe(device))
        }
        return result
    }

    fun descriptorFor(deviceId: Int): Map<String, Any?>? {
        val device = InputDevice.getDevice(deviceId) ?: return null
        return describe(device)
    }

    private fun isGamepad(device: InputDevice): Boolean {
        val sources = device.sources
        val gamepad = (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
        val joystick = (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
        return gamepad || joystick
    }

    private fun describe(device: InputDevice): Map<String, Any?> {
        val capabilities = device.motionRanges
        val axes = mutableListOf<Map<String, Any?>>()
        for (range in capabilities) {
            val axisName = axisName(range.axis) ?: continue
            axes.add(
                mapOf(
                    "axis" to axisName,
                    "min" to range.min,
                    "max" to range.max,
                    "flat" to range.flat,
                    "fuzz" to range.fuzz,
                    "resolution" to range.resolution
                )
            )
        }

        return mapOf(
            "id" to device.id,
            "name" to device.name,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "descriptor" to device.descriptor,
            "controllerNumber" to device.controllerNumber,
            "sources" to device.sources,
            "isExternal" to device.isExternal,
            "connection" to connectionGuess(device),
            "capabilities" to mapOf(
                "axes" to axes,
                "buttonBits" to knownButtons(device),
                "vibratorCount" to vibratorCount(device),
                // On ne lit plus la batterie ici : c'était un appel Binder
                // synchrone sur le thread principal, à chaque scan. La
                // lecture vit dans BatteryReader, en tâche de fond.
                "hasBattery" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
                "hasLight" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
                "hasMotion" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
                "hasTouchpad" to hasTouchpad(device)
            ),
        )
    }

    /** Deux moteurs quand la manette les expose (API 31+). */
    fun vibratorCount(device: InputDevice): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager: VibratorManager? = device.vibratorManager
                manager?.vibratorIds?.size ?: 0
            } else {
                @Suppress("DEPRECATION")
                if (device.vibrator?.hasVibrator() == true) 1 else 0
            }
        } catch (_: Throwable) {
            0
        }
    }

    /**
     * Vibration : force = moteur fort, weak = moteur fin.
     * En dessous d'API 31, on combine les deux intensités en une seule.
     */
    fun vibrate(deviceId: Int, strong: Double, weak: Double, durationMs: Int): Boolean {
        val device = InputDevice.getDevice(deviceId) ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager: VibratorManager = device.vibratorManager ?: return false
                val ids = manager.vibratorIds
                if (ids.isEmpty()) return false
                val left = manager.getVibrator(ids[0])
                left.vibrate(
                    VibrationEffect.createOneShot(
                        durationMs.toLong(),
                        (strong.coerceIn(0.0, 1.0) * 255).toInt().coerceIn(1, 255)
                    )
                )
                if (ids.size > 1) {
                    val right = manager.getVibrator(ids[1])
                    right.vibrate(
                        VibrationEffect.createOneShot(
                            durationMs.toLong(),
                            (weak.coerceIn(0.0, 1.0) * 255).toInt().coerceIn(1, 255)
                        )
                    )
                }
                true
            } else {
                @Suppress("DEPRECATION")
                val vibrator: Vibrator? = device.vibrator
                if (vibrator == null || !vibrator.hasVibrator()) return false
                val level = ((strong + weak) / 2.0).coerceIn(0.0, 1.0)
                @Suppress("DEPRECATION")
                vibrator.vibrate(
                    VibrationEffect.createOneShot(
                        durationMs.toLong(),
                        (level * 255).toInt().coerceIn(1, 255)
                    )
                )
                true
            }
        } catch (_: Throwable) {
            false
        }
    }

    fun stopVibration(deviceId: Int) {
        val device = InputDevice.getDevice(deviceId) ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                device.vibratorManager?.cancel()
            } else {
                @Suppress("DEPRECATION")
                device.vibrator?.cancel()
            }
        } catch (_: Throwable) {
            // Rien à faire : la manette est peut-être partie.
        }
    }

    private fun hasTouchpad(device: InputDevice): Boolean {
        val ranges = device.motionRanges
        return ranges.any { it.axis == MotionEvent.AXIS_X && it.source == InputDevice.SOURCE_TOUCHPAD } ||
            ranges.any { it.source == InputDevice.SOURCE_TOUCHPAD }
    }

    private fun connectionGuess(device: InputDevice): String {
        // Bluetooth renvoie souvent un descripteur commençant par "bluetooth".
        val descriptor = device.descriptor?.lowercase() ?: ""
        return when {
            descriptor.contains("bluetooth") -> "bluetooth"
            device.isExternal -> "usb"
            else -> "unknown"
        }
    }

    /** Bits des boutons que la manette sait produire, d'après son KeyCharacterMap. */
    private fun knownButtons(device: InputDevice): Int {
        val map = device.keyCharacterMap ?: return DEFAULT_BUTTON_BITS
        var bits = 0
        for ((keyCode, index) in BUTTON_INDEX) {
            if (map.get(keyCode, 0) != 0 || keyCode in ALWAYS_PRESENT) {
                bits = bits or (1 shl index)
            }
        }
        // Même si la KeyCharacterMap est incomplète, une manette expose
        // toujours ses boutons de façade et sa croix.
        return bits or DEFAULT_BUTTON_BITS
    }

    companion object {
        /** Ordre aligné avec l'enum Dart PadButton. */
        private val BUTTON_INDEX: Map<Int, Int> = mapOf(
            KeyEvent.KEYCODE_BUTTON_A to 0,
            KeyEvent.KEYCODE_BUTTON_B to 1,
            KeyEvent.KEYCODE_BUTTON_X to 2,
            KeyEvent.KEYCODE_BUTTON_Y to 3,
            KeyEvent.KEYCODE_DPAD_UP to 4,
            KeyEvent.KEYCODE_DPAD_DOWN to 5,
            KeyEvent.KEYCODE_DPAD_LEFT to 6,
            KeyEvent.KEYCODE_DPAD_RIGHT to 7,
            KeyEvent.KEYCODE_BUTTON_L1 to 8,
            KeyEvent.KEYCODE_BUTTON_R1 to 9,
            KeyEvent.KEYCODE_BUTTON_L2 to 10,
            KeyEvent.KEYCODE_BUTTON_R2 to 11,
            KeyEvent.KEYCODE_BUTTON_THUMBL to 12,
            KeyEvent.KEYCODE_BUTTON_THUMBR to 13,
            KeyEvent.KEYCODE_BUTTON_START to 14,
            KeyEvent.KEYCODE_BUTTON_SELECT to 15,
            KeyEvent.KEYCODE_BUTTON_MODE to 16,
            KeyEvent.KEYCODE_BUTTON_1 to 18,
            KeyEvent.KEYCODE_BUTTON_2 to 19,
            KeyEvent.KEYCODE_BUTTON_3 to 20,
            KeyEvent.KEYCODE_BUTTON_4 to 21
        )

        private val ALWAYS_PRESENT = setOf(
            KeyEvent.KEYCODE_BUTTON_A, KeyEvent.KEYCODE_BUTTON_B,
            KeyEvent.KEYCODE_BUTTON_X, KeyEvent.KEYCODE_BUTTON_Y,
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_BUTTON_L1, KeyEvent.KEYCODE_BUTTON_R1,
            KeyEvent.KEYCODE_BUTTON_START
        )

        private const val DEFAULT_BUTTON_BITS = 0x7FFF

        fun buttonIndex(keyCode: Int): Int? = BUTTON_INDEX[keyCode]

        fun axisName(axis: Int): String? = when (axis) {
            MotionEvent.AXIS_X -> "leftX"
            MotionEvent.AXIS_Y -> "leftY"
            MotionEvent.AXIS_Z -> "rightX"
            MotionEvent.AXIS_RZ -> "rightY"
            MotionEvent.AXIS_LTRIGGER -> "leftTrigger"
            MotionEvent.AXIS_RTRIGGER -> "rightTrigger"
            MotionEvent.AXIS_GAS -> "rightTrigger"
            MotionEvent.AXIS_BRAKE -> "leftTrigger"
            else -> null
        }
    }
}
