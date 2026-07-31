import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Real-time viewer tracking for live matches.
///
/// Firestore schema:
/// - `matches/{matchId}/viewers/{userId}` — one doc per live viewer
/// - `matches/{matchId}.viewerStats` — aggregate counters:
///   - `liveViewers` (int) — current count
///   - `totalViews` (int) — cumulative unique views
///   - `peakViewers` (int) — highest concurrent
class ViewerService {
  static ViewerService? _instance;
  static ViewerService get instance => _instance ??= ViewerService._();
  ViewerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Stream viewer stats ──────────────────────────────────────────

  /// Returns a stream of viewer stats for [matchId].
  /// Emits `{liveViewers, totalViews, peakViewers}` or zeros.
  Stream<Map<String, int>> streamViewerStats(String matchId) {
    return _db.collection('matches').doc(matchId).snapshots().map((doc) {
      if (!doc.exists) return {'liveViewers': 0, 'totalViews': 0, 'peakViewers': 0};
      final data = doc.data();
      if (data == null) return {'liveViewers': 0, 'totalViews': 0, 'peakViewers': 0};
      return {
        'liveViewers': (data['liveViewers'] as num? ?? 0).toInt(),
        'totalViews': (data['totalViews'] as num? ?? 0).toInt(),
        'peakViewers': (data['peakViewers'] as num? ?? 0).toInt(),
      };
    });
  }

  // ── Join / Leave ─────────────────────────────────────────────────

  /// Call when user opens the match detail screen.
  /// Creates a viewer doc and increments counters atomically.
  Future<void> joinMatch(String matchId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // anonymous users don't track

    final matchRef = _db.collection('matches').doc(matchId);
    final viewerRef = matchRef.collection('viewers').doc(uid);

    try {
      // Check if viewer doc already exists (re-joining after tab switch)
      final existing = await viewerRef.get();
      if (existing.exists) {
        // Just touch the timestamp
        await viewerRef.update({'lastSeen': FieldValue.serverTimestamp()});
        return;
      }

      // Atomic: create viewer doc + update counters
      await _db.runTransaction((tx) async {
        final matchSnap = await tx.get(matchRef);
        final data = matchSnap.data() ?? {};

        final currentLive = (data['liveViewers'] as num? ?? 0).toInt();
        final currentPeak = (data['peakViewers'] as num? ?? 0).toInt();
        final newLive = currentLive + 1;
        final newPeak = newLive > currentPeak ? newLive : currentPeak;

        tx.set(viewerRef, {
          'joinedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });

        tx.update(matchRef, {
          'liveViewers': newLive,
          'peakViewers': newPeak,
          'totalViews': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('👁️ Viewer joined match $matchId');
    } catch (e) {
      debugPrint('❌ Error joining match viewers: $e');
    }
  }

  /// Call when user leaves the match detail screen (dispose / pop).
  Future<void> leaveMatch(String matchId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final matchRef = _db.collection('matches').doc(matchId);
    final viewerRef = matchRef.collection('viewers').doc(uid);

    try {
      final existing = await viewerRef.get();
      if (!existing.exists) return;

      await _db.runTransaction((tx) async {
        final matchSnap = await tx.get(matchRef);
        final data = matchSnap.data() ?? {};

        final currentLive = (data['liveViewers'] as num? ?? 0).toInt();
        final newLive = currentLive > 0 ? currentLive - 1 : 0;

        tx.delete(viewerRef);

        tx.update(matchRef, {
          'liveViewers': newLive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('👁️ Viewer left match $matchId');
    } catch (e) {
      debugPrint('❌ Error leaving match viewers: $e');
    }
  }

  // ── Cleanup stale viewers ────────────────────────────────────────

  /// Remove viewers whose lastSeen is older than [threshold].
  /// Call periodically or on match start.
  Future<void> cleanupStaleViewers(String matchId, {Duration threshold = const Duration(minutes: 5)}) async {
    try {
      final cutoff = DateTime.now().subtract(threshold);
      final staleSnap = await _db
          .collection('matches')
          .doc(matchId)
          .collection('viewers')
          .where('lastSeen', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      if (staleSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in staleSnap.docs) {
        batch.delete(doc.reference);
      }

      // Also fix liveViewers count
      final matchRef = _db.collection('matches').doc(matchId);
      final matchSnap = await matchRef.get();
      if (matchSnap.exists) {
        final correctCount = (await _db
            .collection('matches')
            .doc(matchId)
            .collection('viewers')
            .count()
            .get()).count ?? 0;
        batch.update(matchRef, {
          'liveViewers': correctCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('🧹 Cleaned up ${staleSnap.docs.length} stale viewers for match $matchId');
    } catch (e) {
      debugPrint('❌ Error cleaning up stale viewers: $e');
    }
  }
}
