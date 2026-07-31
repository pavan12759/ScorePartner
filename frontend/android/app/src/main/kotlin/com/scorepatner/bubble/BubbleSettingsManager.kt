package com.scorepatner.bubble

import android.content.Context
import android.content.SharedPreferences

/**
 * Manages user preferences for the floating score bubble.
 * All settings are stored locally via SharedPreferences.
 */
class BubbleSettingsManager(context: Context) {

    companion object {
        private const val PREFS_NAME = "floating_bubble_prefs"

        // Keys
        private const val KEY_ENABLED = "bubble_enabled"
        private const val KEY_SIZE = "bubble_size"          // "small", "medium", "large"
        private const val KEY_TRANSPARENCY = "bubble_transparency" // 0.0–1.0
        private const val KEY_LOCK_POSITION = "lock_position"
        private const val KEY_AUTO_CLOSE = "auto_close_after_match"
        private const val KEY_VIBRATE_WICKETS = "vibrate_wickets"
        private const val KEY_SOUND_EFFECTS = "sound_effects"
        private const val KEY_LAST_X = "last_x"
        private const val KEY_LAST_Y = "last_y"
        private const val KEY_PINNED_MATCH_ID = "pinned_match_id"

        // Size constants in dp
        const val SIZE_SMALL = 48
        const val SIZE_MEDIUM = 56
        const val SIZE_LARGE = 64
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // ── Getters ─────────────────────────────────────────────

    var isEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    var bubbleSize: String
        get() = prefs.getString(KEY_SIZE, "medium") ?: "medium"
        set(value) = prefs.edit().putString(KEY_SIZE, value).apply()

    val bubbleSizeDp: Int
        get() = when (bubbleSize) {
            "small" -> SIZE_SMALL
            "large" -> SIZE_LARGE
            else -> SIZE_MEDIUM
        }

    var transparency: Float
        get() = prefs.getFloat(KEY_TRANSPARENCY, 1.0f)
        set(value) = prefs.edit().putFloat(KEY_TRANSPARENCY, value.coerceIn(0.1f, 1.0f)).apply()

    var isPositionLocked: Boolean
        get() = prefs.getBoolean(KEY_LOCK_POSITION, false)
        set(value) = prefs.edit().putBoolean(KEY_LOCK_POSITION, value).apply()

    var autoCloseAfterMatch: Boolean
        get() = prefs.getBoolean(KEY_AUTO_CLOSE, true)
        set(value) = prefs.edit().putBoolean(KEY_AUTO_CLOSE, value).apply()

    var vibrateOnWickets: Boolean
        get() = prefs.getBoolean(KEY_VIBRATE_WICKETS, true)
        set(value) = prefs.edit().putBoolean(KEY_VIBRATE_WICKETS, value).apply()

    var soundEffectsEnabled: Boolean
        get() = prefs.getBoolean(KEY_SOUND_EFFECTS, false)
        set(value) = prefs.edit().putBoolean(KEY_SOUND_EFFECTS, value).apply()

    var lastX: Int
        get() = prefs.getInt(KEY_LAST_X, -1)
        set(value) = prefs.edit().putInt(KEY_LAST_X, value).apply()

    var lastY: Int
        get() = prefs.getInt(KEY_LAST_Y, -1)
        set(value) = prefs.edit().putInt(KEY_LAST_Y, value).apply()

    var pinnedMatchId: String?
        get() = prefs.getString(KEY_PINNED_MATCH_ID, null)
        set(value) = prefs.edit().putString(KEY_PINNED_MATCH_ID, value).apply()

    // ── Helpers ──────────────────────────────────────────────

    fun resetToDefaults() {
        prefs.edit()
            .putBoolean(KEY_ENABLED, true)
            .putString(KEY_SIZE, "medium")
            .putFloat(KEY_TRANSPARENCY, 1.0f)
            .putBoolean(KEY_LOCK_POSITION, false)
            .putBoolean(KEY_AUTO_CLOSE, true)
            .putBoolean(KEY_VIBRATE_WICKETS, true)
            .putBoolean(KEY_SOUND_EFFECTS, false)
            .apply()
    }

    fun clearPinnedMatch() {
        prefs.edit()
            .remove(KEY_PINNED_MATCH_ID)
            .remove(KEY_LAST_X)
            .remove(KEY_LAST_Y)
            .apply()
    }

    /**
     * Exports all settings as a map for sending to Flutter via MethodChannel.
     */
    fun toMap(): Map<String, Any?> = mapOf(
        "enabled" to isEnabled,
        "size" to bubbleSize,
        "transparency" to transparency,
        "lockPosition" to isPositionLocked,
        "autoClose" to autoCloseAfterMatch,
        "vibrateWickets" to vibrateOnWickets,
        "soundEffects" to soundEffectsEnabled,
        "pinnedMatchId" to pinnedMatchId
    )

    /**
     * Imports settings from a map received from Flutter via MethodChannel.
     */
    fun fromMap(map: Map<String, Any?>) {
        (map["enabled"] as? Boolean)?.let { isEnabled = it }
        (map["size"] as? String)?.let { bubbleSize = it }
        (map["transparency"] as? Double)?.let { transparency = it.toFloat() }
        (map["lockPosition"] as? Boolean)?.let { isPositionLocked = it }
        (map["autoClose"] as? Boolean)?.let { autoCloseAfterMatch = it }
        (map["vibrateWickets"] as? Boolean)?.let { vibrateOnWickets = it }
        (map["soundEffects"] as? Boolean)?.let { soundEffectsEnabled = it }
    }
}
