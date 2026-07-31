import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/models/team_model.dart';

Future<void> recalculateBowlingStatsForTournament(String tournamentId, List<MatchModel> allMatches) async {
  debugPrint('Recalculating bowling stats for tournament: $tournamentId');
  
  final tournamentMatches = allMatches.where((m) => m.tournamentId == tournamentId && (m.status == 'completed' || m.status == 'abandoned')).toList();
  
  if (tournamentMatches.isEmpty) {
     debugPrint('No completed matches found for tournament: $tournamentId');
     return;
  }
  
  // We need to re-run the logic for Economy and Best Figures
  final economyLeaderboard = <String, TournamentLeaderboardEntry>{};
  final bestSpellsLeaderboard = <String, TournamentLeaderboardEntry>{};
  
  // Helper to process Economy
  void processEconomyBowlers(List<BowlerStats> bowlers, String teamId, String teamName) {
    for (var bowler in bowlers) {
      if (bowler.playerId.isEmpty || bowler.playerId.startsWith('p_')) continue;
      if (bowler.overs < 2.0) continue; 
      
      final current = economyLeaderboard[bowler.playerId];
      
      int currentBalls = (bowler.overs.floor() * 6) + ((bowler.overs - bowler.overs.floor()) * 10).round();
      int totalRuns = (current?.value ?? 0) + bowler.runs;
      int totalBalls = (current?.matches ?? 0) + currentBalls;
      
      double economy = (totalRuns / (totalBalls / 6.0));
      
      economyLeaderboard[bowler.playerId] = TournamentLeaderboardEntry(
        playerId: bowler.playerId,
        playerName: bowler.playerName,
        teamId: teamId,
        teamName: teamName,
        value: totalRuns,
        matches: totalBalls,
        average: economy,
      );
    }
  }

  // Helper to process Best Figures
  void processSpells(List<BowlerStats> bowlers, String teamId, String teamName) {
    for (var bowler in bowlers) {
      if (bowler.playerId.isEmpty || bowler.playerId.startsWith('p_')) continue;
      if (bowler.wickets == 0) continue; 
      
      final currentBest = bestSpellsLeaderboard[bowler.playerId];
      
      bool isBetterSpell = false;
      if (currentBest == null) {
        isBetterSpell = true;
      } else {
        if (bowler.wickets > currentBest.value) {
          isBetterSpell = true;
        } else if (bowler.wickets == currentBest.value && bowler.runs < currentBest.matches) {
          isBetterSpell = true; 
        }
      }
      
      if (isBetterSpell) {
        bestSpellsLeaderboard[bowler.playerId] = TournamentLeaderboardEntry(
          playerId: bowler.playerId,
          playerName: bowler.playerName,
          teamId: teamId,
          teamName: teamName,
          value: bowler.wickets,
          matches: bowler.runs, 
          description: '${bowler.wickets}/${bowler.runs} (${bowler.overs.toStringAsFixed(1)})',
        );
      }
    }
  }

  // Iterate over all matches
  for (var match in tournamentMatches) {
     // team1 bowled to team2
     processEconomyBowlers(match.team2Score.bowlers, match.team1Id, match.team1Name);
     processSpells(match.team2Score.bowlers, match.team1Id, match.team1Name);
     
     // team2 bowled to team1
     processEconomyBowlers(match.team1Score.bowlers, match.team2Id, match.team2Name);
     processSpells(match.team1Score.bowlers, match.team2Id, match.team2Name);
  }
  
  final sortedEconomy = economyLeaderboard.values.toList()
    ..sort((a, b) => a.average.compareTo(b.average));
    
  final sortedSpells = bestSpellsLeaderboard.values.toList()
    ..sort((a, b) {
      int wicketCompare = b.value.compareTo(a.value);
      if (wicketCompare != 0) return wicketCompare;
      return a.matches.compareTo(b.matches); 
    });
    
  final bestEconomyList = sortedEconomy.take(10).toList();
  final bestBowlingFiguresList = sortedSpells.take(10).toList();
  
  debugPrint('Calculated Economy Leaderboard: ${bestEconomyList.length} players');
  debugPrint('Calculated Best Spells Leaderboard: ${bestBowlingFiguresList.length} players');
  
  await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).update({
    'bestEconomy': bestEconomyList.map((e) => e.toMap()).toList(),
    'bestBowlingFigures': bestBowlingFiguresList.map((e) => e.toMap()).toList(),
  });
  
  debugPrint('Successfully updated tournament $tournamentId!');
}

Future<void> runRecalculationScript() async {
  try {
    debugPrint('Starting global recalculation script...');
    final matchesQuery = await FirebaseFirestore.instance.collection('matches').get();
    
    final allMatches = matchesQuery.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return MatchModel.fromMap(data);
    }).toList();
    debugPrint('Found ${allMatches.length} total matches in database.');
    
    final tournamentsQuery = await FirebaseFirestore.instance.collection('tournaments').get();
    debugPrint('Found ${tournamentsQuery.docs.length} total tournaments in database.');
    
    for (var doc in tournamentsQuery.docs) {
      await recalculateBowlingStatsForTournament(doc.id, allMatches);
    }
    
    debugPrint('COMPLETED FULL RECALCULATION!');
  } catch(e) {
    debugPrint('ERROR RUNNING SCRIPT: $e');
  }
}
