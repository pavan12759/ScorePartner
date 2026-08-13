package com.scorepatner.bubble

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.scorepatner.MainActivity
import com.scorepatner.R

/**
 * Creates and manages the foreground service notification for the floating bubble.
 * Required on Android 8+ to keep the foreground service alive.
 */
class BubbleNotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "score_bubble_channel"
        const val NOTIFICATION_ID = 9001
        private const val CHANNEL_NAME = "Live Score Bubble"
        private const val CHANNEL_DESC = "Shows a floating live score bubble over other apps"

        // Action keys
        const val ACTION_CLOSE_BUBBLE = "com.scorepatner.ACTION_CLOSE_BUBBLE"
    }

    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = CHANNEL_DESC
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Builds the initial foreground notification.
     */
    fun buildNotification(
        team1: String = "Team A",
        team2: String = "Team B",
        score: String = "Loading..."
    ): Notification {
        // Tap notification → open app
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPending = PendingIntent.getActivity(
            context, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Close bubble action
        val closeBubbleIntent = Intent(ACTION_CLOSE_BUBBLE).apply {
            setPackage(context.packageName)
        }
        val closePending = PendingIntent.getBroadcast(
            context, 1, closeBubbleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("🏏 $team1 vs $team2")
            .setContentText(score)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(openAppPending)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Close",
                closePending
            )
            .addAction(
                android.R.drawable.ic_menu_view,
                "Open Match",
                openAppPending
            )
            .build()
    }

    /**
     * Updates the notification with latest score.
     */
    fun updateNotification(team1: String, team2: String, score: String) {
        val notification = buildNotification(team1, team2, score)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
