import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/services/live_chat_service.dart';

/// Provider for live chat and emoji reactions during broadcasts.
class LiveChatProvider extends ChangeNotifier {
  final LiveChatService _chatService = LiveChatService.instance;

  // State
  List<LiveChatMessage> _messages = [];
  LiveChatMessage? _pinnedMessage;
  ReactionCounts _reactionCounts = const ReactionCounts();
  List<EmojiReaction> _recentReactions = [];
  bool _isSlowMode = false;
  int _slowModeSeconds = 0;
  bool _chatEnabled = true;
  String? _error;

  // Subscriptions
  StreamSubscription? _messagesSub;
  StreamSubscription? _pinnedSub;
  StreamSubscription? _reactionsSub;
  StreamSubscription? _recentReactionsSub;

  // Getters
  List<LiveChatMessage> get messages => _messages;
  LiveChatMessage? get pinnedMessage => _pinnedMessage;
  ReactionCounts get reactionCounts => _reactionCounts;
  List<EmojiReaction> get recentReactions => _recentReactions;
  bool get isSlowMode => _isSlowMode;
  int get slowModeSeconds => _slowModeSeconds;
  bool get chatEnabled => _chatEnabled;
  String? get error => _error;

  /// Initialize chat for a broadcast
  void initChat(String broadcastId) {
    _subscribeToMessages(broadcastId);
    _subscribeToPinnedMessage(broadcastId);
    _subscribeToReactionCounts(broadcastId);
    _subscribeToRecentReactions(broadcastId);
  }

  /// Send a text message
  Future<bool> sendMessage(String broadcastId, String message) async {
    if (message.trim().isEmpty) return false;

    final success = await _chatService.sendMessage(
      broadcastId: broadcastId,
      message: message.trim(),
      slowModeSeconds: _slowModeSeconds,
    );

    if (!success) {
      _error = 'Message not sent. Slow mode active.';
      notifyListeners();
    }
    return success;
  }

  /// Send an emoji reaction
  Future<void> sendReaction(String broadcastId, String emoji) async {
    await _chatService.sendReaction(
      broadcastId: broadcastId,
      emojiType: emoji,
    );
  }

  /// Pin a message (moderator/owner only)
  Future<void> pinMessage(String broadcastId, String messageId) async {
    await _chatService.pinMessage(broadcastId, messageId);
  }

  /// Unpin a message
  Future<void> unpinMessage(String broadcastId, String messageId) async {
    await _chatService.unpinMessage(broadcastId, messageId);
  }

  /// Delete a message (moderator/owner only)
  Future<void> deleteMessage(String broadcastId, String messageId) async {
    await _chatService.deleteMessage(broadcastId, messageId);
  }

  /// Mute a user
  Future<void> muteUser(String broadcastId, String userId) async {
    await _chatService.muteUser(broadcastId, userId);
  }

  /// Update slow mode
  void setSlowMode(bool enabled, {int seconds = 5}) {
    _isSlowMode = enabled;
    _slowModeSeconds = enabled ? seconds : 0;
    notifyListeners();
  }

  /// Update chat enabled state
  void setChatEnabled(bool enabled) {
    _chatEnabled = enabled;
    notifyListeners();
  }

  // ── Subscriptions ───────────────────────────────────────

  void _subscribeToMessages(String broadcastId) {
    _messagesSub?.cancel();
    _messagesSub = _chatService.streamMessages(broadcastId).listen((messages) {
      _messages = messages;
      notifyListeners();
    });
  }

  void _subscribeToPinnedMessage(String broadcastId) {
    _pinnedSub?.cancel();
    _pinnedSub = _chatService.streamPinnedMessage(broadcastId).listen((msg) {
      _pinnedMessage = msg;
      notifyListeners();
    });
  }

  void _subscribeToReactionCounts(String broadcastId) {
    _reactionsSub?.cancel();
    _reactionsSub = _chatService.streamReactionCounts(broadcastId).listen((counts) {
      _reactionCounts = counts;
      notifyListeners();
    });
  }

  void _subscribeToRecentReactions(String broadcastId) {
    _recentReactionsSub?.cancel();
    _recentReactionsSub = _chatService.streamRecentReactions(broadcastId).listen((reactions) {
      _recentReactions = reactions;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _pinnedSub?.cancel();
    _reactionsSub?.cancel();
    _recentReactionsSub?.cancel();
    super.dispose();
  }
}
