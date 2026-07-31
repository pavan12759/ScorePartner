import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/broadcast_model.dart';
import '../models/broadcast_highlight_model.dart';

/// Service for managing live broadcast sessions in Firestore.
/// Handles CRUD operations, crew management, and viewer tracking.
class BroadcastService {
  static BroadcastService? _instance;
  static BroadcastService get instance => _instance ??= BroadcastService._();
  BroadcastService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _broadcastsCollection = 'broadcasts';

  // ── Broadcast CRUD ───────────────────────────────────────

  /// Start a new broadcast for a match
  Future<BroadcastSession?> startBroadcast({
    required String matchId,
    String overlayThemeId = 'scorepartner_premium',
    BroadcastOverlayConfig? overlayConfig,
    String? title,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      // Check if there's already an active broadcast for this match
      final existing = await getActiveBroadcastForMatch(matchId);
      if (existing != null) {
        debugPrint('⚠️ Broadcast already active for match $matchId');
        return existing;
      }

      final crewCode = _generateCrewCode();
      final docRef = _db.collection(_broadcastsCollection).doc();

      final broadcast = BroadcastSession(
        id: docRef.id,
        matchId: matchId,
        broadcasterId: uid,
        status: 'live',
        startedAt: DateTime.now(),
        overlayThemeId: overlayThemeId,
        overlayConfig: overlayConfig ?? const BroadcastOverlayConfig(),
        chatEnabled: true,
        crewCode: crewCode,
        crew: {uid: 'owner'},
        title: title,
      );

      await docRef.set(broadcast.toMap());

      // Mark the match as broadcasting
      await _db.collection('matches').doc(matchId).update({
        'isBroadcasting': true,
        'activeBroadcastId': docRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📡 Broadcast started: ${docRef.id} for match $matchId');
      return broadcast;
    } catch (e) {
      debugPrint('❌ Error starting broadcast: $e');
      throw Exception('Failed to start broadcast: $e');
    }
  }

  /// End an active broadcast
  Future<void> endBroadcast(String broadcastId) async {
    try {
      final docRef = _db.collection(_broadcastsCollection).doc(broadcastId);
      final doc = await docRef.get();

      if (!doc.exists) return;
      final data = doc.data()!;
      final matchId = data['matchId'] as String?;

      await docRef.update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Unmark match as broadcasting
      if (matchId != null) {
        await _db.collection('matches').doc(matchId).update({
          'isBroadcasting': false,
          'activeBroadcastId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('📡 Broadcast ended: $broadcastId');
    } catch (e) {
      debugPrint('❌ Error ending broadcast: $e');
    }
  }

  /// Get broadcast by ID
  Future<BroadcastSession?> getBroadcastById(String broadcastId) async {
    try {
      final doc = await _db.collection(_broadcastsCollection).doc(broadcastId).get();
      if (!doc.exists) return null;
      return BroadcastSession.fromMap(doc.data()!, docId: doc.id);
    } catch (e) {
      debugPrint('❌ Error getting broadcast: $e');
      return null;
    }
  }

  /// Stream broadcast updates in real-time
  Stream<BroadcastSession?> streamBroadcast(String broadcastId) {
    return _db.collection(_broadcastsCollection).doc(broadcastId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BroadcastSession.fromMap(doc.data()!, docId: doc.id);
    });
  }

  /// Get active broadcast for a match
  Future<BroadcastSession?> getActiveBroadcastForMatch(String matchId) async {
    try {
      final snap = await _db
          .collection(_broadcastsCollection)
          .where('matchId', isEqualTo: matchId)
          .where('status', isEqualTo: 'live')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return BroadcastSession.fromMap(snap.docs.first.data(), docId: snap.docs.first.id);
    } catch (e) {
      debugPrint('❌ Error getting active broadcast: $e');
      return null;
    }
  }

  /// Stream active broadcast for a match
  Stream<BroadcastSession?> streamActiveBroadcastForMatch(String matchId) {
    return _db
        .collection(_broadcastsCollection)
        .where('matchId', isEqualTo: matchId)
        .where('status', isEqualTo: 'live')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return BroadcastSession.fromMap(snap.docs.first.data(), docId: snap.docs.first.id);
    });
  }

  // ── Overlay Config ──────────────────────────────────────

  /// Update overlay configuration
  Future<void> updateOverlayConfig(String broadcastId, BroadcastOverlayConfig config) async {
    try {
      await _db.collection(_broadcastsCollection).doc(broadcastId).update({
        'overlayConfig': config.toMap(),
      });
    } catch (e) {
      debugPrint('❌ Error updating overlay config: $e');
    }
  }

  /// Update overlay theme
  Future<void> updateOverlayTheme(String broadcastId, String themeId) async {
    try {
      await _db.collection(_broadcastsCollection).doc(broadcastId).update({
        'overlayThemeId': themeId,
      });
    } catch (e) {
      debugPrint('❌ Error updating overlay theme: $e');
    }
  }

  // ── Crew Management ─────────────────────────────────────

  /// Join broadcast crew using 6-digit code
  Future<BroadcastSession?> joinBroadcastCrew(String crewCode, String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final snap = await _db
          .collection(_broadcastsCollection)
          .where('crewCode', isEqualTo: crewCode)
          .where('status', isEqualTo: 'live')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('⚠️ No active broadcast found with crew code: $crewCode');
        return null;
      }

      final doc = snap.docs.first;
      await doc.reference.update({
        'crew.$uid': role,
      });

      debugPrint('👥 User $uid joined broadcast crew as $role');
      return BroadcastSession.fromMap(doc.data(), docId: doc.id);
    } catch (e) {
      debugPrint('❌ Error joining crew: $e');
      return null;
    }
  }

