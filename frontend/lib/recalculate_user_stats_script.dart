import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data/models/match_model.dart';
import 'data/services/firebase_data_service.dart';
import 'data/services/stats_service.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/auth_provider.dart';

/// Recalculates stats for the current user AND all players they've played with.
/// This ensures ALL player profiles show accurate stats from completed matches.
Future<void> runUserStatsRecalculationScript(BuildContext context, String userId) async {
  try {
    debugPrint('🚀 Starting global stats recalculation...');
    
    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recalculating stats for all players. Please wait...'),
          duration: Duration(seconds: 6),
        ),
      );
    }
    
    final db = FirebaseFirestore.instance;
    final dataService = FirebaseDataService.instance;
    
    // 1. Fetch ALL completed matches
    final snapshot = await db.collection('matches').get();
    final allMatches = snapshot.docs.map((doc) => MatchModel.fromMap({...doc.data(), 'id': doc.id})).toList();
    final completedMatches = allMatches.where((m) => m.status == 'completed').toList();
    
    debugPrint('📊 Found ${completedMatches.length} completed matches total');
    
    if (completedMatches.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No completed matches found.')),
        );
      }
      return;
    }
    
    // 2. Collect ALL unique player IDs from all completed matches
    final Set<String> allPlayerIds = {};
    for (var match in completedMatches) {
      // Also check scorers' individual stats entries in case playerIds is empty
      for (var b in [...match.team1Score.batters, ...match.team2Score.batters]) {
        if (b.playerId.isNotEmpty) allPlayerIds.add(b.playerId);
      }
      for (var b in [...match.team1Score.bowlers, ...match.team2Score.bowlers]) {
        if (b.playerId.isNotEmpty) allPlayerIds.add(b.playerId);
      }
      // Also add from playerIds array
      for (var pid in match.playerIds) {
        if (pid.isNotEmpty) allPlayerIds.add(pid);
      }
    }
    
    debugPrint('👥 Found ${allPlayerIds.length} unique player IDs/names in match data');
    debugPrint('🔍 Sample IDs: ${allPlayerIds.take(5).toList()}');

    // DEBUG: Check field casing in the database
    final userCheck = await db.collection('users').limit(1).get();
    if (userCheck.docs.isNotEmpty) {
      final fields = userCheck.docs.first.data().keys.toList();
      debugPrint('📂 DATABASE USER FIELDS: $fields');
    }

    // 3. Reset stats for ALL affected players
    final emptyStats = {
      'matches': 0, 'runs': 0, 'balls': 0, 'wickets': 0, 
      'runsConceded': 0, 'ballsBowled': 0, 'strikeRate': 0.0, 'economy': 0.0,
      'bestScore': 0, 'bestBowling': '0/0', 'manOfMatches': 0, 'tournamentWins': 0,
      'fours': 0, 'sixes': 0, 'fifties': 0, 'hundreds': 0, 'ducks': 0, 'fiveWickets': 0,
      'catches': 0, 'runOuts': 0, 'stumpings': 0, 'directHits': 0,
    };
    
    debugPrint('🧹 Resetting stats for ${allPlayerIds.length} potential players');
    int resetCount = 0;
    for (var pid in allPlayerIds) {
      try {
        String targetId = pid;
        
        // Use robust temporary ID detection matching StatsService
        bool isLikelyTemporary = pid.length < 20 || 
                                 pid.startsWith('p_') || 
                                 pid.startsWith('manual_') || 
                                 pid.startsWith('player_') ||
                                 pid.contains(' ');

        if (isLikelyTemporary) {
           String? playerName;
           searchLoop:
           for(var match in completedMatches) {
               for (var b in [...match.team1Score.batters, ...match.team2Score.batters]) {
                 if (b.playerId == pid) { playerName = b.playerName; break searchLoop; }
               }
               for (var b in [...match.team1Score.bowlers, ...match.team2Score.bowlers]) {
                 if (b.playerId == pid) { playerName = b.playerName; break searchLoop; }
               }
           }
           
           if (playerName != null) {
              final resolvedUser = await dataService.resolveTemporaryPlayer(pid, playerName);
              if (resolvedUser != null) {
                 targetId = resolvedUser.uid;
                 debugPrint('🎯 Resolved $pid ($playerName) -> $targetId');
              }
           }
        }

        final userDoc = await db.collection('users').doc(targetId).get();
        if (userDoc.exists) {
          // Reset statistics and gamification data
          await db.collection('users').doc(targetId).update({
            'tennisBallStats': emptyStats,
            'leatherBallStats': emptyStats,
            'stars': 0,
            'rankTitle': 'Bal Yoddha',
            'unlockedTitles': ['Bal Yoddha'],
          });

          // 🧹 CLEAR processed_matches subcollection to allow full re-calculation
          final collectionRef = db.collection('users').doc(targetId).collection('processed_matches');
          final snapshots = await collectionRef.get();
          for (var doc in snapshots.docs) {
            await doc.reference.delete();
          }

          resetCount++;
          if (resetCount % 10 == 0) debugPrint('📍 Reset $resetCount players...');
        }
      } catch (e) {
        debugPrint('⚠️ Skip reset $pid: $e');
      }
    }
    
    debugPrint('✅ Reset stats for $resetCount actual system accounts');
    
    // 4. Re-process EACH completed match using StatsService (updates ALL players)
    final statsService = StatsService();
    int matchDone = 0;
    for (var match in completedMatches) {
      try {
        await statsService.processMatchCompletion(match);
        debugPrint('✅ Processed match: ${match.team1Name} vs ${match.team2Name}');
        matchDone++;
      } catch (e) {
        debugPrint('⚠️ Error processing match ${match.id}: $e');
      }
    }
    
    debugPrint('🏁 DONE! Processed $matchDone matches.');
    
    // 5. Force reload current user
    if (context.mounted) {
       final authProvider = Provider.of<AuthProvider>(context, listen: false);
       await Future.delayed(const Duration(milliseconds: 1500));
       await authProvider.refreshUser();
       
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Recalculation Complete! $matchDone matches processed.'),
             backgroundColor: Colors.green,
             duration: const Duration(seconds: 4),
           ),
         );
       }
    }
  } catch (e, stack) {
    debugPrint('❌ Critical Recalculation Error: $e');
    debugPrintStack(stackTrace: stack);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
