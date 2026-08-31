int _scoreOversToBalls(double overs) {
  final completedOvers = overs.floor();
  final balls = ((overs - completedOvers) * 10).round();
  return (completedOvers * 6) + balls;
}

int _runsChargedToBowlerFromBall(int runs, String? extraType, int extraRuns) {
  if (extraType == 'bye' || extraType == 'leg-bye') return 0;
  return runs + extraRuns;
}

bool _isBowlerCreditedWicketType(String? wicketType) {
  final type = (wicketType ?? '').toLowerCase().replaceAll('-', ' ').trim();
  if (type.contains('run out') || type.contains('retired') || type.contains('obstruct')) {
    return false;
  }
  return true;
}

int _strikeChangeRunsFromBall(BallEvent ball) {
  if (ball.extraType == 'wide') return ball.extraRuns > 0 ? ball.extraRuns - 1 : 0;
  if (ball.extraType == 'bye' || ball.extraType == 'leg-bye') return ball.extraRuns;
  return ball.runs;
}

class MatchModel {
  final String id;
  final String matchName;
  final String? tournamentId;
  final String? tournamentName;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final String ground;
  final String location;
  final String matchType;
  final int oversPerSide;
  final DateTime scheduledDate;
  final String status;
  final int currentInnings;
  final String currentBattingTeam;
  final String bowlingTeam;
  final int currentOver;
  final int currentBall;
  final TeamScore team1Score;
  final TeamScore team2Score;
  final List<BallEvent> ballByBall;
  final MatchResult? result;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Live scoring: Current players on field
  final String? currentStrikerId;
  final String? currentNonStrikerId;
  final String? currentBowlerId;
  
  // Partnership tracking
  final Partnership? currentPartnership;
  final List<Partnership> partnerships;
  
  // Target for 2nd innings
  final int? target;
  
  // Last wicket info
  final LastWicket? lastWicket;

  // Professional Cricket Fields
  final String? tossWinnerId;
  final String? tossDecision;
  final String? team1CaptainId;
  final String? team2CaptainId;
  final String? team1VCId;
  final String? team2VCId;
  final String? team1KeeperId;
  final String? team2KeeperId;

  // Super Over fields
  final bool isSuperOver;
  final int superOverNumber; // Tracks which Super Over (1, 2, 3...)

  final Map<String, TeamScore>? mainMatchScores;

  // Match Format (T20, ODI, Test)
  final String matchFormat; // 'T20', 'ODI', 'Test'
  final List<PowerplayPhase> powerplayConfig;
  
  // Winner Info (Direct Access)
  final String? winnerTeamId;
  final String? winningMarginField; // To distinguish from getter

  // Match Highlights/Badges
  final List<MatchHighlight> highlights;

  // Test Match - Previous Innings Scores
  final TeamScore? team1FirstInningsScore;
  final TeamScore? team2FirstInningsScore;

  // Geo-coordinates for venue (from Google Places)
  final double? latitude;
  final double? longitude;

  // Broadcast
  final bool isBroadcasting;
  final String? activeBroadcastId;
  final String? youtubeLiveUrl;
  final String? youtubeChannelName;
  final String? overlayTheme;
  final bool overlayEnabled;

  const MatchModel({
    required this.id,
    required this.matchName,
    this.tournamentId,
    this.tournamentName,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    required this.ground,
    required this.location,
    required this.matchType,
    required this.oversPerSide,
    required this.scheduledDate,
    required this.status,
    required this.currentInnings,
    required this.currentBattingTeam,
    required this.bowlingTeam,
    required this.currentOver,
    required this.currentBall,
    required this.team1Score,
    required this.team2Score,
    required this.ballByBall,
    this.result,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.currentStrikerId,
    this.currentNonStrikerId,
    this.currentBowlerId,
    this.currentPartnership,
    this.partnerships = const [],
    this.target,
    this.lastWicket,
    this.tossWinnerId,
    this.tossDecision,
    this.team1CaptainId,
    this.team2CaptainId,
    this.team1VCId,
    this.team2VCId,
    this.team1KeeperId,
    this.team2KeeperId,
    this.playerIds = const [],
    this.isSuperOver = false,
    this.superOverNumber = 1,
    this.mainMatchScores,
    this.matchFormat = 'T20',
    this.powerplayConfig = const [],
    this.winnerTeamId,
    this.winningMarginField,
    this.highlights = const [],
    this.team1FirstInningsScore,
    this.team2FirstInningsScore,
    this.latitude,
    this.longitude,
    this.adminIds = const [],
    this.scorerIds = const [],
    this.isBroadcasting = false,
    this.activeBroadcastId,
    this.youtubeLiveUrl,
    this.youtubeChannelName,
    this.overlayTheme,
    this.overlayEnabled = false,
  });

  /// IDs of users who are admins (can edit match, add scorers)
  final List<String> adminIds;

  /// IDs of users who can only score (cannot edit match settings)
  final List<String> scorerIds;

  /// IDs of all players participated in this match (batting/bowling)
  final List<String> playerIds;

  /// Total innings for this format (2 for T20/ODI, 4 for Test)
  int get totalInnings => matchFormat == 'Test' ? 4 : 2;

  /// Whether overs are unlimited (Test cricket)
  bool get isUnlimitedOvers => matchFormat == 'Test' || oversPerSide <= 0;

  /// Current powerplay phase based on current over
  PowerplayPhase? get currentPowerplay {
    if (powerplayConfig.isEmpty) return null;
    final currentScore = currentBattingTeam == 'team1' ? team1Score : team2Score;
    final currentOverNum = currentScore.overs.floor() + 1;
    for (final phase in powerplayConfig) {
      if (currentOverNum >= phase.startOver && currentOverNum <= phase.endOver) {
        return phase;
      }
    }
    return null;
  }
  
  // Helper getters for 2nd innings calculations
  int get runsRequired => target != null && currentInnings == 2 
      ? (target! - (currentBattingTeam == 'team1' ? team1Score.runs : team2Score.runs))
      : 0;
  
