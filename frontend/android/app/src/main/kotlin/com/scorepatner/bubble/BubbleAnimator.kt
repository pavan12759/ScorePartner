package com.scorepatner.bubble

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.animation.ArgbEvaluator
import android.graphics.Color
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.OvershootInterpolator

/**
 * Handles match event animations on the floating bubble.
 * All animations run on the main thread using ValueAnimator for 60 FPS smoothness.
 */
class BubbleAnimator(private val context: Context) {

    private val settings = BubbleSettingsManager(context)

    /**
     * Four — green flash pulse.
     */
    fun animateFour(view: FloatingBubbleView) {
        val green = Color.parseColor("#4CAF50")
        
        val scaleX = ObjectAnimator.ofFloat(view, View.SCALE_X, 1f, 1.05f, 1f).apply {
            duration = 400
            interpolator = OvershootInterpolator(1f)
        }
        val scaleY = ObjectAnimator.ofFloat(view, View.SCALE_Y, 1f, 1.05f, 1f).apply {
            duration = 400
            interpolator = OvershootInterpolator(1f)
        }
        
        val colorAnim = ValueAnimator.ofObject(ArgbEvaluator(), Color.WHITE, green, Color.WHITE).apply {
            duration = 400
            addUpdateListener { animator -> 
                view.setFlashColor(animator.animatedValue as Int)
            }
        }
        
        AnimatorSet().apply {
            playTogether(scaleX, scaleY, colorAnim)
            start()
        }
    }

    /**
     * Six — golden burst flash.
     */
    fun animateSix(view: FloatingBubbleView) {
        val gold = Color.parseColor("#FFC107")
        
        val scaleX = ObjectAnimator.ofFloat(view, View.SCALE_X, 1f, 1.1f, 1f).apply {
            duration = 500
            interpolator = OvershootInterpolator(2f)
        }
        val scaleY = ObjectAnimator.ofFloat(view, View.SCALE_Y, 1f, 1.1f, 1f).apply {
            duration = 500
            interpolator = OvershootInterpolator(2f)
        }
        
        val colorAnim = ValueAnimator.ofObject(ArgbEvaluator(), Color.WHITE, gold, Color.WHITE).apply {
            duration = 500
            addUpdateListener { animator -> 
                view.setFlashColor(animator.animatedValue as Int)
            }
        }
        
        AnimatorSet().apply {
            playTogether(scaleX, scaleY, colorAnim)
            start()
        }
    }

    /**
     * Wicket — red shake flash.
     */
    fun animateWicket(view: FloatingBubbleView) {
        val red = Color.parseColor("#F44336")
        
        val shake = ObjectAnimator.ofFloat(
            view, View.TRANSLATION_X,
            0f, -10f, 10f, -8f, 8f, -5f, 5f, 0f
        ).apply {
            duration = 500
        }
        
        val colorAnim = ValueAnimator.ofObject(ArgbEvaluator(), Color.WHITE, red, Color.WHITE).apply {
            duration = 500
            addUpdateListener { animator -> 
                view.setFlashColor(animator.animatedValue as Int)
            }
        }
        
        AnimatorSet().apply {
            playTogether(shake, colorAnim)
            start()
        }

        if (settings.vibrateOnWickets) {
            vibrate(200)
        }
    }

    /**
     * Fifty — pulsing celebration.
     */
    fun animateFifty(view: View) {
        val pulse = ObjectAnimator.ofFloat(view, View.SCALE_X, 1f, 1.2f, 1f, 1.15f, 1f).apply {
            duration = 600
            interpolator = AccelerateDecelerateInterpolator()
        }
        val pulseY = ObjectAnimator.ofFloat(view, View.SCALE_Y, 1f, 1.2f, 1f, 1.15f, 1f).apply {
            duration = 600
            interpolator = AccelerateDecelerateInterpolator()
        }
        AnimatorSet().apply {
            playTogether(pulse, pulseY)
            start()
        }
    }

    /**
     * Century — larger burst with rotation.
     */
    fun animateCentury(view: View) {
        val scaleX = ObjectAnimator.ofFloat(view, View.SCALE_X, 1f, 1.6f, 1f).apply {
            duration = 700
            interpolator = OvershootInterpolator(2.5f)
        }
        val scaleY = ObjectAnimator.ofFloat(view, View.SCALE_Y, 1f, 1.6f, 1f).apply {
            duration = 700
            interpolator = OvershootInterpolator(2.5f)
        }
        val rotation = ObjectAnimator.ofFloat(view, View.ROTATION, 0f, 360f).apply {
            duration = 700
            interpolator = AccelerateDecelerateInterpolator()
        }
        AnimatorSet().apply {
            playTogether(scaleX, scaleY, rotation)
            start()
        }
    }

    /**
     * Innings End — fade sweep.
     */
    fun animateInningsEnd(view: View) {
        val fadeOut = ObjectAnimator.ofFloat(view, View.ALPHA, 1f, 0.4f).apply {
            duration = 300
        }
        val fadeIn = ObjectAnimator.ofFloat(view, View.ALPHA, 0.4f, 1f).apply {
            duration = 300
        }
        AnimatorSet().apply {
            playSequentially(fadeOut, fadeIn)
            start()
        }
    }

    /**
     * Match End — graceful fade out (caller should remove view after).
     */
    fun animateMatchEnd(view: View, onComplete: () -> Unit) {
        val scaleDown = ObjectAnimator.ofFloat(view, View.SCALE_X, 1f, 0f).apply {
            duration = 500
        }
        val scaleDownY = ObjectAnimator.ofFloat(view, View.SCALE_Y, 1f, 0f).apply {
            duration = 500
        }
        val fadeOut = ObjectAnimator.ofFloat(view, View.ALPHA, 1f, 0f).apply {
            duration = 500
        }
        AnimatorSet().apply {
            playTogether(scaleDown, scaleDownY, fadeOut)
            start()
        }
        // Give time for animation to complete
        view.postDelayed({ onComplete() }, 550)
    }

    /**
     * Generic pulse animation (used for general updates).
     */
    fun pulseOnce(view: View) {
        val scaleX = ObjectAnimator.ofFloat(view, View.SCALE_X, 1f, 1.1f, 1f).apply {
            duration = 250
        }
        val scaleY = ObjectAnimator.ofFloat(view, View.SCALE_Y, 1f, 1.1f, 1f).apply {
            duration = 250
        }
        AnimatorSet().apply {
            playTogether(scaleX, scaleY)
            start()
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate(durationMs: Long) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                    as? VibratorManager
                vibratorManager?.defaultVibrator?.vibrate(
                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(
                        VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                    )
                } else {
                    vibrator?.vibrate(durationMs)
                }
            }
        } catch (e: Exception) {
            // Silently ignore vibration errors
        }
    }
}
