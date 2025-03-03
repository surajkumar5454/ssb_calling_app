package com.example.caller_app

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.content.IntentFilter
import android.telephony.TelephonyManager
import android.provider.Settings
import android.net.Uri
import android.util.Log
import android.content.Context

class CallDetectorService : Service() {
    private val CHANNEL_ID = "CallerAppService"
    private val NOTIFICATION_ID = 1
    private var callReceiver: CallReceiver? = null

    companion object {
        private const val TAG = "CallDetectorService"
        
        fun clearAllNotifications(context: Service) {
            try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancelAll()
                Log.d(TAG, "Cleared all notifications")
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing notifications: ${e.message}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        createNotificationChannel()
        
        // Clear any existing notifications
        clearAllNotifications(this)
        
        // Check for overlay permission
        if (!Settings.canDrawOverlays(this)) {
            Log.d(TAG, "No overlay permission, requesting...")
            requestOverlayPermission()
            return
        }
        
        // Register call receiver with all necessary actions
        callReceiver = CallReceiver().also { receiver ->
            val filter = IntentFilter().apply {
                addAction(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
                addAction(Intent.ACTION_NEW_OUTGOING_CALL)
                addAction("android.intent.action.PHONE_STATE")
                priority = IntentFilter.SYSTEM_HIGH_PRIORITY
            }
            try {
                registerReceiver(receiver, filter)
                Log.d(TAG, "Successfully registered CallReceiver")
            } catch (e: Exception) {
                Log.e(TAG, "Error registering CallReceiver: ${e.message}")
            }
        }
        
        // Start as foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }
        Log.d(TAG, "Service started in foreground")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand with action: ${intent?.action}")
        
        when (intent?.action) {
            "REQUEST_OVERLAY_PERMISSION" -> {
                requestOverlayPermission()
                return START_NOT_STICKY
            }
            "CLEAR_NOTIFICATIONS" -> {
                clearAllNotifications(this)
                return START_STICKY
            }
        }

        // Re-register receiver if needed
        if (callReceiver == null) {
            callReceiver = CallReceiver().also { receiver ->
                val filter = IntentFilter().apply {
                    addAction(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
                    addAction(Intent.ACTION_NEW_OUTGOING_CALL)
                    addAction("android.intent.action.PHONE_STATE")
                    priority = IntentFilter.SYSTEM_HIGH_PRIORITY
                }
                try {
                    registerReceiver(receiver, filter)
                    Log.d(TAG, "Re-registered CallReceiver")
                } catch (e: Exception) {
                    Log.e(TAG, "Error re-registering CallReceiver: ${e.message}")
                }
            }
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Caller App Service"
            val descriptionText = "Service to detect incoming calls"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Created notification channel")
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Caller App Running")
            .setContentText("Monitoring for incoming calls")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSound(null)
            .setShowWhen(false)
            .build()
    }

    private fun requestOverlayPermission() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        ).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service onDestroy")
        
        // Clear all notifications before destroying
        clearAllNotifications(this)
        
        callReceiver?.let {
            try {
                unregisterReceiver(it)
                Log.d(TAG, "Successfully unregistered CallReceiver")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering CallReceiver: ${e.message}")
            }
        }
        
        // Restart service
        val intent = Intent(applicationContext, CallDetectorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d(TAG, "Restarting service")
    }
}
