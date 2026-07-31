import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/services/floating_bubble_channel.dart';

/// Provider for managing floating bubble state from Flutter UI.
///
/// Handles:
/// - Permission flow
/// - Pin/unpin match logic
/// - Settings management
/// - Single-match pinning enforcement
class FloatingBubbleProvider extends ChangeNotifier {
  final FloatingBubbleChannel _channel = FloatingBubbleChannel.instance;

  bool _isActive = false;
  String? _pinnedMatchId;
  bool _isEnabled = true;
  bool _isLoading = false;

  // Settings
  String _bubbleSize = 'medium';
  double _transparency = 1.0;
  bool _lockPosition = false;
  bool _autoClose = true;
  bool _vibrateWickets = true;
  bool _soundEffects = false;

  // Getters
  bool get isActive => _isActive;
  String? get pinnedMatchId => _pinnedMatchId;
  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;
  String get bubbleSize => _bubbleSize;
  double get transparency => _transparency;
  bool get lockPosition => _lockPosition;
  bool get autoClose => _autoClose;
  bool get vibrateWickets => _vibrateWickets;
  bool get soundEffects => _soundEffects;

  /// Whether the platform supports floating bubbles (Android only)
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  FloatingBubbleProvider() {
    _init();
  }

  Future<void> _init() async {
    if (!isSupported) return;
    await refreshState();
    await loadSettings();
  }

  /// Refresh bubble state from native side.
  Future<void> refreshState() async {
    if (!isSupported) return;
    _isActive = await _channel.isBubbleActive();
    _pinnedMatchId = await _channel.getPinnedMatchId();
    notifyListeners();
  }

  /// Load settings from native SharedPreferences.
  Future<void> loadSettings() async {
    if (!isSupported) return;
    final settings = await _channel.getSettings();
    _isEnabled = settings['enabled'] as bool? ?? true;
    _bubbleSize = settings['size'] as String? ?? 'medium';
    _transparency = (settings['transparency'] as num?)?.toDouble() ?? 1.0;
    _lockPosition = settings['lockPosition'] as bool? ?? false;
    _autoClose = settings['autoClose'] as bool? ?? true;
    _vibrateWickets = settings['vibrateWickets'] as bool? ?? true;
    _soundEffects = settings['soundEffects'] as bool? ?? false;
    _pinnedMatchId = settings['pinnedMatchId'] as String?;
    notifyListeners();
  }

  /// Pin a live match. Handles permission flow and replacement confirmation.
  ///
  /// Returns:
  /// - `true` if bubble was started successfully
  /// - `false` if user denied permission or cancelled
  /// - throws on unexpected errors
  Future<bool> pinMatch(String matchId) async {
    if (!isSupported || !_isEnabled) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check overlay permission
      final hasPermission = await _channel.checkOverlayPermission();
      if (!hasPermission) {
        final granted = await _channel.requestOverlayPermission();
        if (!granted) {
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // 2. Stop existing bubble if different match is pinned
      if (_isActive && _pinnedMatchId != null && _pinnedMatchId != matchId) {
        await _channel.stopBubble();
        // Small delay for service to clean up
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 3. Start bubble
      await _channel.startBubble(matchId);

      _isActive = true;
      _pinnedMatchId = matchId;
      _isLoading = false;
      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      debugPrint('❌ Pin match error: ${e.code} - ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Unpin the current match and stop the bubble.
  Future<void> unpinMatch() async {
    if (!isSupported) return;

    await _channel.stopBubble();
    _isActive = false;
    _pinnedMatchId = null;
    notifyListeners();
  }

  /// Check if a specific match is currently pinned.
  bool isMatchPinned(String matchId) => _pinnedMatchId == matchId && _isActive;

  // ── Settings Mutators ─────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    await _saveSettings();
    if (!value && _isActive) {
      await unpinMatch();
    }
    notifyListeners();
  }

  Future<void> setBubbleSize(String value) async {
    _bubbleSize = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setTransparency(double value) async {
    _transparency = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLockPosition(bool value) async {
    _lockPosition = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAutoClose(bool value) async {
    _autoClose = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setVibrateWickets(bool value) async {
    _vibrateWickets = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setSoundEffects(bool value) async {
    _soundEffects = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _bubbleSize = 'medium';
    _transparency = 1.0;
    _lockPosition = false;
    _autoClose = true;
    _vibrateWickets = true;
    _soundEffects = false;
    _isEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _channel.updateSettings({
      'enabled': _isEnabled,
      'size': _bubbleSize,
      'transparency': _transparency,
      'lockPosition': _lockPosition,
      'autoClose': _autoClose,
      'vibrateWickets': _vibrateWickets,
      'soundEffects': _soundEffects,
    });
  }
}
