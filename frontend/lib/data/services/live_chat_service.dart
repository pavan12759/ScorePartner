import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';

/// Service for live chat and emoji reactions during broadcasts.
/// Uses Firestore subcollections under broadcasts/{id}/messages and reactions.
class LiveChatService {
  static LiveChatService? _instance;
  static LiveChatService get instance => _instance ??= LiveChatService._();
  LiveChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Rate limiting
  DateTime? _lastMessageTime;
  DateTime? _lastReactionTime;

  // ── Messages ────────────────────────────────────────────

  /// Send a chat message
  Future<bool> sendMessage({
    required String broadcastId,
    required String message,
    String type = 'text',
    String? imageUrl,
    String? gifUrl,
    int slowModeSeconds = 0,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Rate limiting / slow mode
    if (_lastMessageTime != null && slowModeSeconds > 0) {
      final elapsed = DateTime.now().difference(_lastMessageTime!).inSeconds;
      if (elapsed < slowModeSeconds) {
        debugPrint('⚠️ Slow mode: wait ${slowModeSeconds - elapsed}s');
        return false;
      }
    }

    try {
      final msgRef = _db
          .collection('broadcasts')
          .doc(broadcastId)
          .collection('messages')
          .doc();

      final chatMessage = LiveChatMessage(
        id: msgRef.id,
        broadcastId: broadcastId,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userAvatar: user.photoURL,
        message: message,
        type: type,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        gifUrl: gifUrl,
      );

      await msgRef.set(chatMessage.toMap());
      _lastMessageTime = DateTime.now();

      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  /// Stream chat messages (latest 100, ordered by time)
  Stream<List<LiveChatMessage>> streamMessages(String broadcastId) {
    return _db
        .collection('broadcasts')
        .doc(broadcastId)
        .collection('messages')
        .where('isDeleted', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveChatMessage.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Pin a message
  Future<void> pinMessage(String broadcastId, String messageId) async {
    try {
      // Unpin all existing pinned messages first
      final pinned = await _db
          .collection('broadcasts')
          .doc(broadcastId)
          .collection('messages')
          .where('isPinned', isEqualTo: true)
          .get();

      final batch = _db.batch();
      for (final doc in pinned.docs) {
        batch.update(doc.reference, {'isPinned': false});
      }

      // Pin the new message
      batch.update(
        _db.collection('broadcasts').doc(broadcastId).collection('messages').doc(messageId),
        {'isPinned': true},
      );

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error pinning message: $e');
    }
  }

  /// Unpin a message
  Future<void> unpinMessage(String broadcastId, String messageId) async {
    try {
      await _db
          .collection('broadcasts')
          .doc(broadcastId)
          .collection('messages')
          .doc(messageId)
          .update({'isPinned': false});
    } catch (e) {
      debugPrint('❌ Error unpinning message: $e');
    }
  }

  /// Delete a message (soft delete)
  Future<void> deleteMessage(String broadcastId, String messageId) async {
    try {
      await _db
          .collection('broadcasts')
          .doc(broadcastId)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true});
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
    }
  }

  /// Mute a user
  Future<void> muteUser(String broadcastId, String userId) async {
    try {
      // Mark all their messages as muted
      final userMsgs = await _db
          .collection('broadcasts')
          .doc(broadcastId)
          .collection('messages')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _db.batch();
      for (final doc in userMsgs.docs) {
        batch.update(doc.reference, {'isMuted': true});
      }

      // Add to muted users list
      batch.update(
        _db.collection('broadcasts').doc(broadcastId),
        {'mutedUsers': FieldValue.arrayUnion([userId])},
      );

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error muting user: $e');
    }
  }

  /// Get pinned message
  Stream<LiveChatMessage?> streamPinnedMessage(String broadcastId) {
    return _db
        .collection('broadcasts')
        .doc(broadcastId)
        .collection('messages')
        .where('isPinned', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return LiveChatMessage.fromMap(snap.docs.first.data(), docId: snap.docs.first.id);
    });
  }

  // ── Reactions ───────────────────────────────────────────

  /// Send an emoji reaction (rate limited to 1 per second)
  Future<void> sendReaction({
    required String broadcastId,
    required String emojiType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Rate limit reactions to 1 per second
    if (_lastReactionTime != null) {
      final elapsed = DateTime.now().difference(_lastReactionTime!).inMilliseconds;
      if (elapsed < 1000) return;
    }

    try {
      await _db
          .collection('broadcasts')
          .doc(broadcastId)
          .collection('reactions')
          .add({
        'type': emojiType,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update aggregated counts
      final countField = _emojiToField(emojiType);
      if (countField != null) {
        await _db.collection('broadcasts').doc(broadcastId).update({
          'reactionCounts.$countField': FieldValue.increment(1),
        });
      }

      _lastReactionTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ Error sending reaction: $e');
    }
  }

  /// Stream recent reactions (for floating emoji animation)
  Stream<List<EmojiReaction>> streamRecentReactions(String broadcastId) {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
    return _db
        .collection('broadcasts')
        .doc(broadcastId)
        .collection('reactions')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EmojiReaction.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  /// Stream aggregated reaction counts
  Stream<ReactionCounts> streamReactionCounts(String broadcastId) {
    return _db.collection('broadcasts').doc(broadcastId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return const ReactionCounts();
      final counts = data['reactionCounts'] as Map<String, dynamic>? ?? {};
      return ReactionCounts.fromMap(counts);
    });
  }

  // ── Helpers ─────────────────────────────────────────────

  String? _emojiToField(String emoji) {
    switch (emoji) {
      case '❤️': return 'hearts';
      case '🔥': return 'fires';
      case '👏': return 'claps';
      case '😮': return 'wows';
      case '🏏': return 'cricket';
      case '🎉': return 'celebrations';
      default: return null;
    }
  }
}
