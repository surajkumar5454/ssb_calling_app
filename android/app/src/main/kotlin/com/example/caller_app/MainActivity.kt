package com.example.caller_app

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.content.Context
import android.net.Uri
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.caller_app/phone_state"
    private val REQUEST_CODE_SET_DEFAULT_DIALER = 123
    companion object {
        private const val OVERLAY_PERMISSION_REQ_CODE = 1234
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Store FlutterEngine reference for the BroadcastReceiver
        CallReceiver.flutterEngine = flutterEngine

        // Check for overlay permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${packageName}")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
        }

        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    // Request dialer role if needed
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                        if (!roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                            startActivityForResult(intent, REQUEST_CODE_SET_DEFAULT_DIALER)
                        }
                    }
                    
                    // Start the foreground service
                    startService(Intent(this, CallDetectorService::class.java))
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == OVERLAY_PERMISSION_REQ_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                // Permission denied
                Log.e("MainActivity", "Overlay permission denied")
            }
        }
        if (requestCode == REQUEST_CODE_SET_DEFAULT_DIALER) {
            // Start service regardless of the result
            startService(Intent(this, CallDetectorService::class.java))
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        CallReceiver.flutterEngine = null
    }
}
