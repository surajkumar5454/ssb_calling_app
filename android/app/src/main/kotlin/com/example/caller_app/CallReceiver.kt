package com.example.caller_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.os.Build

class CallReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "CallReceiver"
        private const val CHANNEL = "com.example.caller_app/phone_state"
        var flutterEngine: FlutterEngine? = null
    }

    private var overlayManager: OverlayManager? = null
    private var lastState: String? = null
    private var lastNumber: String? = null

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return

        when (intent?.action) {
            TelephonyManager.ACTION_PHONE_STATE_CHANGED -> handleIncomingCall(context, intent)
            Intent.ACTION_BOOT_COMPLETED -> {
                val serviceIntent = Intent(context, CallDetectorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }

    private fun handleIncomingCall(context: Context, intent: Intent) {
        try {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            var number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            Log.d(TAG, "Phone State: $state, Original Number: $number")

            // Some devices might not provide the number in the first broadcast
            if (state == TelephonyManager.EXTRA_STATE_RINGING && number.isNullOrEmpty()) {
                number = lastNumber
            }

            // Format phone number
            if (!number.isNullOrEmpty()) {
                // Remove any whitespace
                number = number.replace("\\s+".toRegex(), "")
                // Remove +91 prefix if present
                if (number.startsWith("+91")) {
                    number = number.substring(3)
                }
                // Get last 10 digits
                if (number.length > 10) {
                    number = number.substring(number.length - 10)
                }
                Log.d(TAG, "Formatted Number: $number")
            }

            // Avoid duplicate notifications
            if (state == lastState && number == lastNumber) {
                return
            }

            lastState = state
            if (!number.isNullOrEmpty()) {
                lastNumber = number
            }

            if (state == TelephonyManager.EXTRA_STATE_RINGING && !number.isNullOrEmpty()) {
                // Check for overlay permission
                if (!Settings.canDrawOverlays(context)) {
                    val serviceIntent = Intent(context, CallDetectorService::class.java).apply {
                        action = "REQUEST_OVERLAY_PERMISSION"
                    }
                    context.startService(serviceIntent)
                    return
                }

                // Initialize overlay manager if needed
                if (overlayManager == null) {
                    overlayManager = OverlayManager(context)
                }

                // Notify Flutter about incoming call
                Handler(Looper.getMainLooper()).post {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod(
                            "onIncomingCall",
                            number,
                            object : MethodChannel.Result {
                                override fun success(result: Any?) {
                                    Log.d(TAG, "Successfully notified Flutter about incoming call")
                                }

                                override fun error(code: String, message: String?, details: Any?) {
                                    Log.e(TAG, "Error notifying Flutter about incoming call: $message")
                                }

                                override fun notImplemented() {
                                    Log.e(TAG, "onIncomingCall not implemented in Flutter")
                                }
                            }
                        )
                    }
                }

                // Get caller info from Flutter
                Handler(Looper.getMainLooper()).post {
                    try {
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, CHANNEL).invokeMethod(
                                "getCallerInfo",
                                number,
                                object : MethodChannel.Result {
                                    override fun success(result: Any?) {
                                        @Suppress("UNCHECKED_CAST")
                                        val callerInfo = result as? Map<String, Any>
                                        overlayManager?.showOverlay(callerInfo, number)
                                    }

                                    override fun error(code: String, message: String?, details: Any?) {
                                        Log.e(TAG, "Error getting caller info: $message")
                                        overlayManager?.showOverlay(null, number)
                                    }

                                    override fun notImplemented() {
                                        overlayManager?.showOverlay(null, number)
                                    }
                                }
                            )
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting caller info: ${e.message}")
                        overlayManager?.showOverlay(null, number)
                    }
                }
            } else if (state == TelephonyManager.EXTRA_STATE_IDLE) {
                overlayManager?.dismissOverlay()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleIncomingCall: ${e.message}")
            e.printStackTrace()
        }
    }
}
