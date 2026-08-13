import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../models/achievement_model.dart';
import '../models/match_performance.dart';
import '../models/notification_model.dart';
import '../models/join_request_model.dart';
import '../models/tournament_join_request_model.dart';
import 'star_calculator.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'match_stats_calculator.dart';
import '../../core/utils/location_utils.dart';

/// Firebase Data Service - Connects to Firestore for all data operations
/// Replaces mock services with real Firebase persistence
class FirebaseDataService {
  // Singleton
  static FirebaseDataService? _instance;
  static FirebaseDataService get instance => _instance ??= FirebaseDataService._();
  FirebaseDataService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection names
  static const String usersCollection = 'users';
  static const String teamsCollection = 'teams';
  static const String matchesCollection = 'matches';
  static const String tournamentsCollection = 'tournaments';
  static const String followersCollection = 'followers';

  // ==================== USERS ====================

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _db.collection(usersCollection).doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user: $e');
      return null;
    }
  }

  /// Stream user profile in real-time
  Stream<UserModel?> streamUser(String userId) {
    return _db.collection(usersCollection).doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromMap({...snapshot.data()!, 'uid': snapshot.id});
      }
      return null;
    });
  }

  /// Find user by any ID format - tries doc ID, then SPP ID, then phone number
  /// This handles the mismatch where match data may store player IDs differently
  Future<UserModel?> findUserByAnyId(String playerId) async {
    if (playerId.isEmpty) return null;
    
    try {
      // 1. Try direct Firestore doc ID lookup
      final user = await getUserById(playerId);
      if (user != null) return user;
      
      // 2. Try SPP ID lookup (e.g., SPP12345678)
      if (playerId.toUpperCase().startsWith('SPP') && playerId.length > 5) {
        final sppUser = await getUserBySppId(playerId);
        if (sppUser != null) return sppUser;
      }
      
      // 3. Try searching by phone number (support both 'phone' and 'phoneNumber' keys)
      if (playerId.length >= 10) {
        final phoneSnapshot = await _db
            .collection(usersCollection)
            .where('phone', isEqualTo: playerId)
            .limit(1)
            .get();
        if (phoneSnapshot.docs.isNotEmpty) {
          final doc = phoneSnapshot.docs.first;
          return UserModel.fromMap({...doc.data(), 'uid': doc.id});
        }
        
        final phoneNumberSnapshot = await _db
            .collection(usersCollection)
            .where('phoneNumber', isEqualTo: playerId)
            .limit(1)
            .get();
        if (phoneNumberSnapshot.docs.isNotEmpty) {
          final doc = phoneNumberSnapshot.docs.first;
          return UserModel.fromMap({...doc.data(), 'uid': doc.id});
        }
      }
      
      // 4. Try name search if it was a manual player ID generated from a name
      // Example: 'P_PAVAN YADAV' -> 'pavan yadav' or 'P_SPP123' -> 'SPP123'
      String searchName = '';
      final lowerId = playerId.toLowerCase().trim();
      
      if (lowerId.startsWith('p_')) {
        searchName = lowerId.substring(2).trim();
      } else if (lowerId.startsWith('player_')) {
        searchName = lowerId.substring(7).trim();
      } else if (lowerId.startsWith('manual_')) {
        searchName = lowerId.substring(7).trim();
      }
      
      if (searchName.isNotEmpty) {
        final resolved = await resolveTemporaryPlayer(playerId, searchName);
        if (resolved != null) return resolved;
      }
      
      // 5. Fallback: Search directly using the playerId as the playerName (in case of prefix-less manual player ID)
      final resolvedFallback = await resolveTemporaryPlayer(playerId, playerId);
      if (resolvedFallback != null) return resolvedFallback;
      
      debugPrint('⚠️ Could not find user with any ID format: $playerId');
      return null;
    } catch (e) {
      debugPrint('❌ Error in findUserByAnyId: $e');
      return null;
    }
  }

  /// Attempts to find a real user profile for a manually entered player using their name
  Future<UserModel?> resolveTemporaryPlayer(String manualId, String playerName) async {
    if (playerName.isEmpty || playerName == 'Batsman' || playerName == 'Bowler') return null;
    
    try {
      // 1. Check if playerName is actually an SPP ID
      if (playerName.toUpperCase().startsWith('SPP') && playerName.length > 5) {
        final sppUser = await getUserBySppId(playerName.toUpperCase());
        if (sppUser != null) return sppUser;
      }
      
      String cleanName = playerName.trim();
      if (cleanName.toLowerCase().startsWith('p_')) cleanName = cleanName.substring(2).trim();
      
      // 2. Multi-pronged exact name search in Firestore (Direct Queries)
      // This is way faster and more reliable than downloading 1000 users
      final List<String> variations = [
        cleanName, // Original typed case
        cleanName.toLowerCase(), // lowercase
        cleanName.toUpperCase(), // UPPERCASE
        // Title Case (Every Word Capitalized)
        cleanName.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ').trim(),
      ];

      // Remove duplicates
      final uniqueVariations = variations.toSet().toList();

      for (final nameVariant in uniqueVariations) {
        if (nameVariant.isEmpty) continue;
        
        final snapshot = await _db.collection(usersCollection)
            .where('name', isEqualTo: nameVariant)
            .limit(1)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          debugPrint('🎯 Resolved $playerName via exact name match: $nameVariant');
          return UserModel.fromMap({...doc.data(), 'uid': doc.id});
        }
        
        // Also check if this variant is an SPP ID
        if (nameVariant.toUpperCase().startsWith('SPP') && nameVariant.length > 5) {
          final sppUser = await getUserBySppId(nameVariant.toUpperCase());
          if (sppUser != null) return sppUser;
        }
      }

      // 3. Fallback: Search SPP ID field if the name entered WAS an SPP ID but didn't match 'name' field
      final sppSnapshot = await _db.collection(usersCollection)
          .where('spPId', isEqualTo: cleanName.toUpperCase())
          .limit(1)
          .get();
      if (sppSnapshot.docs.isNotEmpty) {
        final doc = sppSnapshot.docs.first;
        return UserModel.fromMap({...doc.data(), 'uid': doc.id});
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error resolving player $playerName: $e');
      return null;
    }
  }

  /// Resolves a temporary player and immediately links their official UID to the match's playerIds array.
  /// This ensures the match shows up in their "My Matches" section while the match is still LIVE.
  Future<String?> resolveAndLinkPlayerToMatch(String matchId, String tempPlayerId, String playerName) async {
    if (matchId.isEmpty || tempPlayerId.isEmpty || playerName.isEmpty) return null;
    
    // 1. Try to resolve if it's a temporary ID
    bool isLikelyTemporary = tempPlayerId.length < 20 || 
                             tempPlayerId.startsWith('p_') || 
                             tempPlayerId.startsWith('manual_') || 
                             tempPlayerId.contains(' ');
                             
    String resolvedId = tempPlayerId;
    
    if (isLikelyTemporary) {
      final resolvedUser = await resolveTemporaryPlayer(tempPlayerId, playerName);
      if (resolvedUser != null && resolvedUser.uid.isNotEmpty) {
        resolvedId = resolvedUser.uid;
        debugPrint('🔗 Real-time Resolution: "$tempPlayerId" ($playerName) -> $resolvedId');
      } else {
        return null; // Could not resolve to a real user
      }
    } else {
      // It's already potentially a UID, but let's verify if it's linked
      // If it's a standard registered user ID, we proceed with resolvedId = tempPlayerId
    }

    try {
      // 2. Link the resolved UID to the match's playerIds array
      await _db.collection(matchesCollection).doc(matchId).update({
        'playerIds': FieldValue.arrayUnion([resolvedId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return resolvedId;
    } catch (e) {
      debugPrint('❌ Error linking $resolvedId to match $matchId: $e');
      return null;
    }
  }


  /// Get user by SPP ID
  Future<UserModel?> getUserBySppId(String sppId) async {
    try {
      final normalizedId = sppId.toUpperCase();
      debugPrint('🔍 Looking up user by SPP ID: $normalizedId');
      
      final snapshot = await _db
          .collection(usersCollection)
          .where('spPId', isEqualTo: normalizedId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        debugPrint('✅ Found user: ${doc.data()['name']}');
        return UserModel.fromMap({...doc.data(), 'uid': doc.id});
      }
      debugPrint('❌ No user found with SPP ID: $normalizedId');
      return null;
    } catch (e) {
      debugPrint('❌ Error looking up user by SPP ID: $e');
      return null;
    }
  }

  /// Search users by name (case-insensitive)
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final queryTrimmed = query.trim();
      
      // Build multiple case variants to search (Firestore startAt/endAt is case-sensitive)
      final variants = <String>{
        queryTrimmed,                                                    // exact as typed
        queryTrimmed.toLowerCase(),                                      // all lowercase
        queryTrimmed.substring(0, 1).toUpperCase() + queryTrimmed.substring(1).toLowerCase(), // Capitalized
        queryTrimmed.toUpperCase(),                                      // ALL CAPS
      };

      final Map<String, UserModel> results = {};

      // Query each case variant
      for (final variant in variants) {
        final snapshot = await _db
            .collection(usersCollection)
            .orderBy('name')
            .startAt([variant])
            .endAt(['$variant\uf8ff'])
            .limit(10)
            .get();

        for (final doc in snapshot.docs) {
          results.putIfAbsent(doc.id, () => UserModel.fromMap({...doc.data(), 'uid': doc.id}));
        }
      }

      // If we still have few results, do a broader client-side search
      if (results.length < 5) {
        final lowerQuery = queryTrimmed.toLowerCase();
        final fallbackSnapshot = await _db
            .collection(usersCollection)
            .orderBy('name')
            .limit(200)
            .get();

        for (final doc in fallbackSnapshot.docs) {
          final name = (doc.data()['name'] ?? '').toString().toLowerCase();
          if (name.contains(lowerQuery)) {
            results.putIfAbsent(doc.id, () => UserModel.fromMap({...doc.data(), 'uid': doc.id}));
          }
        }
      }

      return results.values.take(20).toList();
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  /// Update user stats after match
  Future<void> updateUserStats(String userId, String ballType, Map<String, dynamic> stats) async {
    try {
      final statsField = ballType == 'tennis' ? 'tennisBallStats' : 'leatherBallStats';
      await _db.collection(usersCollection).doc(userId).update({
        statsField: stats,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Updated stats for user $userId');
    } catch (e) {
      debugPrint('❌ Error updating user stats: $e');
    }
  }

  /// Comprehensively update player match stats using a transaction
  /// Apply match performance to user stats atomically and idempotently
  Future<void> applyMatchPerformanceAtomic(MatchPerformance perf) async {
    final userId = perf.playerId;
    if (userId.isEmpty || userId.startsWith('p_') || userId.startsWith('manual_')) {
      debugPrint('ℹ️ Skipping stats increment for manual/unregistered player $userId');
      return;
    }

    try {
      final statsField = perf.ballType == 'tennis' ? 'tennisBallStats' : 'leatherBallStats';
      final docRef = _db.collection(usersCollection).doc(userId);
      final trackerRef = docRef.collection('processed_matches').doc(perf.matchId);

      await _db.runTransaction((transaction) async {
        // 1. Check if already processed
        final trackerSnap = await transaction.get(trackerRef);
        if (trackerSnap.exists) {
          debugPrint('⏭️ Match ${perf.matchId} already processed for $userId. Skipping.');
          return;
        }

        // 2. Get current user data
        final userSnap = await transaction.get(docRef);
        if (!userSnap.exists) {
          debugPrint('❌ User $userId does not exist');
          return;
        }

        final data = userSnap.data()!;
        Map<String, dynamic> existingStats = data[statsField] != null
            ? Map<String, dynamic>.from(data[statsField] as Map)
            : {
                'matches': 0, 'runs': 0, 'wickets': 0, 'strikeRate': 0.0, 'economy': 0.0,
                'bestScore': 0, 'bestBowling': '0/0', 'manOfMatches': 0, 'tournamentWins': 0,
                'balls': 0, 'ballsBowled': 0, 'runsConceded': 0, 'fours': 0, 'sixes': 0,
                'fifties': 0, 'hundreds': 0, 'ducks': 0, 'fiveWickets': 0,
                'catches': 0, 'runOuts': 0, 'stumpings': 0, 'directHits': 0,
              };

        // 3. Calculate new totals
        int totalMatches = (existingStats['matches'] as num? ?? 0).toInt() + 1;
        int totalRuns = (existingStats['runs'] as num? ?? 0).toInt() + perf.runsScored;
        int totalBallsFaced = (existingStats['balls'] as num? ?? 0).toInt() + perf.ballsFaced;
        int totalWickets = (existingStats['wickets'] as num? ?? 0).toInt() + perf.wickets;
        int totalRunsConceded = (existingStats['runsConceded'] as num? ?? 0).toInt() + perf.runsConceded;
        int totalBallsBowled = (existingStats['ballsBowled'] as num? ?? 0).toInt() + perf.ballsBowled;

        // Best Score
        int newBestScore = perf.runsScored > (existingStats['bestScore'] as num? ?? 0).toInt() 
            ? perf.runsScored : (existingStats['bestScore'] as num? ?? 0).toInt();

        // Best Bowling
        String currentBestBowling = existingStats['bestBowling'] as String? ?? '0/0';
        int currBestWickets = int.tryParse(currentBestBowling.split('/')[0]) ?? 0;
        int currBestRuns = int.tryParse(currentBestBowling.split('/')[1]) ?? 0;
        String newBestBowling = currentBestBowling;
        if (perf.wickets > currBestWickets || (perf.wickets == currBestWickets && perf.wickets > 0 && perf.runsConceded < currBestRuns)) {
          newBestBowling = '${perf.wickets}/${perf.runsConceded}';
        }

        // Apply updates to stats map
        existingStats['matches'] = totalMatches;
        existingStats['runs'] = totalRuns;
        existingStats['balls'] = totalBallsFaced;
        existingStats['wickets'] = totalWickets;
        existingStats['runsConceded'] = totalRunsConceded;
        existingStats['ballsBowled'] = totalBallsBowled;
        existingStats['fours'] = (existingStats['fours'] as num? ?? 0).toInt() + perf.fours;
        existingStats['sixes'] = (existingStats['sixes'] as num? ?? 0).toInt() + perf.sixes;
        existingStats['fifties'] = (existingStats['fifties'] as num? ?? 0).toInt() + (perf.isFifty ? 1 : 0);
        existingStats['hundreds'] = (existingStats['hundreds'] as num? ?? 0).toInt() + (perf.isHundred ? 1 : 0);
        existingStats['ducks'] = (existingStats['ducks'] as num? ?? 0).toInt() + (perf.isDuck ? 1 : 0);
        existingStats['fiveWickets'] = (existingStats['fiveWickets'] as num? ?? 0).toInt() + (perf.isFiveWicketHaul ? 1 : 0);
        existingStats['catches'] = (existingStats['catches'] as num? ?? 0).toInt() + perf.catches;
        existingStats['runOuts'] = (existingStats['runOuts'] as num? ?? 0).toInt() + perf.runOuts;
        existingStats['stumpings'] = (existingStats['stumpings'] as num? ?? 0).toInt() + perf.stumpings;
        existingStats['directHits'] = (existingStats['directHits'] as num? ?? 0).toInt() + perf.directHits;
        existingStats['bestScore'] = newBestScore;
        existingStats['bestBowling'] = newBestBowling;
        existingStats['manOfMatches'] = (existingStats['manOfMatches'] as num? ?? 0).toInt() + (perf.isManOfMatch ? 1 : 0);
        
        // Calculated averages
        existingStats['strikeRate'] = totalBallsFaced > 0 ? double.parse(((totalRuns / totalBallsFaced) * 100).toStringAsFixed(2)) : 0.0;
        double totalOvers = totalBallsBowled / 6.0;
        existingStats['economy'] = totalOvers > 0 ? double.parse((totalRunsConceded / totalOvers).toStringAsFixed(2)) : 0.0;

        // 4. Badges (Gen-Z logic)
        List<dynamic> existingAchievementsRaw = data['achievements'] as List<dynamic>? ?? [];
        List<String> existingBadgeTypes = existingAchievementsRaw.whereType<Map<String, dynamic>>().map((e) => e['type'] as String? ?? '').toList();
        List<Map<String, dynamic>> newBadges = [];

        if (totalRuns >= 100 && !existingBadgeTypes.contains('badge_first_blood')) newBadges.add(PlayerAchievement.firstBlood(userId, totalRuns).toMap());
        if (totalRuns >= 500 && !existingBadgeTypes.contains('badge_run_machine')) newBadges.add(PlayerAchievement.runMachine(userId, totalRuns).toMap());
        if (totalRuns >= 1000 && !existingBadgeTypes.contains('badge_certified_batsman')) newBadges.add(PlayerAchievement.certifiedBatsman(userId, totalRuns).toMap());
        if (totalWickets >= 10 && !existingBadgeTypes.contains('badge_breakthrough')) newBadges.add(PlayerAchievement.breakthrough(userId, totalWickets).toMap());
        if (totalWickets >= 50 && !existingBadgeTypes.contains('badge_wicket_dealer')) newBadges.add(PlayerAchievement.wicketDealer(userId, totalWickets).toMap());

        // 5. ⭐ Warrior Progression – Star Calculation (fault-tolerant)
        int newStars = (data['stars'] as num? ?? 0).toInt();
        String newRankTitle = (data['rankTitle'] as String?) ?? 'Bal Yoddha';
        List<String> currentUnlockedTitles = [];
        try {
          int oldStars = newStars;
          int matchStars = StarCalculator.calculateMatchStars(
            runsScored: perf.runsScored,
            ballsFaced: perf.ballsFaced,
            wickets: perf.wickets,
            catches: perf.catches,
            runOuts: perf.runOuts,
            stumpings: perf.stumpings,
            directHits: perf.directHits,
            isManOfMatch: perf.isManOfMatch,
            isWinner: perf.isWinner,
          );
          newStars = oldStars + matchStars;
          newRankTitle = StarCalculator.getRankTitle(newStars);
          currentUnlockedTitles = List<String>.from(data['unlockedTitles'] ?? <String>['Bal Yoddha']);
          
          // Add rank title if new
          if (!currentUnlockedTitles.contains(newRankTitle)) {
            currentUnlockedTitles.add(newRankTitle);
          }

          // Calculate Epic Titles based on new cumulative stats
          String bowlingStyle = (data['bowlingStyle'] as String? ?? '');
          List<String> epicTitles = StarCalculator.calculateEpicTitles(existingStats, bowlingStyle);
          for (final title in epicTitles) {
            if (!currentUnlockedTitles.contains(title)) {
              currentUnlockedTitles.add(title);
              debugPrint('🎖️ Player $userId unlocked Epic Title: $title');
            }
          }
          debugPrint('⭐ Player $userId earned $matchStars stars ($oldStars → $newStars) | Rank: $newRankTitle');
        } catch (starError, starStack) {
          debugPrint('⚠️ Star calculation failed for $userId (stats will still update): $starError');
          debugPrint('$starStack');
          // Keep defaults so stats still commit
          currentUnlockedTitles = List<String>.from(data['unlockedTitles'] ?? <String>['Bal Yoddha']);
        }

        // 6. Commit all updates
        Map<String, dynamic> mainUpdate = {
          statsField: existingStats,
          'stars': newStars,
          'rankTitle': newRankTitle,
          'unlockedTitles': currentUnlockedTitles,
          'lastActiveAt': FieldValue.serverTimestamp(),
        };
        if (newBadges.isNotEmpty) mainUpdate['achievements'] = FieldValue.arrayUnion(newBadges);

        transaction.update(docRef, mainUpdate);
        transaction.set(trackerRef, {'processedAt': FieldValue.serverTimestamp(), 'matchId': perf.matchId});
      });
      debugPrint('✅ Idempotently updated stats for $userId (Match: ${perf.matchId})');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in applyMatchPerformanceAtomic for $userId: $e');
      debugPrint('📋 Stack trace: $stackTrace');
    }
  }

  /// Reverses the stats application for a player for a specific match.
  /// Used when a completed match is deleted.
  Future<void> rollbackMatchPerformanceAtomic(MatchPerformance perf) async {
    final userId = perf.playerId;
    if (userId.isEmpty || userId.startsWith('p_') || userId.startsWith('manual_')) {
      debugPrint('ℹ️ Skipping stats rollback for manual/unregistered player $userId');
      return;
    }

    try {
      final statsField = perf.ballType == 'tennis' ? 'tennisBallStats' : 'leatherBallStats';
      final docRef = _db.collection(usersCollection).doc(userId);
      final trackerRef = docRef.collection('processed_matches').doc(perf.matchId);

      await _db.runTransaction((transaction) async {
        // 1. Check if it was ever processed
        final trackerSnap = await transaction.get(trackerRef);
        if (!trackerSnap.exists) {
          debugPrint('⏭️ Match ${perf.matchId} not processed for $userId. Nothing to rollback.');
          return;
        }

        // 2. Get current user data
        final userSnap = await transaction.get(docRef);
        if (!userSnap.exists) {
          debugPrint('❌ User $userId does not exist');
          return;
        }

        final data = userSnap.data()!;
        if (data[statsField] == null) return;
        
        Map<String, dynamic> existingStats = Map<String, dynamic>.from(data[statsField] as Map);

        // 3. Subtract the match's stats
        int totalMatches = (existingStats['matches'] as num? ?? 0).toInt() - 1;
        int totalRuns = (existingStats['runs'] as num? ?? 0).toInt() - perf.runsScored;
        int totalBallsFaced = (existingStats['balls'] as num? ?? 0).toInt() - perf.ballsFaced;
        int totalWickets = (existingStats['wickets'] as num? ?? 0).toInt() - perf.wickets;
        int totalRunsConceded = (existingStats['runsConceded'] as num? ?? 0).toInt() - perf.runsConceded;
        int totalBallsBowled = (existingStats['ballsBowled'] as num? ?? 0).toInt() - perf.ballsBowled;

        // Prevent negative values just in case
        if (totalMatches < 0) totalMatches = 0;
        if (totalRuns < 0) totalRuns = 0;
        if (totalBallsFaced < 0) totalBallsFaced = 0;
        if (totalWickets < 0) totalWickets = 0;
        if (totalRunsConceded < 0) totalRunsConceded = 0;
        if (totalBallsBowled < 0) totalBallsBowled = 0;

        existingStats['matches'] = totalMatches;
        existingStats['runs'] = totalRuns;
        existingStats['balls'] = totalBallsFaced;
        existingStats['wickets'] = totalWickets;
        existingStats['runsConceded'] = totalRunsConceded;
        existingStats['ballsBowled'] = totalBallsBowled;

        int fours = (existingStats['fours'] as num? ?? 0).toInt() - perf.fours;
        existingStats['fours'] = fours < 0 ? 0 : fours;

        int sixes = (existingStats['sixes'] as num? ?? 0).toInt() - perf.sixes;
        existingStats['sixes'] = sixes < 0 ? 0 : sixes;

        int fifties = (existingStats['fifties'] as num? ?? 0).toInt() - (perf.isFifty ? 1 : 0);
        existingStats['fifties'] = fifties < 0 ? 0 : fifties;

        int hundreds = (existingStats['hundreds'] as num? ?? 0).toInt() - (perf.isHundred ? 1 : 0);
        existingStats['hundreds'] = hundreds < 0 ? 0 : hundreds;

        int ducks = (existingStats['ducks'] as num? ?? 0).toInt() - (perf.isDuck ? 1 : 0);
        existingStats['ducks'] = ducks < 0 ? 0 : ducks;

        int fiveWickets = (existingStats['fiveWickets'] as num? ?? 0).toInt() - (perf.isFiveWicketHaul ? 1 : 0);
        existingStats['fiveWickets'] = fiveWickets < 0 ? 0 : fiveWickets;

        int catches = (existingStats['catches'] as num? ?? 0).toInt() - perf.catches;
        existingStats['catches'] = catches < 0 ? 0 : catches;

        int runOuts = (existingStats['runOuts'] as num? ?? 0).toInt() - perf.runOuts;
        existingStats['runOuts'] = runOuts < 0 ? 0 : runOuts;

        int stumpings = (existingStats['stumpings'] as num? ?? 0).toInt() - perf.stumpings;
        existingStats['stumpings'] = stumpings < 0 ? 0 : stumpings;

        int directHits = (existingStats['directHits'] as num? ?? 0).toInt() - perf.directHits;
        existingStats['directHits'] = directHits < 0 ? 0 : directHits;

        int manOfMatches = (existingStats['manOfMatches'] as num? ?? 0).toInt() - (perf.isManOfMatch ? 1 : 0);
        existingStats['manOfMatches'] = manOfMatches < 0 ? 0 : manOfMatches;

        // Re-calculate averages
        existingStats['strikeRate'] = totalBallsFaced > 0 ? double.parse(((totalRuns / totalBallsFaced) * 100).toStringAsFixed(2)) : 0.0;
        double totalOvers = totalBallsBowled / 6.0;
        existingStats['economy'] = totalOvers > 0 ? double.parse((totalRunsConceded / totalOvers).toStringAsFixed(2)) : 0.0;

        // Reverse Stars
        int currentStars = (data['stars'] as num? ?? 0).toInt();
        int matchStars = StarCalculator.calculateMatchStars(
          runsScored: perf.runsScored,
          ballsFaced: perf.ballsFaced,
          wickets: perf.wickets,
          catches: perf.catches,
          runOuts: perf.runOuts,
          stumpings: perf.stumpings,
          directHits: perf.directHits,
          isManOfMatch: perf.isManOfMatch,
          isWinner: perf.isWinner,
        );

        int newStars = currentStars - matchStars;
        if (newStars < 0) newStars = 0;
        String newRankTitle = StarCalculator.getRankTitle(newStars);

        Map<String, dynamic> mainUpdate = {
          statsField: existingStats,
          'stars': newStars,
          'rankTitle': newRankTitle,
          'lastActiveAt': FieldValue.serverTimestamp(),
        };

        transaction.update(docRef, mainUpdate);
        transaction.delete(trackerRef); // Remove the tracker so it's clean
      });
      debugPrint('✅ Idempotently rolled back stats for $userId (Match: ${perf.matchId})');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in rollbackMatchPerformanceAtomic for $userId: $e');
      debugPrint('📋 Stack trace: $stackTrace');
    }
  }

  Future<void> updatePlayerMatchStats(String userId, String ballType, Map<String, dynamic> matchStats) async {
    if (userId.isEmpty || userId.startsWith('p_') || userId.startsWith('manual_')) {
       debugPrint('ℹ️ Skipping stats increment for manual/unregistered player $userId');
       return;
    }

    try {
      final statsField = ballType == 'tennis' ? 'tennisBallStats' : 'leatherBallStats';
      final docRef = _db.collection(usersCollection).doc(userId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          debugPrint('❌ User $userId does not exist');
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        // Extract existing stats base
        Map<String, dynamic> existingStats = data[statsField] != null
            ? Map<String, dynamic>.from(data[statsField] as Map)
            : {
                'matches': 0,
                'runs': 0,
                'wickets': 0,
                'strikeRate': 0.0,
                'economy': 0.0,
                'bestScore': 0,
                'bestBowling': '0/0',
                'manOfMatches': 0,
                'tournamentWins': 0,
                // raw counters
                'balls': 0,
                'ballsBowled': 0,
                'runsConceded': 0,
                'fours': 0,
                'sixes': 0,
                'fifties': 0,
                'hundreds': 0,
                'ducks': 0,
                'fiveWickets': 0,
              };

        // Current totals
        int totalMatches = (existingStats['matches'] as num? ?? 0).toInt() + (matchStats['played'] == true ? 1 : 0);
        int totalRuns = (existingStats['runs'] as num? ?? 0).toInt() + (matchStats['runsScored'] as int? ?? 0);
        int totalBallsFaced = (existingStats['balls'] as num? ?? 0).toInt() + (matchStats['ballsFaced'] as int? ?? 0);
        
        int totalWickets = (existingStats['wickets'] as num? ?? 0).toInt() + (matchStats['wicketsTaking'] as int? ?? 0);
        int totalRunsConceded = (existingStats['runsConceded'] as num? ?? 0).toInt() + (matchStats['runsConceded'] as int? ?? 0);
        int totalBallsBowled = (existingStats['ballsBowled'] as num? ?? 0).toInt() + (matchStats['ballsBowled'] as int? ?? 0);
        
        int matchRuns = matchStats['runsScored'] as int? ?? 0;
        int currentBestScore = (existingStats['bestScore'] as num? ?? 0).toInt();
        int newBestScore = matchRuns > currentBestScore ? matchRuns : currentBestScore;

        // Strike rate = (runs / balls) * 100
        double newStrikeRate = totalBallsFaced > 0 ? (totalRuns / totalBallsFaced) * 100 : 0.0;
        
        // Economy = (runs conceded / overs bowled)
        double totalOversBowled = totalBallsBowled / 6.0;
        double newEconomy = totalOversBowled > 0 ? (totalRunsConceded / totalOversBowled) : 0.0;

        // Best Bowling format: 'wickets/runs' e.g. '5/20'
        int matchWickets = matchStats['wicketsTaking'] as int? ?? 0;
        int matchRunsConceded = matchStats['runsConceded'] as int? ?? 0;
        String currentBestBowling = existingStats['bestBowling'] as String? ?? '0/0';
        
        int currBestWickets = 0;
        int currBestRuns = 0;
        if (currentBestBowling.contains('/')) {
          final parts = currentBestBowling.split('/');
          if (parts.length == 2) {
            currBestWickets = int.tryParse(parts[0]) ?? 0;
            currBestRuns = int.tryParse(parts[1]) ?? 0;
          }
        }
        
        String newBestBowling = currentBestBowling;
        if (matchWickets > currBestWickets || (matchWickets == currBestWickets && matchWickets > 0 && matchRunsConceded < currBestRuns)) {
          newBestBowling = '$matchWickets/$matchRunsConceded';
        }

        // Man of the Match
        int currentMom = (existingStats['manOfMatches'] as num? ?? 0).toInt();
        int newMom = currentMom + (matchStats['isManOfMatch'] == true ? 1 : 0);

        // Apply back to existingStats
        existingStats['matches'] = totalMatches;
        existingStats['runs'] = totalRuns;
        existingStats['balls'] = totalBallsFaced;
        existingStats['wickets'] = totalWickets;
        existingStats['runsConceded'] = totalRunsConceded;
        existingStats['ballsBowled'] = totalBallsBowled;
        
        existingStats['fours'] = (existingStats['fours'] as num? ?? 0).toInt() + (matchStats['fours'] as int? ?? 0);
        existingStats['sixes'] = (existingStats['sixes'] as num? ?? 0).toInt() + (matchStats['sixes'] as int? ?? 0);
        existingStats['fifties'] = (existingStats['fifties'] as num? ?? 0).toInt() + (matchStats['fifties'] as int? ?? 0);
        existingStats['hundreds'] = (existingStats['hundreds'] as num? ?? 0).toInt() + (matchStats['hundreds'] as int? ?? 0);
        existingStats['ducks'] = (existingStats['ducks'] as num? ?? 0).toInt() + (matchStats['ducks'] as int? ?? 0);
        existingStats['fiveWickets'] = (existingStats['fiveWickets'] as num? ?? 0).toInt() + (matchStats['fiveWickets'] as int? ?? 0);
        
        existingStats['bestScore'] = newBestScore;
        existingStats['strikeRate'] = double.parse(newStrikeRate.toStringAsFixed(2));
        existingStats['economy'] = double.parse(newEconomy.toStringAsFixed(2));
        existingStats['bestBowling'] = newBestBowling;
        existingStats['manOfMatches'] = newMom;

        // 🎮 Evaluate Gen-Z Career Badges atomically
        List<dynamic> existingAchievementsRaw = data['achievements'] as List<dynamic>? ?? [];
        List<String> existingBadgeTypes = existingAchievementsRaw
            .whereType<Map<String, dynamic>>()
            .map((e) => e['type'] as String? ?? '')
            .toList();

        List<Map<String, dynamic>> newBadges = [];

        // Batsman logic check
        if (totalRuns >= 100 && !existingBadgeTypes.contains('badge_first_blood')) {
          newBadges.add(PlayerAchievement.firstBlood(userId, totalRuns).toMap());
        }
        if (totalRuns >= 500 && !existingBadgeTypes.contains('badge_run_machine')) {
          newBadges.add(PlayerAchievement.runMachine(userId, totalRuns).toMap());
        }
        if (totalRuns >= 1000 && !existingBadgeTypes.contains('badge_certified_batsman')) {
          newBadges.add(PlayerAchievement.certifiedBatsman(userId, totalRuns).toMap());
        }
        if (totalRuns >= 2500 && !existingBadgeTypes.contains('badge_local_legend')) {
          newBadges.add(PlayerAchievement.localLegend(userId, totalRuns).toMap());
        }
        if (totalRuns >= 5000 && !existingBadgeTypes.contains('badge_goat_batter')) {
          newBadges.add(PlayerAchievement.goatBatter(userId, totalRuns).toMap());
        }

        int totalSixes = (existingStats['sixes'] as num? ?? 0).toInt();
        if (totalSixes >= 50 && !existingBadgeTypes.contains('badge_six_hunter')) {
          newBadges.add(PlayerAchievement.sixHunter(userId, totalSixes).toMap());
        }

        int totalFours = (existingStats['fours'] as num? ?? 0).toInt();
        if (totalFours >= 200 && !existingBadgeTypes.contains('badge_boundary_boss')) {
          newBadges.add(PlayerAchievement.boundaryBoss(userId, totalFours).toMap());
        }

        if (totalMatches >= 10 && newStrikeRate > 150.0 && !existingBadgeTypes.contains('badge_quick_fire')) {
          newBadges.add(PlayerAchievement.quickFire(userId, newStrikeRate).toMap());
        }

        // Bowler logic check
        if (totalWickets >= 10 && !existingBadgeTypes.contains('badge_breakthrough')) {
          newBadges.add(PlayerAchievement.breakthrough(userId, totalWickets).toMap());
        }
        if (totalWickets >= 50 && !existingBadgeTypes.contains('badge_wicket_dealer')) {
          newBadges.add(PlayerAchievement.wicketDealer(userId, totalWickets).toMap());
        }
        if (totalWickets >= 100 && !existingBadgeTypes.contains('badge_bowling_brain')) {
          newBadges.add(PlayerAchievement.bowlingBrain(userId, totalWickets).toMap());
        }
        if (totalWickets >= 250 && !existingBadgeTypes.contains('badge_nightmare')) {
          newBadges.add(PlayerAchievement.nightmare(userId, totalWickets).toMap());
        }
        if (totalWickets >= 500 && !existingBadgeTypes.contains('badge_death_bringer')) {
          newBadges.add(PlayerAchievement.deathBringer(userId, totalWickets).toMap());
        }

        if (totalOversBowled >= 10.0 && newEconomy < 6.0 && !existingBadgeTypes.contains('badge_economy_freak')) {
          newBadges.add(PlayerAchievement.economyFreak(userId, newEconomy).toMap());
        }

        // Flex logic check
        if (totalMatches >= 100 && !existingBadgeTypes.contains('badge_veteran')) {
          newBadges.add(PlayerAchievement.veteran(userId, totalMatches).toMap());
        }

        Map<String, dynamic> updates = {
          statsField: existingStats,
          'lastActiveAt': FieldValue.serverTimestamp(),
        };

        if (newBadges.isNotEmpty) {
          updates['achievements'] = FieldValue.arrayUnion(newBadges);
        }

        transaction.update(docRef, updates);
      });
      
      debugPrint('✅ Comprehensively updated stats for user $userId');
    } catch (e) {
      debugPrint('❌ Error comprehensively updating user stats: $e');
    }
  }

  /// Add achievements to user profile
  Future<void> addAchievements(String userId, List<PlayerAchievement> achievements) async {
    if (userId.isEmpty || userId.startsWith('p_') || userId.startsWith('manual_')) {
       debugPrint('ℹ️ Skipping achievements update for manual/unregistered player $userId');
       return;
    }

    try {
      final docRef = _db.collection('users').doc(userId);
      
      // Convert achievements to map
      final achievementsList = achievements.map((a) => a.toMap()).toList();
      
      // Use arrayUnion to add to list
      await docRef.update({
        'achievements': FieldValue.arrayUnion(achievementsList),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Added ${achievements.length} achievements for user $userId');
    } catch (e) {
      debugPrint('❌ Error adding achievements: $e');
    }
  }

  /// Link tournament to player (add to tournamentIds list)
  Future<void> linkTournamentToPlayer(String userId, String tournamentId) async {
    if (userId.isEmpty || userId.startsWith('p_') || userId.startsWith('manual_')) {
       debugPrint('ℹ️ Skipping tournament link for manual/unregistered player $userId');
       return;
    }

    try {
      final docRef = _db.collection('users').doc(userId);
      
      await docRef.update({
        'tournamentIds': FieldValue.arrayUnion([tournamentId]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Linked tournament $tournamentId to user $userId');
    } catch (e) {
      debugPrint('❌ Error linking tournament to player: $e');
    }
  }

  /// Update user presence (online status)
  Future<void> updateUserPresence(String userId, bool isOnline) async {
    try {
      await _db.collection(usersCollection).doc(userId).update({
        'isOnline': isOnline,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating user presence: $e');
    }
  }

  /// Check user presence stream
  Stream<bool> getUserPresenceStream(String userId) {
    return _db.collection(usersCollection).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      
      // Determine if online based on lastActiveAt threshold (e.g., 2 minutes)
      // Or explicit 'isOnline' field if maintained accurately
      final isOnline = data['isOnline'] ?? false;
      final lastActiveAt = (data['lastActiveAt'] as Timestamp?)?.toDate();
      
      if (isOnline) return true;

      // Fallback: Check if last active within 2 minutes
      if (lastActiveAt != null) {
        final diff = DateTime.now().difference(lastActiveAt);
        return diff.inMinutes < 2;
      }
      
      return false;
    });
  }

  // ==================== TEAMS ====================

  /// Upload team logo and update the team's logoUrl in Firestore
  /// Stores as base64 data URL directly in Firestore (avoids Storage CORS issues on web)
  Future<bool> updateTeamLogo(String teamId, Uint8List imageBytes) async {
    try {
      debugPrint('📸 Logo upload starting — raw size: ${imageBytes.length} bytes');

      // Resize image to 200x200 to keep it small for Firestore
      Uint8List finalBytes = imageBytes;
      try {
        final codec = await ui.instantiateImageCodec(
          imageBytes,
          targetWidth: 200,
          targetHeight: 200,
        );
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          finalBytes = byteData.buffer.asUint8List();
          debugPrint('📸 Resized to 200x200 — new size: ${finalBytes.length} bytes');
        }
      } catch (resizeError) {
        debugPrint('⚠️ Could not resize, using original: $resizeError');
      }

      // Convert to base64 data URL
      final base64Image = base64Encode(finalBytes);
      final dataUrl = 'data:image/png;base64,$base64Image';
      debugPrint('📸 Base64 data URL length: ${dataUrl.length} chars');
      
      // Firestore doc limit is 1MB
      if (dataUrl.length > 900000) {
        debugPrint('❌ Logo too large even after resize (${dataUrl.length} chars)');
        return false;
      }

      await _db.collection(teamsCollection).doc(teamId).update({
        'logoUrl': dataUrl,
      });
      debugPrint('✅ Team logo saved successfully!');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating team logo: $e');
      return false;
    }
  }

  /// Create a new team
  Future<TeamModel?> createTeam(TeamModel team, String creatorId) async {
    try {
      final teamData = {
        ...team.toMap(),
        'createdBy': creatorId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      teamData.remove('id'); // Let Firestore generate ID

      final docRef = await _db.collection(teamsCollection).add(teamData);
      debugPrint('✅ Team created: ${team.name} (ID: ${docRef.id})');
      
      return team.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error creating team: $e');
      return null;
    }
  }

  /// Get teams created by user or where user is captain
  Future<List<TeamModel>> getUserTeams(String userId) async {
    try {
      debugPrint('🔍 Fetching teams for user: $userId');
      
      // Query by captainId (simpler query without orderBy to avoid index requirement)
      final snapshot = await _db
          .collection(teamsCollection)
          .where('captainId', isEqualTo: userId)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} teams for user');
      
      final teams = snapshot.docs
          .map((doc) => TeamModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sort locally by createdAt
      teams.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return teams;
    } catch (e) {
      debugPrint('❌ Error getting user teams: $e');
      // If it's an index error, the message will contain a link to create the index
      return [];
    }
  }

  /// Get teams where user is a player (member)
  Future<List<TeamModel>> getTeamsWhereUserIsPlayer(String userId, String? spPId) async {
    try {
      debugPrint('🔍 Fetching teams where user $userId is a player');
      
      // Firestore can't query nested arrays directly, so we fetch all teams and filter client-side
      // For better performance, we limit to recent teams
      final snapshot = await _db
          .collection(teamsCollection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final allTeams = snapshot.docs
          .map((doc) => TeamModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Filter teams where user is in the players list
      final playerTeams = allTeams.where((team) {
        return team.players.any((player) => 
          player.userId == userId || 
          (spPId != null && spPId.isNotEmpty && player.spPId == spPId)
        );
      }).toList();

      debugPrint('📊 Found ${playerTeams.length} teams where user is a player');
      return playerTeams;
    } catch (e) {
      debugPrint('❌ Error getting player teams: $e');
      return [];
    }
  }

  /// Get all teams
  Future<List<TeamModel>> getAllTeams({int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection(teamsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => TeamModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting teams: $e');
      return [];
    }
  }

  /// Get team by ID
  Future<TeamModel?> getTeamById(String teamId) async {
    try {
      final doc = await _db.collection(teamsCollection).doc(teamId).get();
      if (doc.exists) {
        return TeamModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting team by ID: $e');
      return null;
    }
  }

  /// Add player to team
  Future<bool> addPlayerToTeam(String teamId, TeamPlayer player) async {
    try {
      await _db.collection(teamsCollection).doc(teamId).update({
        'players': FieldValue.arrayUnion([player.toMap()]),
      });
      debugPrint('✅ Player ${player.name} added to team $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding player to team: $e');
      return false;
    }
  }

  /// Remove player from team
  Future<bool> removePlayerFromTeam(String teamId, TeamPlayer player) async {
    try {
      await _db.collection(teamsCollection).doc(teamId).update({
        'players': FieldValue.arrayRemove([player.toMap()]),
      });
      debugPrint('✅ Player ${player.name} removed from team $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing player from team: $e');
      return false;
    }
  }

  /// Get team by SPT ID
  Future<TeamModel?> getTeamBySptId(String sptId) async {
    try {
      final normalizedId = sptId.toUpperCase();
      final snapshot = await _db
          .collection(teamsCollection)
          .where('spTId', isEqualTo: normalizedId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return TeamModel.fromMap({...doc.data(), 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting team by SPT ID: $e');
      return null;
    }
  }

  /// Update team details
  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
    try {
      await _db.collection(teamsCollection).doc(teamId).update(data);
      debugPrint('✅ Team updated: $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating team: $e');
      return false;
    }
  }

  /// Change team captain
  Future<bool> changeCaptain(String teamId, String newCaptainId, String newCaptainName) async {
    try {
      final doc = await _db.collection(teamsCollection).doc(teamId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final players = (data['players'] as List<dynamic>? ?? [])
          .map((p) => Map<String, dynamic>.from(p))
          .toList();

      // Update isCaptain flags in players array
      // Handle both 'userId' and 'uid' keys for consistency
      for (var p in players) {
        final playerId = p['userId'] ?? p['uid'] ?? '';
        p['isCaptain'] = (playerId == newCaptainId);
        // Normalize: ensure 'userId' key always exists
        if (p['userId'] == null && p['uid'] != null) {
          p['userId'] = p['uid'];
        }
      }

      await _db.collection(teamsCollection).doc(teamId).update({
        'captainId': newCaptainId,
        'captainName': newCaptainName,
        'players': players,
      });

      debugPrint('✅ Captain changed to $newCaptainName for team $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error changing captain: $e');
      return false;
    }
  }

  /// Change team vice-captain
  Future<bool> changeViceCaptain(String teamId, String newVcId, String newVcName) async {
    try {
      final doc = await _db.collection(teamsCollection).doc(teamId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final players = (data['players'] as List<dynamic>? ?? [])
          .map((p) => Map<String, dynamic>.from(p))
          .toList();

      // Update isViceCaptain flags in players array
      // Handle both 'userId' and 'uid' keys for consistency (some players may use 'uid')
      for (var p in players) {
        final playerId = p['userId'] ?? p['uid'] ?? '';
        p['isViceCaptain'] = (playerId == newVcId);
        // Normalize: ensure 'userId' key always exists
        if (p['userId'] == null && p['uid'] != null) {
          p['userId'] = p['uid'];
        }
      }

      await _db.collection(teamsCollection).doc(teamId).update({
        'viceCaptainId': newVcId,
        'viceCaptainName': newVcName,
        'players': players,
      });

      debugPrint('✅ Vice-Captain changed to $newVcName for team $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error changing vice-captain: $e');
      return false;
    }
  }

  /// Update team match stats (matchesPlayed, matchesWon, matchesLost)
  Future<void> updateTeamMatchStats({
    required String teamId,
    required bool isWinner,
    bool isTie = false,
  }) async {
    try {
      if (teamId.isEmpty) return;

      final updates = <String, dynamic>{
        'matchesPlayed': FieldValue.increment(1),
      };

      if (isTie) {
        // Ties don't count as won or lost
      } else if (isWinner) {
        updates['matchesWon'] = FieldValue.increment(1);
      } else {
        updates['matchesLost'] = FieldValue.increment(1);
      }

      await _db.collection(teamsCollection).doc(teamId).update(updates);
      debugPrint('✅ Updated match stats for team $teamId (won: $isWinner, tie: $isTie)');
    } catch (e) {
      debugPrint('❌ Error updating team match stats: $e');
    }
  }

  /// Recalculate team stats from all completed matches
  Future<void> recalculateTeamStats(String teamId) async {
    try {
      if (teamId.isEmpty) return;

      // Get all completed matches
      final snapshot = await _db
          .collection(matchesCollection)
          .where('status', isEqualTo: 'completed')
          .get();

      int played = 0;
      int won = 0;
      int lost = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final team1Id = data['team1Id'] ?? '';
        final team2Id = data['team2Id'] ?? '';

        // Check if this team played in this match
        if (team1Id != teamId && team2Id != teamId) continue;

        played++;

        final winnerTeamId = data['winnerTeamId'] ?? '';
        final winnerTeam = data['winnerTeam'] ?? '';

        if (winnerTeam == 'Match Tied' || winnerTeamId == null || winnerTeamId == '') {
          // Tie or no result — neither won nor lost
        } else if (winnerTeamId == teamId) {
          won++;
        } else {
          lost++;
        }
      }

      await _db.collection(teamsCollection).doc(teamId).update({
        'matchesPlayed': played,
        'matchesWon': won,
        'matchesLost': lost,
      });

      debugPrint('✅ Recalculated stats for team $teamId: P=$played W=$won L=$lost');
    } catch (e) {
      debugPrint('❌ Error recalculating team stats: $e');
    }
  }

  /// Stream team updates
  Stream<TeamModel?> streamTeam(String teamId) {
    return _db.collection(teamsCollection).doc(teamId).snapshots().map((doc) {
      if (doc.exists) {
        return TeamModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    });
  }

  // ==================== MATCHES ====================

  /// Create a new match
  Future<MatchModel?> createMatch(MatchModel match, String creatorId) async {
    try {
      final matchData = {
        ...match.toMap(),
        'createdBy': creatorId,
        'createdAt': DateTime.now(), // Use client time to avoid FieldValue type issues
        'updatedAt': DateTime.now(),
        'adminIds': match.adminIds.contains(creatorId) 
            ? match.adminIds 
            : [...match.adminIds, creatorId], 
      };
      matchData.remove('id');

      final docRef = await _db.collection(matchesCollection).add(matchData);
      debugPrint('✅ Match created: ${match.matchName} (ID: ${docRef.id})');
      
      return MatchModel.fromMap({
        ...matchData, 
        'id': docRef.id,
        // Dates are already DateTime in matchData now, so they work with fromMap (which handles DateTime)
      });
    } catch (e) {
      debugPrint('❌ Error creating match: $e');
      return null;
    }
  }

  /// Get match by ID
  Future<MatchModel?> getMatchById(String matchId) async {
    try {
      final doc = await _db.collection(matchesCollection).doc(matchId).get();
      if (doc.exists) {
        return MatchModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting match: $e');
      return null;
    }
  }

  /// Get live matches
  Future<List<MatchModel>> getLiveMatches() async {
    try {
      final snapshot = await _db
          .collection(matchesCollection)
          .where('status', isEqualTo: 'live')
          .limit(20)
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting live matches: $e');
      return [];
    }
  }

  /// Get matches near the given coordinates (within radiusKm)
  Future<List<MatchModel>> getMatchesNearMe(double lat, double lng, {double radiusKm = 50.0}) async {
    try {
      // Fetch active/upcoming matches first to limit client side filtering overhead.
      final snapshot = await _db
          .collection(matchesCollection)
          .where('status', whereIn: ['live', 'scheduled'])
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // Filter matches by distance
      final nearMatches = matches.where((match) {
        if (match.latitude != null && match.longitude != null) {
          final distance = LocationUtils.calculateDistanceKm(
            lat, lng, 
            match.latitude!, match.longitude!
          );
          return distance <= radiusKm;
        }
        return false;
      }).toList();

      nearMatches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return nearMatches;
    } catch (e) {
      debugPrint('❌ Error getting matches near me: $e');
      return [];
    }
  }

  /// Get upcoming matches
  Future<List<MatchModel>> getUpcomingMatches() async {
    try {
      final snapshot = await _db
          .collection(matchesCollection)
          .where('status', isEqualTo: 'scheduled')
          .limit(20)
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      matches.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting upcoming matches: $e');
      return [];
    }
  }

  /// Get past/completed matches
  Future<List<MatchModel>> getPastMatches({int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection(matchesCollection)
          .where('status', isEqualTo: 'completed')
          .limit(limit)
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting past matches: $e');
      return [];
    }
  }

  /// Get all matches at a specific ground/venue
  Future<List<MatchModel>> getMatchesByGround(String groundName) async {
    try {
      if (groundName.trim().isEmpty) return [];

      final snapshot = await _db
          .collection(matchesCollection)
          .where('ground', isEqualTo: groundName)
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort: live first, then upcoming, then completed (by date desc)
      matches.sort((a, b) {
        const order = {'live': 0, 'scheduled': 1, 'completed': 2};
        final statusCompare = (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
        if (statusCompare != 0) return statusCompare;
        return b.scheduledDate.compareTo(a.scheduledDate);
      });

      debugPrint('📍 Found ${matches.length} matches at ground: $groundName');
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting matches by ground: $e');
      return [];
    }
  }

  /// Get completed matches between two specific teams
  Future<List<MatchModel>> getMatchesBetweenTeams(String teamAId, String teamBId) async {
    try {
      // Query matches where teamA is team1
      final snap1 = await _db
          .collection(matchesCollection)
          .where('status', isEqualTo: 'completed')
          .where('team1Id', isEqualTo: teamAId)
          .where('team2Id', isEqualTo: teamBId)
          .get();

      // Query matches where teamA is team2 (reversed)
      final snap2 = await _db
          .collection(matchesCollection)
          .where('status', isEqualTo: 'completed')
          .where('team1Id', isEqualTo: teamBId)
          .where('team2Id', isEqualTo: teamAId)
          .get();

      final matches = [
        ...snap1.docs.map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id})),
        ...snap2.docs.map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id})),
      ];

      matches.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting H2H matches: $e');
      return [];
    }
  }

  /// Get matches created by user
  Future<List<MatchModel>> getUserMatches(String userId) async {
    try {
      debugPrint('🔍 getUserMatches called for: $userId');
      
      // 1. Matches created by user (backward compatibility)
      final createdQuery = _db
          .collection(matchesCollection)
          .where('createdBy', isEqualTo: userId)
          .get();

      // 2. Matches where user is admin
      final adminQuery = _db
          .collection(matchesCollection)
          .where('adminIds', arrayContains: userId)
          .get();

      // 3. Matches where user is scorer
      final scorerQuery = _db
          .collection(matchesCollection)
          .where('scorerIds', arrayContains: userId)
          .get();

      final results = await Future.wait([createdQuery, adminQuery, scorerQuery]);
      
      final allDocs = <String, QueryDocumentSnapshot>{};
      
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          allDocs[doc.id] = doc;
        }
      }

      debugPrint('📊 Found ${allDocs.length} matches in Firestore (merged)');
      
      final matches = allDocs.values
          .map((doc) => MatchModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();

      // Sort locally by createdAt descending
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting user matches: $e');
      return [];
    }
  }

  /// Get matches where the user played
  Future<List<MatchModel>> getUserPlayedMatches(String userId) async {
    try {
      debugPrint('🔍 getUserPlayedMatches called for: $userId');
      final snapshot = await _db
          .collection(matchesCollection)
          .where('playerIds', arrayContains: userId)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} played matches in Firestore');
      
      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort locally by createdAt descending
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return matches;
    } catch (e) {
      debugPrint('❌ Error getting user played matches: $e');
      return [];
    }
  }

  /// Add a player to the match participants list
  Future<void> addPlayerToMatch(String matchId, String playerId) async {
    try {
      if (playerId.isEmpty) return;
      await _db.collection(matchesCollection).doc(matchId).update({
        'playerIds': FieldValue.arrayUnion([playerId])
      });
    } catch (e) {
      debugPrint('❌ Error adding player to match: $e');
    }
  }

  /// Backfill playerIds for all existing matches based on batters/bowlers
  Future<void> backfillPlayerIds() async {
    try {
      debugPrint('🔄 Starting playerIds backfill...');
      final snapshot = await _db.collection(matchesCollection).get();

      int updated = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final existingPlayerIds = (data['playerIds'] as List<dynamic>?) ?? [];
        
        // Skip if already has playerIds
        if (existingPlayerIds.isNotEmpty) continue;

        // Extract player IDs from team scores
        final playerIds = <String>{};
        
        // Team 1 batters
        final team1Batters = (data['team1Score']?['batters'] as List<dynamic>?) ?? [];
        for (var b in team1Batters) {
          if (b['playerId'] != null && b['playerId'].toString().isNotEmpty) {
            playerIds.add(b['playerId'].toString());
          }
        }
        
        // Team 2 batters
        final team2Batters = (data['team2Score']?['batters'] as List<dynamic>?) ?? [];
        for (var b in team2Batters) {
          if (b['playerId'] != null && b['playerId'].toString().isNotEmpty) {
            playerIds.add(b['playerId'].toString());
          }
        }
        
        // Team 1 bowlers
        final team1Bowlers = (data['team1Score']?['bowlers'] as List<dynamic>?) ?? [];
        for (var b in team1Bowlers) {
          if (b['playerId'] != null && b['playerId'].toString().isNotEmpty) {
            playerIds.add(b['playerId'].toString());
          }
        }
        
        // Team 2 bowlers
        final team2Bowlers = (data['team2Score']?['bowlers'] as List<dynamic>?) ?? [];
        for (var b in team2Bowlers) {
          if (b['playerId'] != null && b['playerId'].toString().isNotEmpty) {
            playerIds.add(b['playerId'].toString());
          }
        }

        if (playerIds.isNotEmpty) {
          await doc.reference.update({'playerIds': playerIds.toList()});
          updated++;
          debugPrint('✅ Backfilled ${playerIds.length} playerIds for match ${doc.id}');
        }
      }
      debugPrint('🎉 Backfill complete. Updated $updated matches.');
    } catch (e) {
      debugPrint('❌ Error backfilling playerIds: $e');
    }
  }

  /// Update match
  Future<bool> updateMatch(String matchId, Map<String, dynamic> data) async {
    try {
      await _db.collection(matchesCollection).doc(matchId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    debugPrint('✅ Match updated: $matchId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating match: $e');
      return false;
    }
  }

  /// Delete a match by ID and rollback all associated data
  Future<bool> deleteMatch(String matchId) async {
    try {
      final matchDoc = await _db.collection(matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) return false;
      
      final matchData = matchDoc.data()!;
      final match = MatchModel.fromMap({...matchData, 'id': matchId});

      if (match.status == 'completed') {
        debugPrint('🔄 Rolling back stats for completed match: $matchId');
        // 1. Rollback player performances
        final performances = MatchStatsCalculator.calculateAllPerformances(match);
        for (var perf in performances) {
          String resolvedId = perf.playerId;
          if (resolvedId.startsWith('SPP')) {
            final userDoc = await getUserBySppId(resolvedId);
            if (userDoc != null) {
              resolvedId = userDoc.uid;
            }
          }
          final finalPerf = MatchPerformance(
            playerId: resolvedId,
            playerName: perf.playerName,
            matchId: perf.matchId,
            ballType: perf.ballType,
            runsScored: perf.runsScored,
            ballsFaced: perf.ballsFaced,
            fours: perf.fours,
            sixes: perf.sixes,
            isOut: perf.isOut,
            isDuck: perf.isDuck,
            isFifty: perf.isFifty,
            isHundred: perf.isHundred,
            wickets: perf.wickets,
            runsConceded: perf.runsConceded,
            ballsBowled: perf.ballsBowled,
            isFiveWicketHaul: perf.isFiveWicketHaul,
            catches: perf.catches,
            runOuts: perf.runOuts,
            stumpings: perf.stumpings,
            isManOfMatch: perf.isManOfMatch,
            isWinner: perf.isWinner,
            playedAt: perf.playedAt,
            directHits: perf.directHits,
          );
          await rollbackMatchPerformanceAtomic(finalPerf);
        }
        
        // 2. Recalculate Team Stats
        await recalculateTeamStats(match.team1Id);
        await recalculateTeamStats(match.team2Id);
        
        // 3. Rollback Tournament Standings (if applicable)
        if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
           await updateTournamentStandings(match.tournamentId!);
        }
      }

      // Delete subcollections like viewers
      final viewersQuery = await _db.collection(matchesCollection).doc(matchId).collection('viewers').get();
      for (var doc in viewersQuery.docs) {
        await doc.reference.delete();
      }

      // Delete associated Firebase Storage files (Posters, Match Gallery, etc)
      try {
        final storageRef = FirebaseStorage.instance.ref().child('matches/$matchId');
        final listResult = await storageRef.listAll();
        for (var item in listResult.items) {
          await item.delete();
        }
        for (var prefix in listResult.prefixes) {
           // Basic nested folder deletion
           final nestedResult = await prefix.listAll();
           for (var nestedItem in nestedResult.items) {
             await nestedItem.delete();
           }
        }
      } catch (e) {
        debugPrint('ℹ️ No storage files found or failed to delete storage for $matchId: $e');
      }

      // Delete the main match document (cascades scorecards, innings, etc)
      await _db.collection(matchesCollection).doc(matchId).delete();
      debugPrint('🗑️ Deleted match completely: $matchId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting match: $e');
      return false;
    }
  }

  /// Delete a team by ID
  Future<bool> deleteTeam(String teamId) async {
    try {
      await _db.collection(teamsCollection).doc(teamId).delete();
      debugPrint('🗑️ Deleted team: $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting team: $e');
      return false;
    }
  }

  /// Delete a tournament by ID
  Future<bool> deleteTournament(String tournamentId) async {
    try {
      await _db.collection(tournamentsCollection).doc(tournamentId).delete();
      debugPrint('🗑️ Deleted tournament: $tournamentId');
      
      // Also delete all matches associated with this tournament
      final matchesSnapshot = await _db.collection(matchesCollection)
          .where('tournamentId', isEqualTo: tournamentId)
          .get();
          
      for (final doc in matchesSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('🗑️ Deleted ${matchesSnapshot.docs.length} matches associated with tournament: $tournamentId');
      
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting tournament: $e');
      return false;
    }
  }

  /// Update tournament standings after a match
  Future<void> updateTournamentStandings(String tournamentId) async {
    try {
      debugPrint('📊 Updating standings for tournament: $tournamentId');
      
      // 1. Get all matches for this tournament
      final tournamentDoc = await _db.collection(tournamentsCollection).doc(tournamentId).get();
      if (!tournamentDoc.exists) return;
      
      // Get fixtures from tournament doc
      final fixturesList = (tournamentDoc.data()?['fixtures'] as List<dynamic>?) ?? [];
      // Get all completed matches that are part of this tournament
      final matchesSnapshot = await _db.collection(matchesCollection)
          .where('status', isEqualTo: 'completed')
          .get();
          
      final tournamentMatchIds = fixturesList.map((f) => f['matchId'] as String).toSet();
      
      final completedMatches = matchesSnapshot.docs
          .map((d) => MatchModel.fromMap({...d.data(), 'id': d.id}))
          .where((m) => tournamentMatchIds.contains(m.id))
          .toList();
          
      debugPrint('📊 Found ${completedMatches.length} completed matches for tournament');

      // 2. Calculate points
      final Map<String, TeamPoints> teamStats = {};
      
      for (var match in completedMatches) {
        final t1 = match.team1Id;
        final t2 = match.team2Id;
        
        // Initialize if not present
        if (!teamStats.containsKey(t1)) {
          teamStats[t1] = TeamPoints(teamId: t1, teamName: match.team1Name);
        }
        if (!teamStats.containsKey(t2)) {
          teamStats[t2] = TeamPoints(teamId: t2, teamName: match.team2Name);
        }
        
        final s1 = teamStats[t1]!;
        final s2 = teamStats[t2]!;
        
        // Initialize
        var updatedS1 = s1;
        var updatedS2 = s2;
        
        // Update played
        updatedS1 = updatedS1.copyWith(played: updatedS1.played + 1);
        updatedS2 = updatedS2.copyWith(played: updatedS2.played + 1);
        
        // Determine winner
        // Use result map if available or check status
        final winnerName = match.result?.winner;
        
        bool isTie = false;
        bool isTeam1Winner = false;
        bool isTeam2Winner = false;
        
        if (winnerName != null) {
           if (winnerName == match.team1Name) {
             isTeam1Winner = true;
           } else if (winnerName == match.team2Name) {
             isTeam2Winner = true;
           } else if (winnerName.toLowerCase().contains('tie')) {
             isTie = true;
           }
        }
        
        if (isTeam1Winner) {
          updatedS1 = updatedS1.copyWith(
            won: updatedS1.won + 1,
            points: updatedS1.points + 2
          );
          updatedS2 = updatedS2.copyWith(
            lost: updatedS2.lost + 1
          );
        } else if (isTeam2Winner) {
          updatedS2 = updatedS2.copyWith(
            won: updatedS2.won + 1,
            points: updatedS2.points + 2
          );
          updatedS1 = updatedS1.copyWith(
            lost: updatedS1.lost + 1
          );
        } else if (isTie) {
          updatedS1 = updatedS1.copyWith(
            tied: updatedS1.tied + 1,
            points: updatedS1.points + 1
          );
          updatedS2 = updatedS2.copyWith(
            tied: updatedS2.tied + 1,
            points: updatedS2.points + 1
          );
        } else {
          // No Result / Abandoned
          updatedS1 = updatedS1.copyWith(
            noResult: updatedS1.noResult + 1,
            points: updatedS1.points + 1
          );
          updatedS2 = updatedS2.copyWith(
            noResult: updatedS2.noResult + 1,
            points: updatedS2.points + 1
          );
        }
        
        // NRR: Simplified to runs scored / balls faced (approx)
        // For Team 1
        updatedS1 = updatedS1.copyWith(
          runsFor: updatedS1.runsFor + match.team1Score.runs,
          ballsFor: updatedS1.ballsFor + _matchesBalls(match.team1Score),
          runsAgainst: updatedS1.runsAgainst + match.team2Score.runs,
          ballsAgainst: updatedS1.ballsAgainst + _matchesBalls(match.team2Score)
        );
        
        // For Team 2
        updatedS2 = updatedS2.copyWith(
          runsFor: updatedS2.runsFor + match.team2Score.runs,
          ballsFor: updatedS2.ballsFor + _matchesBalls(match.team2Score),
          runsAgainst: updatedS2.runsAgainst + match.team1Score.runs,
          ballsAgainst: updatedS2.ballsAgainst + _matchesBalls(match.team1Score)
        );
        
        // Update map
        teamStats[t1] = updatedS1;
        teamStats[t2] = updatedS2;
      }
      
      // Final NRR Calc and Update
      for (var teamId in teamStats.keys) {
        final team = teamStats[teamId]!;
        final nrr = TeamPoints.calculateNRR(
          team.runsFor, 
          team.ballsFor, 
          team.runsAgainst, 
          team.ballsAgainst
        );
        
        teamStats[teamId] = team.copyWith(nrr: nrr);
      }
      
      // 3. Update Tournament Document
      final pointsTable = teamStats.values.map((tp) => tp.toMap()).toList();
      
      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'pointsTable': pointsTable,
      });
      
      debugPrint('✅ Tournament standings updated');
      
    } catch (e) {
      debugPrint('❌ Error updating tournament standings: $e');
    }
  }

  /// Helper to get total balls from score
  int _matchesBalls(TeamScore score) {
    // Convert float overs (e.g., 10.4) to total balls
    // 10.4 means 10 overs + 4 balls
    int completedOvers = score.overs.floor();
    // Use string parsing or rounding to safely get decimal part as integer
    int extraBalls = ((score.overs - completedOvers) * 10).round();
    return (completedOvers * 6) + extraBalls;
  }

  /// Stream match updates (for live scoring)
  Stream<MatchModel?> streamMatch(String matchId) {
    return _db.collection(matchesCollection).doc(matchId).snapshots().map((doc) {
      if (doc.exists) {
        return MatchModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    });
  }

  // ==================== TOURNAMENTS ====================

  /// Get tournament by ID
  Future<TournamentModel?> getTournamentById(String tournamentId) async {
    try {
      final doc = await _db.collection(tournamentsCollection).doc(tournamentId).get();
      if (doc.exists) {
        return TournamentModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting tournament by ID: $e');
      return null;
    }
  }

  /// Add a team to an existing tournament
  Future<bool> addTeamToTournament(String tournamentId, String teamId) async {
    try {
      final doc = await _db.collection(tournamentsCollection).doc(tournamentId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final currentTeams = List<String>.from(data['registeredTeamIds'] ?? []);
      
      if (currentTeams.contains(teamId)) {
        return true; 
      }

      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'registeredTeamIds': FieldValue.arrayUnion([teamId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Team $teamId added to tournament $tournamentId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding team to tournament: $e');
      return false;
    }
  }

  /// Create a new tournament
  Future<TournamentModel?> createTournament(TournamentModel tournament, String creatorId) async {
    try {
      final tournamentData = {
        ...tournament.toMap(),
        'organizerId': creatorId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      tournamentData.remove('id');

      final docRef = await _db.collection(tournamentsCollection).add(tournamentData);
      debugPrint('✅ Tournament created: ${tournament.name} (ID: ${docRef.id})');
      
      return TournamentModel.fromMap({...tournamentData, 'id': docRef.id});
    } catch (e) {
      debugPrint('❌ Error creating tournament: $e');
      return null;
    }
  }

  /// Search tournaments by name or location
  Future<List<TournamentModel>> searchTournaments(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final normalizedQuery = query.toLowerCase();
      // Fetch recent tournaments to filter client-side
      final snapshot = await _db
          .collection(tournamentsCollection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final tournaments = snapshot.docs
          .map((doc) => TournamentModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
          
      return tournaments.where((t) => 
        t.name.toLowerCase().contains(normalizedQuery) || 
        t.location.toLowerCase().contains(normalizedQuery)
      ).toList();
    } catch (e) {
      debugPrint('❌ Error searching tournaments: $e');
      return [];
    }
  }

  /// Search matches by name
  Future<List<MatchModel>> searchMatches(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final normalizedQuery = query.toLowerCase();
      // Fetch recent matches to filter client-side
      final snapshot = await _db
          .collection(matchesCollection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
          
      return matches.where((m) => 
        m.matchName.toLowerCase().contains(normalizedQuery) ||
        m.team1Name.toLowerCase().contains(normalizedQuery) ||
        m.team2Name.toLowerCase().contains(normalizedQuery)
      ).toList();
    } catch (e) {
      debugPrint('❌ Error searching matches: $e');
      return [];
    }
  }

  /// Get all tournaments
  Future<List<TournamentModel>> getAllTournaments({String? status, int limit = 20}) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection(tournamentsCollection);
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      
      final snapshot = await query
          .orderBy('startDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => TournamentModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting tournaments: $e');
      return [];
    }
  }

  /// Get tournaments created by user
  Future<List<TournamentModel>> getUserTournaments(String userId) async {
    try {
      debugPrint('🔍 Fetching tournaments for user: $userId');
      
      // Query without orderBy to avoid composite index requirement
      final snapshot = await _db
          .collection(tournamentsCollection)
          .where('organizerId', isEqualTo: userId)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} tournaments for user');
      
      final tournaments = snapshot.docs
          .map((doc) => TournamentModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sort locally by startDate descending
      tournaments.sort((a, b) => b.startDate.compareTo(a.startDate));
      
      return tournaments;
    } catch (e) {
      debugPrint('❌ Error getting user tournaments: $e');
      return [];
    }
  }

  /// Get tournament by ID
  Future<TournamentModel?> getTournament(String tournamentId) async {
    try {
      final doc = await _db.collection(tournamentsCollection).doc(tournamentId).get();
      if (doc.exists) {
        return TournamentModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting tournament: $e');
      return null;
    }
  }

  /// Get tournaments where user is a player (their teams are registered)
  Future<List<TournamentModel>> getPlayerTournaments(String userId, List<String> teamIds) async {
    try {
      debugPrint('🔍 Finding tournaments for player: $userId with ${teamIds.length} teams');
      
      if (teamIds.isEmpty) return [];
      
      // Firestore 'array-contains-any' supports up to 10 items
      // For more teams, we need multiple queries
      List<TournamentModel> allTournaments = [];
      
      for (int i = 0; i < teamIds.length; i += 10) {
        final batch = teamIds.skip(i).take(10).toList();
        final snapshot = await _db
            .collection(tournamentsCollection)
            .where('registeredTeamIds', arrayContainsAny: batch)
            .get();
        
        final tournaments = snapshot.docs
            .map((doc) => TournamentModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList();
        
        allTournaments.addAll(tournaments);
      }
      
      // Remove duplicates (if a team appears in multiple batches)
      final uniqueIds = <String>{};
      allTournaments = allTournaments.where((t) => uniqueIds.add(t.id)).toList();
      
      // Sort by start date
      allTournaments.sort((a, b) => b.startDate.compareTo(a.startDate));
      
      debugPrint('📊 Found ${allTournaments.length} tournaments for player');
      return allTournaments;
    } catch (e) {
      debugPrint('❌ Error getting player tournaments: $e');
      return [];
    }
  }

  /// Get matches from tournaments where player is participating
  Future<List<MatchModel>> getPlayerTournamentMatches(String userId, List<String> teamIds) async {
    try {
      debugPrint('🔍 getPlayerTournamentMatches called for userId: $userId with ${teamIds.length} teams');
      
      // First get all tournaments where player's teams are registered
      final tournaments = await getPlayerTournaments(userId, teamIds);
      debugPrint('📊 Found ${tournaments.length} tournaments for user teams');
      
      if (tournaments.isEmpty) return [];
      
      // Get all match IDs from tournament matchIds AND fixtures
      final matchIds = <String>{};
      for (var tournament in tournaments) {
        // Add matches from matchIds list
        for (var matchId in tournament.matchIds) {
          if (matchId.isNotEmpty) {
            matchIds.add(matchId);
          }
        }
        
        // Also add from fixtures (in case matchId is set there)
        for (var fixture in tournament.fixtures) {
          if (fixture.matchId != null && fixture.matchId!.isNotEmpty) {
            matchIds.add(fixture.matchId!);
          }
        }
      }
      
      debugPrint('📊 Total match IDs to fetch: ${matchIds.length}');
      
      if (matchIds.isEmpty) {
        // No matchIds - also try getting matches where team1Id or team2Id matches user's teams
        debugPrint('🔍 No matchIds found, trying to find matches by team IDs');
        List<MatchModel> teamMatches = [];
        
        // Query matches by team1Id or team2Id
        for (var teamId in teamIds.take(5)) { // Limit to avoid too many queries
          final team1Snapshot = await _db
              .collection(matchesCollection)
              .where('team1Id', isEqualTo: teamId)
              .limit(20)
              .get();
              
          final team2Snapshot = await _db
              .collection(matchesCollection)
              .where('team2Id', isEqualTo: teamId)
              .limit(20)
              .get();
          
          for (var doc in team1Snapshot.docs) {
            teamMatches.add(MatchModel.fromMap({...doc.data(), 'id': doc.id}));
          }
          for (var doc in team2Snapshot.docs) {
            teamMatches.add(MatchModel.fromMap({...doc.data(), 'id': doc.id}));
          }
        }
        
        // Deduplicate
        final seenIds = <String>{};
        teamMatches = teamMatches.where((m) => seenIds.add(m.id)).toList();
        
        debugPrint('📊 Found ${teamMatches.length} matches by team ID lookup');
        return teamMatches;
      }
      
      // Fetch matches in batches (Firestore limit is 10 for whereIn)
      List<MatchModel> allMatches = [];
      final matchIdList = matchIds.toList();
      
      for (int i = 0; i < matchIdList.length; i += 10) {
        final batch = matchIdList.skip(i).take(10).toList();
        final snapshot = await _db
            .collection(matchesCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        final matches = snapshot.docs
            .map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList();
        
        allMatches.addAll(matches);
      }
      
      // Sort by status priority (live > scheduled > completed) then by date
      allMatches.sort((a, b) {
        final statusOrder = {'live': 0, 'scheduled': 1, 'completed': 2};
        final aOrder = statusOrder[a.status] ?? 3;
        final bOrder = statusOrder[b.status] ?? 3;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return b.createdAt.compareTo(a.createdAt);
      });
      
      debugPrint('📊 Found ${allMatches.length} tournament matches for player');
      return allMatches;
    } catch (e) {
      debugPrint('❌ Error getting player tournament matches: $e');
      return [];
    }
  }

  /// Register team for tournament
  Future<bool> registerTeamForTournament(String tournamentId, String teamId) async {
    try {
      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'registeredTeamIds': FieldValue.arrayUnion([teamId]),
      });
      debugPrint('✅ Team $teamId registered for tournament $tournamentId');
      return true;
    } catch (e) {
      debugPrint('❌ Error registering team: $e');
      return false;
    }
  }

  /// Increment views of a tournament
  Future<void> incrementTournamentViews(String tournamentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasViewed = prefs.getBool('hasViewed_tournament_$tournamentId') ?? false;

      if (!hasViewed) {
        await _db.collection(tournamentsCollection).doc(tournamentId).update({
          'views': FieldValue.increment(1),
        });
        await prefs.setBool('hasViewed_tournament_$tournamentId', true);
        debugPrint('✅ Incremented views for tournament $tournamentId');
      } else {
        debugPrint('ℹ️ User has already viewed tournament $tournamentId on this device');
      }
    } catch (e) {
      debugPrint('❌ Error incrementing tournament views: $e');
    }
  }

  /// Update tournament details
  Future<bool> updateTournament(String tournamentId, Map<String, dynamic> data) async {
    try {
      await _db.collection(tournamentsCollection).doc(tournamentId).update(data);
      debugPrint('✅ Tournament updated: $tournamentId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating tournament: $e');
      return false;
    }
  }

  /// Generate tournament fixtures based on format
  Future<List<TournamentFixture>> generateFixtures({
    required String tournamentId,
    required String format,
    required List<TeamModel> teams,
    DateTime? startDate,
  }) async {
    try {
      debugPrint('🏏 Generating fixtures for tournament: $tournamentId, format: $format');
      
      List<TournamentFixture> fixtures = [];
      final effectiveStartDate = startDate ?? DateTime.now();
      int fixtureIndex = 0;
      
      if (format == 'knockout') {
        // Knockout/Elimination format
        fixtures = _generateKnockoutFixtures(teams, effectiveStartDate, fixtureIndex);
      } else {
        // League/Round-Robin format (default)
        fixtures = _generateRoundRobinFixtures(teams, effectiveStartDate, fixtureIndex);
      }
      
      // Initialize points table for league format
      List<TeamPoints> pointsTable = [];
      if (format != 'knockout') {
        pointsTable = teams.map((team) => TeamPoints(
          teamId: team.id,
          teamName: team.name,
        )).toList();
      }
      
      // Save to Firestore
      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'fixtures': fixtures.map((f) => f.toMap()).toList(),
        'pointsTable': pointsTable.map((p) => p.toMap()).toList(),
      });
      
      debugPrint('✅ Generated ${fixtures.length} fixtures');
      return fixtures;
    } catch (e) {
      debugPrint('❌ Error generating fixtures: $e');
      return [];
    }
  }

  /// Add a single fixture to a tournament (manual match creation)
  Future<bool> addFixtureToTournament(String tournamentId, TournamentFixture fixture) async {
    try {
      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'fixtures': FieldValue.arrayUnion([fixture.toMap()]),
      });
      debugPrint('✅ Added fixture ${fixture.id} to tournament $tournamentId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding fixture to tournament: $e');
      return false;
    }
  }

  /// Delete a fixture from a tournament (and optionally the linked match)
  Future<bool> deleteFixtureFromTournament(String tournamentId, String fixtureId, {String? matchId}) async {
    try {
      // Read current tournament data
      final doc = await _db.collection(tournamentsCollection).doc(tournamentId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final fixtures = (data['fixtures'] as List<dynamic>?) ?? [];

      // Remove the fixture with the matching id
      final updatedFixtures = fixtures.where((f) => f['id'] != fixtureId).toList();

      // Also remove matchId from matchIds list if present
      List<String> matchIds = List<String>.from(data['matchIds'] ?? []);
      if (matchId != null && matchId.isNotEmpty) {
        matchIds.remove(matchId);
      }

      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'fixtures': updatedFixtures,
        'matchIds': matchIds,
      });

      // Delete the match document AND rollback all player/team stats
      if (matchId != null && matchId.isNotEmpty) {
        try {
          // Use deleteMatch() which handles full stats rollback,
          // team stats recalculation, storage cleanup, and subcollection deletion
          final deleted = await deleteMatch(matchId);
          if (deleted) {
            debugPrint('✅ Deleted match with full stats rollback: $matchId');
          } else {
            debugPrint('⚠️ deleteMatch returned false for: $matchId');
          }
        } catch (e) {
          debugPrint('⚠️ Could not delete match document: $e');
        }
      }

      // Recalculate tournament standings after fixture removal
      await updateTournamentStandings(tournamentId);

      debugPrint('✅ Deleted fixture $fixtureId from tournament $tournamentId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting fixture from tournament: $e');
      return false;
    }
  }

  /// Generate round-robin fixtures (each team plays every other team once)
  List<TournamentFixture> _generateRoundRobinFixtures(
    List<TeamModel> teams,
    DateTime startDate,
    int startIndex,
  ) {
    List<TournamentFixture> fixtures = [];
    int fixtureIndex = startIndex;
    int matchDay = 0;
    
    // Round-robin: each team plays every other team once
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        fixtures.add(TournamentFixture(
          id: 'fixture_${fixtureIndex++}',
          team1Id: teams[i].id,
          team1Name: teams[i].name,
          team2Id: teams[j].id,
          team2Name: teams[j].name,
          round: 'League Match ${fixtures.length + 1}',
          roundNumber: 1,
          scheduledDate: startDate.add(Duration(days: matchDay)),
          status: 'scheduled',
        ));
        matchDay++; // One match per day
      }
    }
    
    return fixtures;
  }

  /// Generate knockout bracket fixtures
  List<TournamentFixture> _generateKnockoutFixtures(
    List<TeamModel> teams,
    DateTime startDate,
    int startIndex,
  ) {
    List<TournamentFixture> fixtures = [];
    int fixtureIndex = startIndex;
    
    // Calculate bracket rounds
    int numTeams = teams.length;
    int round = 1;
    String roundName = _getKnockoutRoundName(numTeams);
    
    // First round matches
    for (int i = 0; i < numTeams; i += 2) {
      if (i + 1 < numTeams) {
        fixtures.add(TournamentFixture(
          id: 'fixture_${fixtureIndex++}',
          team1Id: teams[i].id,
          team1Name: teams[i].name,
          team2Id: teams[i + 1].id,
          team2Name: teams[i + 1].name,
          round: roundName,
          roundNumber: round,
          scheduledDate: startDate.add(Duration(days: round - 1)),
          status: 'scheduled',
        ));
      }
    }
    
    // Add placeholder fixtures for subsequent rounds
    int remainingTeams = (numTeams / 2).ceil();
    int dayOffset = 1;
    
    while (remainingTeams > 1) {
      round++;
      roundName = _getKnockoutRoundName(remainingTeams);
      int matchesInRound = (remainingTeams / 2).ceil();
      
      for (int i = 0; i < matchesInRound; i++) {
        fixtures.add(TournamentFixture(
          id: 'fixture_${fixtureIndex++}',
          team1Id: 'TBD',
          team1Name: 'Winner Match ${(i * 2) + 1}',
          team2Id: 'TBD',
          team2Name: 'Winner Match ${(i * 2) + 2}',
          round: roundName,
          roundNumber: round,
          scheduledDate: startDate.add(Duration(days: dayOffset)),
          status: 'pending',
        ));
      }
      
      remainingTeams = matchesInRound;
      dayOffset++;
    }
    
    return fixtures;
  }

  String _getKnockoutRoundName(int teamsRemaining) {
    switch (teamsRemaining) {
      case 2:
        return 'Final';
      case 4:
        return 'Semi-Final';
      case 8:
        return 'Quarter-Final';
      default:
        return 'Round of $teamsRemaining';
    }
  }



  /// Stream tournament updates
  Stream<TournamentModel?> streamTournament(String tournamentId) {
    return _db.collection(tournamentsCollection).doc(tournamentId).snapshots().map((doc) {
      if (doc.exists) {
        return TournamentModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    });
  }

  // ==================== FOLLOW SYSTEM ====================

  /// Follow a user
  Future<bool> followUser(String followerId, String followingId) async {
    try {
      final batch = _db.batch();
      
      // Add to follower's following list
      batch.set(
        _db.collection(usersCollection).doc(followerId).collection('following').doc(followingId),
        {'followedAt': FieldValue.serverTimestamp()},
      );
      
      // Add to followed user's followers list
      batch.set(
        _db.collection(usersCollection).doc(followingId).collection('followers').doc(followerId),
        {'followedAt': FieldValue.serverTimestamp()},
      );
      
      await batch.commit();
      
      // Look up follower's details to send a proper notification
      final followerDoc = await _db.collection(usersCollection).doc(followerId).get();
      final followerName = followerDoc.exists ? (followerDoc.data()?['name'] ?? 'Someone') : 'Someone';
      
      // Create follow notification
      await createNotification(
        userId: followingId,
        notification: NotificationModel(
          id: '', // Will be generated
          userId: followingId,
          type: NotificationType.follow,
          title: 'New Follower',
          body: '$followerName started following you',
          data: {'followerId': followerId},
          createdAt: DateTime.now(),
        ),
      );
      
      // Trigger backend push notification
      try {
        final tokenSnapshot = await _db
            .collection(usersCollection)
            .doc(followingId)
            .collection('fcmTokens')
            .get();
        
        final List<String> tokens = [];
        for (var doc in tokenSnapshot.docs) {
           if (doc.data()['token'] != null) {
               tokens.add(doc.data()['token']);
           }
        }
        
        if (tokens.isNotEmpty) {
           await ApiService.instance.post('/api/notifications/send', {
              'tokens': tokens,
              'title': 'New Follower!',
              'body': '$followerName started following you',
              'data': {
                 'type': 'follow',
                 'followerId': followerId,
              }
           });
           debugPrint('✅ Triggered backend follow push notification');
        }
      } catch (e) {
         debugPrint('⚠️ Failed to trigger backend follow push notification: $e');
      }
      
      debugPrint('✅ User $followerId now follows $followingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String followerId, String followingId) async {
    try {
      final batch = _db.batch();
      
      batch.delete(_db.collection(usersCollection).doc(followerId).collection('following').doc(followingId));
      batch.delete(_db.collection(usersCollection).doc(followingId).collection('followers').doc(followerId));
      
      await batch.commit();
      debugPrint('✅ User $followerId unfollowed $followingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      return false;
    }
  }

  /// Get list of follower UIDs for a user
  Future<List<String>> getFollowerIds(String userId) async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('followers')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('❌ Error getting followers: $e');
      return [];
    }
  }

  /// Get list of following UIDs for a user
  Future<List<String>> getFollowingIds(String userId) async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('following')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('❌ Error getting following: $e');
      return [];
    }
  }

  /// Check if following a user
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final doc = await _db
          .collection(usersCollection)
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get follower count
  Future<int> getFollowerCount(String userId) async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('followers')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('following')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
  // ==================== CHAT ====================

  /// Get or create a chat room between two users
  Future<String> getChatRoom(String userId, String otherUserId) async {
    try {
      // Check if chat room already exists
      // We need to query for a room that contains both users
      // Firestore array-contains only allows checking for one value
      // So we might need a composite key or a different query strategy.
      // Strategy: Query where participants array-contains userId, then filter client-side for otherUserId
      // OR better: Store a map of participant booleans 'participants.$uid': true for precise querying?
      // No, for 2 people, we can construct a deterministic ID if we want, like 'minId_maxId'
      
      final List<String> ids = [userId, otherUserId]..sort();
      final String chatRoomId = '${ids[0]}_${ids[1]}';
      
      final doc = await _db.collection('chats').doc(chatRoomId).get();
      
      if (!doc.exists) {
        // Create new chat room
        await _db.collection('chats').doc(chatRoomId).set({
          'participants': ids,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCounts': {
            userId: 0,
            otherUserId: 0,
          },
          'participantIds': { // scalable querying if needed later
             userId: true,
             otherUserId: true,
          }
        });
      }
      
      return chatRoomId;
    } catch (e) {
      debugPrint('❌ Error getting chat room: $e');
      rethrow;
    }
  }

  /// Upload chat image — stores as base64 data URL in Firestore (avoids Storage CORS issues on web)
  Future<String?> uploadChatImage(String path, {Uint8List? bytes}) async {
    try {
      // Get image bytes
      Uint8List imageBytes;
      if (bytes != null) {
        imageBytes = bytes;
      } else if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        imageBytes = response.bodyBytes;
      } else {
        String cleanPath = path.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (!await file.exists()) {
          throw Exception('Image file does not exist at path: $cleanPath');
        }
        imageBytes = await file.readAsBytes();
      }
      
      debugPrint('📸 Chat image raw size: ${imageBytes.length} bytes');

      // Resize to 300x300 to keep Firestore doc small
      Uint8List finalBytes = imageBytes;
      try {
        final codec = await ui.instantiateImageCodec(
          imageBytes,
          targetWidth: 300,
          targetHeight: 300,
        );
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          finalBytes = byteData.buffer.asUint8List();
          debugPrint('📸 Resized to 300x300: ${finalBytes.length} bytes');
        }
      } catch (resizeError) {
        debugPrint('⚠️ Resize failed, using original: $resizeError');
      }

      // Convert to base64 data URL
      final base64Image = base64Encode(finalBytes);
      final dataUrl = 'data:image/png;base64,$base64Image';
      debugPrint('📸 Chat image data URL ready (${dataUrl.length} chars)');
      
      return dataUrl;
    } catch (e) {
      debugPrint('❌ Error uploading chat image: $e');
      return null;
    }
  }

  /// Upload voice message
  Future<String?> uploadVoiceMessage(String path, {Uint8List? bytes}) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance.ref().child('chat_audio/$fileName');
      
      UploadTask uploadTask;
      final metadata = SettableMetadata(contentType: 'audio/m4a');
      
      if (bytes != null) {
        uploadTask = ref.putData(bytes, metadata);
      } else if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        uploadTask = ref.putData(response.bodyBytes, metadata);
      } else {
        String cleanPath = path.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (!await file.exists()) {
          throw Exception('File does not exist at path: $cleanPath');
        }
        uploadTask = ref.putFile(file, metadata);
      }
      
      final snapshot = await uploadTask;
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload task failed with state: ${snapshot.state}');
      }
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading voice message: $e');
      return null;
    }
  }

  /// Send a message (text, image, or audio)
  Future<void> sendMessage(String chatId, String text, String senderId, {String type = 'text', String? imageUrl, String? audioUrl, int? duration, String? replyToId, String? replyToText}) async {
    try {
      final messageData = {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'duration': duration, // Duration in seconds
        'replyToId': replyToId,
        'replyToText': replyToText,
        'isDeleted': false,
      };

      // Add to messages sub-collection
      await _db.collection('chats').doc(chatId).collection('messages').add(messageData);

      String lastMsgText = text;
      if (type == 'image') lastMsgText = '📷 Image';
      if (type == 'audio') lastMsgText = '🎤 Voice Message';

      // Update chat room metadata
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': lastMsgText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
    }
  }

  /// Delete a message (Soft delete)
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
        'isDeleted': true,
        'text': 'This message was deleted',
        'imageUrl': null,
        'audioUrl': null,
      });
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
    }
  }

  /// React to a message
  Future<void> reactToMessage(String chatId, String messageId, String userId, String reaction) async {
    try {
      await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).set({
        'reactions': {userId: reaction}
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error reacting to message: $e');
    }
  }

  /// Clear all messages in a chat
  Future<void> clearChatMessages(String chatId) async {
    try {
      final snapshot = await _db.collection('chats').doc(chatId).collection('messages').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Update last message
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': 'Chat cleared',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error clearing chat: $e');
    }
  }

  /// Get user's active chats stream
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  /// Get messages stream for a chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get chat room stream (for typing status, online status, headers)
  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  /// Set typing status
  Future<void> setTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _db.collection('chats').doc(chatId).update({
        'typingUsers': isTyping 
            ? FieldValue.arrayUnion([userId]) 
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      debugPrint('❌ Error setting typing status: $e');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId) // Only mark others' messages as read
          .get();

      if (unreadMessages.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      
      // Update unread count in chat room metadata if we were tracking it (skipped for now)
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Save FCM Token for push notifications
  Future<void> saveFCMToken(String userId, String token) async {
    try {
      await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });
      debugPrint('✅ Saved FCM token for user $userId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Remove FCM Token on logout
  Future<void> removeFCMToken(String userId, String token) async {
    try {
      await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .delete();
      debugPrint('✅ Removed FCM token for user $userId');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  /// Create a new in-app notification
  Future<void> createNotification({
    required String userId,
    required NotificationModel notification,
  }) async {
    try {
      final docRef = _db
          .collection(usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc();
          
      await docRef.set(notification.toMap());
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  /// Get stream of user notifications
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _db
        .collection(usersCollection)
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get stream of unread notification count
  Stream<int> getUnreadNotificationCount(String userId) {
    return _db
        .collection(usersCollection)
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  Future<void> markNotificationRead(String userId, String notificationId) async {
    try {
      await _db
          .collection(usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Notify all followers of all players in a match that the match has started
  Future<void> notifyFollowersOfMatchStart(MatchModel match) async {
    try {
      // Collect all unique player IDs from the match
      final playerIds = <String>{};
      
      void addPlayers(TeamScore? score) {
        if (score == null) return;
        for (var b in score.batters) {
          if (b.playerId.isNotEmpty && !b.playerId.startsWith('p_')) playerIds.add(b.playerId);
        }
        for (var b in score.bowlers) {
          if (b.playerId.isNotEmpty && !b.playerId.startsWith('p_')) playerIds.add(b.playerId);
        }
      }
      
      addPlayers(match.team1Score);
      addPlayers(match.team2Score);
      
      // For each player, find followers and send notifications
      for (final playerId in playerIds) {
        // We need the player name to put in the notification body
        final playerDoc = await _db.collection(usersCollection).doc(playerId).get();
        if (!playerDoc.exists) continue;
        
        final playerName = playerDoc.data()?['name'] ?? 'A player you follow';
        final followers = await getFollowerIds(playerId);
        
        // Use batch to send notifications efficiently
        if (followers.isNotEmpty) {
           final batch = _db.batch();
           int batchCount = 0;
           
           for (final followerId in followers) {
              final notifRef = _db
                  .collection(usersCollection)
                  .doc(followerId)
                  .collection('notifications')
                  .doc();
                  
              final notif = NotificationModel(
                id: '',
                userId: followerId,
                type: NotificationType.matchStart,
                title: 'Match Started! 🏏',
                body: '$playerName is playing: ${match.team1Name} vs ${match.team2Name}',
                data: {'matchId': match.id, 'playerId': playerId},
                createdAt: DateTime.now(),
              );
              
              batch.set(notifRef, notif.toMap());
              batchCount++;
              
              if (batchCount == 500) {
                 await batch.commit();
                 batchCount = 0;
              }
           }
           
           if (batchCount > 0) {
              await batch.commit();
           }
        }
      }
      
      // Also trigger backend push notifications
      try {
        await ApiService.instance.post('/api/notifications/match-start', {
          'matchId': match.id,
          'playerIds': playerIds.toList(),
          'team1Name': match.team1Name,
          'team2Name': match.team2Name,
        });
        debugPrint('✅ Triggered backend match-start push notifications');
      } catch (e) {
        debugPrint('⚠️ Failed to trigger backend match-start push notifications: $e');
      }
      
    } catch (e) {
      debugPrint('❌ Error sending match start notifications: $e');
    }
  }

  /// Notify followers of an achievement
  Future<void> notifyFollowersOfAchievement({
    required String playerId,
    required String playerName,
    required String achievementTitle,
    required String matchId,
  }) async {
    try {
      final followers = await getFollowerIds(playerId);
      if (followers.isEmpty) return;
      
      final batch = _db.batch();
      int batchCount = 0;
      
      for (final followerId in followers) {
        final notifRef = _db
            .collection(usersCollection)
            .doc(followerId)
            .collection('notifications')
            .doc();
            
        final notif = NotificationModel(
          id: '',
          userId: followerId,
          type: NotificationType.achievement,
          title: 'Achievement Unlocked! 🏆',
          body: '$playerName just got $achievementTitle!',
          data: {'matchId': matchId, 'playerId': playerId},
          createdAt: DateTime.now(),
        );
        
        batch.set(notifRef, notif.toMap());
        batchCount++;
        
        if (batchCount == 500) {
           await batch.commit();
           batchCount = 0;
        }
      }
      
      if (batchCount > 0) {
         await batch.commit();
      }
      
      // Send backend push
      try {
        // Collect tokens
        final List<String> tokens = [];
        for (final followerId in followers) {
           final tokenSnapshot = await _db
               .collection(usersCollection)
               .doc(followerId)
               .collection('fcmTokens')
               .get();
           for (var doc in tokenSnapshot.docs) {
               if (doc.data()['token'] != null) {
                   tokens.add(doc.data()['token']);
               }
           }
        }
        
        if (tokens.isNotEmpty) {
           await ApiService.instance.post('/api/notifications/send', {
              'tokens': tokens,
              'title': 'Achievement Alert! 🏆',
              'body': 'Your friend $playerName just got $achievementTitle!',
              'data': {
                 'type': 'achievement',
                 'matchId': matchId,
              }
           });
           debugPrint('✅ Triggered backend achievement push notifications');
        }
      } catch (e) {
         debugPrint('⚠️ Failed to trigger backend achievement push notifications: $e');
      }
      
    } catch (e) {
      debugPrint('❌ Error sending achievement notifications: $e');
    }
  }

  // ==================== MATCH HIGHLIGHTS ====================

  Future<bool> saveMatchHighlight({
    required String matchId,
    required MatchHighlight highlight,
    required Uint8List imageBytes,
  }) async {
    try {
      debugPrint('?? Match Highlight upload starting');

      final base64Image = base64Encode(imageBytes);
      final dataUrl = 'data:image/png;base64,' + base64Image;
      
      final finalHighlight = MatchHighlight(
        id: highlight.id,
        imageUrl: dataUrl,
        type: highlight.type,
        title: highlight.title,
        description: highlight.description,
        playerId: highlight.playerId,
        playerName: highlight.playerName,
        createdAt: highlight.createdAt,
      );

      await _db.collection(matchesCollection).doc(matchId).update({
        'highlights': FieldValue.arrayUnion([finalHighlight.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('? Match highlight saved successfully!');
      return true;
    } catch (e) {
      debugPrint('? Error saving match highlight: ' + e.toString());
      return false;
    }
  }

  Future<bool> saveMatchHighlightsBatch({
    required String matchId,
    required List<MatchHighlight> highlights,
  }) async {
    try {
      debugPrint('?? Match Highlights batch upload starting');
      
      final highlightsData = highlights.map((h) => h.toMap()).toList();

      await _db.collection(matchesCollection).doc(matchId).update({
        'highlights': highlightsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('? Match highlights batch saved successfully!');

      // Run player achievements and notifications gracefully in background
      processPlayerAchievementsAndNotifications(matchId, highlights);
      
      return true;
    } catch (e) {
      debugPrint('? Error saving match highlights batch: ' + e.toString());
      return false;
    }
  }

  String _getEmojiForHighlightType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('century') || lowerType.contains('100') || lowerType.contains('runs')) {
      return '💯';
    } else if (lowerType.contains('fifty') || lowerType.contains('50') || lowerType.contains('half_century')) {
      return '5️⃣0️⃣';
    } else if (lowerType.contains('wicket') || lowerType.contains('five_wickets')) {
      return '🔥';
    } else if (lowerType.contains('man_of_match') || lowerType.contains('mvp') || lowerType.contains('mom')) {
      return '⭐';
    } else if (lowerType.contains('win')) {
      return '🏆';
    }
    return '🏅';
  }

  Future<void> processPlayerAchievementsAndNotifications(
    String matchId,
    List<MatchHighlight> highlights,
  ) async {
    try {
      final matchDoc = await _db.collection(matchesCollection).doc(matchId).get();
      String matchName = 'Match';
      if (matchDoc.exists) {
        final matchData = matchDoc.data()!;
        final team1Name = matchData['team1Name'] ?? 'Team 1';
        final team2Name = matchData['team2Name'] ?? 'Team 2';
        matchName = '$team1Name vs $team2Name';
      }

      for (final highlight in highlights) {
        String? lookupId = highlight.playerId;
        if (lookupId == null || lookupId.isEmpty) {
          lookupId = highlight.playerName;
        }
        if (lookupId == null || lookupId.isEmpty) continue;

        try {
          final resolvedUser = await findUserByAnyId(lookupId);
          if (resolvedUser == null) {
            debugPrint('⚠️ Could not resolve user for ID/Name: $lookupId');
            continue;
          }

          final actualPlayerId = resolvedUser.uid;
          final ach = PlayerAchievement(
            id: highlight.id,
            type: highlight.type,
            title: highlight.title,
            description: highlight.description,
            matchId: matchId,
            matchName: matchName,
            earnedAt: highlight.createdAt,
            badgeIcon: _getEmojiForHighlightType(highlight.type),
          );

          // Add to player achievements
          await _db.collection(usersCollection).doc(actualPlayerId).update({
            'achievements': FieldValue.arrayUnion([ach.toMap()]),
          });
          debugPrint('✅ Added badge ${highlight.title} to player $actualPlayerId achievements');

          // Notify the player
          final notifRef = _db
              .collection(usersCollection)
              .doc(actualPlayerId)
              .collection('notifications')
              .doc();
          
          final notif = NotificationModel(
            id: '',
            userId: actualPlayerId,
            type: NotificationType.achievement,
            title: 'New Badge Earned! 🏆',
            body: 'You earned the badge: ${highlight.title}! Check your profile.',
            data: {'matchId': matchId, 'playerId': actualPlayerId, 'highlightId': highlight.id},
            createdAt: DateTime.now(),
          );

          await notifRef.set(notif.toMap());
          debugPrint('✅ Sent in-app notification to player $actualPlayerId');

          // Send FCM push notification to the player
          try {
            final tokenSnapshot = await _db
                .collection(usersCollection)
                .doc(actualPlayerId)
                .collection('fcmTokens')
                .get();
            final List<String> tokens = [];
            for (var doc in tokenSnapshot.docs) {
              if (doc.data()['token'] != null) {
                tokens.add(doc.data()['token']);
              }
            }
            if (tokens.isNotEmpty) {
              await ApiService.instance.post('/api/notifications/send', {
                'tokens': tokens,
                'title': 'New Badge Earned! 🏆',
                'body': 'You earned the badge: ${highlight.title}! Check your profile.',
                'data': {
                  'type': 'achievement',
                  'matchId': matchId,
                }
              });
              debugPrint('✅ Sent push notification to player $actualPlayerId');
            }
          } catch (pushErr) {
            debugPrint('⚠️ Failed to send push notification: $pushErr');
          }

          // Notify followers of achievement
          await notifyFollowersOfAchievement(
            playerId: actualPlayerId,
            playerName: resolvedUser.name,
            achievementTitle: highlight.title,
            matchId: matchId,
          );

        } catch (playerErr) {
          debugPrint('❌ Error updating achievements/notifications for player ${highlight.playerId}: $playerErr');
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing player achievements: $e');
    }
  }

  // ==================== TEAM INVITATIONS ====================

  static const String joinRequestsCollection = 'joinRequests';

  /// Generate a unique invite link for a team
  /// Creates a UUID token, stores it on the team doc with 7-day expiry
  Future<String?> generateInviteLink(String teamId) async {
    try {
      // Generate a unique token using Firestore doc ID (guaranteed unique)
      final tokenDoc = _db.collection('_tokens').doc();
      final token = tokenDoc.id;

      final expiry = DateTime.now().add(const Duration(days: 7));
      final link = 'https://scorepartner.in/join/team/$teamId?invite=$token';

      await _db.collection(teamsCollection).doc(teamId).update({
        'inviteToken': token,
        'inviteLinkEnabled': true,
        'inviteExpiry': expiry.toIso8601String(),
        'inviteLink': link,
      });

      debugPrint('✅ Invite link generated for team $teamId: $link');
      return link;
    } catch (e) {
      debugPrint('❌ Error generating invite link: $e');
      return null;
    }
  }

  /// Revoke (disable) the invite link for a team
  Future<bool> revokeInviteLink(String teamId) async {
    try {
      await _db.collection(teamsCollection).doc(teamId).update({
        'inviteToken': '',
        'inviteLinkEnabled': false,
        'inviteExpiry': null,
        'inviteLink': '',
      });
      debugPrint('✅ Invite link revoked for team $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error revoking invite link: $e');
      return false;
    }
  }

  /// Validate an invite token for a team
  /// Returns the team if valid, null if invalid/expired/disabled
  Future<TeamModel?> validateInviteToken(String teamId, String token) async {
    try {
      final team = await getTeamById(teamId);
      if (team == null) {
        debugPrint('❌ Team not found: $teamId');
        return null;
      }

      // Check token matches
      if (team.inviteToken != token) {
        debugPrint('❌ Invalid invite token for team $teamId');
        return null;
      }

      // Check if link is enabled
      if (!team.inviteLinkEnabled) {
        debugPrint('❌ Invite link is disabled for team $teamId');
        return null;
      }

      // Check expiry
      if (team.inviteExpiry != null && DateTime.now().isAfter(team.inviteExpiry!)) {
        debugPrint('❌ Invite link expired for team $teamId');
        return null;
      }

      return team;
    } catch (e) {
      debugPrint('❌ Error validating invite token: $e');
      return null;
    }
  }

  /// Create a join request for a team
  /// Returns error message if failed, null if success
  Future<String?> createJoinRequest(JoinRequestModel request) async {
    try {
      // Check if player is already in the team
      final team = await getTeamById(request.teamId);
      if (team == null) return 'Team not found';

      final isAlreadyMember = team.players.any(
        (p) => p.userId == request.playerId || 
               (request.playerSpPId.isNotEmpty && p.spPId == request.playerSpPId),
      );
      if (isAlreadyMember) return 'You are already a member of this team';

      // Check for existing pending request
      final existingRequest = await getPlayerPendingRequestForTeam(
        request.playerId,
        request.teamId,
      );
      if (existingRequest != null) return 'You already have a pending request for this team';

      // Create the request
      final docRef = await _db.collection(joinRequestsCollection).add(request.toMap());
      debugPrint('✅ Join request created: ${docRef.id} for team ${request.teamId}');

      // Notify team admin (captain)
      if (team.captainId.isNotEmpty) {
        await createNotification(
          userId: team.captainId,
          notification: NotificationModel(
            id: '',
            userId: team.captainId,
            type: NotificationType.teamJoinRequest,
            title: 'New Join Request',
            body: '${request.playerName} wants to join ${team.name}',
            data: {
              'teamId': request.teamId,
              'requestId': docRef.id,
              'playerId': request.playerId,
            },
            createdAt: DateTime.now(),
          ),
        );
      }

      return null; // Success
    } catch (e) {
      debugPrint('❌ Error creating join request: $e');
      return 'Failed to submit request. Please try again.';
    }
  }

  /// Stream pending join requests for a team (admin view)
  Stream<List<JoinRequestModel>> getJoinRequestsForTeam(String teamId) {
    return _db
        .collection(joinRequestsCollection)
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => JoinRequestModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get a player's pending request for a specific team (to prevent duplicates)
  Future<JoinRequestModel?> getPlayerPendingRequestForTeam(
    String playerId,
    String teamId,
  ) async {
    try {
      final snapshot = await _db
          .collection(joinRequestsCollection)
          .where('playerId', isEqualTo: playerId)
          .where('teamId', isEqualTo: teamId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return JoinRequestModel.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking pending request: $e');
      return null;
    }
  }

  /// Accept a join request — adds the player to the team and notifies them
  Future<bool> acceptJoinRequest(String requestId, String reviewerUid) async {
    try {
      final doc = await _db.collection(joinRequestsCollection).doc(requestId).get();
      if (!doc.exists) return false;

      final request = JoinRequestModel.fromMap(doc.data()!, doc.id);
      if (request.status != JoinRequestStatus.pending) return false;

      // Add player to team
      final newPlayer = TeamPlayer(
        userId: request.playerId,
        spPId: request.playerSpPId,
        name: request.playerName,
        role: request.playerRole,
        battingStyle: request.battingStyle,
        bowlingStyle: request.bowlingStyle,
        isRegistered: true,
      );

      final addSuccess = await addPlayerToTeam(request.teamId, newPlayer);
      if (!addSuccess) return false;

      // Update request status
      await _db.collection(joinRequestsCollection).doc(requestId).update({
        'status': 'accepted',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewerUid,
      });

      // Notify player
      await createNotification(
        userId: request.playerId,
        notification: NotificationModel(
          id: '',
          userId: request.playerId,
          type: NotificationType.teamJoinAccepted,
          title: 'Welcome to the team! 🎉',
          body: 'Congratulations! You have joined ${request.teamName}.',
          data: {
            'teamId': request.teamId,
            'requestId': requestId,
          },
          createdAt: DateTime.now(),
        ),
      );

      debugPrint('✅ Join request $requestId accepted');
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting join request: $e');
      return false;
    }
  }

  /// Reject a join request and notify the player
  Future<bool> rejectJoinRequest(String requestId, String reviewerUid) async {
    try {
      final doc = await _db.collection(joinRequestsCollection).doc(requestId).get();
      if (!doc.exists) return false;

      final request = JoinRequestModel.fromMap(doc.data()!, doc.id);
      if (request.status != JoinRequestStatus.pending) return false;

      // Update request status
      await _db.collection(joinRequestsCollection).doc(requestId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewerUid,
      });

      // Notify player
      await createNotification(
        userId: request.playerId,
        notification: NotificationModel(
          id: '',
          userId: request.playerId,
          type: NotificationType.teamJoinRejected,
          title: 'Request Declined',
          body: 'Your request to join ${request.teamName} was declined.',
          data: {
            'teamId': request.teamId,
            'requestId': requestId,
          },
          createdAt: DateTime.now(),
        ),
      );

      debugPrint('✅ Join request $requestId rejected');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting join request: $e');
      return false;
    }
  }

  // ==================== TOURNAMENT JOIN REQUESTS ====================

  static const String tournamentJoinRequestsCollection = 'tournament_join_requests';

  Future<TournamentModel?> validateTournamentInviteToken(String tournamentId, String token) async {
    try {
      final doc = await _db.collection(tournamentsCollection).doc(tournamentId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['inviteToken'] != token || data['inviteLinkEnabled'] != true) {
        return null;
      }

      // Check expiry if exists
      if (data['inviteExpiry'] != null) {
        final expiry = (data['inviteExpiry'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiry)) {
          return null;
        }
      }

      return TournamentModel.fromMap({...data, 'id': doc.id});
    } catch (e) {
      debugPrint('❌ Error validating tournament invite token: $e');
      return null;
    }
  }

  Future<String?> createTournamentJoinRequest(TournamentJoinRequestModel request) async {
    try {
      // 1. Check if tournament exists and has slots
      final tournamentDoc = await _db.collection(tournamentsCollection).doc(request.tournamentId).get();
      if (!tournamentDoc.exists) return 'Tournament not found';
      
      final tData = tournamentDoc.data()!;
      final registeredTeams = List<String>.from(tData['registeredTeamIds'] ?? []);
      final maxTeams = tData['maxTeams'] ?? 8;
      
      if (registeredTeams.length >= maxTeams) {
        return 'Tournament is full';
      }
      
      if (registeredTeams.contains(request.teamId)) {
        return 'Team is already registered for this tournament';
      }

      // 2. Check for existing pending request
      final existingReqs = await _db.collection(tournamentJoinRequestsCollection)
          .where('tournamentId', isEqualTo: request.tournamentId)
          .where('teamId', isEqualTo: request.teamId)
          .where('status', isEqualTo: TournamentJoinRequestStatus.pending.name)
          .limit(1)
          .get();
          
      if (existingReqs.docs.isNotEmpty) {
        return 'A request is already pending for this team';
      }

      // 3. Create the request
      final docRef = await _db.collection(tournamentJoinRequestsCollection).add(request.toMap());

      // 4. Notify Tournament Organizer
      await createNotification(
        notification: NotificationModel(
          id: '',
          userId: tData['organizerId'],
          type: NotificationType.teamJoinRequest, // Reuse or create a new type if needed
          title: 'New Tournament Registration Request',
          body: '${request.teamName} has requested to join ${request.tournamentName}.',
          data: {
            'tournamentId': request.tournamentId,
            'teamId': request.teamId,
            'requestId': docRef.id,
          },
          createdAt: DateTime.now(),
        ),
      );

      return null; // Success
    } catch (e) {
      debugPrint('❌ Error creating tournament join request: $e');
      return 'An error occurred while submitting the request';
    }
  }

  Future<List<TournamentJoinRequestModel>> getTournamentJoinRequests(String tournamentId) async {
    try {
      final snapshot = await _db.collection(tournamentJoinRequestsCollection)
          .where('tournamentId', isEqualTo: tournamentId)
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => TournamentJoinRequestModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint('❌ Error getting tournament join requests: $e');
      return [];
    }
  }

  Future<bool> updateTournamentJoinRequestStatus(String requestId, String status, String adminId, {String rejectionReason = ''}) async {
    try {
      final doc = await _db.collection(tournamentJoinRequestsCollection).doc(requestId).get();
      if (!doc.exists) return false;
      
      final reqData = doc.data()!;
      final teamId = reqData['teamId'];
      final tournamentId = reqData['tournamentId'];
      final requestedByUserId = reqData['requestedByUserId'];

      await _db.collection(tournamentJoinRequestsCollection).doc(requestId).update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'rejectionReason': rejectionReason,
      });

      if (status == TournamentJoinRequestStatus.accepted.name) {
        // Add team to tournament
        await addTeamToTournament(tournamentId, teamId);
      }

      // Notify requester
      await createNotification(
        notification: NotificationModel(
          id: '',
          userId: requestedByUserId,
          type: status == TournamentJoinRequestStatus.accepted.name 
              ? NotificationType.teamJoinAccepted 
              : NotificationType.teamJoinRejected,
          title: status == TournamentJoinRequestStatus.accepted.name 
              ? 'Registration Accepted' 
              : 'Registration Rejected',
          body: status == TournamentJoinRequestStatus.accepted.name
              ? 'Your request for ${reqData['teamName']} to join ${reqData['tournamentName']} was approved.'
              : 'Your request for ${reqData['teamName']} to join ${reqData['tournamentName']} was rejected. ${rejectionReason.isNotEmpty ? "\nReason: $rejectionReason" : ""}',
          data: {
            'tournamentId': tournamentId,
            'teamId': teamId,
          },
          createdAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error updating tournament join request status: $e');
      return false;
    }
  }

  Future<TournamentJoinRequestModel?> getTeamPendingRequestForTournament(String teamId, String tournamentId) async {
    try {
      final snapshot = await _db.collection(tournamentJoinRequestsCollection)
          .where('tournamentId', isEqualTo: tournamentId)
          .where('teamId', isEqualTo: teamId)
          .where('status', isEqualTo: TournamentJoinRequestStatus.pending.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return TournamentJoinRequestModel.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting team pending request for tournament: $e');
      return null;
    }
  }

  Future<String?> generateTournamentInviteLink(String tournamentId) async {
    try {
      // 1. Generate token
      final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      
      // 2. Update tournament
      await _db.collection(tournamentsCollection).doc(tournamentId).update({
        'inviteToken': token,
        'inviteLinkEnabled': true,
      });
      
      // 3. Return the link (using same logic as team invite link but with different path)
      // scorepartner.app/join/tournament/{tournamentId}?invite={token}
      return 'https://scorepartner.app/join/tournament/$tournamentId?invite=$token';
    } catch (e) {
      debugPrint('❌ Error generating tournament invite link: $e');
      return null;
    }
  }
}
