package com.padlab.padlab

import android.content.Context
import android.hardware.input.InputManager
import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import com.padlab.pad_bridge.PadBridgePlugin
import io.flutter.embedding.android.FlutterActivity

/**
 * Activity principale de PadLab.
 *
 * Elle ne fait que **relayer** les événements manette au plugin : elle ne les
 * consomme jamais, donc Flutter continue de recevoir les mêmes entrées.
 * Les événements sont regroupés côté natif (~120 Hz) avant d'être envoyés à
 * Dart, ce qui évite de saturer le pont sur une manette 1000 Hz.
 */
class MainActivity : FlutterActivity() {

    private var inputManager: InputManager? = null

    private val deviceListener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) = PadBridgePlugin.onDevicesChanged()
        override fun onInputDeviceRemoved(deviceId: Int) = PadBridgePlugin.onDevicesChanged()
        override fun onInputDeviceChanged(deviceId: Int) = PadBridgePlugin.onDevicesChanged()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.registerInputDeviceListener(deviceListener, null)
    }

    override fun onDestroy() {
        inputManager?.unregisterInputDeviceListener(deviceListener)
        inputManager = null
        super.onDestroy()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Relais seul : le retour de super garde le comportement Flutter intact.
        PadBridgePlugin.onKey(event)
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        PadBridgePlugin.onMotion(event, event.deviceId)
        return super.dispatchGenericMotionEvent(event)
    }
}
