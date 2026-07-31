import '../models/match_model.dart';
import '../models/match_performance.dart';

class MatchStatsCalculator {
  /// Extracts performance data for all players involved in the match
  static List<MatchPerformance> calculateAllPerformances(MatchModel match) {
    final Map<String, MatchPerformance> performances = {};
    
    final String ballType = match.matchType.toLowerCase().contains('leather') ? 'leather' : 'tennis';
    final String manualMomName = (match.result?.manOfMatch ?? '').trim().toLowerCase();

    // Determine winner team ID
    final String? winnerTeamId = match.result?.winner != null && match.result!.winner != 'Match Tied'
        ? (match.result!.winner == match.team1Name ? match.team1Id : match.team2Id)
        : null;

    // Collect team1 player IDs and team2 player IDs for winner assignment
    final Set<String> team1PlayerIds = {};
    final Set<String> team2PlayerIds = {};
    for (var b in match.team1Score.batters) { team1PlayerIds.add(b.playerId); }
    for (var b in match.team1Score.bowlers) { team1PlayerIds.add(b.playerId); }
    for (var b in match.team2Score.batters) { team2PlayerIds.add(b.playerId); }
    for (var b in match.team2Score.bowlers) { team2PlayerIds.add(b.playerId); }

    bool isPlayerWinner(String playerId) {
      if (winnerTeamId == null) return false;
      if (winnerTeamId == match.team1Id) return team1PlayerIds.contains(playerId);
      if (winnerTeamId == match.team2Id) return team2PlayerIds.contains(playerId);
      return false;
    }

    // Helper to get or create performance object
    MatchPerformance getPerf(String pid, String name) {
      return performances.putIfAbsent(pid, () => MatchPerformance(
        playerId: pid,
        playerName: name,
        matchId: match.id,
        ballType: ballType,
        playedAt: match.createdAt,
        isWinner: isPlayerWinner(pid),
      ));
    }

    // Process Team 1 Batters
    for (var b in match.team1Score.batters) {
      if (b.playerId.isEmpty || b.playerId.startsWith('p_')) continue; 
      final p = getPerf(b.playerId, b.playerName);
      performances[b.playerId] = _updateWithBatting(p, b);
    }

    // Process Team 1 Bowlers
    for (var b in match.team1Score.bowlers) {
      if (b.playerId.isEmpty) continue;
      final p = getPerf(b.playerId, b.playerName);
      performances[b.playerId] = _updateWithBowling(p, b);
    }

    // Process Team 2 Batters
    for (var b in match.team2Score.batters) {
      if (b.playerId.isEmpty) continue;
      final p = getPerf(b.playerId, b.playerName);
      performances[b.playerId] = _updateWithBatting(p, b);
    }

    // Process Team 2 Bowlers
    for (var b in match.team2Score.bowlers) {
      if (b.playerId.isEmpty) continue;
      final p = getPerf(b.playerId, b.playerName);
      performances[b.playerId] = _updateWithBowling(p, b);
    }

    // ── Extract Fielding Stats from ball-by-ball ──
    final Map<String, int> catchCounts = {};
    final Map<String, int> runOutCounts = {};
    final Map<String, int> stumpingCounts = {};

    for (var ball in match.ballByBall) {
      if (ball.wicket != null) {
        final fielderId = ball.wicket!.fielderId;
        final wicketType = (ball.wicket!.type ?? '').toLowerCase();

        if (fielderId != null && fielderId.isNotEmpty) {
          if (wicketType == 'caught' || wicketType == 'caught-behind' || wicketType == 'catch') {
            catchCounts[fielderId] = (catchCounts[fielderId] ?? 0) + 1;
          } else if (wicketType == 'run-out' || wicketType == 'run out') {
            runOutCounts[fielderId] = (runOutCounts[fielderId] ?? 0) + 1;
          } else if (wicketType == 'stumped' || wicketType == 'stumping') {
            stumpingCounts[fielderId] = (stumpingCounts[fielderId] ?? 0) + 1;
          }
        }
      }
    }

    // Apply fielding stats to performances
    for (var fielderId in {...catchCounts.keys, ...runOutCounts.keys, ...stumpingCounts.keys}) {
      if (fielderId.isEmpty) continue;
      final p = getPerf(fielderId, performances[fielderId]?.playerName ?? 'Fielder');
      performances[fielderId] = _updateWithFielding(
        p,
        catchCounts[fielderId] ?? 0,
        runOutCounts[fielderId] ?? 0,
        stumpingCounts[fielderId] ?? 0,
      );
    }

    // Assign Man of the Match
    if (manualMomName.isNotEmpty) {
      for (var entry in performances.entries) {
        if (entry.value.playerName.toLowerCase().trim() == manualMomName) {
          performances[entry.key] = _updateWithMom(entry.value);
          break;
        }
      }
    }

    return performances.values.toList();
  }

