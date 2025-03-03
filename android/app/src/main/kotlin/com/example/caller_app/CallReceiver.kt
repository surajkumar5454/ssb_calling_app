package com.example.caller_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
        if (context == null || intent == null) {
            Log.e(TAG, "Null context or intent")
            return
        }

        Log.d(TAG, "onReceive called with action: ${intent.action}")
        Log.d(TAG, "Intent extras: ${intent.extras?.keySet()?.joinToString { "$it: ${intent.extras?.get(it)}" }}")

        // Get the TelephonyManager
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        
        when (intent.action) {
            TelephonyManager.ACTION_PHONE_STATE_CHANGED,
            Intent.ACTION_NEW_OUTGOING_CALL,
            "android.intent.action.PHONE_STATE" -> {
                handleIncomingCall(context, intent, telephonyManager)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "Handling boot completed")
                val serviceIntent = Intent(context, CallDetectorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }

    private fun handleIncomingCall(context: Context, intent: Intent, telephonyManager: TelephonyManager) {
        try {
            var state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            var number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            // If state is null, try to get it from TelephonyManager
            if (state == null) {
                state = when (telephonyManager.callState) {
                    TelephonyManager.CALL_STATE_RINGING -> TelephonyManager.EXTRA_STATE_RINGING
                    TelephonyManager.CALL_STATE_OFFHOOK -> TelephonyManager.EXTRA_STATE_OFFHOOK
                    else -> TelephonyManager.EXTRA_STATE_IDLE
                }
            }

            Log.d(TAG, "Phone State: $state, Original Number: $number")
            Log.d(TAG, "All extras: ${intent.extras?.keySet()?.joinToString { "$it: ${intent.extras?.get(it)}" }}")

            // Format phone number
            if (!number.isNullOrEmpty()) {
                number = number.replace("\\s+".toRegex(), "")
                if (number.startsWith("+91")) {
                    number = number.substring(3)
                }
                if (number.length > 10) {
                    number = number.substring(number.length - 10)
                }
                Log.d(TAG, "Formatted Number: $number")
            } else {
                // Try to get number from the last state if it's empty
                number = lastNumber
                Log.d(TAG, "Using last known number: $number")
            }

            when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> {
                    Log.d(TAG, "Call is RINGING")
                    if (number.isNullOrEmpty()) {
                        Log.d(TAG, "Empty number in RINGING state")
                        return
                    }

                    // Cancel any existing notifications
                    (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()

                    // Check for overlay permission
                    if (!Settings.canDrawOverlays(context)) {
                        Log.e(TAG, "Overlay permission not granted")
                        return
                    }

                    // Initialize overlay manager if needed
                    if (overlayManager == null) {
                        Log.d(TAG, "Creating new OverlayManager")
                        overlayManager = OverlayManager(context.applicationContext)
                    }

                    // Get caller info from Flutter
                    Handler(Looper.getMainLooper()).post {
                        try {
                            Log.d(TAG, "Getting caller info for number: $number")
                            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                                MethodChannel(messenger, CHANNEL).invokeMethod(
                                    "getCallerInfo",
                                    number,
                                    object : MethodChannel.Result {
                                        override fun success(result: Any?) {
                                            Log.d(TAG, "Got caller info: $result")
                                            @Suppress("UNCHECKED_CAST")
                                            val callerInfo = result as? Map<String, Any>
                                            overlayManager?.showOverlay(callerInfo, number)
                                        }

                                        override fun error(code: String, message: String?, details: Any?) {
                                            Log.e(TAG, "Error getting caller info: $message")
                                            overlayManager?.showOverlay(null, number)
                                        }

                                        override fun notImplemented() {
                                            Log.e(TAG, "getCallerInfo not implemented")
                                            overlayManager?.showOverlay(null, number)
                                        }
                                    }
                                )
                            } ?: run {
                                Log.e(TAG, "FlutterEngine is null, showing overlay with just number")
                                overlayManager?.showOverlay(null, number)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error getting caller info: ${e.message}")
                            e.printStackTrace()
                            overlayManager?.showOverlay(null, number)
                        }
                    }
                }
                TelephonyManager.EXTRA_STATE_IDLE -> {
                    Log.d(TAG, "Call ended")
                    overlayManager?.dismissOverlay()
                    (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
                    lastState = null
                    lastNumber = null
                }
                TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                    Log.d(TAG, "Call answered")
                    overlayManager?.dismissOverlay()
                    (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
                }
            }

            lastState = state
            if (!number.isNullOrEmpty()) {
                lastNumber = number
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleIncomingCall: ${e.message}")
            e.printStackTrace()
        }
    }
}
