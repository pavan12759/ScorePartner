package com.scorepatner.bubble

import android.annotation.SuppressLint
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.PixelFormat
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.PopupMenu
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.scorepatner.MainActivity

/**
 * Foreground service that manages the floating live score bubble overlay.
 *
 * Lifecycle:
 * 1. Started via intent with EXTRA_MATCH_ID
 * 2. Creates foreground notification
 * 3. Adds overlay bubble to WindowManager
 * 4. Attaches Firestore snapshot listener for live match data
 * 5. Updates bubble + expanded card in real time
 * 6. Auto-stops when match ends (if autoClose enabled)
 * 7. Stops via intent action or notification button
 */
class FloatingBubbleService : Service() {

    companion object {
        private const val TAG = "FloatingBubbleService"

        const val EXTRA_MATCH_ID = "match_id"
        const val ACTION_STOP = "com.scorepatner.STOP_BUBBLE"
        const val ACTION_UPDATE_SETTINGS = "com.scorepatner.UPDATE_BUBBLE_SETTINGS"

        @Volatile
        var isRunning = false
            private set

        var currentMatchId: String? = null
            private set
    }

    // System services
    private lateinit var windowManager: WindowManager
    private lateinit var settings: BubbleSettingsManager
    private lateinit var notificationHelper: BubbleNotificationHelper
    private lateinit var animator: BubbleAnimator

    // Views
    private var bubbleView: FloatingBubbleView? = null
    private var expandedCard: ExpandedScoreCardView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var cardParams: WindowManager.LayoutParams? = null
    private var isExpanded = false

    // Firestore
    private val db = FirebaseFirestore.getInstance()
    private var matchListener: ListenerRegistration? = null

    // State
    private val handler = Handler(Looper.getMainLooper())
    private var lastMatchData: Map<String, Any?> = emptyMap()
    private var previousRuns = -1
    private var previousWickets = -1
    private var previousOvers = -1.0

    // Network monitoring
    private var connectivityCallback: ConnectivityManager.NetworkCallback? = null
    private var isNetworkAvailable = true

