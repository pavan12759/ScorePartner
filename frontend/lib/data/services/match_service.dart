import 'dart:async';
import '../models/match_model.dart';

/// Mock Match Service - No backend required
/// Uses in-memory storage with sample data
class MatchService {
  // Singleton
  static final MatchService _instance = MatchService._internal();

  factory MatchService() {
    return _instance;
  }

  MatchService._internal() {
    _initializeMockData();
  }

  // Mock storage
  final Map<String, MatchModel> _mockMatches = {};
  final StreamController<List<MatchModel>> _matchesController =
      StreamController<List<MatchModel>>.broadcast();

  void _initializeMockData() {
    // Sample batters for live match
    final team1Batters = [
      BatterStats(
        playerId: 'p1',
        playerName: 'Rohit Sharma',
        runs: 45,
        balls: 32,
        fours: 4,
        sixes: 2,
        isOut: false,
        isOnStrike: true,
        isPlaying: true,
      ),
      BatterStats(
        playerId: 'p2',
        playerName: 'Virat Kohli',
        runs: 28,
        balls: 21,
        fours: 3,
        sixes: 1,
        isOut: false,
        isOnStrike: false,
        isPlaying: true,
      ),
      BatterStats(
        playerId: 'p3',
        playerName: 'KL Rahul',
        runs: 15,
        balls: 12,
        fours: 2,
        sixes: 0,
        isOut: true,
        dismissalType: 'caught',
        dismissedBy: 'J Bumrah',
        isOnStrike: false,
        isPlaying: false,
      ),
    ];

    final team2Bowlers = [
      BowlerStats(
        playerId: 'b1',
        playerName: 'Jasprit Bumrah',
        overs: 4,
        balls: 0,
        maidens: 1,
        runs: 22,
        wickets: 2,
        wides: 1,
        noBalls: 0,
        isBowling: false,
      ),
      BowlerStats(
        playerId: 'b2',
        playerName: 'Mohammed Shami',
        overs: 3,
        balls: 3,
        maidens: 0,
        runs: 28,
        wickets: 1,
        wides: 2,
        noBalls: 1,
        isBowling: true,
      ),
    ];

    // Sample ball events
    final sampleBallEvents = [
      BallEvent(
        ballNumber: 1,
        overNumber: 12,
        battingTeam: 'team_1',
        bowlerId: 'b2',
        bowlerName: 'Mohammed Shami',
        batsmanId: 'p1',
        batsmanName: 'Rohit Sharma',
        runs: 1,
        commentary: '1 run taken',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      BallEvent(
        ballNumber: 2,
        overNumber: 12,
        battingTeam: 'team_1',
        bowlerId: 'b2',
        bowlerName: 'Mohammed Shami',
        batsmanId: 'p2',
        batsmanName: 'Virat Kohli',
        runs: 4,
        commentary: 'Four runs to the boundary!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      BallEvent(
        ballNumber: 3,
        overNumber: 12,
        battingTeam: 'team_1',
        bowlerId: 'b2',
        bowlerName: 'Mohammed Shami',
        batsmanId: 'p2',
        batsmanName: 'Virat Kohli',
        runs: 0,
        commentary: 'Dot ball',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ];

    // Current partnership
    final currentPartnership = Partnership(
      batter1Id: 'p1',
      batter1Name: 'Rohit Sharma',
      batter2Id: 'p2',
      batter2Name: 'Virat Kohli',
      runs: 42,
      balls: 28,
      batter1Runs: 25,
      batter1Balls: 15,
      batter2Runs: 17,
      batter2Balls: 13,
      isActive: true,
      wicketNumber: 2,
    );

    // Last wicket info
    final lastWicket = LastWicket(
      playerName: 'KL Rahul',
      playerId: 'p3',
      runs: 15,
      balls: 12,
      dismissalType: 'caught',
      bowlerName: 'Jasprit Bumrah',
      fielderName: 'Ravindra Jadeja',
      teamScore: 56,
      wicketNumber: 2,
      overs: 8.3,
    );

    // Add sample matches
    final sampleMatches = [
      MatchModel(
        id: 'match_1',
        matchName: 'Warriors vs Eagles',
        tournamentId: '',
        team1Id: 'team_1',
        team2Id: 'team_2',
        team1Name: 'Warriors',
        team2Name: 'Eagles',
        ground: 'Central Park Ground',
        location: 'Mumbai',
        matchType: 'T20',
        oversPerSide: 20,
        scheduledDate: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'live',
        currentInnings: 1,
        currentBattingTeam: 'team_1',
        bowlingTeam: 'team_2',
        currentOver: 12,
        currentBall: 3,
        team1Score: TeamScore(
          runs: 98,
          wickets: 2,
          overs: 12.3,
          batters: team1Batters,
          extras: Extras(wides: 3, noBalls: 1, byes: 0, legByes: 2),
        ),
        team2Score: TeamScore(
          runs: 0,
          wickets: 0,
          overs: 0,
          bowlers: team2Bowlers,
        ),
        ballByBall: sampleBallEvents,
        result: null,
        createdBy: 'user_1',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now(),
        currentStrikerId: 'p1',
        currentNonStrikerId: 'p2',
        currentBowlerId: 'b2',
        currentPartnership: currentPartnership,
        partnerships: [
          Partnership(
            batter1Id: 'p3',
            batter1Name: 'KL Rahul',
            batter2Id: 'p1',
            batter2Name: 'Rohit Sharma',
            runs: 56,
            balls: 42,
            batter1Runs: 15,
            batter1Balls: 12,
            batter2Runs: 41,
            batter2Balls: 30,
            isActive: false,
            wicketNumber: 1,
          ),
        ],
        lastWicket: lastWicket,
      ),
      MatchModel(
        id: 'match_2',
        matchName: 'Tigers vs Lions',
        tournamentId: '',
        team1Id: 'team_3',
        team2Id: 'team_4',
        team1Name: 'Tigers',
        team2Name: 'Lions',
        ground: 'Royal Stadium',
        location: 'Delhi',
        matchType: 'T10',
        oversPerSide: 10,
        scheduledDate: DateTime.now().add(const Duration(hours: 2)),
        status: 'scheduled',
        currentInnings: 0,
        currentBattingTeam: '',
        bowlingTeam: '',
        currentOver: 0,
        currentBall: 0,
        team1Score: TeamScore(runs: 0, wickets: 0, overs: 0),
        team2Score: TeamScore(runs: 0, wickets: 0, overs: 0),
        ballByBall: [],
        result: null,
        createdBy: 'user_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // 2nd innings chase match
      MatchModel(
        id: 'match_4',
        matchName: 'Royals vs Kings',
        tournamentId: '',
        team1Id: 'team_7',
        team2Id: 'team_8',
        team1Name: 'Royals',
        team2Name: 'Kings',
        ground: 'National Stadium',
        location: 'Kolkata',
        matchType: 'T20',
        oversPerSide: 20,
        scheduledDate: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'live',
        currentInnings: 2,
        currentBattingTeam: 'team_8',
        bowlingTeam: 'team_7',
        currentOver: 15,
        currentBall: 2,
        team1Score: TeamScore(runs: 178, wickets: 6, overs: 20.0),
        team2Score: TeamScore(
          runs: 132,
          wickets: 4,
          overs: 15.2,
          batters: [
            BatterStats(
              playerId: 'p10',
              playerName: 'David Warner',
              runs: 58,
              balls: 38,
              fours: 6,
              sixes: 2,
              isOut: false,
              isOnStrike: true,
              isPlaying: true,
            ),
            BatterStats(
              playerId: 'p11',
              playerName: 'Steve Smith',
              runs: 32,
              balls: 28,
              fours: 3,
              sixes: 0,
              isOut: false,
              isOnStrike: false,
              isPlaying: true,
            ),
          ],
        ),
        ballByBall: [],
        result: null,
        createdBy: 'user_1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now(),
        target: 179,
        currentPartnership: Partnership(
          batter1Id: 'p10',
          batter1Name: 'David Warner',
          batter2Id: 'p11',
          batter2Name: 'Steve Smith',
          runs: 65,
          balls: 48,
          batter1Runs: 38,
          batter1Balls: 25,
          batter2Runs: 27,
          batter2Balls: 23,
          isActive: true,
          wicketNumber: 4,
        ),
      ),
      MatchModel(
        id: 'match_3',
        matchName: 'Strikers vs Blazers',
        tournamentId: '',
        team1Id: 'team_5',
        team2Id: 'team_6',
        team1Name: 'Strikers',
        team2Name: 'Blazers',
        ground: 'City Cricket Ground',
        location: 'Hyderabad',
        matchType: 'T20',
        oversPerSide: 20,
        scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
        status: 'completed',
        currentInnings: 2,
        currentBattingTeam: 'team_6',
        bowlingTeam: 'team_5',
        currentOver: 18,
        currentBall: 4,
        team1Score: TeamScore(runs: 156, wickets: 4, overs: 20.0),
        team2Score: TeamScore(runs: 142, wickets: 8, overs: 18.4),
        ballByBall: [],
        result: MatchResult(
          winner: 'Strikers',
          margin: 'Won by 14 runs',
          manOfMatch: 'Virat Singh',
        ),
        createdBy: 'user_1',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 20)),
      ),
    ];

    for (var match in sampleMatches) {
      _mockMatches[match.id] = match;
    }
  }

  // Create new match
  Future<String> createMatch(MatchModel match) async {
    final id = 'match_${DateTime.now().millisecondsSinceEpoch}';
    final newMatch = MatchModel(
      id: id,
      matchName: match.matchName,
      tournamentId: match.tournamentId,
      team1Id: match.team1Id,
      team2Id: match.team2Id,
      team1Name: match.team1Name,
      team2Name: match.team2Name,
      ground: match.ground,
      location: match.location,
      matchType: match.matchType,
      oversPerSide: match.oversPerSide,
      scheduledDate: match.scheduledDate,
      status: match.status,
      currentInnings: match.currentInnings,
      currentBattingTeam: match.currentBattingTeam,
      bowlingTeam: match.bowlingTeam,
      currentOver: match.currentOver,
      currentBall: match.currentBall,
      team1Score: match.team1Score,
      team2Score: match.team2Score,
      ballByBall: match.ballByBall,
      result: match.result,
      createdBy: match.createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockMatches[id] = newMatch;
    _notifyListeners();
    return id;
  }

  // Get match by ID
  Future<MatchModel?> getMatchById(String matchId) async {
    return _mockMatches[matchId];
  }

  // Get match stream (Realtime simulation)
  Stream<MatchModel> getMatchStream(String matchId) {
    return Stream.periodic(const Duration(seconds: 2), (i) {
      return _mockMatches[matchId]!;
    }).where((m) => _mockMatches.containsKey(matchId));
  }

  // Update match
  Future<void> updateMatch(MatchModel match) async {
    _mockMatches[match.id] = match;
    _notifyListeners();
  }

  // Add ball event to match
  Future<void> addBallEvent(String matchId, BallEvent ballEvent) async {
    final match = _mockMatches[matchId];
    if (match != null) {
      final newBallByBall = List<BallEvent>.from(match.ballByBall)..add(ballEvent);
      _mockMatches[matchId] = MatchModel(
        id: match.id,
        matchName: match.matchName,
        tournamentId: match.tournamentId,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        ground: match.ground,
        location: match.location,
        matchType: match.matchType,
        oversPerSide: match.oversPerSide,
        scheduledDate: match.scheduledDate,
        status: match.status,
        currentInnings: match.currentInnings,
        currentBattingTeam: match.currentBattingTeam,
        bowlingTeam: match.bowlingTeam,
        currentOver: match.currentOver,
        currentBall: match.currentBall,
        team1Score: match.team1Score,
        team2Score: match.team2Score,
        ballByBall: newBallByBall,
        result: match.result,
        createdBy: match.createdBy,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        currentStrikerId: match.currentStrikerId,
        currentNonStrikerId: match.currentNonStrikerId,
        currentBowlerId: match.currentBowlerId,
        currentPartnership: match.currentPartnership,
        partnerships: match.partnerships,
        target: match.target,
        lastWicket: match.lastWicket,
      );
      _notifyListeners();
    }
  }

  // Update live match score
  Future<void> updateLiveScore(
    String matchId, {
    required int currentOver,
    required int currentBall,
    required TeamScore battingTeamScore,
    required TeamScore bowlingTeamScore,
    String? currentBattingTeam,
    String? bowlingTeam,
  }) async {
    final match = _mockMatches[matchId];
    if (match != null) {
      final isTeam1Batting = (currentBattingTeam ?? match.currentBattingTeam) == 'team_1';
      
      _mockMatches[matchId] = MatchModel(
        id: match.id,
        matchName: match.matchName,
        tournamentId: match.tournamentId,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        ground: match.ground,
        location: match.location,
        matchType: match.matchType,
        oversPerSide: match.oversPerSide,
        scheduledDate: match.scheduledDate,
        status: match.status,
        currentInnings: match.currentInnings,
        currentBattingTeam: currentBattingTeam ?? match.currentBattingTeam,
        bowlingTeam: bowlingTeam ?? match.bowlingTeam,
        currentOver: currentOver,
        currentBall: currentBall,
        team1Score: isTeam1Batting ? battingTeamScore : bowlingTeamScore,
        team2Score: isTeam1Batting ? bowlingTeamScore : battingTeamScore,
        ballByBall: match.ballByBall,
        result: match.result,
        createdBy: match.createdBy,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        currentStrikerId: match.currentStrikerId,
        currentNonStrikerId: match.currentNonStrikerId,
        currentBowlerId: match.currentBowlerId,
        currentPartnership: match.currentPartnership,
        partnerships: match.partnerships,
        target: match.target,
        lastWicket: match.lastWicket,
      );
      _notifyListeners();
    }
  }

  // Update current players on field
  Future<void> updateCurrentPlayers(
    String matchId, {
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
  }) async {
    final match = _mockMatches[matchId];
    if (match != null) {
      _mockMatches[matchId] = MatchModel(
        id: match.id,
        matchName: match.matchName,
        tournamentId: match.tournamentId,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        ground: match.ground,
        location: match.location,
        matchType: match.matchType,
        oversPerSide: match.oversPerSide,
        scheduledDate: match.scheduledDate,
        status: match.status,
        currentInnings: match.currentInnings,
        currentBattingTeam: match.currentBattingTeam,
        bowlingTeam: match.bowlingTeam,
        currentOver: match.currentOver,
        currentBall: match.currentBall,
        team1Score: match.team1Score,
        team2Score: match.team2Score,
        ballByBall: match.ballByBall,
        result: match.result,
        createdBy: match.createdBy,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        currentStrikerId: strikerId ?? match.currentStrikerId,
        currentNonStrikerId: nonStrikerId ?? match.currentNonStrikerId,
        currentBowlerId: bowlerId ?? match.currentBowlerId,
        currentPartnership: match.currentPartnership,
        partnerships: match.partnerships,
        target: match.target,
        lastWicket: match.lastWicket,
      );
      _notifyListeners();
    }
  }

  // Update partnership
  Future<void> updatePartnership(String matchId, Partnership partnership) async {
    final match = _mockMatches[matchId];
    if (match != null) {
      _mockMatches[matchId] = MatchModel(
        id: match.id,
        matchName: match.matchName,
        tournamentId: match.tournamentId,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        ground: match.ground,
        location: match.location,
        matchType: match.matchType,
        oversPerSide: match.oversPerSide,
        scheduledDate: match.scheduledDate,
        status: match.status,
        currentInnings: match.currentInnings,
        currentBattingTeam: match.currentBattingTeam,
        bowlingTeam: match.bowlingTeam,
        currentOver: match.currentOver,
        currentBall: match.currentBall,
        team1Score: match.team1Score,
        team2Score: match.team2Score,
        ballByBall: match.ballByBall,
        result: match.result,
        createdBy: match.createdBy,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        currentStrikerId: match.currentStrikerId,
        currentNonStrikerId: match.currentNonStrikerId,
        currentBowlerId: match.currentBowlerId,
        currentPartnership: partnership,
        partnerships: match.partnerships,
        target: match.target,
        lastWicket: match.lastWicket,
      );
      _notifyListeners();
    }
  }

  // Record wicket with last wicket info
  Future<void> recordWicket(String matchId, LastWicket lastWicket, Partnership? newPartnership) async {
    final match = _mockMatches[matchId];
    if (match != null) {
      // Add current partnership to history
      final updatedPartnerships = List<Partnership>.from(match.partnerships);
      if (match.currentPartnership != null) {
        updatedPartnerships.add(match.currentPartnership!.copyWith(isActive: false));
      }
      
      _mockMatches[matchId] = MatchModel(
        id: match.id,
        matchName: match.matchName,
        tournamentId: match.tournamentId,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        ground: match.ground,
        location: match.location,
        matchType: match.matchType,
        oversPerSide: match.oversPerSide,
        scheduledDate: match.scheduledDate,
        status: match.status,
        currentInnings: match.currentInnings,
        currentBattingTeam: match.currentBattingTeam,
        bowlingTeam: match.bowlingTeam,
        currentOver: match.currentOver,
        currentBall: match.currentBall,
        team1Score: match.team1Score,
        team2Score: match.team2Score,
        ballByBall: match.ballByBall,
        result: match.result,
        createdBy: match.createdBy,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        currentStrikerId: match.currentStrikerId,
        currentNonStrikerId: match.currentNonStrikerId,
        currentBowlerId: match.currentBowlerId,
        currentPartnership: newPartnership,
        partnerships: updatedPartnerships,
        target: match.target,
        lastWicket: lastWicket,
      );
      _notifyListeners();
    }
  }

  // Complete match with result
  Future<void> completeMatch(String matchId, MatchResult result) async {
    final match = _mockMatches[matchId];
    if (match != null) {
      _mockMatches[matchId] = MatchModel(
        id: match.id,
        matchName: match.matchName,
        tournamentId: match.tournamentId,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        ground: match.ground,
        location: match.location,
        matchType: match.matchType,
        oversPerSide: match.oversPerSide,
        scheduledDate: match.scheduledDate,
        status: 'completed',
        currentInnings: match.currentInnings,
        currentBattingTeam: match.currentBattingTeam,
        bowlingTeam: match.bowlingTeam,
        currentOver: match.currentOver,
        currentBall: match.currentBall,
        team1Score: match.team1Score,
        team2Score: match.team2Score,
        ballByBall: match.ballByBall,
        result: result,
        createdBy: match.createdBy,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        currentStrikerId: match.currentStrikerId,
        currentNonStrikerId: match.currentNonStrikerId,
        currentBowlerId: match.currentBowlerId,
        currentPartnership: match.currentPartnership,
        partnerships: match.partnerships,
        target: match.target,
        lastWicket: match.lastWicket,
      );
      _notifyListeners();
    }
  }

  // Get live matches
  Future<List<MatchModel>> getLiveMatches() async {
    return _mockMatches.values.where((m) => m.status == 'live').toList();
  }

  // Get upcoming matches
  Future<List<MatchModel>> getUpcomingMatches() async {
    return _mockMatches.values.where((m) => m.status == 'scheduled').toList();
  }

  // Get user's matches
  Stream<List<MatchModel>> getUserMatches(String userId) {
    return _matchesController.stream.map(
      (matches) => matches.where((m) => m.createdBy == userId).toList(),
    );
  }

  // Search matches
  Future<List<MatchModel>> searchMatches(String query) async {
    final lowerQuery = query.toLowerCase();
    return _mockMatches.values
        .where((m) =>
            m.team1Name.toLowerCase().contains(lowerQuery) ||
            m.team2Name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Delete match
  Future<void> deleteMatch(String matchId) async {
    _mockMatches.remove(matchId);
    _notifyListeners();
  }

  void _notifyListeners() {
    _matchesController.add(_mockMatches.values.toList());
  }

  void dispose() {
    _matchesController.close();
  }
}
