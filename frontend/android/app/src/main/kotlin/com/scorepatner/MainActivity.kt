package com.scorepatner

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.scorepatner.bubble.BubbleSettingsManager
import com.scorepatner.bubble.FloatingBubbleService

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.scorepatner/floating_bubble"
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1234
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBubble" -> {
                        val matchId = call.argument<String>("matchId")
                        if (matchId.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "matchId is required", null)
                            return@setMethodCallHandler
                        }

                        if (!Settings.canDrawOverlays(this)) {
                            result.error(
                                "PERMISSION_DENIED",
                                "Overlay permission not granted",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val intent = Intent(this, FloatingBubbleService::class.java).apply {
                            putExtra(FloatingBubbleService.EXTRA_MATCH_ID, matchId)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }

                    "stopBubble" -> {
                        val intent = Intent(this, FloatingBubbleService::class.java).apply {
                            action = FloatingBubbleService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }

                    "isBubbleActive" -> {
                        result.success(FloatingBubbleService.isRunning)
                    }

                    "getPinnedMatchId" -> {
                        result.success(FloatingBubbleService.currentMatchId)
                    }

                    "checkOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }

                    "requestOverlayPermission" -> {
                        if (Settings.canDrawOverlays(this)) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                    }

                    "updateSettings" -> {
                        val settingsMap = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val manager = BubbleSettingsManager(this)
                        manager.fromMap(settingsMap)

                        // Notify running service to refresh
                        if (FloatingBubbleService.isRunning) {
                            val intent = Intent(this, FloatingBubbleService::class.java).apply {
                                action = FloatingBubbleService.ACTION_UPDATE_SETTINGS
                            }
                            startService(intent)
                        }
                        result.success(true)
                    }

                    "getSettings" -> {
                        val manager = BubbleSettingsManager(this)
                        result.success(manager.toMap())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            val granted = Settings.canDrawOverlays(this)
            pendingResult?.success(granted)
            pendingResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle deep link from bubble double-tap
        val matchId = intent.getStringExtra("matchId")
        val route = intent.getStringExtra("route")
        if (matchId != null && route != null) {
            // Forward to Flutter via MethodChannel
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod(
                    "openMatch", mapOf("matchId" to matchId)
                )
            }
        }
    }
}
