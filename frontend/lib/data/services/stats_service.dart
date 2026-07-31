import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/match_model.dart';
import '../models/match_performance.dart';
import 'match_stats_calculator.dart';
import 'firebase_data_service.dart';
import '../../presentation/widgets/mvp_calculator_widget.dart';

class StatsService {
  final FirebaseDataService _dataService = FirebaseDataService.instance;

  /// Process match completion to update user stats and award achievements
  Future<void> processMatchCompletion(MatchModel match) async {
    try {
      debugPrint('📊 Starting atomic stats overhaul for match: ${match.id}');
      
      // 1. Calculate performances for all players in the match
      final performances = MatchStatsCalculator.calculateAllPerformances(match);
      debugPrint('🧮 Calculated ${performances.length} player performances.');

      // 2. Resolve and Apply stats atomically for each player
      Set<String> resolvedActualUids = {};
      
      for (var perf in performances) {
        final originalId = perf.playerId;
        String resolvedId = originalId;

        // Skip placeholders
        if (originalId.isEmpty || originalId.contains('placeholder')) {
          debugPrint('⏭️ Skipping placeholder: "$originalId"');
          continue;
        }

        // Resolve manual/temporary IDs to real users if possible.
        // Only flag IDs that START with known manual prefixes or are very short.
        // Firebase Auth UIDs are typically 28 characters and don't start with these prefixes.
        bool isLikelyTemporary = originalId.startsWith('p_') || 
                                 originalId.startsWith('manual_') || 
                                 originalId.startsWith('player_') ||
                                 originalId.length < 20;

        if (isLikelyTemporary) {
           debugPrint('🔍 Attempting to resolve temp ID: "$originalId" (${perf.playerName})');
           final resolvedUser = await _dataService.resolveTemporaryPlayer(originalId, perf.playerName);
           if (resolvedUser != null && resolvedUser.uid.isNotEmpty) {
              resolvedId = resolvedUser.uid;
              debugPrint('🔄 Resolved "$originalId" (${perf.playerName}) -> $resolvedId');
           } else {
              debugPrint('⚠️ Skip: Could not resolve temp player "$originalId" (${perf.playerName})');
              continue; 
           }
        } else {
           debugPrint('✅ Using real UID directly: "$originalId" (${perf.playerName})');
        }

        // Apply stats using the new atomic method
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
        );

        await _dataService.applyMatchPerformanceAtomic(finalPerf);
        resolvedActualUids.add(resolvedId);
      }

      // 3. Sync player IDs to match document (for visibility)
      if (resolvedActualUids.isNotEmpty) {
        await _dataService.updateMatch(match.id, {
          'playerIds': FieldValue.arrayUnion(resolvedActualUids.toList()),
        });
      }

      // 4. Automatically Generate Badges and Rewards
      await _generateAutomaticBadges(match, resolvedActualUids);

      debugPrint('✅ Stats overhaul complete for match ${match.id}. Updated ${resolvedActualUids.length} players.');
      
    } catch (e) {
      debugPrint('❌ Critical error in StatsService overhaul: $e');
    }
  }

  Future<void> _generateAutomaticBadges(MatchModel match, Set<String> validPlayerIds) async {
    try {
      debugPrint('🏅 Generating automatic badges for match ${match.id}');
      List<MatchHighlight> automaticHighlights = [];
      const uuid = Uuid();

      // 1. Batter Milestones (Fifty / Century)
      final allBatters = [...match.team1Score.batters, ...match.team2Score.batters];
      for (final batter in allBatters) {
        if (batter.runs >= 50 && batter.playerId.isNotEmpty && validPlayerIds.contains(batter.playerId)) {
          final isCentury = batter.runs >= 100;
          automaticHighlights.add(MatchHighlight(
            id: uuid.v4(),
            imageUrl: '', // No screenshot generated automatically
            type: isCentury ? 'century' : 'fifty',
            title: isCentury ? 'CENTURY HERO' : 'HALF CENTURY',
            description: 'Blazed ${batter.runs} runs off ${batter.balls} balls (${batter.fours}x4, ${batter.sixes}x6)!',
            playerId: batter.playerId,
            playerName: batter.playerName,
            createdAt: DateTime.now(),
          ));
        }
      }

      // 2. Bowler Milestones (Wickets)
      final allBowlers = [...match.team1Score.bowlers, ...match.team2Score.bowlers];
      for (final bowler in allBowlers) {
        if (bowler.wickets >= 3 && bowler.playerId.isNotEmpty && validPlayerIds.contains(bowler.playerId)) {
          automaticHighlights.add(MatchHighlight(
            id: uuid.v4(),
            imageUrl: '',
            type: 'wicket',
            title: 'STRIKE BOWLER',
            description: 'Sensational bowling spell taking ${bowler.wickets} wickets for ${bowler.runs} runs in ${bowler.oversDisplay} overs!',
            playerId: bowler.playerId,
            playerName: bowler.playerName,
            createdAt: DateTime.now(),
          ));
        }
      }

      // 3. Man of the Match (MVP)
      final mvpList = calculateMvpRatings(match);
      if (mvpList.isNotEmpty) {
        final mvp = mvpList.firstWhere(
          (p) => p.isManOfMatch, 
          orElse: () => mvpList.reduce((a, b) => a.mvpPoints > b.mvpPoints ? a : b)
        );
        if (mvp.playerId.isNotEmpty && validPlayerIds.contains(mvp.playerId)) {
          automaticHighlights.add(MatchHighlight(
            id: uuid.v4(),
            imageUrl: '',
            type: 'mvp',
            title: 'MAN OF THE MATCH',
            description: 'Spectacular all-round performance securing ${mvp.mvpPoints.toStringAsFixed(0)} MVP points!',
            playerId: mvp.playerId,
            playerName: mvp.playerName,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (automaticHighlights.isNotEmpty) {
        // Send them to FirebaseDataService to process player achievements & notifications
        await _dataService.processPlayerAchievementsAndNotifications(match.id, automaticHighlights);
        debugPrint('✅ Successfully queued ${automaticHighlights.length} badges for notifications & rewards!');
      } else {
        debugPrint('ℹ️ No milestone badges earned in this match.');
      }
    } catch (e) {
      debugPrint('❌ Error generating automatic badges: $e');
    }
  }
}

