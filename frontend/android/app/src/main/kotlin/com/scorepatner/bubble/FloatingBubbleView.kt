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
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.scorepatner.R
import kotlin.math.hypot

/**
 * Custom Android View for the collapsed floating bubble (Pill Shape).
 *
 * Features:
 * - Pill-shaped design with glassmorphism effect
 * - Shows Live Score directly on the bubble
 * - White background with light orange glow
 * - Draggable with edge-snapping
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

    // UI Elements
    private val container: LinearLayout
    private val tvLiveDot: TextView
    private val tvScore: TextView

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

    private var isLive = false
    private var flashColor: Int? = null

    init {
        setWillNotDraw(false)
        clipChildren = false
        clipToPadding = false

        // Container for text
        container = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(12f), dpToPx(8f), dpToPx(12f), dpToPx(8f))
            layoutParams = LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
        }

        // Live dot
        tvLiveDot = TextView(context).apply {
            text = "●"
            setTextColor(Color.parseColor("#00C853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            setPadding(0, 0, dpToPx(6f), 0)
            visibility = View.GONE
        }
        container.addView(tvLiveDot)

        // App Logo
        val ivIcon = ImageView(context).apply {
            setImageResource(R.mipmap.ic_launcher)
            layoutParams = LinearLayout.LayoutParams(dpToPx(18f), dpToPx(18f)).apply {
                setMargins(0, 0, dpToPx(6f), 0)
            }
        }
        container.addView(ivIcon)

        // Score Text
        tvScore = TextView(context).apply {
            text = "Loading..."
            setTextColor(Color.parseColor("#1A1A2E"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            paint.isFakeBoldText = true
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        container.addView(tvScore)

        // Chevron
        val tvChevron = TextView(context).apply {
            text = "›"
            setTextColor(Color.parseColor("#666666"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setPadding(dpToPx(6f), 0, 0, dpToPx(2f)) // Adjust vertical alignment
        }
        container.addView(tvChevron)

        addView(container)

        // Initial layout params (height fixed, width wrap_content)
        layoutParams = LayoutParams(
            LayoutParams.WRAP_CONTENT,
            dpToPx(44f)
        )
        
        minimumWidth = dpToPx(120f)

        alpha = settings.transparency
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }

    override fun onDraw(canvas: Canvas) {
        val cornerRadius = height / 2f
        val rect = RectF(
            dpToPx(4f).toFloat(), 
            dpToPx(4f).toFloat(), 
            width.toFloat() - dpToPx(4f), 
            height.toFloat() - dpToPx(4f)
        )

        // 1. Draw outer glow
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, glowPaint)

        // 2. Draw white background (or flash color)
        if (flashColor != null) {
            val flashPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                color = flashColor!!
            }
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, flashPaint)
        } else {
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, backgroundPaint)
        }

        // 3. Draw border
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, borderPaint)

        super.onDraw(canvas)
    }

    fun setLiveStatus(live: Boolean) {
        isLive = live
        tvLiveDot.visibility = if (live) View.VISIBLE else View.GONE
        invalidate()
    }

    fun updateScore(text: String) {
        tvScore.text = text
        // Request layout since width might change based on text length
        requestLayout()
    }

    fun setFlashColor(color: Int?) {
        flashColor = color
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
                    longPressRunnable?.let { removeCallbacks(it) }

                    onPositionChanged(
                        initialX + dx.toInt(),
                        initialY + dy.toInt()
                    )
                }
                return true
            }

            MotionEvent.ACTION_UP -> {
                longPressRunnable?.let { removeCallbacks(it) }

                if (!isDragging) {
                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastTapTime < doubleTapTimeout) {
                        tapCount++
                        if (tapCount >= 2) {
                            tapCount = 0
                            onDoubleTap()
                        }
                    } else {
                        tapCount = 1
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

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp,
            context.resources.displayMetrics
        ).toInt()
    }
}