  static MatchPerformance _updateWithBatting(MatchPerformance p, BatterStats b) {
    return MatchPerformance(
      playerId: p.playerId,
      playerName: p.playerName,
      matchId: p.matchId,
      ballType: p.ballType,
      playedAt: p.playedAt,
      runsScored: p.runsScored + b.runs,
      ballsFaced: p.ballsFaced + b.balls,
      fours: p.fours + b.fours,
      sixes: p.sixes + b.sixes,
      isOut: p.isOut || b.isOut,
      isDuck: p.isDuck || (b.isOut && b.runs == 0),
      isFifty: p.isFifty || (b.runs >= 50 && b.runs < 100),
      isHundred: p.isHundred || (b.runs >= 100),
      wickets: p.wickets,
      runsConceded: p.runsConceded,
      ballsBowled: p.ballsBowled,
      isFiveWicketHaul: p.isFiveWicketHaul,
      catches: p.catches,
      runOuts: p.runOuts,
      stumpings: p.stumpings,
      isManOfMatch: p.isManOfMatch,
      isWinner: p.isWinner,
    );
  }

  static MatchPerformance _updateWithBowling(MatchPerformance p, BowlerStats b) {
    return MatchPerformance(
      playerId: p.playerId,
      playerName: p.playerName,
      matchId: p.matchId,
      ballType: p.ballType,
      playedAt: p.playedAt,
      wickets: p.wickets + b.wickets,
      runsConceded: p.runsConceded + b.runs,
      ballsBowled: p.ballsBowled + (b.overs * 6) + b.balls,
      isFiveWicketHaul: p.isFiveWicketHaul || (b.wickets >= 5),
      runsScored: p.runsScored,
      ballsFaced: p.ballsFaced,
      fours: p.fours,
      sixes: p.sixes,
      isOut: p.isOut,
      isDuck: p.isDuck,
      isFifty: p.isFifty,
      isHundred: p.isHundred,
      catches: p.catches,
      runOuts: p.runOuts,
      stumpings: p.stumpings,
      isManOfMatch: p.isManOfMatch,
      isWinner: p.isWinner,
    );
  }

  static MatchPerformance _updateWithFielding(MatchPerformance p, int newCatches, int newRunOuts, int newStumpings) {
    return MatchPerformance(
      playerId: p.playerId,
      playerName: p.playerName,
      matchId: p.matchId,
      ballType: p.ballType,
      playedAt: p.playedAt,
      runsScored: p.runsScored,
      ballsFaced: p.ballsFaced,
      fours: p.fours,
      sixes: p.sixes,
      isOut: p.isOut,
      isDuck: p.isDuck,
      isFifty: p.isFifty,
      isHundred: p.isHundred,
      wickets: p.wickets,
      runsConceded: p.runsConceded,
      ballsBowled: p.ballsBowled,
      isFiveWicketHaul: p.isFiveWicketHaul,
      catches: p.catches + newCatches,
      runOuts: p.runOuts + newRunOuts,
      stumpings: p.stumpings + newStumpings,
      isManOfMatch: p.isManOfMatch,
      isWinner: p.isWinner,
    );
  }

  static MatchPerformance _updateWithMom(MatchPerformance p) {
    return MatchPerformance(
      playerId: p.playerId,
      playerName: p.playerName,
      matchId: p.matchId,
      ballType: p.ballType,
      playedAt: p.playedAt,
      isManOfMatch: true,
      runsScored: p.runsScored,
      ballsFaced: p.ballsFaced,
      fours: p.fours,
      sixes: p.sixes,
      isOut: p.isOut,
      isDuck: p.isDuck,
      isFifty: p.isFifty,
      isHundred: p.isHundred,
      wickets: p.wickets,
      runsConceded: p.runsConceded,
      ballsBowled: p.ballsBowled,
      isFiveWicketHaul: p.isFiveWicketHaul,
      catches: p.catches,
      runOuts: p.runOuts,
      stumpings: p.stumpings,
      isWinner: p.isWinner,
    );
  }
}
