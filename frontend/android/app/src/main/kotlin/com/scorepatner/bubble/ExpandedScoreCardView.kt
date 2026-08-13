package com.scorepatner.bubble

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.view.animation.AccelerateDecelerateInterpolator

/**
 * Horizontal floating card that shows detailed live score info.
 * Displayed when the user single-taps the collapsed bubble.
 *
 * Shows: Teams, Score, Overs, CRR, Target Info,
 * Current Batters, Current Bowler, This Over balls, Live Viewers.
 */
@SuppressLint("ViewConstructor")
class ExpandedScoreCardView(
    context: Context,
    private val onDismiss: () -> Unit
) : FrameLayout(context) {

    // Text views for dynamic content
    private val tvMatchHeader: TextView
    private val tvTeam1Name: TextView
    private val tvTeam1Score: TextView
    private val tvTeam2Name: TextView
    private val tvTeam2Score: TextView
    private val tvStats: TextView // CRR / RRR / Target
    private val tvBatter1: TextView
    private val tvBatter2: TextView
    private val tvBowler: TextView
    private val thisOverContainer: LinearLayout
    private val tvViewers: TextView
    private val tvTotalViews: TextView
    private val tvReconnecting: TextView

    // Card container
    private val cardContainer: LinearLayout

    // Colors
    private val primaryOrange = Color.parseColor("#FF8D48")
    private val darkText = Color.parseColor("#1A1A2E")
    private val greyText = Color.parseColor("#666666")
    private val greenColor = Color.parseColor("#4CAF50")
    private val redColor = Color.parseColor("#F44336")

    init {
        // Set up tap-to-dismiss
        setOnClickListener { dismiss() }
        clipChildren = false
        clipToPadding = false

        // Auto-dismiss after 15 seconds
        postDelayed({ dismiss() }, 15000)

        // Card container with glassmorphism styling
        cardContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(16f), dpToPx(14f), dpToPx(16f), dpToPx(14f))
            setBackgroundColor(Color.TRANSPARENT)
        }

        // ── Row 1: Match Header ──
        tvMatchHeader = createText("🏏 Team A vs Team B • LIVE", 11f, primaryOrange, true)
        cardContainer.addView(tvMatchHeader)
        cardContainer.addView(createSpacer(6))

        // ── Row 2: Team 1 score (Batting) ──
        val team1Row = createHorizontalRow()
        tvTeam1Name = createText("Team 1", 14f, darkText, true)
        tvTeam1Score = createText("0/0 (0.0 ov)", 14f, darkText, true)
        team1Row.addView(tvTeam1Name, createWeightParams(1f))
        team1Row.addView(tvTeam1Score)
        cardContainer.addView(team1Row)
        cardContainer.addView(createSpacer(2))

        // ── Row 3: Team 2 score (Bowling) ──
        val team2Row = createHorizontalRow()
        tvTeam2Name = createText("Team 2", 12f, greyText, false)
        tvTeam2Score = createText("0/0 (0.0 ov)", 12f, greyText, false)
        team2Row.addView(tvTeam2Name, createWeightParams(1f))
        team2Row.addView(tvTeam2Score)
        cardContainer.addView(team2Row)
        cardContainer.addView(createSpacer(6))

        // ── Row 4: Stats / Target ──
        tvStats = createText("CRR: 0.00", 11f, primaryOrange, false)
        cardContainer.addView(tvStats)
        cardContainer.addView(createDivider())

        // ── Row 5: Current Batters ──
        val battersRow = createHorizontalRow()
        tvBatter1 = createText("🏏 Batter 1*", 11f, darkText, false)
        tvBatter2 = createText("Batter 2", 11f, greyText, false)
        battersRow.addView(tvBatter1, createWeightParams(1f))
        battersRow.addView(tvBatter2)
        cardContainer.addView(battersRow)
        cardContainer.addView(createSpacer(4))

        // ── Row 6: Bowler ──
        tvBowler = createText("⚾ Bowler", 11f, darkText, false)
        cardContainer.addView(tvBowler)
        cardContainer.addView(createSpacer(6))

        // ── Row 7: This Over ──
        val thisOverRow = createHorizontalRow()
        thisOverRow.addView(createText("This Over: ", 11f, greyText, false))
        thisOverContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        thisOverRow.addView(thisOverContainer)
        cardContainer.addView(thisOverRow)
        cardContainer.addView(createDivider())

        // ── Row 8: Viewers ──
        val viewerRow = createHorizontalRow()
        tvViewers = createText("👁 0 watching", 10f, greyText, false)
        tvTotalViews = createText("📊 0 views", 10f, greyText, false)
        viewerRow.addView(tvViewers, createWeightParams(1f))
        viewerRow.addView(tvTotalViews)
        cardContainer.addView(viewerRow)

        // ── Reconnecting banner (hidden by default) ──
        tvReconnecting = createText("⏳ Reconnecting...", 10f, redColor, true).apply {
            visibility = View.GONE
            setBackgroundColor(Color.parseColor("#20F44336"))
            setPadding(dpToPx(4f), dpToPx(2f), dpToPx(4f), dpToPx(2f))
        }
        cardContainer.addView(tvReconnecting)

        // Wrap card in a styled frame
        addView(cardContainer, LayoutParams(
            dpToPx(300f), LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        })

        // Start invisible for animation
        alpha = 0f
        scaleX = 0.5f
        scaleY = 0.5f
    }

    override fun dispatchDraw(canvas: Canvas) {
        // Draw glassmorphism background
        val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
        val cornerRadius = dpToPx(20f).toFloat()

        // Shadow
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#20000000")
            maskFilter = BlurMaskFilter(dpToPx(8f).toFloat(), BlurMaskFilter.Blur.NORMAL)
        }
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, shadowPaint)

        // White background with slight transparency
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FAFFFFFF")
        }
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, bgPaint)

        // Orange glow border
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dpToPx(1f).toFloat()
            color = Color.parseColor("#40FF8D48")
        }
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, borderPaint)

        super.dispatchDraw(canvas)
    }

    // ── Public update methods ───────────────────────────────

    fun updateMatchData(data: Map<String, Any?>) {
        val team1Name = data["team1Name"] as? String ?: "Team 1"
        val team2Name = data["team2Name"] as? String ?: "Team 2"
        val team1Runs = (data["team1Runs"] as? Number)?.toInt() ?: 0
        val team1Wickets = (data["team1Wickets"] as? Number)?.toInt() ?: 0
        val team1Overs = (data["team1Overs"] as? Number)?.toDouble() ?: 0.0
        val team2Runs = (data["team2Runs"] as? Number)?.toInt() ?: 0
        val team2Wickets = (data["team2Wickets"] as? Number)?.toInt() ?: 0
        val team2Overs = (data["team2Overs"] as? Number)?.toDouble() ?: 0.0
        val crr = (data["crr"] as? Number)?.toDouble() ?: 0.0
        val status = data["status"] as? String ?: "live"
        val currentBattingTeam = data["currentBattingTeam"] as? String ?: "team1"
        val batter1 = data["batter1"] as? String ?: "-"
        val batter2 = data["batter2"] as? String ?: "-"
        val bowler = data["bowler"] as? String ?: "-"
        val liveViewers = (data["liveViewers"] as? Number)?.toInt() ?: 0
        val totalViews = (data["totalViews"] as? Number)?.toInt() ?: 0
        
        val targetInfo = data["targetInfo"] as? String ?: ""
        @Suppress("UNCHECKED_CAST")
        val thisOver = data["thisOver"] as? List<String> ?: emptyList()

        val statusText = if (status == "live") "LIVE 🟢" else status.uppercase()
        tvMatchHeader.text = "🏏 $team1Name vs $team2Name • $statusText"

        // Highlight batting team
        val isTeam1Batting = currentBattingTeam == "team1"
        tvTeam1Name.text = team1Name
        tvTeam1Score.text = "$team1Runs/$team1Wickets (${formatOvers(team1Overs)} ov)"
        tvTeam1Name.setTextColor(if (isTeam1Batting) darkText else greyText)
        tvTeam1Score.setTextColor(if (isTeam1Batting) darkText else greyText)
        tvTeam1Name.paint.isFakeBoldText = isTeam1Batting
        tvTeam1Score.paint.isFakeBoldText = isTeam1Batting

        tvTeam2Name.text = team2Name
        tvTeam2Score.text = "$team2Runs/$team2Wickets (${formatOvers(team2Overs)} ov)"
        tvTeam2Name.setTextColor(if (!isTeam1Batting) darkText else greyText)
        tvTeam2Score.setTextColor(if (!isTeam1Batting) darkText else greyText)
        tvTeam2Name.paint.isFakeBoldText = !isTeam1Batting
        tvTeam2Score.paint.isFakeBoldText = !isTeam1Batting

        if (targetInfo.isNotEmpty()) {
            tvStats.text = "CRR: ${String.format("%.2f", crr)}  •  $targetInfo"
        } else {
            tvStats.text = "CRR: ${String.format("%.2f", crr)}"
        }

        tvBatter1.text = "🏏 $batter1*"
        tvBatter2.text = batter2
        tvBowler.text = "⚾ $bowler"
        tvViewers.text = "👁 $liveViewers watching"
        tvTotalViews.text = "📊 $totalViews views"
        
        updateThisOver(thisOver)
    }
    
    private fun updateThisOver(balls: List<String>) {
        thisOverContainer.removeAllViews()
        for (ball in balls) {
            val tv = TextView(context).apply {
                text = ball
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                gravity = Gravity.CENTER
                setPadding(dpToPx(4f), dpToPx(1f), dpToPx(4f), dpToPx(1f))
                
                val bgColor = when (ball) {
                    "4" -> Color.parseColor("#4CAF50") // Green
                    "6" -> Color.parseColor("#FFC107") // Gold
                    "W" -> Color.parseColor("#F44336") // Red
                    else -> Color.parseColor("#9E9E9E") // Grey
                }
                
                // Draw rounded rect background
                background = object : android.graphics.drawable.ShapeDrawable(android.graphics.drawable.shapes.RoundRectShape(FloatArray(8) { dpToPx(4f).toFloat() }, null, null)) {
                    init { paint.color = bgColor }
                }
                
                layoutParams = LinearLayout.LayoutParams(
                    dpToPx(18f), dpToPx(18f)
                ).apply {
                    marginEnd = dpToPx(4f)
                }
            }
            thisOverContainer.addView(tv)
        }
    }

    fun showReconnecting(show: Boolean) {
        tvReconnecting.visibility = if (show) View.VISIBLE else View.GONE
    }

    // ── Animations ──────────────────────────────────────────

    fun animateIn() {
        animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(250)
            .setInterpolator(AccelerateDecelerateInterpolator())
            .start()
    }

    fun dismiss() {
        animate()
            .alpha(0f)
            .scaleX(0.5f)
            .scaleY(0.5f)
            .setDuration(200)
            .setInterpolator(AccelerateDecelerateInterpolator())
            .withEndAction { onDismiss() }
            .start()
    }

    // ── Helper methods ──────────────────────────────────────

    private fun createText(
        text: String,
        sizeSp: Float,
        color: Int,
        bold: Boolean
    ): TextView {
        return TextView(context).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            setTextColor(color)
            if (bold) paint.isFakeBoldText = true
            setPadding(0, dpToPx(1f), 0, dpToPx(1f))
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
    }

    private fun createHorizontalRow(): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun createWeightParams(weight: Float): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT, weight
        )
    }

    private fun createSpacer(heightDp: Int): View {
        return View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(heightDp.toFloat())
            )
        }
    }

    private fun createHSpacer(widthDp: Int): View {
        return View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                dpToPx(widthDp.toFloat()),
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun createDivider(): View {
        return View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(1f)
            ).apply {
                topMargin = dpToPx(6f)
                bottomMargin = dpToPx(6f)
            }
            setBackgroundColor(Color.parseColor("#15000000"))
        }
    }

    private fun formatOvers(overs: Double): String {
        val completed = overs.toInt()
        val balls = ((overs - completed) * 10).toInt()
        return if (balls > 0) "$completed.$balls" else "$completed.0"
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp,
            context.resources.displayMetrics
        ).toInt()
    }
}
