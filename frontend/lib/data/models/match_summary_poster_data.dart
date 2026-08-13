import 'match_model.dart';

/// Read-only data class that extracts poster-ready content from a MatchModel.
/// This NEVER mutates match data — it is purely a presentation layer.
class MatchSummaryPosterData {
  final String matchTitle;
  final String? tournamentName;
  final DateTime date;
  final String ground;
  final String location;
  final String matchFormat;

  // Team info
  final String team1Name;
  final String team2Name;
  final String team1Id;
  final String team2Id;

  // Main match scores (NOT super over)
  final TeamScore team1Score;
  final TeamScore team2Score;

  // Multi-innings (Test cricket)
  final TeamScore? team1FirstInningsScore;
  final TeamScore? team2FirstInningsScore;

  // Top performers from the MAIN match
  final List<TopBatterData> team1TopBatters;
  final List<TopBatterData> team2TopBatters;
  final List<TopBowlerData> team1TopBowlers;
  final List<TopBowlerData> team2TopBowlers;

  // Man of the Match
  final String manOfMatchName;
  final String manOfMatchTeam;
  final TopBatterData? manOfMatchBatting;
  final TopBowlerData? manOfMatchBowling;

  // Result
  final String resultText;
  final String? winnerTeamName;

  // Super Over (separate from main match)
  final bool hadSuperOver;
  final TeamScore? superOverTeam1Score;
  final TeamScore? superOverTeam2Score;

  // Partnerships
  final List<Partnership> partnerships;

  // Overs per side
  final int oversPerSide;

  const MatchSummaryPosterData({
    required this.matchTitle,
    this.tournamentName,
    required this.date,
    required this.ground,
    required this.location,
    required this.matchFormat,
    required this.team1Name,
    required this.team2Name,
    required this.team1Id,
    required this.team2Id,
    required this.team1Score,
    required this.team2Score,
    this.team1FirstInningsScore,
    this.team2FirstInningsScore,
    required this.team1TopBatters,
    required this.team2TopBatters,
    required this.team1TopBowlers,
    required this.team2TopBowlers,
    required this.manOfMatchName,
    required this.manOfMatchTeam,
    this.manOfMatchBatting,
    this.manOfMatchBowling,
    required this.resultText,
    this.winnerTeamName,
    required this.hadSuperOver,
    this.superOverTeam1Score,
    this.superOverTeam2Score,
    required this.partnerships,
    required this.oversPerSide,
  });

