package com.example.caller_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class CallReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "CallReceiver"
        private const val CHANNEL = "com.example.caller_app/phone_state"
        private const val NOTIFICATION_CHANNEL_ID = "incoming_calls"
        var flutterEngine: FlutterEngine? = null
    }

    private var overlayManager: OverlayManager? = null
    private var lastState: String? = null
    private var lastNumber: String? = null
    private var currentNotificationId: Int? = null

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

            when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> {
                    if (number.isNullOrEmpty()) {
                        Log.d(TAG, "Empty number in RINGING state")
                        return
                    }

                    // Cancel any existing notifications
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    currentNotificationId?.let {
                        notificationManager.cancel(it)
                    }

                    // Generate new notification ID
                    currentNotificationId = System.currentTimeMillis().toInt()

                    // Show immediate notification
                    showImmediateNotification(context, number)

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
                                            updateNotification(context, number, callerInfo)
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
                }
                TelephonyManager.EXTRA_STATE_IDLE -> {
                    overlayManager?.dismissOverlay()
                    // Cancel notification and release wake lock
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    currentNotificationId?.let {
                        notificationManager.cancel(it)
                        currentNotificationId = null
                    }
                    WakeLockManager.releaseWakeLock()
                    // Clear state
                    lastState = null
                    lastNumber = null
                }
                TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                    // Call was answered, cancel notification
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    currentNotificationId?.let {
                        notificationManager.cancel(it)
                        currentNotificationId = null
                    }
                    WakeLockManager.releaseWakeLock()
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

    private fun showImmediateNotification(context: Context, number: String) {
        // Acquire wake lock to ensure screen turns on
        WakeLockManager.acquireWakeLock(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("phone_number", number)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            currentNotificationId ?: 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setShowBadge(true)
                setBypassDnd(true)
                enableLights(true)
                enableVibration(true)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                importance = NotificationManager.IMPORTANCE_HIGH
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(com.example.caller_app.R.mipmap.ic_launcher)
            .setContentTitle("Incoming Call")
            .setContentText("Unknown number: $number")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_LIGHTS or NotificationCompat.DEFAULT_VIBRATE)
            .setSound(null)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        currentNotificationId?.let {
            notificationManager.notify(it, notification)
        }
    }

    private fun updateNotification(context: Context, number: String, callerInfo: Map<String, Any>?) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("phone_number", number)
            putExtra("caller_info", callerInfo?.toString())
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            currentNotificationId ?: 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = "Incoming Call"
        val body = if (callerInfo != null) {
            Log.d(TAG, "Raw caller info: $callerInfo")  // Debug log
            val name = callerInfo["name"]?.toString() ?: "Unknown"
            val rank = callerInfo["rank"]?.toString() ?: ""
            val unit = callerInfo["unit"]?.toString() ?: ""
            val branch = callerInfo["branch"]?.toString() ?: ""
            val uidno = callerInfo["uidno"]?.toString() ?: ""

            Log.d(TAG, "Parsed fields - name: $name, rank: $rank, unit: $unit, branch: $branch, uidno: $uidno")  // Debug log

            buildString {
                append("$name ($rank)")
                if (uidno.isNotEmpty()) {
                    append("\nUID: $uidno")
                }
                if (unit.isNotEmpty()) {
                    append("\nUnit: $unit")
                }
                if (branch.isNotEmpty()) {
                    append("\nBranch: $branch")
                }
            }
        } else {
            "Unknown number: $number"
        }

        Log.d(TAG, "Final notification body: $body")  // Debug log

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(com.example.caller_app.R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_LIGHTS or NotificationCompat.DEFAULT_VIBRATE)
            .setSound(null)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        currentNotificationId?.let {
            notificationManager.notify(it, notification)
        }
    }
}
