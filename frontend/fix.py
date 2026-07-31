import re

with open('lib/presentation/providers/scoring_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """    } else {
    return (List.of(phrases)..shuffle()).first;
  }"""

replacement = """    } else {
      // Runs
      if (runs == 0) {
        result = _getRandomCommentary(_dotBallPhrases);
      } else if (runs == 1) {
        result = _getRandomCommentary(_singlePhrases);
      } else if (runs == 2) {
        result = _getRandomCommentary(_twoRunPhrases);
      } else if (runs == 3) {
        result = _getRandomCommentary(_threeRunPhrases);
      } else if (runs == 4) {
        result = _getRandomCommentary(_fourPhrases);
      } else if (runs == 6) {
        result = _getRandomCommentary(_sixPhrases);
      } else {
        result = "\$runs runs";
      }
    }

    return "\$prefix\$result";
  }

  /// Calculate Man of the Match from WINNING TEAM only
  String _calculateManOfMatch(MatchModel match, String? winnerTeamId) {
    if (winnerTeamId == null || winnerTeamId.isEmpty) return '';

    // Identify winning team score
    TeamScore winningTeamScore;
    if (match.team1Id == winnerTeamId) {
      winningTeamScore = match.isSuperOver && match.mainMatchScores != null
          ? match.mainMatchScores!['team1']!
          : match.team1Score;
    } else if (match.team2Id == winnerTeamId) {
      winningTeamScore = match.isSuperOver && match.mainMatchScores != null
          ? match.mainMatchScores!['team2']!
          : match.team2Score;
    } else {
      return ''; // Should not happen
    }

    String bestPlayerName = '';
    double maxPoints = -1;

    // Check Batters
    for (var b in winningTeamScore.batters) {
      double points = (b.runs * 1.0) + (b.fours * 1) + (b.sixes * 2);
      if (points > maxPoints) {
        maxPoints = points;
        bestPlayerName = b.playerName;
      }
    }

    // Check Bowlers (weighted more for impact)
    for (var b in winningTeamScore.bowlers) {
      double points = (b.wickets * 20.0) + (b.maidens * 10);
      if (points > maxPoints) {
        maxPoints = points;
        bestPlayerName = b.playerName;
      }
    }

    return bestPlayerName;
  }

  // --- Realistic Commentary Phrases ---

  String _getRandomCommentary(List<String> phrases) {
    return (List.of(phrases)..shuffle()).first;
  }"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/presentation/providers/scoring_provider.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('SUCCESS')
else:
    print('TARGET NOT FOUND')
