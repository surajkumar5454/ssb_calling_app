package com.example.caller_app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.ImageView
import android.view.ViewGroup
import android.graphics.Color
import android.widget.LinearLayout
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import android.graphics.drawable.GradientDrawable
import android.view.MotionEvent
import kotlin.math.abs
import io.flutter.plugin.common.MethodChannel

class OverlayManager(private val context: Context) {
    companion object {
        private const val CHANNEL = "com.example.caller_app/phone_state"
        var flutterEngine = CallReceiver.flutterEngine
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var initialX: Float = 0f
    private var initialTouchX: Float = 0f
    private var isDismissing = false
    private var isTap = false
    private var startClickTime: Long = 0

    private fun handleTouch(view: View, event: MotionEvent, phoneNumber: String): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                isTap = true
                startClickTime = System.currentTimeMillis()
                initialX = view.x
                initialTouchX = event.rawX
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val moved = abs(event.rawX - initialTouchX)
                if (moved > 10) { // Small threshold to differentiate between tap and swipe
                    isTap = false
                }
                view.x = initialX + event.rawX - initialTouchX
                return true
            }
            MotionEvent.ACTION_UP -> {
                val clickDuration = System.currentTimeMillis() - startClickTime
                val moved = abs(event.rawX - initialTouchX)
                
                when {
                    moved > 100 -> { // Swipe threshold
                        dismissOverlay()
                    }
                    isTap && clickDuration < 200 -> { // Tap threshold
                        // Navigate to contact details
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, CHANNEL).invokeMethod("navigateToContact", phoneNumber)
                        }
                        dismissOverlay()
                    }
                    else -> {
                        view.x = initialX // Reset position
                    }
                }
                return true
            }
            else -> return false
        }
    }

    fun showOverlay(callerInfo: Map<String, Any>?, phoneNumber: String) {
        if (overlayView != null) return

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layout = FrameLayout(context)
        layout.layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
        
        val cardBackground = GradientDrawable()
        cardBackground.setColor(Color.parseColor("#BF2C3E50"))
        cardBackground.cornerRadius = 16f * context.resources.displayMetrics.density
        
        val contentLayout = LinearLayout(context)
        contentLayout.orientation = LinearLayout.HORIZONTAL
        contentLayout.setPadding(32, 24, 32, 24)
        
        val profileIcon = ImageView(context)
        profileIcon.setImageResource(android.R.drawable.ic_dialog_info)
        val iconSize = (48 * context.resources.displayMetrics.density).toInt()
        profileIcon.layoutParams = LinearLayout.LayoutParams(iconSize, iconSize)

        val textContent = LinearLayout(context)
        textContent.orientation = LinearLayout.VERTICAL
        textContent.setPadding((16 * context.resources.displayMetrics.density).toInt(), 0, 0, 0)
        
        if (callerInfo != null) {
            addTextView(textContent, callerInfo["name"]?.toString() ?: "Unknown", 18f, true)
            addTextView(textContent, "${callerInfo["rank"]} - ${callerInfo["branch"]}", 14f)
            addTextView(textContent, "Unit: ${callerInfo["unit"]}", 14f)
            addTextView(textContent, formatPhoneNumber(phoneNumber), 12f)
        } else {
            addTextView(textContent, "Incoming Call", 18f, true)
            addTextView(textContent, formatPhoneNumber(phoneNumber), 16f)
        }

        contentLayout.addView(profileIcon)
        contentLayout.addView(textContent)
        layout.addView(contentLayout)
        layout.background = cardBackground

        layout.setOnTouchListener { view, event -> handleTouch(view, event, phoneNumber) }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )
        
        params.gravity = Gravity.TOP
        params.y = (context.resources.displayMetrics.heightPixels * 0.20).toInt()

        overlayView = layout
        windowManager?.addView(overlayView, params)

        val dismissDelay = if (callerInfo != null) 30000L else 3000L
        Handler(Looper.getMainLooper()).postDelayed({
            dismissOverlay()
        }, dismissDelay)
    }

    private fun addTextView(parent: LinearLayout, text: String, textSize: Float, isBold: Boolean = false) {
        val textView = TextView(context)
        textView.text = text
        textView.setTextColor(Color.WHITE)
        textView.textSize = textSize
        if (isBold) textView.setTypeface(null, android.graphics.Typeface.BOLD)
        parent.addView(textView)
    }

    private fun formatPhoneNumber(number: String): String {
        return if (number.length > 10) number.substring(number.length - 10) else number
    }

    fun dismissOverlay() {
        if (!isDismissing && overlayView != null) {
            isDismissing = true
            try {
                windowManager?.removeView(overlayView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            overlayView = null
            isDismissing = false
        }
    }
}
