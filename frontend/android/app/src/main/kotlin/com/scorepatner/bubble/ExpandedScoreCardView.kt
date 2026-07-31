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
 * Shows: Teams, Score, Overs, CRR, RRR, Live Status,
 * Current Batters, Current Bowler, Last Ball, Live Viewers, Total Views.
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
    private val tvOvers: TextView
    private val tvCrr: TextView
    private val tvRrr: TextView
    private val tvStatus: TextView
    private val tvBatter1: TextView
    private val tvBatter2: TextView
    private val tvBowler: TextView
    private val tvLastBall: TextView
    private val tvViewers: TextView
    private val tvTotalViews: TextView
    private val tvReconnecting: TextView

    // Card container
    private val cardContainer: LinearLayout

    // Colors
    private val primaryOrange = Color.parseColor("#FF8D48")
    private val lightOrangeBg = Color.parseColor("#FFF5EE")
    private val darkText = Color.parseColor("#1A1A2E")
    private val greyText = Color.parseColor("#666666")
    private val greenColor = Color.parseColor("#4CAF50")
    private val redColor = Color.parseColor("#F44336")

    init {
        // Set up tap-to-dismiss
        setOnClickListener { dismiss() }
        clipChildren = false
        clipToPadding = false

        // Auto-dismiss after 10 seconds
        postDelayed({ dismiss() }, 10000)

        // Card container with glassmorphism styling
        cardContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(14f), dpToPx(10f), dpToPx(14f), dpToPx(10f))
            setBackgroundColor(Color.TRANSPARENT)
        }

        // Build the card layout
        // ── Row 1: Match Header ──
        tvMatchHeader = createText("🏏 Team A vs Team B", 11f, primaryOrange, true)
        cardContainer.addView(tvMatchHeader)
        cardContainer.addView(createSpacer(3))

        // ── Row 2: Team 1 score ──
        val team1Row = createHorizontalRow()
        tvTeam1Name = createText("Team 1", 12f, darkText, true)
        tvTeam1Score = createText("0/0 (0.0)", 12f, darkText, true)
        team1Row.addView(tvTeam1Name, createWeightParams(1f))
        team1Row.addView(tvTeam1Score)
        cardContainer.addView(team1Row)

        // ── Row 3: Team 2 score ──
        val team2Row = createHorizontalRow()
        tvTeam2Name = createText("Team 2", 12f, greyText, false)
        tvTeam2Score = createText("0/0 (0.0)", 12f, greyText, false)
        team2Row.addView(tvTeam2Name, createWeightParams(1f))
        team2Row.addView(tvTeam2Score)
        cardContainer.addView(team2Row)
        cardContainer.addView(createSpacer(4))

        // ── Row 4: CRR / RRR / Status ──
        val statsRow = createHorizontalRow()
        tvCrr = createText("CRR: 0.00", 9f, greyText, false)
        tvRrr = createText("", 9f, primaryOrange, false)
        tvOvers = createText("", 9f, greyText, false)
        tvStatus = createText("● LIVE", 9f, greenColor, true)
        statsRow.addView(tvCrr, createWeightParams(1f))
        statsRow.addView(tvRrr)
        statsRow.addView(createHSpacer(8))
        statsRow.addView(tvStatus)
        cardContainer.addView(statsRow)
        cardContainer.addView(createDivider())

        // ── Row 5: Current Batters ──
        val battersRow = createHorizontalRow()
        tvBatter1 = createText("🏏 Batter 1*", 9f, darkText, false)
        tvBatter2 = createText("Batter 2", 9f, greyText, false)
        battersRow.addView(tvBatter1, createWeightParams(1f))
        battersRow.addView(tvBatter2)
        cardContainer.addView(battersRow)

        // ── Row 6: Bowler + Last Ball ──
        val bowlerRow = createHorizontalRow()
        tvBowler = createText("⚾ Bowler", 9f, darkText, false)
        tvLastBall = createText("Last: -", 9f, greyText, false)
        bowlerRow.addView(tvBowler, createWeightParams(1f))
        bowlerRow.addView(tvLastBall)
        cardContainer.addView(bowlerRow)
        cardContainer.addView(createDivider())

        // ── Row 7: Viewers ──
        val viewerRow = createHorizontalRow()
        tvViewers = createText("👁 0 watching", 8f, greyText, false)
        tvTotalViews = createText("📊 0 views", 8f, greyText, false)
        viewerRow.addView(tvViewers, createWeightParams(1f))
        viewerRow.addView(tvTotalViews)
        cardContainer.addView(viewerRow)

        // ── Reconnecting banner (hidden by default) ──
        tvReconnecting = createText("⏳ Reconnecting...", 9f, redColor, true).apply {
            visibility = View.GONE
            setBackgroundColor(Color.parseColor("#20F44336"))
            setPadding(dpToPx(4f), dpToPx(2f), dpToPx(4f), dpToPx(2f))
        }
        cardContainer.addView(tvReconnecting)

        // Wrap card in a styled frame
        addView(cardContainer, LayoutParams(
            dpToPx(280f), LayoutParams.WRAP_CONTENT
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
        val cornerRadius = dpToPx(16f).toFloat()

        // Shadow
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#20000000")
            maskFilter = BlurMaskFilter(dpToPx(8f).toFloat(), BlurMaskFilter.Blur.NORMAL)
        }
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, shadowPaint)

        // White background with slight transparency
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#F5FFFFFF")
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
        val rrr = (data["rrr"] as? Number)?.toDouble() ?: 0.0
        val status = data["status"] as? String ?: "live"
        val currentBattingTeam = data["currentBattingTeam"] as? String ?: "team1"
        val batter1 = data["batter1"] as? String ?: "-"
        val batter2 = data["batter2"] as? String ?: "-"
        val bowler = data["bowler"] as? String ?: "-"
        val lastBall = data["lastBall"] as? String ?: "-"
        val liveViewers = (data["liveViewers"] as? Number)?.toInt() ?: 0
        val totalViews = (data["totalViews"] as? Number)?.toInt() ?: 0

        tvMatchHeader.text = "🏏 $team1Name vs $team2Name"

        // Highlight batting team
        val isTeam1Batting = currentBattingTeam == "team1"
        tvTeam1Name.text = team1Name
        tvTeam1Score.text = "$team1Runs/$team1Wickets (${formatOvers(team1Overs)})"
        tvTeam1Name.setTextColor(if (isTeam1Batting) darkText else greyText)
        tvTeam1Score.setTextColor(if (isTeam1Batting) darkText else greyText)
        tvTeam1Name.paint.isFakeBoldText = isTeam1Batting

        tvTeam2Name.text = team2Name
        tvTeam2Score.text = "$team2Runs/$team2Wickets (${formatOvers(team2Overs)})"
        tvTeam2Name.setTextColor(if (!isTeam1Batting) darkText else greyText)
        tvTeam2Score.setTextColor(if (!isTeam1Batting) darkText else greyText)
        tvTeam2Name.paint.isFakeBoldText = !isTeam1Batting

        tvCrr.text = "CRR: ${String.format("%.2f", crr)}"
        tvRrr.text = if (rrr > 0) "RRR: ${String.format("%.2f", rrr)}" else ""

        when (status) {
            "live" -> {
                tvStatus.text = "● LIVE"
                tvStatus.setTextColor(greenColor)
            }
            "completed" -> {
                tvStatus.text = "✓ COMPLETED"
                tvStatus.setTextColor(greyText)
            }
            else -> {
                tvStatus.text = status.uppercase()
                tvStatus.setTextColor(greyText)
            }
        }

        tvBatter1.text = "🏏 $batter1*"
        tvBatter2.text = batter2
        tvBowler.text = "⚾ $bowler"
        tvLastBall.text = "Last: $lastBall"
        tvViewers.text = "👁 $liveViewers watching"
        tvTotalViews.text = "📊 $totalViews views"
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
                topMargin = dpToPx(4f)
                bottomMargin = dpToPx(4f)
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
