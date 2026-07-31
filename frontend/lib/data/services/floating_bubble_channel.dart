import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart-side bridge to the native Android FloatingBubbleService.
/// Communicates via MethodChannel for start/stop/settings.
class FloatingBubbleChannel {
  static const _channel = MethodChannel('com.scorepatner/floating_bubble');

  // Singleton
  static FloatingBubbleChannel? _instance;
  static FloatingBubbleChannel get instance =>
      _instance ??= FloatingBubbleChannel._();
  FloatingBubbleChannel._() {
    // Listen for native → Dart calls (e.g., openMatch from double-tap)
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// Callback for when the native side requests opening a match
  Function(String matchId)? onOpenMatch;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'openMatch':
        final matchId = call.arguments['matchId'] as String?;
        if (matchId != null && onOpenMatch != null) {
          onOpenMatch!(matchId);
        }
        break;
    }
  }

  // ── Public API ────────────────────────────────────────────

  /// Start the floating bubble for a given match.
  /// Returns true if successful, throws on error.
  Future<bool> startBubble(String matchId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startBubble',
        {'matchId': matchId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ FloatingBubble startBubble error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Stop the floating bubble.
  Future<bool> stopBubble() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopBubble');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ FloatingBubble stopBubble error: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Check if the bubble service is currently running.
  Future<bool> isBubbleActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBubbleActive');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ FloatingBubble isBubbleActive error: $e');
      return false;
    }
  }

  /// Get the currently pinned match ID (null if none).
  Future<String?> getPinnedMatchId() async {
    try {
      return await _channel.invokeMethod<String?>('getPinnedMatchId');
    } catch (e) {
      debugPrint('❌ FloatingBubble getPinnedMatchId error: $e');
      return null;
    }
  }

  /// Check if overlay permission is granted.
  Future<bool> checkOverlayPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ FloatingBubble checkOverlayPermission error: $e');
      return false;
    }
  }

  /// Request overlay permission. Opens system settings.
  /// Returns true if permission was granted after returning.
  Future<bool> requestOverlayPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ FloatingBubble requestOverlayPermission error: $e');
      return false;
    }
  }

  /// Send updated settings to native side.
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'updateSettings',
        settings,
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ FloatingBubble updateSettings error: $e');
      return false;
    }
  }

  /// Get current settings from native side.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final result = await _channel.invokeMethod<Map>('getSettings');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('❌ FloatingBubble getSettings error: $e');
      return {};
    }
  }
}