  int get ballsRemaining {
    if (currentInnings != 2) return 0;
    if (isUnlimitedOvers) return 0; // No balls remaining concept in Test
    final currentScore = currentBattingTeam == 'team1' ? team1Score : team2Score;
    final totalBalls = oversPerSide * 6;
    final ballsBowled = _scoreOversToBalls(currentScore.overs);
    final remaining = totalBalls - ballsBowled;
    return remaining > 0 ? remaining : 0;
  }
  
  double get requiredRunRate {
    if (currentInnings != 2 || ballsRemaining <= 0) return 0.0;
    return (runsRequired / ballsRemaining) * 6;
  }
  
  double get currentRunRate {
    final currentScore = currentBattingTeam == 'team1' ? team1Score : team2Score;
    final ballsBowled = _scoreOversToBalls(currentScore.overs);
    if (ballsBowled <= 0) return 0.0;
    return currentScore.runs / (ballsBowled / 6.0);
  }

  /// Recalculates the entire match state from the ball-by-ball history.
  /// Useful for correcting errors in past balls.
  MatchModel recalculateFromBallByBall() {
    // 1. Reset scores to initial state
    TeamScore newTeam1Score = team1Score.copyWith(
      runs: 0,
      wickets: 0,
      overs: 0,
      extras: Extras(),
      batters: team1Score.batters.map((b) => b.copyWith(
        runs: 0, balls: 0, fours: 0, sixes: 0, isOut: false, 
        dismissalType: null, dismissedBy: null, bowlerName: null, fielderName: null,
        isPlaying: false, isOnStrike: false,
      )).toList(),
      bowlers: team1Score.bowlers.map((b) => b.copyWith(
        overs: 0, balls: 0, maidens: 0, runs: 0, wickets: 0, wides: 0, noBalls: 0, isBowling: false,
      )).toList(),
    );

    TeamScore newTeam2Score = team2Score.copyWith(
      runs: 0,
      wickets: 0,
      overs: 0,
      extras: Extras(),
      batters: team2Score.batters.map((b) => b.copyWith(
        runs: 0, balls: 0, fours: 0, sixes: 0, isOut: false, 
        dismissalType: null, dismissedBy: null, bowlerName: null, fielderName: null,
        isPlaying: false, isOnStrike: false,
      )).toList(),
      bowlers: team2Score.bowlers.map((b) => b.copyWith(
        overs: 0, balls: 0, maidens: 0, runs: 0, wickets: 0, wides: 0, noBalls: 0, isBowling: false,
      )).toList(),
    );

    int newCurrentOver = 0;
    int newCurrentBall = 0;
    String? strikerId = currentStrikerId;
    String? nonStrikerId = currentNonStrikerId;

  // 2. Process each ball chronologically
    String? lastBattingTeamId;
    for (var ball in ballByBall) {
      bool isTeam1Batting = ball.battingTeam == team1Id;
      String currentBattingTeamId = isTeam1Batting ? team1Id : team2Id;
      
      // Reset over counters when batting team changes (innings change)
      if (lastBattingTeamId != null && lastBattingTeamId != currentBattingTeamId) {
        newCurrentOver = 0;
        newCurrentBall = 0;
      }
      lastBattingTeamId = currentBattingTeamId;
      
      TeamScore battingScore = isTeam1Batting ? newTeam1Score : newTeam2Score;
      TeamScore bowlingScore = isTeam1Batting ? newTeam2Score : newTeam1Score;

      // Update runs and extras
      int totalRuns = ball.runs + ball.extraRuns;
      int bowlerRuns = _runsChargedToBowlerFromBall(ball.runs, ball.extraType, ball.extraRuns);
      bool bowlerGetsWicket = ball.wicket != null && _isBowlerCreditedWicketType(ball.wicket!.type);
      battingScore = battingScore.copyWith(
        runs: battingScore.runs + totalRuns,
        wickets: battingScore.wickets + (ball.wicket != null ? 1 : 0),
        extras: battingScore.extras.copyWith(
          wides: battingScore.extras.wides + (ball.extraType == 'wide' ? ball.extraRuns : 0),
          noBalls: battingScore.extras.noBalls + (ball.extraType == 'no-ball' ? ball.extraRuns : 0),
          byes: battingScore.extras.byes + (ball.extraType == 'bye' ? ball.extraRuns : 0),
          legByes: battingScore.extras.legByes + (ball.extraType == 'leg-bye' ? ball.extraRuns : 0),
        ),
      );

      // Update overs
      if (ball.isLegalBall) {
        newCurrentBall++;
        if (newCurrentBall >= 6) {
          newCurrentOver++;
          newCurrentBall = 0;
          battingScore = battingScore.copyWith(overs: newCurrentOver.toDouble());
        } else {
          battingScore = battingScore.copyWith(overs: newCurrentOver + (newCurrentBall / 10.0));
        }
      }

      // Update individual batter stats
      battingScore = battingScore.copyWith(
        batters: battingScore.batters.map((batter) {
          if (batter.playerId == ball.batsmanId) {
            bool ballFaced = ball.extraType != 'wide' && ball.extraType != 'no-ball';
            bool isOut = ball.wicket != null && ball.wicket!.playerId == batter.playerId;
            return batter.copyWith(
              runs: batter.runs + ball.runs,
              balls: ballFaced ? batter.balls + 1 : batter.balls,
              fours: ball.runs == 4 ? batter.fours + 1 : batter.fours,
              sixes: ball.runs == 6 ? batter.sixes + 1 : batter.sixes,
              isOut: isOut,
              dismissalType: isOut ? ball.wicket!.type : batter.dismissalType,
              dismissedBy: isOut ? ball.wicket!.fielderId : batter.dismissedBy,
              bowlerName: isOut ? ball.bowlerName : batter.bowlerName,
              fielderName: isOut ? ball.wicket!.fielderId : batter.fielderName,
              isPlaying: !isOut,
            );
          } else if (ball.wicket != null && batter.playerId == ball.wicket!.playerId) {
             return batter.copyWith(
                 isOut: true, 
                 dismissalType: ball.wicket!.type, 
                 dismissedBy: ball.wicket!.fielderId,
                 bowlerName: ball.bowlerName,
                 fielderName: ball.wicket!.fielderId,
                 isPlaying: false
             );
          }
          return batter;
        }).toList(),
      );

      // Update individual bowler stats
      bowlingScore = bowlingScore.copyWith(
        bowlers: bowlingScore.bowlers.map((bowler) {
          if (bowler.playerId == ball.bowlerId) {
            int bBalls = bowler.balls;
            int bOvers = bowler.overs;
            if (ball.isLegalBall) {
              bBalls++;
              if (bBalls >= 6) {
                bOvers++;
                bBalls = 0;
              }
            }
            return bowler.copyWith(
              overs: bOvers,
              balls: bBalls,
              runs: bowler.runs + bowlerRuns,
              wickets: bowlerGetsWicket ? bowler.wickets + 1 : bowler.wickets,
              wides: ball.extraType == 'wide' ? bowler.wides + 1 : bowler.wides,
              noBalls: ball.extraType == 'no-ball' ? bowler.noBalls + 1 : bowler.noBalls,
              isBowling: true,
            );
          }
          return bowler;
        }).toList(),
      );

      if (isTeam1Batting) {
        newTeam1Score = battingScore;
        newTeam2Score = bowlingScore;
      } else {
        newTeam2Score = battingScore;
        newTeam1Score = bowlingScore;
      }

      // Update strike rotation (Simplified: we'd need more state for perfect accuracy, 
      // but for basic correction we follow standard rules)
      if (_strikeChangeRunsFromBall(ball).isOdd) {
        String? temp = strikerId;
        strikerId = nonStrikerId;
        nonStrikerId = temp;
      }
    }

    return copyWith(
      team1Score: newTeam1Score,
      team2Score: newTeam2Score,
      currentOver: newCurrentOver,
      currentBall: newCurrentBall,
      currentStrikerId: strikerId,
      currentNonStrikerId: nonStrikerId,
    );
  }

