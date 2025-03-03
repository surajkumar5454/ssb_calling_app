package com.example.caller_app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.MotionEvent
import android.widget.Button
import android.content.Intent
import android.view.animation.AnimationUtils

class OverlayManager(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    
    companion object {
        private const val TAG = "OverlayManager"
    }

    init {
        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            Log.d(TAG, "OverlayManager initialized with context: ${context.javaClass.simpleName}")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing OverlayManager: ${e.message}")
            e.printStackTrace()
        }
    }

    fun showOverlay(callerInfo: Map<String, Any>?, phoneNumber: String) {
        try {
            Log.d(TAG, "Showing overlay for number: $phoneNumber")
            dismissOverlay() // Remove any existing overlay first
            
            val inflater = LayoutInflater.from(context)
            val view = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(32, 32, 32, 32)
                setBackgroundResource(android.R.drawable.dialog_holo_light_frame)
            }

            // Profile image
            val profileIcon = ImageView(context).apply {
                setImageResource(android.R.drawable.ic_dialog_info)
                val size = (64 * context.resources.displayMetrics.density).toInt()
                layoutParams = LinearLayout.LayoutParams(size, size)
            }
            view.addView(profileIcon)

            // Name and details
            val detailsText = TextView(context).apply {
                if (callerInfo != null) {
                    text = buildString {
                        append(callerInfo["name"]?.toString() ?: "Unknown")
                        append("\n")
                        append(callerInfo["rank"]?.toString() ?: "")
                        append("\n")
                        append(callerInfo["unit"]?.toString() ?: "")
                        if (!callerInfo["branch"]?.toString().isNullOrEmpty()) {
                            append("\n")
                            append(callerInfo["branch"])
                        }
                    }
                } else {
                    text = "Unknown Caller\n$phoneNumber"
                }
                textSize = 18f
                gravity = Gravity.CENTER
                setPadding(16, 16, 16, 16)
            }
            view.addView(detailsText)

            // Buttons container
            val buttonsLayout = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
                    topMargin = (16 * context.resources.displayMetrics.density).toInt()
                }
            }

            // View Details button
            val viewDetailsButton = Button(context).apply {
                text = "View Details"
                setOnClickListener {
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("phone_number", phoneNumber)
                    }
                    context.startActivity(intent)
                    dismissOverlay()
                }
            }
            buttonsLayout.addView(viewDetailsButton)

            // Dismiss button
            val dismissButton = Button(context).apply {
                text = "Dismiss"
                setOnClickListener {
                    dismissOverlay()
                }
            }
            buttonsLayout.addView(dismissButton)

            view.addView(buttonsLayout)

            // Add touch listener for dragging
            view.setOnTouchListener(object : View.OnTouchListener {
                private var initialX: Int = 0
                private var initialY: Int = 0
                private var initialTouchX: Float = 0f
                private var initialTouchY: Float = 0f

                override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                    when (event?.action) {
                        MotionEvent.ACTION_DOWN -> {
                            initialX = params.x
                            initialY = params.y
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            params.x = initialX + (event.rawX - initialTouchX).toInt()
                            params.y = initialY + (event.rawY - initialTouchY).toInt()
                            windowManager?.updateViewLayout(view, params)
                            return true
                        }
                    }
                    return false
                }
            })

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 0
                y = 100
            }

            try {
                windowManager?.addView(view, params)
                overlayView = view
                
                // Add entrance animation
                view.startAnimation(AnimationUtils.loadAnimation(context, android.R.anim.fade_in))
                
                Log.d(TAG, "Overlay shown successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error showing overlay: ${e.message}")
                e.printStackTrace()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in showOverlay: ${e.message}")
            e.printStackTrace()
        }
    }

    fun dismissOverlay() {
        try {
            overlayView?.let { view ->
                try {
                    // Add exit animation
                    val anim = AnimationUtils.loadAnimation(context, android.R.anim.fade_out)
                    anim.duration = 200
                    view.startAnimation(anim)
                    
                    handler.postDelayed({
                        try {
                            windowManager?.removeView(view)
                            overlayView = null
                            Log.d(TAG, "Overlay dismissed successfully")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error removing overlay view: ${e.message}")
                        }
                    }, 200)
                } catch (e: Exception) {
                    Log.e(TAG, "Error animating overlay dismissal: ${e.message}")
                    // Fallback to immediate removal
                    try {
                        windowManager?.removeView(view)
                        overlayView = null
                    } catch (e2: Exception) {
                        Log.e(TAG, "Error in fallback overlay removal: ${e2.message}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in dismissOverlay: ${e.message}")
            e.printStackTrace()
        }
    }
}
