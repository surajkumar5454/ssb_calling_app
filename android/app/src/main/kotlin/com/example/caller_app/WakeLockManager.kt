package com.example.caller_app

import android.content.Context
import android.os.PowerManager
import android.util.Log

object WakeLockManager {
    private var wakeLock: PowerManager.WakeLock? = null
    private const val TAG = "WakeLockManager"

    fun acquireWakeLock(context: Context) {
        if (wakeLock == null) {
            try {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.FULL_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "CallerApp:WakeLock"
                )
                wakeLock?.acquire(10*60*1000L) // 10 minutes max
            } catch (e: Exception) {
                Log.e(TAG, "Error acquiring wake lock: ${e.message}")
            }
        }
    }

    fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}")
        }
    }
}
