

class MatchPerformance {
  final String playerId;
  final String playerName;
  final String matchId;
  final String ballType; // 'tennis' or 'leather'
  
  // Batting
  final int runsScored;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final bool isOut;
  final bool isDuck;
  final bool isFifty;
  final bool isHundred;
  
  // Bowling
  final int wickets;
  final int runsConceded;
  final int ballsBowled;
  final bool isFiveWicketHaul;
  
  // Fielding
  final int catches;
  final int runOuts;
  final int stumpings;
  final int directHits;
  
  // Others
  final bool isManOfMatch;
  final bool isWinner;
  final DateTime playedAt;

  MatchPerformance({
    required this.playerId,
    required this.playerName,
    required this.matchId,
    required this.ballType,
    this.runsScored = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.isDuck = false,
    this.isFifty = false,
    this.isHundred = false,
    this.wickets = 0,
    this.runsConceded = 0,
    this.ballsBowled = 0,
    this.isFiveWicketHaul = false,
    this.catches = 0,
    this.runOuts = 0,
    this.stumpings = 0,
    this.directHits = 0,
    this.isManOfMatch = false,
    this.isWinner = false,
    DateTime? playedAt,
  }) : playedAt = playedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'matchId': matchId,
      'ballType': ballType,
      'runsScored': runsScored,
      'ballsFaced': ballsFaced,
      'fours': fours,
      'sixes': sixes,
      'isOut': isOut,
      'isDuck': isDuck,
      'isFifty': isFifty,
      'isHundred': isHundred,
      'wickets': wickets,
      'runsConceded': runsConceded,
      'ballsBowled': ballsBowled,
      'isFiveWicketHaul': isFiveWicketHaul,
      'catches': catches,
      'runOuts': runOuts,
      'stumpings': stumpings,
      'directHits': directHits,
      'isManOfMatch': isManOfMatch,
      'isWinner': isWinner,
      'playedAt': playedAt.toIso8601String(),
    };
  }
}
