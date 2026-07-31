package com.scorepatner.bubble

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import com.scorepatner.R
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Custom Android View for the collapsed floating bubble.
 *
 * Features:
 * - Circular design with glassmorphism effect
 * - White background with light orange glow
 * - App icon centered
 * - Draggable with edge-snapping
 * - Avoids system navigation area
 * - Handles single tap, double tap, long press gestures
 */
@SuppressLint("ViewConstructor")
class FloatingBubbleView(
    context: Context,
    private val settings: BubbleSettingsManager,
    private val onSingleTap: () -> Unit,
    private val onDoubleTap: () -> Unit,
    private val onLongPress: (View) -> Unit,
    private val onPositionChanged: (Int, Int) -> Unit
) : FrameLayout(context) {

    // Gesture detection
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var initialX = 0
    private var initialY = 0
    private var isDragging = false
    private var lastTapTime = 0L
    private var tapCount = 0
    private var longPressRunnable: Runnable? = null
    private val longPressTimeout = 500L
    private val doubleTapTimeout = 300L
    private val tapSlop = dpToPx(8f)

    // Glow paint
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#FF8D48")
        maskFilter = BlurMaskFilter(dpToPx(6f).toFloat(), BlurMaskFilter.Blur.OUTER)
    }

    private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.WHITE
    }

    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(1.5f).toFloat()
        color = Color.parseColor("#33FF8D48") // Semi-transparent orange
    }

    // Live status indicator paint
    private val liveDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#FF8D48")
    }

    private var isLive = false

    init {
        setWillNotDraw(false) // Enable custom drawing
        // Disable clipping so glow renders outside bounds
        clipChildren = false
        clipToPadding = false

        // Add app icon
        val iconSize = dpToPx((settings.bubbleSizeDp * 0.55f).toInt().toFloat())
        val icon = ImageView(context).apply {
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.CENTER_CROP
            layoutParams = LayoutParams(iconSize, iconSize).apply {
                gravity = Gravity.CENTER
            }
        }
        addView(icon)

        // Set view size
        val size = dpToPx(settings.bubbleSizeDp.toFloat())
        layoutParams = LayoutParams(size, size)

        // Apply transparency
        alpha = settings.transparency

        // Layer type for blur mask filter
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val radius = (width.coerceAtMost(height) / 2f) - dpToPx(4f)

        // 1. Draw outer glow
        canvas.drawCircle(cx, cy, radius + dpToPx(2f), glowPaint)

        // 2. Draw white circle background
        canvas.drawCircle(cx, cy, radius, backgroundPaint)

        // 3. Draw border
        canvas.drawCircle(cx, cy, radius, borderPaint)

        // 4. Draw live status dot (top-right)
        if (isLive) {
            val dotRadius = dpToPx(4f).toFloat()
            val dotX = cx + radius * 0.65f
            val dotY = cy - radius * 0.65f
            canvas.drawCircle(dotX, dotY, dotRadius + dpToPx(1f), Paint().apply {
                color = Color.WHITE
                isAntiAlias = true
            })
            canvas.drawCircle(dotX, dotY, dotRadius, liveDotPaint)
        }

        super.onDraw(canvas)
    }

    fun setLiveStatus(live: Boolean) {
        isLive = live
        invalidate()
    }

    // ── Touch handling ──────────────────────────────────────

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (settings.isPositionLocked && event.action != MotionEvent.ACTION_DOWN) {
            // Allow tap/long-press but not drag when locked
        }

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                isDragging = false
                initialTouchX = event.rawX
                initialTouchY = event.rawY

                val lp = layoutParams as? WindowManager.LayoutParams
                if (lp != null) {
                    initialX = lp.x
                    initialY = lp.y
                }

                // Schedule long press
                longPressRunnable = Runnable {
                    if (!isDragging) {
                        onLongPress(this)
                    }
                }
                postDelayed(longPressRunnable!!, longPressTimeout)
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                val distance = hypot(dx.toDouble(), dy.toDouble())

                if (distance > tapSlop && !settings.isPositionLocked) {
                    isDragging = true
                    // Cancel long press
                    longPressRunnable?.let { removeCallbacks(it) }

                    onPositionChanged(
                        initialX + dx.toInt(),
                        initialY + dy.toInt()
                    )
                }
                return true
            }

            MotionEvent.ACTION_UP -> {
                // Cancel long press
                longPressRunnable?.let { removeCallbacks(it) }

                if (!isDragging) {
                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastTapTime < doubleTapTimeout) {
                        tapCount++
                        if (tapCount >= 2) {
                            // Double tap detected
                            tapCount = 0
                            onDoubleTap()
                        }
                    } else {
                        tapCount = 1
                        // Delay single tap to wait for possible double tap
                        postDelayed({
                            if (tapCount == 1) {
                                onSingleTap()
                                tapCount = 0
                            }
                        }, doubleTapTimeout)
                    }
                    lastTapTime = currentTime
                }
                isDragging = false
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    // ── Helpers ──────────────────────────────────────────────

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp,
            context.resources.displayMetrics
        ).toInt()
    }
}