  factory MatchModel.fromMap(Map<String, dynamic> data) {
    return MatchModel(
      id: data['id'] ?? '',
      matchName: data['matchName'] ?? '',
      tournamentId: data['tournamentId'],
      tournamentName: data['tournamentName'],
      team1Id: data['team1Id'] ?? '',
      team2Id: data['team2Id'] ?? '',
      team1Name: data['team1Name'] ?? '',
      team2Name: data['team2Name'] ?? '',
      ground: data['ground'] ?? '',
      location: data['location'] ?? '',
      matchType: data['matchType'] ?? '',
      oversPerSide: data['oversPerSide'] ?? 0,
      scheduledDate: MatchModel._parseDate(data['scheduledDate']),
      status: data['status'] ?? '',
      currentInnings: data['currentInnings'] ?? 0,
      currentBattingTeam: data['currentBattingTeam'] ?? '',
      bowlingTeam: data['bowlingTeam'] ?? '',
      currentOver: data['currentOver'] ?? 0,
      currentBall: data['currentBall'] ?? 0,
      team1Score: TeamScore.fromMap(data['team1Score'] ?? {}),
      team2Score: TeamScore.fromMap(data['team2Score'] ?? {}),
      ballByBall: (data['ballByBall'] as List<dynamic>?)?.map((e) => BallEvent.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      result: data['result'] != null ? MatchResult.fromMap(data['result']) : null,
      createdBy: data['createdBy'] ?? '',
      createdAt: MatchModel._parseDate(data['createdAt']),
      updatedAt: MatchModel._parseDate(data['updatedAt']),
      currentStrikerId: data['currentStrikerId'],
      currentNonStrikerId: data['currentNonStrikerId'],
      currentBowlerId: data['currentBowlerId'],
      currentPartnership: data['currentPartnership'] != null ? Partnership.fromMap(data['currentPartnership']) : null,
      partnerships: (data['partnerships'] as List<dynamic>?)?.map((e) => Partnership.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      target: data['target'],
      lastWicket: data['lastWicket'] != null ? LastWicket.fromMap(data['lastWicket']) : null,
      tossWinnerId: data['tossWinnerId'],
      tossDecision: data['tossDecision'],
      team1CaptainId: data['team1CaptainId'],
      team2CaptainId: data['team2CaptainId'],
      team1VCId: data['team1VCId'],
      team2VCId: data['team2VCId'],
      team1KeeperId: data['team1KeeperId'],
      team2KeeperId: data['team2KeeperId'],
      isSuperOver: data['isSuperOver'] ?? false,
      superOverNumber: data['superOverNumber'] ?? 1,
      mainMatchScores: data['mainMatchScores'] != null 
          ? {
              'team1': TeamScore.fromMap(data['mainMatchScores']['team1'] ?? {}),
              'team2': TeamScore.fromMap(data['mainMatchScores']['team2'] ?? {}),
            }
          : null,
      matchFormat: data['matchFormat'] ?? '',
      powerplayConfig: (data['powerplayConfig'] as List<dynamic>?)?.map((e) => PowerplayPhase.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      winnerTeamId: data['winnerTeamId'],
      winningMarginField: data['winningMarginField'],
      highlights: (data['highlights'] as List<dynamic>?)?.map((e) => MatchHighlight.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      team1FirstInningsScore: data['team1FirstInningsScore'] != null ? TeamScore.fromMap(data['team1FirstInningsScore']) : null,
      team2FirstInningsScore: data['team2FirstInningsScore'] != null ? TeamScore.fromMap(data['team2FirstInningsScore']) : null,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      adminIds: (data['adminIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      scorerIds: (data['scorerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      playerIds: (data['playerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isBroadcasting: data['isBroadcasting'] ?? false,
      activeBroadcastId: data['activeBroadcastId'],
      youtubeLiveUrl: data['youtubeLiveUrl'],
      youtubeChannelName: data['youtubeChannelName'],
      overlayTheme: data['overlayTheme'],
      overlayEnabled: data['overlayEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchName': matchName,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'team1Id': team1Id,
      'team2Id': team2Id,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'ground': ground,
      'location': location,
      'matchType': matchType,
      'oversPerSide': oversPerSide,
      'scheduledDate': scheduledDate.toIso8601String(),
      'status': status,
      'currentInnings': currentInnings,
      'currentBattingTeam': currentBattingTeam,
      'bowlingTeam': bowlingTeam,
      'currentOver': currentOver,
      'currentBall': currentBall,
      'team1Score': team1Score.toMap(),
      'team2Score': team2Score.toMap(),
      'ballByBall': ballByBall.map((e) => e.toMap()).toList(),
      'result': result?.toMap(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'currentStrikerId': currentStrikerId,
      'currentNonStrikerId': currentNonStrikerId,
      'currentBowlerId': currentBowlerId,
      'currentPartnership': currentPartnership?.toMap(),
      'partnerships': partnerships.map((e) => e.toMap()).toList(),
      'target': target,
      'lastWicket': lastWicket?.toMap(),
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'team1CaptainId': team1CaptainId,
      'team2CaptainId': team2CaptainId,
      'team1VCId': team1VCId,
      'team2VCId': team2VCId,
      'team1KeeperId': team1KeeperId,
      'team2KeeperId': team2KeeperId,
      'isSuperOver': isSuperOver,
      'superOverNumber': superOverNumber,
      if (mainMatchScores != null) 'mainMatchScores': {
        'team1': mainMatchScores!['team1']?.toMap() ?? {},
        'team2': mainMatchScores!['team2']?.toMap() ?? {},
      },
      'matchFormat': matchFormat,
      'powerplayConfig': powerplayConfig.map((e) => e.toMap()).toList(),
      'winnerTeamId': winnerTeamId,
      'winningMarginField': winningMarginField,
      'highlights': highlights.map((e) => e.toMap()).toList(),
      'team1FirstInningsScore': team1FirstInningsScore?.toMap(),
      'team2FirstInningsScore': team2FirstInningsScore?.toMap(),
      'latitude': latitude,
      'longitude': longitude,
      'adminIds': adminIds,
      'scorerIds': scorerIds,
      'playerIds': playerIds,
      'isBroadcasting': isBroadcasting,
      'activeBroadcastId': activeBroadcastId,
      'youtubeLiveUrl': youtubeLiveUrl,
      'youtubeChannelName': youtubeChannelName,
      'overlayTheme': overlayTheme,
      'overlayEnabled': overlayEnabled,
    };
  }

  MatchModel copyWith({
    String? id,
    String? matchName,
    String? tournamentId,
    String? tournamentName,
    String? team1Id,
    String? team2Id,
    String? team1Name,
    String? team2Name,
    String? ground,
    String? location,
    String? matchType,
    int? oversPerSide,
    DateTime? scheduledDate,
    String? status,
    int? currentInnings,
    String? currentBattingTeam,
    String? bowlingTeam,
    int? currentOver,
    int? currentBall,
    TeamScore? team1Score,
    TeamScore? team2Score,
    List<BallEvent>? ballByBall,
    MatchResult? result,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currentStrikerId,
    String? currentNonStrikerId,
    String? currentBowlerId,
    Partnership? currentPartnership,
    List<Partnership>? partnerships,
    int? target,
    LastWicket? lastWicket,
    String? tossWinnerId,
    String? tossDecision,
    String? team1CaptainId,
    String? team2CaptainId,
    String? team1VCId,
    String? team2VCId,
    String? team1KeeperId,
    String? team2KeeperId,
    bool? isSuperOver,
    int? superOverNumber,
    Map<String, TeamScore>? mainMatchScores,
    String? matchFormat,
    List<PowerplayPhase>? powerplayConfig,
    String? winnerTeamId,
    String? winningMarginField,
    List<MatchHighlight>? highlights,
    TeamScore? team1FirstInningsScore,
    TeamScore? team2FirstInningsScore,
    double? latitude,
    double? longitude,
    List<String>? adminIds,
    List<String>? scorerIds,
    List<String>? playerIds,
    String? youtubeLiveUrl,
    String? youtubeChannelName,
    String? overlayTheme,
    bool? overlayEnabled,
  }) {
    return MatchModel(
      id: id ?? this.id,
      matchName: matchName ?? this.matchName,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      team1Id: team1Id ?? this.team1Id,
      team2Id: team2Id ?? this.team2Id,
      team1Name: team1Name ?? this.team1Name,
      team2Name: team2Name ?? this.team2Name,
      ground: ground ?? this.ground,
      location: location ?? this.location,
      matchType: matchType ?? this.matchType,
      oversPerSide: oversPerSide ?? this.oversPerSide,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      currentInnings: currentInnings ?? this.currentInnings,
      currentBattingTeam: currentBattingTeam ?? this.currentBattingTeam,
      bowlingTeam: bowlingTeam ?? this.bowlingTeam,
      currentOver: currentOver ?? this.currentOver,
      currentBall: currentBall ?? this.currentBall,
      team1Score: team1Score ?? this.team1Score,
      team2Score: team2Score ?? this.team2Score,
      ballByBall: ballByBall ?? this.ballByBall,
      result: result ?? this.result,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentStrikerId: currentStrikerId ?? this.currentStrikerId,
      currentNonStrikerId: currentNonStrikerId ?? this.currentNonStrikerId,
      currentBowlerId: currentBowlerId ?? this.currentBowlerId,
      currentPartnership: currentPartnership ?? this.currentPartnership,
      partnerships: partnerships ?? this.partnerships,
      target: target ?? this.target,
      lastWicket: lastWicket ?? this.lastWicket,
      tossWinnerId: tossWinnerId ?? this.tossWinnerId,
      tossDecision: tossDecision ?? this.tossDecision,
      team1CaptainId: team1CaptainId ?? this.team1CaptainId,
      team2CaptainId: team2CaptainId ?? this.team2CaptainId,
      team1VCId: team1VCId ?? this.team1VCId,
      team2VCId: team2VCId ?? this.team2VCId,
      team1KeeperId: team1KeeperId ?? this.team1KeeperId,
      team2KeeperId: team2KeeperId ?? this.team2KeeperId,
      isSuperOver: isSuperOver ?? this.isSuperOver,
      superOverNumber: superOverNumber ?? this.superOverNumber,
      mainMatchScores: mainMatchScores ?? this.mainMatchScores,
      matchFormat: matchFormat ?? this.matchFormat,
      powerplayConfig: powerplayConfig ?? this.powerplayConfig,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      winningMarginField: winningMarginField ?? this.winningMarginField,
      highlights: highlights ?? this.highlights,
      team1FirstInningsScore: team1FirstInningsScore ?? this.team1FirstInningsScore,
      team2FirstInningsScore: team2FirstInningsScore ?? this.team2FirstInningsScore,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      adminIds: adminIds ?? this.adminIds,
      scorerIds: scorerIds ?? this.scorerIds,
      playerIds: playerIds ?? this.playerIds,
      youtubeLiveUrl: youtubeLiveUrl ?? this.youtubeLiveUrl,
      youtubeChannelName: youtubeChannelName ?? this.youtubeChannelName,
      overlayTheme: overlayTheme ?? this.overlayTheme,
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
    );
  }

  static MatchModel empty() {
    return MatchModel(
      id: '',
      matchName: '',
      team1Id: '',
      team2Id: '',
      team1Name: '',
      team2Name: '',
      ground: '',
      location: '',
      matchType: '',
      oversPerSide: 0,
      scheduledDate: DateTime.now(),
      status: '',
      currentInnings: 0,
      currentBattingTeam: '',
      bowlingTeam: '',
      currentOver: 0,
      currentBall: 0,
      team1Score: TeamScore.empty(),
      team2Score: TeamScore.empty(),
      ballByBall: [],
      createdBy: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      partnerships: [],
      isSuperOver: false,
      superOverNumber: 1,
      matchFormat: '',
      powerplayConfig: [],
      highlights: [],
      adminIds: [],
      scorerIds: [],
      playerIds: [],
    );
  }

  String? get winnerTeam {
    if (winnerTeamId == null) {
      if (result != null && result!.winner.isNotEmpty) {
        return result!.winner;
      }
      return null;
    }
    if (winnerTeamId == team1Id) return team1Name;
    if (winnerTeamId == team2Id) return team2Name;
    if (winnerTeamId == 'tied' || winnerTeamId == 'Match Tied') return 'Match Tied';
    return winnerTeamId;
  }

  String get winningMargin {
    if (winningMarginField != null && winningMarginField!.isNotEmpty) {
      return winningMarginField!;
    }
    if (result != null && result!.margin.isNotEmpty) {
      return result!.margin;
    }
    return '';
  }

  static Map<String, dynamic> getFormatDefaults(String format) {
    switch (format) {
      case 'T20':
        return {
          'overs': 20,
          'powerplay': [
            const PowerplayPhase(name: 'Powerplay', startOver: 1, endOver: 6, maxFieldersOutside: 2),
            const PowerplayPhase(name: 'Middle/Death Overs', startOver: 7, endOver: 20, maxFieldersOutside: 5),
          ],
        };
      case 'ODI':
        return {
          'overs': 50,
          'powerplay': [
            const PowerplayPhase(name: 'Powerplay 1', startOver: 1, endOver: 10, maxFieldersOutside: 2),
            const PowerplayPhase(name: 'Powerplay 2', startOver: 11, endOver: 40, maxFieldersOutside: 4),
            const PowerplayPhase(name: 'Powerplay 3', startOver: 41, endOver: 50, maxFieldersOutside: 5),
          ],
        };
      case 'Test':
        return {
          'overs': 90,
          'powerplay': <PowerplayPhase>[],
        };
      default:
        return {
          'overs': 20,
          'powerplay': <PowerplayPhase>[],
        };
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    
    // Handle Firestore Timestamp dynamically
    try {
      if (value.runtimeType.toString() == 'Timestamp') {
        final int seconds = value.seconds as int;
        final int nanoseconds = value.nanoseconds as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + (nanoseconds / 1000000).round());
      }
    } catch (_) {}

    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

/// Team score tracking
class TeamScore {
  final int runs;
  final int wickets;
  final double overs;
  final List<BatterStats> batters;
  final List<BowlerStats> bowlers;
  final Extras extras;

  const TeamScore({
    this.runs = 0,
    this.wickets = 0,
    this.overs = 0.0,
    this.batters = const [],
    this.bowlers = const [],
    this.extras = const Extras(),
  });

  static TeamScore empty() {
    return const TeamScore();
  }

  factory TeamScore.fromMap(Map<String, dynamic> data) {
    return TeamScore(
      runs: data['runs'] ?? 0,
      wickets: data['wickets'] ?? 0,
      overs: (data['overs'] ?? 0.0).toDouble(),
      batters: (data['batters'] as List<dynamic>?)
              ?.map((e) => BatterStats.fromMap(e as Map<String, dynamic>))
              .toList() ?? [],
      bowlers: (data['bowlers'] as List<dynamic>?)
              ?.map((e) => BowlerStats.fromMap(e as Map<String, dynamic>))
              .toList() ?? [],
      extras: data['extras'] != null 
          ? Extras.fromMap(data['extras']) 
          : Extras(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'runs': runs,
      'wickets': wickets,
      'overs': overs,
      'batters': batters.map((e) => e.toMap()).toList(),
      'bowlers': bowlers.map((e) => e.toMap()).toList(),
      'extras': extras.toMap(),
    };
  }
  
  TeamScore copyWith({
    int? runs,
    int? wickets,
    double? overs,
    List<BatterStats>? batters,
    List<BowlerStats>? bowlers,
    Extras? extras,
  }) {
    return TeamScore(
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      overs: overs ?? this.overs,
      batters: batters ?? this.batters,
      bowlers: bowlers ?? this.bowlers,
      extras: extras ?? this.extras,
    );
  }

  String get oversDisplay {
    int wholeOvers = overs.floor();
    int balls = ((overs - wholeOvers) * 10).round();
    return '$wholeOvers.$balls';
  }

}

/// Individual batter statistics for a match
class BatterStats {
  final String playerId;
  final String playerName;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool isOut;
  final String? dismissalType;
  final String? dismissedBy;
  final String? bowlerName;
  final String? fielderName;
  final bool isOnStrike;
  final bool isPlaying;

  BatterStats({
    required this.playerId,
    required this.playerName,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalType,
    this.dismissedBy,
    this.bowlerName,
    this.fielderName,
    this.isOnStrike = false,
    this.isPlaying = false,
  });

  double get strikeRate => balls > 0 ? (runs / balls) * 100 : 0.0;

  String get dismissalString {
    if (!isOut) return isPlaying ? "not out" : "yet to bat";
    
    String type = (dismissalType ?? '').toLowerCase().trim();
    String by = (dismissedBy ?? '').trim(); 
    String fielder = (fielderName ?? '').trim();
    String bowler = (bowlerName ?? '').trim(); 

    // FALLBACK: If specific fields are empty, try to use 'dismissedBy'
    if (fielder.isEmpty && (type.contains('caught') || type.contains('run out') || type.contains('stumped'))) {
       fielder = by;
    }
    // For bowler, we only use 'by' if it's NOT a fielder-involved dismissal OR if we know 'by' refers to bowler
    if (bowler.isEmpty && (type.contains('bowled') || type.contains('lbw') || type.contains('hit wicket'))) {
       bowler = by;
    }
    
    // Logic for "c Fielder b Bowler" when we only have fielder (legacy)
    // If we have fielder but no bowler, we can return "c Fielder" (or "c Fielder b Unknown"?)
    // Cricbuzz usually shows "c Fielder b Bowler". If bowler missing, maybe just "c Fielder".

    if (type.contains('caught and bowled') || (type.contains('caught') && fielder == bowler && fielder.isNotEmpty)) {
      return "c & b $bowler";
    }
    
    if (type.contains('caught') || type == 'c' || type == 'catch') {
      if (fielder.isNotEmpty && bowler.isNotEmpty) {
        return "c $fielder b $bowler";
      }
      if (fielder.isNotEmpty) {
         return "c $fielder"; // Better than "caught"
      }
      if (bowler.isNotEmpty) {
        return "c unknown b $bowler"; 
      }
      return "caught";
    } 
    
    if (type.contains('bowled') || type == 'b') {
      return "b $bowler";
    } 
    
    if (type.contains('lbw')) {
      return "lbw b $bowler";
    } 
    
    if (type.contains('run out') || type == 'ro') {
      if (fielder.isNotEmpty) {
        return "run out ($fielder)";
      }
      return "run out";
    } 
    
    if (type.contains('stumped') || type == 'st') {
       if (fielder.isNotEmpty && bowler.isNotEmpty) {
        return "st $fielder b $bowler";
      }
      if (fielder.isNotEmpty) return "st $fielder";
      if (bowler.isNotEmpty) return "st unknown b $bowler";
      return "stumped";
    } 
    
    if (type.contains('hit wicket')) {
      return "hit wicket b $bowler";
    } 
    
    if (type.contains('retired')) {
      return "retired hurt";
    }
    
    // Absolute fallback
    if (by.isNotEmpty) return "$type $by";
    return type.isNotEmpty ? type : "out";
  }

  factory BatterStats.fromMap(Map<String, dynamic> data) {
    return BatterStats(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      runs: data['runs'] ?? 0,
      balls: data['balls'] ?? 0,
      fours: data['fours'] ?? 0,
      sixes: data['sixes'] ?? 0,
      isOut: data['isOut'] ?? false,
      dismissalType: data['dismissalType'],
      dismissedBy: data['dismissedBy'],
      bowlerName: data['bowlerName'],
      fielderName: data['fielderName'],
      isOnStrike: data['isOnStrike'] ?? false,
      isPlaying: data['isPlaying'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'runs': runs,
      'balls': balls,
      'fours': fours,
      'sixes': sixes,
      'isOut': isOut,
      'dismissalType': dismissalType,
      'dismissedBy': dismissedBy,
      'bowlerName': bowlerName,
      'fielderName': fielderName,
      'isOnStrike': isOnStrike,
      'isPlaying': isPlaying,
    };
  }
  
  BatterStats copyWith({
    String? playerId,
    String? playerName,
    int? runs,
    int? balls,
    int? fours,
    int? sixes,
    bool? isOut,
    String? dismissalType,
    String? dismissedBy,
    String? bowlerName,
    String? fielderName,
    bool? isOnStrike,
    bool? isPlaying,
  }) {
    return BatterStats(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      runs: runs ?? this.runs,
      balls: balls ?? this.balls,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      isOut: isOut ?? this.isOut,
      dismissalType: dismissalType ?? this.dismissalType,
      dismissedBy: dismissedBy ?? this.dismissedBy,
      bowlerName: bowlerName ?? this.bowlerName,
      fielderName: fielderName ?? this.fielderName,
      isOnStrike: isOnStrike ?? this.isOnStrike,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Individual bowler statistics for a match
class BowlerStats {
  final String playerId;
  final String playerName;
  final int overs;
  final int balls;
  final int maidens;
  final int runs;
  final int wickets;
  final int wides;
  final int noBalls;
  final bool isBowling;

  BowlerStats({
    required this.playerId,
    required this.playerName,
    this.overs = 0,
    this.balls = 0,
    this.maidens = 0,
    this.runs = 0,
    this.wickets = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.isBowling = false,
  });

  double get economy {
    final ballsBowled = (overs * 6) + balls;
    return ballsBowled > 0 ? runs / (ballsBowled / 6.0) : 0.0;
  }
  String get oversDisplay => '$overs.${balls % 6}';

  factory BowlerStats.fromMap(Map<String, dynamic> data) {
    return BowlerStats(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      overs: data['overs'] ?? 0,
      balls: data['balls'] ?? 0,
      maidens: data['maidens'] ?? 0,
      runs: data['runs'] ?? 0,
      wickets: data['wickets'] ?? 0,
      wides: data['wides'] ?? 0,
      noBalls: data['noBalls'] ?? 0,
      isBowling: data['isBowling'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'overs': overs,
      'balls': balls,
      'maidens': maidens,
      'runs': runs,
      'wickets': wickets,
      'wides': wides,
      'noBalls': noBalls,
      'isBowling': isBowling,
    };
  }
  
  BowlerStats copyWith({
    String? playerId,
    String? playerName,
    int? overs,
    int? balls,
    int? maidens,
    int? runs,
    int? wickets,
    int? wides,
    int? noBalls,
    bool? isBowling,
  }) {
    return BowlerStats(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      overs: overs ?? this.overs,
      balls: balls ?? this.balls,
      maidens: maidens ?? this.maidens,
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
      isBowling: isBowling ?? this.isBowling,
    );
  }
}

class BallEvent {
  final int ballNumber;
  final int overNumber;
  final String battingTeam;
  final String bowlerId;
  final String bowlerName;
  final String batsmanId;
  final String batsmanName;
  final int runs; // Runs scored by batsman
  final int extraRuns; // Extra runs (wide runs, no-ball runs, byes, leg byes)
  final String? extraType; // 'wide', 'no-ball', 'bye', 'leg-bye', null for normal
  final Wicket? wicket;
  final String commentary;
  final DateTime timestamp;
  final bool isLegalBall; // False for wides and no-balls

  BallEvent({
    required this.ballNumber,
    required this.overNumber,
    required this.battingTeam,
    required this.bowlerId,
    this.bowlerName = '',
    required this.batsmanId,
    this.batsmanName = '',
    required this.runs,
    this.extraRuns = 0,
    this.extraType,
    this.wicket,
    required this.commentary,
    required this.timestamp,
    bool? isLegalBall,
  }) : isLegalBall = isLegalBall ?? (extraType != 'wide' && extraType != 'no-ball');

  /// Total runs for this ball (batsman runs + extra runs)
  int get totalRuns => runs + extraRuns;

  /// Display string for the ball (e.g., "WD+1", "NB+2", "4", "W", "LB+1")
  String get displayString {
    if (wicket != null && extraType == null) return 'W';
    
    String base = '';
    switch (extraType) {
      case 'wide':
        base = 'WD';
        break;
      case 'no-ball':
        base = 'NB';
        break;
      case 'bye':
        base = 'B';
        break;
      case 'leg-bye':
        base = 'LB';
        break;
      default:
        if (wicket != null) return 'W';
        return runs.toString();
    }
    
    // For extras, show the extra run count
    int displayRuns = extraType == 'wide' || extraType == 'no-ball' 
        ? extraRuns  // WD shows penalty (1) + additional runs
        : runs + extraRuns; // Byes show total
    
    if (displayRuns > 1 || (extraType == 'wide' && extraRuns > 1) || (extraType == 'no-ball' && extraRuns > 1)) {
      return '$base+${displayRuns > 1 ? displayRuns - (extraType == "wide" || extraType == "no-ball" ? 1 : 0) : ""}';
    }
    return base;
  }

  factory BallEvent.fromMap(Map<String, dynamic> data) {
    return BallEvent(
      ballNumber: data['ballNumber'] ?? 0,
      overNumber: data['overNumber'] ?? 0,
      battingTeam: data['battingTeam'] ?? '',
      bowlerId: data['bowlerId'] ?? '',
      bowlerName: data['bowlerName'] ?? '',
      batsmanId: data['batsmanId'] ?? '',
      batsmanName: data['batsmanName'] ?? '',
      runs: data['runs'] ?? 0,
      extraRuns: data['extraRuns'] ?? 0,
      extraType: data['extraType'] ?? data['extras'], // Support old 'extras' field
      wicket: data['wicket'] != null ? Wicket.fromMap(data['wicket']) : null,
      commentary: data['commentary'] ?? '',
      timestamp: MatchModel._parseDate(data['timestamp']),
      isLegalBall: data['isLegalBall'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ballNumber': ballNumber,
      'overNumber': overNumber,
      'battingTeam': battingTeam,
      'bowlerId': bowlerId,
      'bowlerName': bowlerName,
      'batsmanId': batsmanId,
      'batsmanName': batsmanName,
      'runs': runs,
      'extraRuns': extraRuns,
      'extraType': extraType,
      'wicket': wicket?.toMap(),
      'commentary': commentary,
      'timestamp': timestamp.toIso8601String(),
      'isLegalBall': isLegalBall,
    };
  }
}


class Wicket {
  final String type;
  final String playerId;
  final String? fielderId;

  Wicket({required this.type, required this.playerId, this.fielderId});

  factory Wicket.fromMap(Map<String, dynamic> data) {
    return Wicket(
      type: data['type'] ?? '',
      playerId: data['playerId'] ?? '',
      fielderId: data['fielderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type, 'playerId': playerId, 'fielderId': fielderId};
  }
}

class MatchResult {
  final String winner;
  final String margin;
  final String manOfMatch;

  MatchResult({
    required this.winner,
    required this.margin,
    required this.manOfMatch,
  });

  factory MatchResult.fromMap(Map<String, dynamic> data) {
    return MatchResult(
      winner: data['winner'] ?? '',
      margin: data['margin'] ?? '',
      manOfMatch: data['manOfMatch'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'winner': winner, 'margin': margin, 'manOfMatch': manOfMatch};
  }
}

/// Partnership between two batters
class Partnership {
  final String batter1Id;
  final String batter1Name;
  final String batter2Id;
  final String batter2Name;
  final int runs;
  final int balls;
  final int batter1Runs;
  final int batter1Balls;
  final int batter2Runs;
  final int batter2Balls;
  final bool isActive;
  final int wicketNumber; // Which wicket this partnership is for (1st, 2nd, etc.)

  Partnership({
    required this.batter1Id,
    required this.batter1Name,
    required this.batter2Id,
    required this.batter2Name,
    this.runs = 0,
    this.balls = 0,
    this.batter1Runs = 0,
    this.batter1Balls = 0,
    this.batter2Runs = 0,
    this.batter2Balls = 0,
    this.isActive = true,
    this.wicketNumber = 1,
  });

  double get batter1Contribution => runs > 0 ? (batter1Runs / runs) * 100 : 0;
  double get batter2Contribution => runs > 0 ? (batter2Runs / runs) * 100 : 0;

  factory Partnership.fromMap(Map<String, dynamic> data) {
    return Partnership(
      batter1Id: data['batter1Id'] ?? '',
      batter1Name: data['batter1Name'] ?? '',
      batter2Id: data['batter2Id'] ?? '',
      batter2Name: data['batter2Name'] ?? '',
      runs: data['runs'] ?? 0,
      balls: data['balls'] ?? 0,
      batter1Runs: data['batter1Runs'] ?? 0,
      batter1Balls: data['batter1Balls'] ?? 0,
      batter2Runs: data['batter2Runs'] ?? 0,
      batter2Balls: data['batter2Balls'] ?? 0,
      isActive: data['isActive'] ?? true,
      wicketNumber: data['wicketNumber'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batter1Id': batter1Id,
      'batter1Name': batter1Name,
      'batter2Id': batter2Id,
      'batter2Name': batter2Name,
      'runs': runs,
      'balls': balls,
      'batter1Runs': batter1Runs,
      'batter1Balls': batter1Balls,
      'batter2Runs': batter2Runs,
      'batter2Balls': batter2Balls,
      'isActive': isActive,
      'wicketNumber': wicketNumber,
    };
  }

  Partnership copyWith({
    String? batter1Id,
    String? batter1Name,
    String? batter2Id,
    String? batter2Name,
    int? runs,
    int? balls,
    int? batter1Runs,
    int? batter1Balls,
    int? batter2Runs,
    int? batter2Balls,
    bool? isActive,
    int? wicketNumber,
  }) {
    return Partnership(
      batter1Id: batter1Id ?? this.batter1Id,
      batter1Name: batter1Name ?? this.batter1Name,
      batter2Id: batter2Id ?? this.batter2Id,
      batter2Name: batter2Name ?? this.batter2Name,
      runs: runs ?? this.runs,
      balls: balls ?? this.balls,
      batter1Runs: batter1Runs ?? this.batter1Runs,
      batter1Balls: batter1Balls ?? this.batter1Balls,
      batter2Runs: batter2Runs ?? this.batter2Runs,
      batter2Balls: batter2Balls ?? this.batter2Balls,
      isActive: isActive ?? this.isActive,
      wicketNumber: wicketNumber ?? this.wicketNumber,
    );
  }
}

/// Last wicket information for display
class LastWicket {
  final String playerName;
  final String playerId;
  final int runs;
  final int balls;
  final String dismissalType;
  final String? bowlerName;
  final String? fielderName;
  final int teamScore; // Score at fall of wicket
  final int wicketNumber;
  final double overs;

  LastWicket({
    required this.playerName,
    required this.playerId,
    required this.runs,
    required this.balls,
    required this.dismissalType,
    this.bowlerName,
    this.fielderName,
    required this.teamScore,
    required this.wicketNumber,
    required this.overs,
  });

  /// Returns formatted dismissal string like "c Bumrah b Archer"
  String get dismissalString {
    switch (dismissalType.toLowerCase()) {
      case 'caught':
        return 'c ${fielderName ?? ''} b ${bowlerName ?? ''}';
      case 'bowled':
        return 'b ${bowlerName ?? ''}';
      case 'lbw':
        return 'lbw b ${bowlerName ?? ''}';
      case 'stumped':
        return 'st ${fielderName ?? ''} b ${bowlerName ?? ''}';
      case 'run out':
        return 'run out (${fielderName ?? ''})';
      case 'hit wicket':
        return 'hit wicket b ${bowlerName ?? ''}';
      case 'retired':
        return 'retired hurt';
      default:
        return dismissalType;
    }
  }

  factory LastWicket.fromMap(Map<String, dynamic> data) {
    return LastWicket(
      playerName: data['playerName'] ?? '',
      playerId: data['playerId'] ?? '',
      runs: data['runs'] ?? 0,
      balls: data['balls'] ?? 0,
      dismissalType: data['dismissalType'] ?? '',
      bowlerName: data['bowlerName'],
      fielderName: data['fielderName'],
      teamScore: data['teamScore'] ?? 0,
      wicketNumber: data['wicketNumber'] ?? 0,
      overs: (data['overs'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerName': playerName,
      'playerId': playerId,
      'runs': runs,
      'balls': balls,
      'dismissalType': dismissalType,
      'bowlerName': bowlerName,
      'fielderName': fielderName,
      'teamScore': teamScore,
      'wicketNumber': wicketNumber,
      'overs': overs,
    };
  }
}

/// Extras breakdown for detailed scoring
class Extras {
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final int penalty;

  const Extras({
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.penalty = 0,
  });

  int get total => wides + noBalls + byes + legByes + penalty;

  factory Extras.fromMap(Map<String, dynamic> data) {
    return Extras(
      wides: data['wides'] ?? 0,
      noBalls: data['noBalls'] ?? 0,
      byes: data['byes'] ?? 0,
      legByes: data['legByes'] ?? 0,
      penalty: data['penalty'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wides': wides,
      'noBalls': noBalls,
      'byes': byes,
      'legByes': legByes,
      'penalty': penalty,
    };
  }

  Extras copyWith({
    int? wides,
    int? noBalls,
    int? byes,
    int? legByes,
    int? penalty,
  }) {
    return Extras(
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
      byes: byes ?? this.byes,
      legByes: legByes ?? this.legByes,
      penalty: penalty ?? this.penalty,
    );
  }
}

/// Powerplay Phase configuration
class PowerplayPhase {
  final String name; // 'Powerplay 1', 'Powerplay 2', 'Death Overs', 'New Ball', etc.
  final int startOver;
  final int endOver;
  final int maxFieldersOutside; // Max fielders outside 30-yard circle
  final String? description;

  const PowerplayPhase({
    required this.name,
    required this.startOver,
    required this.endOver,
    this.maxFieldersOutside = 5,
    this.description,
  });

  factory PowerplayPhase.fromMap(Map<String, dynamic> data) {
    return PowerplayPhase(
      name: data['name'] ?? '',
      startOver: data['startOver'] ?? 1,
      endOver: data['endOver'] ?? 20,
      maxFieldersOutside: data['maxFieldersOutside'] ?? 5,
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startOver': startOver,
      'endOver': endOver,
      'maxFieldersOutside': maxFieldersOutside,
      'description': description,
    };
  }
}

class MatchHighlight {
  final String id;
  final String imageUrl;
  final String type; // 'win', 'fifty', 'century', 'wicket'
  final String title;
  final String description;
  final String? playerId;
  final String? playerName;
  final DateTime createdAt;

  const MatchHighlight({
    required this.id,
    required this.imageUrl,
    required this.type,
    required this.title,
    required this.description,
    this.playerId,
    this.playerName,
    required this.createdAt,
  });

  factory MatchHighlight.fromMap(Map<String, dynamic> data) {
    return MatchHighlight(
      id: data['id'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      playerId: data['playerId'],
      playerName: data['playerName'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is int ? DateTime.fromMillisecondsSinceEpoch(data['createdAt']) : DateTime.parse(data['createdAt'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'type': type,
      'title': title,
      'description': description,
      'playerId': playerId,
      'playerName': playerName,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