  /// Extract poster data from a completed MatchModel.
  /// Super over statistics are kept separate from main match top performers.
  factory MatchSummaryPosterData.fromMatch(MatchModel match) {
    // Determine main match scores (if super over happened, use mainMatchScores)
    final TeamScore mainTeam1Score;
    final TeamScore mainTeam2Score;
    final bool hadSuperOver;

    if (match.isSuperOver && match.mainMatchScores != null) {
      // Current scores are super over; main match is in mainMatchScores
      mainTeam1Score = match.mainMatchScores!['team1'] ?? match.team1Score;
      mainTeam2Score = match.mainMatchScores!['team2'] ?? match.team2Score;
      hadSuperOver = true;
    } else {
      mainTeam1Score = match.team1Score;
      mainTeam2Score = match.team2Score;
      hadSuperOver = false;
    }

    // Extract top batters from MAIN match (combine both innings)
    final allBatters = <TopBatterData>[];
    for (final batter in mainTeam1Score.batters) {
      if (batter.runs > 0 || batter.balls > 0) {
        allBatters.add(TopBatterData(
          playerName: batter.playerName,
          playerId: batter.playerId,
          teamName: match.team1Name,
          runs: batter.runs,
          balls: batter.balls,
          fours: batter.fours,
          sixes: batter.sixes,
          strikeRate: batter.strikeRate,
          isOut: batter.isOut,
        ));
      }
    }
    for (final batter in mainTeam2Score.batters) {
      if (batter.runs > 0 || batter.balls > 0) {
        allBatters.add(TopBatterData(
          playerName: batter.playerName,
          playerId: batter.playerId,
          teamName: match.team2Name,
          runs: batter.runs,
          balls: batter.balls,
          fours: batter.fours,
          sixes: batter.sixes,
          strikeRate: batter.strikeRate,
          isOut: batter.isOut,
        ));
      }
    }
    // Sort by runs descending, then by strike rate
    allBatters.sort((a, b) {
      final runComp = b.runs.compareTo(a.runs);
      if (runComp != 0) return runComp;
      return b.strikeRate.compareTo(a.strikeRate);
    });

    // Extract top bowlers from MAIN match
    final allBowlers = <TopBowlerData>[];
    // Team1's bowlers bowl to team2, and vice versa
    for (final bowler in mainTeam1Score.bowlers) {
      if (bowler.wickets > 0 || bowler.runs > 0) {
        allBowlers.add(TopBowlerData(
          playerName: bowler.playerName,
          playerId: bowler.playerId,
          teamName: match.team1Name,
          wickets: bowler.wickets,
          runsConceded: bowler.runs,
          overs: bowler.overs,
          balls: bowler.balls,
          maidens: bowler.maidens,
          economy: bowler.economy,
        ));
      }
    }
    for (final bowler in mainTeam2Score.bowlers) {
      if (bowler.wickets > 0 || bowler.runs > 0) {
        allBowlers.add(TopBowlerData(
          playerName: bowler.playerName,
          playerId: bowler.playerId,
          teamName: match.team2Name,
          wickets: bowler.wickets,
          runsConceded: bowler.runs,
          overs: bowler.overs,
          balls: bowler.balls,
          maidens: bowler.maidens,
          economy: bowler.economy,
        ));
      }
    }
    // Sort: most wickets first, then best economy
    allBowlers.sort((a, b) {
      final wicketComp = b.wickets.compareTo(a.wickets);
      if (wicketComp != 0) return wicketComp;
      if (a.economy == 0 && b.economy == 0) return 0;
      if (a.economy == 0) return 1;
      if (b.economy == 0) return -1;
      return a.economy.compareTo(b.economy);
    });

    // Build result text
    final resultText = _buildResultText(match, hadSuperOver);

    // Determine winner team name
    final winnerTeamName = match.winnerTeam;

    // Man of the Match
    final momName = match.result?.manOfMatch ?? '';
    String momTeam = '';
    TopBatterData? momBatting;
    TopBowlerData? momBowling;

    if (momName.isNotEmpty) {
      // Find MOM in batters
      final momBatter = allBatters.where(
        (b) => b.playerName.toLowerCase() == momName.toLowerCase(),
      );
      if (momBatter.isNotEmpty) {
        momBatting = momBatter.first;
        momTeam = momBatter.first.teamName;
      }
      // Find MOM in bowlers
      final momBowler = allBowlers.where(
        (b) => b.playerName.toLowerCase() == momName.toLowerCase(),
      );
      if (momBowler.isNotEmpty) {
        momBowling = momBowler.first;
        if (momTeam.isEmpty) momTeam = momBowler.first.teamName;
      }
    }

    // Super over scores (current scores when isSuperOver is true)
    TeamScore? soTeam1;
    TeamScore? soTeam2;
    if (hadSuperOver) {
      soTeam1 = match.team1Score;
      soTeam2 = match.team2Score;
    }

    return MatchSummaryPosterData(
      matchTitle: match.matchName,
      tournamentName: match.tournamentName,
      date: match.scheduledDate,
      ground: match.ground,
      location: match.location,
      matchFormat: match.matchFormat,
      team1Name: match.team1Name,
      team2Name: match.team2Name,
      team1Id: match.team1Id,
      team2Id: match.team2Id,
      team1Score: mainTeam1Score,
      team2Score: mainTeam2Score,
      team1FirstInningsScore: match.team1FirstInningsScore,
      team2FirstInningsScore: match.team2FirstInningsScore,
      team1TopBatters: allBatters.where((b) => b.teamName == match.team1Name).take(3).toList(),
      team2TopBatters: allBatters.where((b) => b.teamName == match.team2Name).take(3).toList(),
      team1TopBowlers: allBowlers.where((b) => b.teamName == match.team1Name).take(3).toList(),
      team2TopBowlers: allBowlers.where((b) => b.teamName == match.team2Name).take(3).toList(),
      manOfMatchName: momName,
      manOfMatchTeam: momTeam,
      manOfMatchBatting: momBatting,
      manOfMatchBowling: momBowling,
      resultText: resultText,
      winnerTeamName: winnerTeamName,
      hadSuperOver: hadSuperOver,
      superOverTeam1Score: soTeam1,
      superOverTeam2Score: soTeam2,
      partnerships: match.partnerships,
      oversPerSide: match.oversPerSide,
    );
  }

  static String _buildResultText(MatchModel match, bool hadSuperOver) {
    final winner = match.winnerTeam;
    final margin = match.winningMargin;

    if (winner == null || winner.isEmpty) {
      return 'MATCH COMPLETED';
    }

    if (winner.toLowerCase().contains('tied') ||
        winner.toLowerCase().contains('tie') ||
        winner.toLowerCase().contains('draw')) {
      return 'MATCH TIED';
    }

    if (hadSuperOver) {
      return '${winner.toUpperCase()} WON IN SUPER OVER';
    }

    if (margin.isNotEmpty) {
      return '${winner.toUpperCase()} WON BY ${margin.toUpperCase()}';
    }

    return '${winner.toUpperCase()} WON';
  }
}

/// Top batter data for the poster
class TopBatterData {
  final String playerName;
  final String playerId;
  final String teamName;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final bool isOut;

  const TopBatterData({
    required this.playerName,
    required this.playerId,
    required this.teamName,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    required this.isOut,
  });

  String get scoreDisplay => '$runs ($balls)';
  String get detailDisplay => '4s: $fours | 6s: $sixes | SR: ${strikeRate.toStringAsFixed(2)}';
}

/// Top bowler data for the poster
class TopBowlerData {
  final String playerName;
  final String playerId;
  final String teamName;
  final int wickets;
  final int runsConceded;
  final int overs;
  final int balls;
  final int maidens;
  final double economy;

  const TopBowlerData({
    required this.playerName,
    required this.playerId,
    required this.teamName,
    required this.wickets,
    required this.runsConceded,
    required this.overs,
    required this.balls,
    required this.maidens,
    required this.economy,
  });

  String get figuresDisplay => '$wickets/$runsConceded';
  String get oversDisplay => '$overs.${balls % 6}';
  String get detailDisplay => '$oversDisplay ov | Econ: ${economy.toStringAsFixed(2)}';
}
