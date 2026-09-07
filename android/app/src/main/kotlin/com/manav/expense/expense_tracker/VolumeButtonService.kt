package com.manav.expense.expense_tracker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class VolumeButtonService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var isLongPressTriggered = false
    private var isKeyDown = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            val info = serviceInfo ?: AccessibilityServiceInfo()
            info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            info.notificationTimeout = 100
            info.flags = info.flags or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            serviceInfo = info
            Log.d("VolumeButtonService", "onServiceConnected: Key event filtering active")
        } catch (e: Exception) {
            Log.e("VolumeButtonService", "Error in onServiceConnected", e)
        }
    }

    private val longPressRunnable = Runnable {
        isLongPressTriggered = true
        Log.d("VolumeButtonService", "Volume Down Long Press detected! Launching popup...")

        // 1. Gentle haptic feedback
        vibratePhone()

        // 2. Launch floating QuickAddActivity popup
        launchQuickAddDialog()
    }

    private fun launchQuickAddDialog() {
        try {
            val intent = Intent(this, QuickAddActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }

            // Using PendingIntent bypasses background start restrictions on Android 10+
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            pendingIntent.send()
        } catch (e: Exception) {
            Log.e("VolumeButtonService", "PendingIntent failed, fallback to startActivity", e)
            try {
                val intent = Intent(this, QuickAddActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (ex: Exception) {
                Log.e("VolumeButtonService", "startActivity also failed", ex)
            }
        }
    }

    private fun vibratePhone() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator?.vibrate(
                    VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(50)
                }
            }
        } catch (e: Exception) {
            Log.w("VolumeButtonService", "Could not vibrate", e)
        }
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode

        // Listen for Volume Down button
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (event.repeatCount == 0 && !isKeyDown) {
                        isKeyDown = true
                        isLongPressTriggered = false
                        // 500ms long-press hold threshold
                        handler.postDelayed(longPressRunnable, 500)
                    }
                    return isLongPressTriggered
                }
                KeyEvent.ACTION_UP -> {
                    isKeyDown = false
                    handler.removeCallbacks(longPressRunnable)
                    if (isLongPressTriggered) {
                        isLongPressTriggered = false
                        return true // Consume event so volume doesn't change
                    } else {
                        // Normal short tap: adjust volume normally
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        audioManager?.adjustVolume(AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                        return true
                    }
                }
            }
        }

        return super.onKeyEvent(event)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for key events
    }

    override fun onInterrupt() {
        handler.removeCallbacks(longPressRunnable)
        isLongPressTriggered = false
        isKeyDown = false
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(longPressRunnable)
    }
}