    // Close action receiver
    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action == BubbleNotificationHelper.ACTION_CLOSE_BUBBLE) {
                stopSelf()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        settings = BubbleSettingsManager(this)
        notificationHelper = BubbleNotificationHelper(this)
        animator = BubbleAnimator(this)

        // Register close action receiver
        val filter = IntentFilter(BubbleNotificationHelper.ACTION_CLOSE_BUBBLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(closeReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(closeReceiver, filter)
        }

        // Monitor network
        setupNetworkMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_SETTINGS -> {
                // Reload settings and refresh bubble
                refreshBubbleAppearance()
                return START_STICKY
            }
        }

        val matchId = intent?.getStringExtra(EXTRA_MATCH_ID)
        if (matchId.isNullOrEmpty()) {
            Log.e(TAG, "No match ID provided")
            stopSelf()
            return START_NOT_STICKY
        }

        // Check overlay permission
        if (!Settings.canDrawOverlays(this)) {
            Log.e(TAG, "Overlay permission not granted")
            stopSelf()
            return START_NOT_STICKY
        }

        // Start foreground with notification
        val notification = notificationHelper.buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(BubbleNotificationHelper.NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(BubbleNotificationHelper.NOTIFICATION_ID, notification)
        }

        isRunning = true
        currentMatchId = matchId
        settings.pinnedMatchId = matchId

        // Create bubble overlay
        createBubbleView()

        // Start listening to Firestore
        startMatchListener(matchId)

        Log.d(TAG, "Bubble started for match: $matchId")
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")

        // Remove views
        removeBubbleViews()

        // Stop Firestore listener
        matchListener?.remove()
        matchListener = null

        // Unregister receivers
        try {
            unregisterReceiver(closeReceiver)
        } catch (e: Exception) { /* ignore */ }

        // Remove network callback
        connectivityCallback?.let {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager
            cm?.unregisterNetworkCallback(it)
        }

        isRunning = false
        currentMatchId = null
        settings.clearPinnedMatch()

        super.onDestroy()
    }

    // ── Bubble View Creation ────────────────────────────────

    @SuppressLint("ClickableViewAccessibility")
    private fun createBubbleView() {
        val sizePx = dpToPx(settings.bubbleSizeDp.toFloat())

        // Overlay params
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        bubbleParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            dpToPx(44f) + dpToPx(16f), // Height + extra space for glow
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Restore last position or default to right side
            if (settings.lastX >= 0 && settings.lastY >= 0) {
                x = settings.lastX
                y = settings.lastY
            } else {
                val metrics = getScreenMetrics()
                x = metrics.widthPixels - sizePx - dpToPx(16f)
                y = metrics.heightPixels / 3
            }
        }

        bubbleView = FloatingBubbleView(
            context = this,
            settings = settings,
            onSingleTap = { toggleExpandedCard() },
            onDoubleTap = { openMatchInApp() },
            onLongPress = { view -> showContextMenu(view) },
            onPositionChanged = { newX, newY -> updateBubblePosition(newX, newY) }
        )

        try {
            windowManager.addView(bubbleView, bubbleParams)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add bubble view", e)
            stopSelf()
        }
    }

    private fun removeBubbleViews() {
        try {
            bubbleView?.let { windowManager.removeView(it) }
        } catch (e: Exception) { /* ignore */ }
        try {
            expandedCard?.let { windowManager.removeView(it) }
        } catch (e: Exception) { /* ignore */ }
        bubbleView = null
        expandedCard = null
        isExpanded = false
    }

    // ── Position Management ─────────────────────────────────

    private fun updateBubblePosition(newX: Int, newY: Int) {
        val metrics = getScreenMetrics()
        val navBarHeight = getNavigationBarHeight()

        // Clamp position to screen bounds, avoiding nav bar
        val clampedX = newX.coerceIn(0, metrics.widthPixels - (bubbleParams?.width ?: 0))
        val clampedY = newY.coerceIn(
            getStatusBarHeight(),
            metrics.heightPixels - (bubbleParams?.height ?: 0) - navBarHeight
        )

        bubbleParams?.x = clampedX
        bubbleParams?.y = clampedY

        try {
            windowManager.updateViewLayout(bubbleView, bubbleParams)
        } catch (e: Exception) { /* ignore */ }

        // Save position
        settings.lastX = clampedX
        settings.lastY = clampedY
    }

    // ── Expanded Card ───────────────────────────────────────

    private fun toggleExpandedCard() {
        if (isExpanded) {
            collapseCard()
        } else {
            expandCard()
        }
    }

    private fun expandCard() {
        if (isExpanded) return

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        cardParams = WindowManager.LayoutParams(
            dpToPx(290f),
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Position card next to bubble
            val bx = bubbleParams?.x ?: 0
            val by = bubbleParams?.y ?: 0
            val metrics = getScreenMetrics()
            val cardWidth = dpToPx(290f)

            // Place card to the left or right of bubble, whichever has more space
            x = if (bx > metrics.widthPixels / 2) {
                bx - cardWidth - dpToPx(8f)
            } else {
                bx + (bubbleParams?.width ?: 0) + dpToPx(8f)
            }
            y = by
        }

        expandedCard = ExpandedScoreCardView(this) { collapseCard() }
        expandedCard?.updateMatchData(lastMatchData)

        try {
            windowManager.addView(expandedCard, cardParams)
            expandedCard?.animateIn()
            isExpanded = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add expanded card", e)
        }
    }

    private fun collapseCard() {
        if (!isExpanded) return
        expandedCard?.dismiss()
        // The dismiss animation will call onDismiss which removes the view
        handler.postDelayed({
            try {
                expandedCard?.let { windowManager.removeView(it) }
            } catch (e: Exception) { /* ignore */ }
            expandedCard = null
            isExpanded = false
        }, 250)
    }

    // ── Context Menu (Long Press) ───────────────────────────

    private fun showContextMenu(anchor: View) {
        try {
            val popup = PopupMenu(this, anchor)
            popup.menu.add(0, 1, 0, "🏏 Open Match")
            popup.menu.add(0, 2, 1, "📌 Unpin Match")
            popup.menu.add(0, 3, 2, "✕ Close Bubble")
            popup.menu.add(0, 4, 3, "🚫 Disable Floating Score")

            popup.setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    1 -> { openMatchInApp(); true }
                    2 -> { stopSelf(); true }
                    3 -> { stopSelf(); true }
                    4 -> {
                        settings.isEnabled = false
                        stopSelf()
                        true
                    }
                    else -> false
                }
            }
            popup.show()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show context menu", e)
        }
    }

    // ── Open Match in App ───────────────────────────────────

    private fun openMatchInApp() {
        val matchId = currentMatchId ?: return
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/match/$matchId")
            putExtra("matchId", matchId)
        }
        startActivity(intent)
    }

    // ── Firestore Listener ──────────────────────────────────

    private fun startMatchListener(matchId: String) {
        matchListener?.remove()

        matchListener = db.collection("matches").document(matchId)
            .addSnapshotListener(object : com.google.firebase.firestore.EventListener<DocumentSnapshot> {
                override fun onEvent(
                    snapshot: DocumentSnapshot?,
                    error: com.google.firebase.firestore.FirebaseFirestoreException?
                ) {
                    if (error != null) {
                        Log.e(TAG, "Firestore listener error", error)
                        return
                    }

                    if (snapshot == null || !snapshot.exists()) {
                        Log.w(TAG, "Match document does not exist")
                        return
                    }

                    handler.post { processMatchUpdate(snapshot) }
                }
            })
    }

    @Suppress("UNCHECKED_CAST")
    private fun processMatchUpdate(snapshot: DocumentSnapshot) {
        val data = snapshot.data ?: return

        val team1Name = data["team1Name"] as? String ?: "Team 1"
        val team2Name = data["team2Name"] as? String ?: "Team 2"
        val status = data["status"] as? String ?: "live"
        val currentBattingTeam = data["currentBattingTeam"] as? String ?: "team1"
        val currentInnings = (data["currentInnings"] as? Number)?.toInt() ?: 1
        
        val team1Id = data["team1Id"] as? String ?: ""
        val team2Id = data["team2Id"] as? String ?: ""
        val currentBattingTeamId = if (currentBattingTeam == "team1") team1Id else team2Id
        
        val currentStrikerId = data["currentStrikerId"] as? String
        val currentNonStrikerId = data["currentNonStrikerId"] as? String
        val currentBowlerId = data["currentBowlerId"] as? String

        // Parse team scores
        val team1ScoreMap = data["team1Score"] as? Map<String, Any?> ?: emptyMap()
        val team2ScoreMap = data["team2Score"] as? Map<String, Any?> ?: emptyMap()

        val team1Runs = (team1ScoreMap["runs"] as? Number)?.toInt() ?: 0
        val team1Wickets = (team1ScoreMap["wickets"] as? Number)?.toInt() ?: 0
        val team1Overs = (team1ScoreMap["overs"] as? Number)?.toDouble() ?: 0.0

        val team2Runs = (team2ScoreMap["runs"] as? Number)?.toInt() ?: 0
        val team2Wickets = (team2ScoreMap["wickets"] as? Number)?.toInt() ?: 0
        val team2Overs = (team2ScoreMap["overs"] as? Number)?.toDouble() ?: 0.0

        // Current batting team stats
        val battingRuns = if (currentBattingTeam == "team1") team1Runs else team2Runs
        val battingWickets = if (currentBattingTeam == "team1") team1Wickets else team2Wickets
        val battingOvers = if (currentBattingTeam == "team1") team1Overs else team2Overs

        // Calculate CRR
        val ballsBowled = oversToTotalBalls(battingOvers)
        val crr = if (ballsBowled > 0) battingRuns / (ballsBowled / 6.0) else 0.0

        // Calculate RRR and Target Info
        val target = (data["target"] as? Number)?.toInt()
        val oversPerSide = (data["oversPerSide"] as? Number)?.toInt() ?: 20
        var rrr = 0.0
        var targetInfo = ""
        if (target != null && currentInnings == 2) {
            val remaining = target - battingRuns
            val totalBalls = oversPerSide * 6
            val ballsLeft = totalBalls - ballsBowled
            if (ballsLeft > 0) {
                rrr = remaining / (ballsLeft / 6.0)
                targetInfo = "Need $remaining from $ballsLeft balls"
            }
        }

        // Parse batter/bowler names from scores
        val battingScore = if (currentBattingTeam == "team1") team1ScoreMap else team2ScoreMap
        val bowlingScore = if (currentBattingTeam == "team1") team2ScoreMap else team1ScoreMap

        val batters = battingScore["batters"] as? List<Map<String, Any?>> ?: emptyList()
        val bowlers = bowlingScore["bowlers"] as? List<Map<String, Any?>> ?: emptyList()

        // Find current batters using IDs first, fallback to isPlaying
        val batter1 = batters.find { it["playerId"] as? String == currentStrikerId } 
            ?: batters.firstOrNull { (it["isPlaying"] as? Boolean) == true }
        
        val batter2 = batters.find { it["playerId"] as? String == currentNonStrikerId }
            ?: batters.filter { (it["isPlaying"] as? Boolean) == true }.getOrNull(1)
            
        val batter1Name = batter1?.let {
            val name = (it["playerName"] as? String)?.takeIf { n -> n.isNotBlank() } ?: (it["name"] as? String)?.takeIf { n -> n.isNotBlank() } ?: "Batter"
            val runs = (it["runs"] as? Number)?.toInt() ?: 0
            val balls = (it["balls"] as? Number)?.toInt() ?: 0
            "$name $runs($balls)"
        } ?: "-"
        val batter2Name = batter2?.let {
            val name = (it["playerName"] as? String)?.takeIf { n -> n.isNotBlank() } ?: (it["name"] as? String)?.takeIf { n -> n.isNotBlank() } ?: "Batter"
            val runs = (it["runs"] as? Number)?.toInt() ?: 0
            val balls = (it["balls"] as? Number)?.toInt() ?: 0
            "$name $runs($balls)"
        } ?: "-"

        // Find current bowler using ID first, fallback to isBowling
        val activeBowler = bowlers.find { it["playerId"] as? String == currentBowlerId } 
            ?: bowlers.find { (it["isBowling"] as? Boolean) == true }
            
        val bowlerName = activeBowler?.let {
            val name = (it["playerName"] as? String)?.takeIf { n -> n.isNotBlank() } ?: (it["name"] as? String)?.takeIf { n -> n.isNotBlank() } ?: "Bowler"
            val overs = (it["overs"] as? Number)?.toDouble() ?: 0.0
            val runs = (it["runs"] as? Number)?.toInt() ?: 0
            val wickets = (it["wickets"] as? Number)?.toInt() ?: 0
            "$name ${formatOvers(overs)}-$runs-$wickets"
        } ?: "-"

        // Get last ball
        val ballByBall = data["ballByBall"] as? List<Map<String, Any?>> ?: emptyList()
        val lastBallEvent = ballByBall.lastOrNull()
        val lastBall = lastBallEvent?.let {
            val runs = (it["runs"] as? Number)?.toInt() ?: 0
            val wicket = it["isWicket"] as? Boolean ?: false
            val extraType = it["extraType"] as? String
            when {
                wicket -> "W"
                extraType == "wide" -> "WD"
                extraType == "no-ball" -> "NB"
                extraType == "bye" || extraType == "leg-bye" -> "${runs}B"
                runs == 4 -> "4"
                runs == 6 -> "6"
                else -> runs.toString()
            }
        } ?: "-"

        // This Over
        val currentOverInt = if (battingOvers == battingOvers.toInt().toDouble() && battingOvers > 0) battingOvers.toInt() - 1 else battingOvers.toInt()
        val thisOverBalls = ballByBall.filter { 
            val ballOverInt = (it["overNumber"] as? Number)?.toInt() ?: 0
            ballOverInt == currentOverInt && it["battingTeam"] == currentBattingTeamId
        }.map {
            val runs = (it["runs"] as? Number)?.toInt() ?: 0
            val wicket = it["isWicket"] as? Boolean ?: false
            val extraType = it["extraType"] as? String
            when {
                wicket -> "W"
                extraType == "wide" -> "WD"
                extraType == "no-ball" -> "NB"
                extraType == "bye" || extraType == "leg-bye" -> "${runs}B"
                runs == 4 -> "4"
                runs == 6 -> "6"
                else -> runs.toString()
            }
        }.takeLast(6) // Fallback to avoid wrapping too much

        // Viewer stats
        val liveViewers = (data["liveViewers"] as? Number)?.toInt() ?: 0
        val totalViews = (data["totalViews"] as? Number)?.toInt() ?: 0

        // Build match data map
        val matchData = mapOf<String, Any?>(
            "team1Name" to team1Name,
            "team2Name" to team2Name,
            "team1Runs" to team1Runs,
            "team1Wickets" to team1Wickets,
            "team1Overs" to team1Overs,
            "team2Runs" to team2Runs,
            "team2Wickets" to team2Wickets,
            "team2Overs" to team2Overs,
            "crr" to crr,
            "rrr" to rrr,
            "status" to status,
            "currentBattingTeam" to currentBattingTeam,
            "batter1" to batter1Name,
            "batter2" to batter2Name,
            "bowler" to bowlerName,
            "lastBall" to lastBall,
            "thisOver" to thisOverBalls,
            "targetInfo" to targetInfo,
            "liveViewers" to liveViewers,
            "totalViews" to totalViews
        )

        // Detect match events for animations
        detectAndAnimateEvents(battingRuns, battingWickets, battingOvers, lastBallEvent, status)

        // Update state
        lastMatchData = matchData
        previousRuns = battingRuns
        previousWickets = battingWickets
        previousOvers = battingOvers

        // Update bubble pill text
        val t1Abbr = team1Name.take(3).uppercase()
        val t2Abbr = team2Name.take(3).uppercase()
        val pillText = if (currentInnings == 2) {
            if (currentBattingTeam == "team2") {
                "$t2Abbr $team2Runs/$team2Wickets • $t1Abbr $team1Runs/$team1Wickets (${formatOvers(team2Overs)})"
            } else {
                "$t1Abbr $team1Runs/$team1Wickets • $t2Abbr $team2Runs/$team2Wickets (${formatOvers(team1Overs)})"
            }
        } else {
            val batAbbr = if (currentBattingTeam == "team1") t1Abbr else t2Abbr
            "$batAbbr $battingRuns/$battingWickets (${formatOvers(battingOvers)})"
        }
        
        bubbleView?.updateScore(pillText)
        bubbleView?.setLiveStatus(status == "live")

        // Update expanded card if open
        expandedCard?.updateMatchData(matchData)
        expandedCard?.showReconnecting(!isNetworkAvailable)

        // Update notification
        val scoreText = "$battingRuns/$battingWickets (${formatOvers(battingOvers)}) • CRR: ${String.format("%.2f", crr)}"
        notificationHelper.updateNotification(team1Name, team2Name, scoreText)

        // Auto-close on match end
        if (status == "completed" && settings.autoCloseAfterMatch) {
            bubbleView?.let { animator.animateMatchEnd(it) { stopSelf() } }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun detectAndAnimateEvents(
        currentRuns: Int,
        currentWickets: Int,
        currentOvers: Double,
        lastBallEvent: Map<String, Any?>?,
        status: String
    ) {
        val view = bubbleView ?: return
        if (previousRuns < 0) return // First update, skip

        // Wicket
        if (currentWickets > previousWickets) {
            animator.animateWicket(view)
            return
        }

        // Check last ball for boundaries
        if (lastBallEvent != null && currentRuns > previousRuns) {
            val runs = (lastBallEvent["runs"] as? Number)?.toInt() ?: 0
            when (runs) {
                6 -> animator.animateSix(view)
                4 -> animator.animateFour(view)
                else -> if (currentRuns != previousRuns) animator.pulseOnce(view)
            }

            // Check for milestones
            val batters = lastBallEvent["batters"] as? List<Map<String, Any?>>
            if (batters != null) {
                for (b in batters) {
                    val bRuns = (b["runs"] as? Number)?.toInt() ?: 0
                    if (bRuns == 100 || bRuns == 200 || bRuns == 300) {
                        animator.animateCentury(view)
                    } else if (bRuns == 50 || bRuns == 150 || bRuns == 250) {
                        animator.animateFifty(view)
                    }
                }
            }
        }

        // Innings change
        if (currentOvers == 0.0 && previousOvers > 0) {
            animator.animateInningsEnd(view)
        }

        // Match end
        if (status == "completed" && previousRuns >= 0) {
            // Handled by auto-close logic
        }
    }

    // ── Network Monitoring ──────────────────────────────────

    private fun setupNetworkMonitoring() {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return

        connectivityCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                handler.post {
                    isNetworkAvailable = true
                    expandedCard?.showReconnecting(false)
                }
            }

            override fun onLost(network: Network) {
                handler.post {
                    isNetworkAvailable = false
                    expandedCard?.showReconnecting(true)
                }
            }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        cm.registerNetworkCallback(request, connectivityCallback!!)
    }

    // ── Settings Refresh ────────────────────────────────────

    private fun refreshBubbleAppearance() {
        // Reload settings and re-apply transparency
        bubbleView?.alpha = settings.transparency
    }

    // ── Helpers ─────────────────────────────────────────────

    private fun oversToTotalBalls(overs: Double): Int {
        val completed = overs.toInt()
        val balls = ((overs - completed) * 10).toInt()
        return (completed * 6) + balls
    }

    private fun formatOvers(overs: Double): String {
        val completed = overs.toInt()
        val balls = ((overs - completed) * 10).toInt()
        return if (balls > 0) "$completed.$balls" else "$completed.0"
    }

    private fun getScreenMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getMetrics(metrics)
        return metrics
    }

    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else dpToPx(24f)
    }

    private fun getNavigationBarHeight(): Int {
        val resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else dpToPx(48f)
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp,
            resources.displayMetrics
        ).toInt()
    }
}