  /// Remove crew member
  Future<void> removeCrewMember(String broadcastId, String userId) async {
    try {
      await _db.collection(_broadcastsCollection).doc(broadcastId).update({
        'crew.$userId': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('❌ Error removing crew member: $e');
    }
  }

  /// Update crew member role
  Future<void> updateCrewRole(String broadcastId, String userId, String newRole) async {
    try {
      await _db.collection(_broadcastsCollection).doc(broadcastId).update({
        'crew.$userId': newRole,
      });
    } catch (e) {
      debugPrint('❌ Error updating crew role: $e');
    }
  }

  // ── Viewer Tracking ─────────────────────────────────────

  /// Join as a broadcast viewer
  Future<void> joinAsViewer(String broadcastId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final broadcastRef = _db.collection(_broadcastsCollection).doc(broadcastId);
      final viewerRef = broadcastRef.collection('viewers').doc(uid);

      final existing = await viewerRef.get();
      if (existing.exists) {
        await viewerRef.update({'lastSeen': FieldValue.serverTimestamp()});
        return;
      }

      await _db.runTransaction((tx) async {
        final snap = await tx.get(broadcastRef);
        final data = snap.data() ?? {};
        final currentViewers = (data['viewerCount'] as num?)?.toInt() ?? 0;
        final currentPeak = (data['peakViewers'] as num?)?.toInt() ?? 0;
        final newCount = currentViewers + 1;

        tx.set(viewerRef, {
          'joinedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });

        tx.update(broadcastRef, {
          'viewerCount': newCount,
          'peakViewers': newCount > currentPeak ? newCount : currentPeak,
          'totalViews': FieldValue.increment(1),
        });
      });
    } catch (e) {
      debugPrint('❌ Error joining broadcast: $e');
    }
  }

  /// Leave as a broadcast viewer
  Future<void> leaveAsViewer(String broadcastId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final broadcastRef = _db.collection(_broadcastsCollection).doc(broadcastId);
      final viewerRef = broadcastRef.collection('viewers').doc(uid);

      final existing = await viewerRef.get();
      if (!existing.exists) return;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(broadcastRef);
        final data = snap.data() ?? {};
        final current = (data['viewerCount'] as num?)?.toInt() ?? 0;

        tx.delete(viewerRef);
        tx.update(broadcastRef, {
          'viewerCount': current > 0 ? current - 1 : 0,
        });
      });
    } catch (e) {
      debugPrint('❌ Error leaving broadcast: $e');
    }
  }

  /// Stream viewer count
  Stream<int> streamViewerCount(String broadcastId) {
    return _db.collection(_broadcastsCollection).doc(broadcastId).snapshots().map((doc) {
      return (doc.data()?['viewerCount'] as num?)?.toInt() ?? 0;
    });
  }

  // ── Highlights ──────────────────────────────────────────

  /// Add a broadcast highlight
  Future<void> addHighlight(String broadcastId, BroadcastHighlight highlight) async {
    try {
      await _db
          .collection(_broadcastsCollection)
          .doc(broadcastId)
          .collection('highlights')
          .add(highlight.toMap());
    } catch (e) {
      debugPrint('❌ Error adding highlight: $e');
    }
  }

  /// Stream highlights for a broadcast
  Stream<List<BroadcastHighlight>> streamHighlights(String broadcastId) {
    return _db
        .collection(_broadcastsCollection)
        .doc(broadcastId)
        .collection('highlights')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BroadcastHighlight.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  // ── Chat Settings ───────────────────────────────────────

  /// Toggle chat
  Future<void> toggleChat(String broadcastId, bool enabled) async {
    try {
      await _db.collection(_broadcastsCollection).doc(broadcastId).update({
        'chatEnabled': enabled,
      });
    } catch (e) {
      debugPrint('❌ Error toggling chat: $e');
    }
  }

  /// Set slow mode
  Future<void> setSlowMode(String broadcastId, int seconds) async {
    try {
      await _db.collection(_broadcastsCollection).doc(broadcastId).update({
        'slowModeSeconds': seconds,
      });
    } catch (e) {
      debugPrint('❌ Error setting slow mode: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────

  /// Generate 6-digit crew code
  String _generateCrewCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
