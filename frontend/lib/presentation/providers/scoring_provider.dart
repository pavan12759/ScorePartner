import 'package:flutter/foundation.dart';
import '../../data/models/match_model.dart';
import '../../data/models/team_model.dart';
import '../../data/services/firebase_data_service.dart';
import '../../data/services/commentary_service.dart';
import '../../data/services/socket_service.dart';
import '../../data/services/stats_service.dart';

class ScoringProvider extends ChangeNotifier {
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  final CommentaryService _commentaryService = CommentaryService();
  final SocketService _socketService = SocketService();
  final StatsService _statsService = StatsService(); 
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Current player tracking
  String? _currentStrikerId;
  String? _currentNonStrikerId;
  String? _currentBowlerId;
  String? _lastOverBowlerId; // Track who bowled last over
  
  // Undo stack
  final List<BallEvent> _undoStack = [];
  final List<Map<String, dynamic>> _undoStateStack = [];
  static const int _maxUndoItems = 10;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentStrikerId => _currentStrikerId;
  String? get currentNonStrikerId => _currentNonStrikerId;
  String? get currentBowlerId => _currentBowlerId;
  String? get lastOverBowlerId => _lastOverBowlerId;
  bool get canUndo => _undoStack.isNotEmpty;
  int get undoStackSize => _undoStack.length;

  /// Initialize socket connection
  void initializeSocket({String? serverUrl}) {
    _socketService.connect(serverUrl: serverUrl ?? 'http://127.0.0.1:5000');
  }

  /// Join a match for real-time updates
  void joinMatch(String matchId) {
    _socketService.joinMatch(matchId);
  }

  /// Leave a match
  void leaveMatch(String matchId) {
    _socketService.leaveMatch(matchId);
  }

  int _runsChargedToBowler(int runs, String? extraType, int extraRuns) {
    if (extraType == 'bye' || extraType == 'leg-bye') return 0;
    return runs + extraRuns;
  }

  bool _isBowlerCreditedWicket(String? wicketType) {
    final type = (wicketType ?? '').toLowerCase().replaceAll('-', ' ').trim();
    if (type.contains('run out') || type.contains('retired') || type.contains('obstruct')) {
      return false;
    }
    return true;
  }

  int _strikeChangeRuns(int runs, String? extraType, int extraRuns) {
    if (extraType == 'wide') return extraRuns > 0 ? extraRuns - 1 : 0;
    if (extraType == 'bye' || extraType == 'leg-bye') return extraRuns;
    return runs;
  }

  /// Score a ball with full extras support
  Future<void> scoreBall(MatchModel match, {
    required int runs,
    String? extraType,
    int extraRuns = 0,
    bool isWicket = false,
    String? wicketType,
    String? playerOutId,
    String? fielderId,
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
    bool crossed = false,
  }) async {
    if (_isLoading) return;
    // Validation: Check if match is already finished or innings complete
    final isTeam1BattingDirect = match.currentBattingTeam == 'team1';
    final currentScoreActive = isTeam1BattingDirect ? match.team1Score : match.team2Score;
    
    final maxWicketsActive = match.isSuperOver
        ? 2
        : (currentScoreActive.batters.length > 1 ? currentScoreActive.batters.length - 1 : 10);
    bool isAllOutActive = currentScoreActive.wickets >= maxWicketsActive;
    bool areOversCompleteActive = match.oversPerSide > 0 && currentScoreActive.overs >= match.oversPerSide;
    bool targetReachedActive = match.currentInnings == 2 &&
        match.target != null &&
        currentScoreActive.runs >= match.target!;
    
    if (match.status == 'completed' || isAllOutActive || areOversCompleteActive || targetReachedActive) {
      _errorMessage = "Innings/Match already completed. Cannot score more balls.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Use provided IDs or fallback to tracked IDs
      final actualStrikerId = strikerId ?? _currentStrikerId ?? match.currentStrikerId ?? 'striker_placeholder';
      final actualNonStrikerId = nonStrikerId ?? _currentNonStrikerId ?? match.currentNonStrikerId ?? 'non_striker_placeholder';
      final actualBowlerId = bowlerId ?? _currentBowlerId ?? match.currentBowlerId ?? 'bowler_placeholder';

      if (_currentStrikerId == null && actualStrikerId != 'striker_placeholder') {
        _currentStrikerId = actualStrikerId;
      }
      if (_currentNonStrikerId == null && actualNonStrikerId != 'non_striker_placeholder') {
        _currentNonStrikerId = actualNonStrikerId;
      }
      if (_currentBowlerId == null && actualBowlerId != 'bowler_placeholder') {
        _currentBowlerId = actualBowlerId;
      }
      
      // Calculate total runs for this ball
      int totalRuns = runs + extraRuns;
      int bowlerRuns = _runsChargedToBowler(runs, extraType, extraRuns);
      bool bowlerGetsWicket = isWicket && _isBowlerCreditedWicket(wicketType);
      int completedRunsForStrike = _strikeChangeRuns(runs, extraType, extraRuns);
      
      // Determine if ball is legal
      bool isLegalBall = extraType != 'wide' && extraType != 'no-ball';
      
      bool isTeam1Batting = match.currentBattingTeam == 'team1';
      TeamScore currentScore = isTeam1Batting ? match.team1Score : match.team2Score;
      TeamScore bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;

      // Save state for undo
      _saveStateForUndo(match, currentScore, bowlingScore);

      // Update runs and wickets
      int newRuns = currentScore.runs + totalRuns;
      int newWickets = currentScore.wickets + (isWicket ? 1 : 0);
      
      // Update extras breakdown
      Extras newExtras = currentScore.extras.copyWith(
        wides: currentScore.extras.wides + (extraType == 'wide' ? extraRuns : 0),
        noBalls: currentScore.extras.noBalls + (extraType == 'no-ball' ? extraRuns : 0),
        byes: currentScore.extras.byes + (extraType == 'bye' ? extraRuns : 0),
        legByes: currentScore.extras.legByes + (extraType == 'leg-bye' ? extraRuns : 0),
      );
      
      // Update overs
      double newOvers = currentScore.overs;
      int currentOver = match.currentOver;
      int currentBall = match.currentBall;

      if (isLegalBall) {
        currentBall++;
        if (currentBall >= 6) {
          currentOver++;
          currentBall = 0;
          newOvers = currentOver.toDouble();
        } else {
          newOvers = currentOver + (currentBall / 10.0);
        }
      }

      // ============ HANDLE STRIKE ROTATION (BEFORE SAVING) ============
      
      // 1. Swap for odd completed runs
      if (completedRunsForStrike.isOdd) {
        _swapStrike();
      }
      
      // 2. Swap for wicket crossing
      if (isWicket && crossed) {
        _swapStrike();
      }
      
      // 3. Swap at end of over
      if (isLegalBall && currentBall == 0) {
        _swapStrike();
      }

      // ============ UPDATE INDIVIDUAL BATTER STATS ============
      String batterName = '';
      String bowlerName = '';
      
      List<BatterStats> updatedBatters = currentScore.batters.map((batter) {
        if (batter.playerId == actualStrikerId) {
          batterName = batter.playerName;
          // Update striker's stats
          bool ballFaced = extraType != 'wide' && extraType != 'no-ball';
          bool isOut = isWicket && (playerOutId == actualStrikerId || playerOutId == null);
          
          return batter.copyWith(
            runs: batter.runs + runs, // Add runs scored by bat (not extras)
            balls: ballFaced ? batter.balls + 1 : batter.balls,
            fours: runs == 4 ? batter.fours + 1 : batter.fours,
            sixes: runs == 6 ? batter.sixes + 1 : batter.sixes,
            isOut: isOut,
            dismissalType: isOut ? wicketType : batter.dismissalType,
            isPlaying: !isOut,
            isOnStrike: !isOut && batter.playerId == _currentStrikerId,
          );
          
          // Check for milestones (logic omitted for brevity in map, handled elsewhere if needed or just side-effect?)
          // actually the milestones check was just a side comment in previous code, no logic. 
        } else if (batter.playerId == actualNonStrikerId) {
          // Check if non-striker is out (e.g. run out)
          bool isOut = isWicket && playerOutId == actualNonStrikerId;
          return batter.copyWith(
            isOut: isOut,
            dismissalType: isOut ? wicketType : batter.dismissalType,
            isPlaying: !isOut,
            isOnStrike: !isOut && batter.playerId == _currentStrikerId,
          );
        }
        return batter.copyWith(isOnStrike: batter.playerId == _currentStrikerId);
      }).toList();
      
      // If no batter found with that ID, set default name
      if (batterName.isEmpty) {
        batterName = 'Batsman';
      }
      
      // ============ UPDATE INDIVIDUAL BOWLER STATS ============
      List<BowlerStats> updatedBowlers = bowlingScore.bowlers.map((bowler) {
        if (bowler.playerId == actualBowlerId) {
          bowlerName = bowler.playerName;
          // Update bowler's stats
          int newBowlerBalls = bowler.balls;
          int newBowlerOvers = bowler.overs;
          
          if (isLegalBall) {
            newBowlerBalls++;
            if (newBowlerBalls >= 6) {
              newBowlerOvers++;
              newBowlerBalls = 0;
            }
          }
          
          return bowler.copyWith(
            overs: newBowlerOvers,
            balls: newBowlerBalls,
            runs: bowler.runs + bowlerRuns,
            wickets: bowlerGetsWicket ? bowler.wickets + 1 : bowler.wickets,
            wides: extraType == 'wide' ? bowler.wides + 1 : bowler.wides,
            noBalls: extraType == 'no-ball' ? bowler.noBalls + 1 : bowler.noBalls,
            isBowling: true,
          );
        }
        return bowler;
      }).toList();
      
      if (bowlerName.isEmpty) {
        bowlerName = 'Bowler';
      }
      
      // Create updated bowling score with bowler stats
      final newBowlingTeamScore = bowlingScore.copyWith(
        bowlers: updatedBowlers,
      );

      final newBattingTeamScore = currentScore.copyWith(
        runs: newRuns,
        wickets: newWickets,
        overs: newOvers,
        extras: newExtras,
        batters: updatedBatters,
      );

      // Create Ball Event
      final ballEvent = BallEvent(
        ballNumber: currentBall == 0 ? 6 : currentBall,
        overNumber: isLegalBall && currentBall == 0 ? currentOver - 1 : currentOver,
        battingTeam: isTeam1Batting ? match.team1Id : match.team2Id,
        bowlerId: actualBowlerId,
        bowlerName: bowlerName,
        batsmanId: actualStrikerId,
        batsmanName: batterName,
        runs: runs,
        extraRuns: extraRuns,
        extraType: extraType,
        wicket: isWicket ? Wicket(
          type: wicketType ?? 'bowled', 
          playerId: playerOutId ?? actualStrikerId,
          fielderId: fielderId,
        ) : null,
        commentary: _generateCommentary(
          overNumber: isLegalBall && currentBall == 0 ? currentOver - 1 : currentOver,
          ballNumber: currentBall == 0 ? 6 : currentBall,
          bowlerName: bowlerName,
          batsmanName: batterName,
          runs: runs, 
          extraType: extraType, 
          extraRuns: extraRuns, 
          isWicket: isWicket, 
          wicketType: wicketType,
          fielderName: fielderId,
        ) + _checkMilestones(updatedBatters, actualStrikerId, runs),
        timestamp: DateTime.now(),
        isLegalBall: isLegalBall,
      );

      // Add to undo stack
      _undoStack.add(ballEvent);
      if (_undoStack.length > _maxUndoItems) {
        _undoStack.removeAt(0);
        _undoStateStack.removeAt(0);
      }

      // Update ball-by-ball
      final updatedBallByBall = [...match.ballByBall, ballEvent];
      
      // Update player participation
      List<String> currentPlayerIds = List.from(match.playerIds);
      bool playersUpdated = false;
      
      if (!currentPlayerIds.contains(actualStrikerId) && actualStrikerId != 'striker_placeholder') {
        currentPlayerIds.add(actualStrikerId);
        playersUpdated = true;
      }
      if (!currentPlayerIds.contains(actualNonStrikerId) && actualNonStrikerId != 'non_striker_placeholder') {
        currentPlayerIds.add(actualNonStrikerId);
        playersUpdated = true;
      }
      if (!currentPlayerIds.contains(actualBowlerId) && actualBowlerId != 'bowler_placeholder') {
        currentPlayerIds.add(actualBowlerId);
        playersUpdated = true;
      }

      Map<String, dynamic> updateData = {
        'currentOver': currentOver,
        'currentBall': currentBall,
        'currentStrikerId': _currentStrikerId,
        'currentNonStrikerId': _currentNonStrikerId,
        'currentBowlerId': actualBowlerId,
        isTeam1Batting ? 'team1Score' : 'team2Score': newBattingTeamScore.toMap(),
        isTeam1Batting ? 'team2Score' : 'team1Score': newBowlingTeamScore.toMap(),
        'ballByBall': updatedBallByBall.map((e) => e.toMap()).toList(),
      };
      
      if (playersUpdated) {
        updateData['playerIds'] = currentPlayerIds;
      }
      
      // Update Firebase with both batting and bowling team scores
      await _dataService.updateMatch(match.id, updateData);
      
      // Emit to socket for real-time sync
      _socketService.emitBallEvent(match.id, ballEvent);
      
      // Logic moved up
      if (isLegalBall && currentBall == 0) {
         _lastOverBowlerId = actualBowlerId;
      }
      
      // Voice Commentary
      _playCommentary(
        runs, 
        extraType, 
        extraRuns, 
        isWicket,
        wicketType: wicketType,
        fielderName: fielderId,
      );

      // ============ CHECK FOR END OF INNINGS ============
      
      // Determine if team is all out
      final maxWickets = match.isSuperOver
          ? 2
          : 10; // Default to 10 wickets for a standard match
      bool isAllOut = newWickets >= maxWickets;
      
      // Determine if overs are complete
      bool areOversComplete = isLegalBall && currentBall == 0 && match.oversPerSide > 0 && currentOver >= match.oversPerSide;
      
      if (match.currentInnings == 1) {
        if (isAllOut || areOversComplete) {
          _commentaryService.speakEvent('Innings over. ${isAllOut ? "All out." : "Overs complete."}', 0);
          // Insert Innings Break Event
          await _addSystemEvent(
            match,
            "INNINGS BREAK - End of Innings 1. Target: ${newRuns + 1}",
            newBattingTeamScore,
            newBowlingTeamScore,
            existingBallByBall: updatedBallByBall,
          );
        }
      } else if (match.currentInnings == 2) {
        if (match.matchFormat == 'Test') {
           if (isAllOut) _commentaryService.speakEvent('Innings over. All out.', 0);
           return; 
        }
        
        final opponentScore = isTeam1Batting ? match.team2Score : match.team1Score;
        // Use match.target if set, otherwise fallback to opponent score + 1
        final dynamicTarget = match.target ?? (opponentScore.runs + 1);
        
        bool targetReached = newRuns >= dynamicTarget;
        
        if (targetReached || isAllOut || areOversComplete) {
          // Calculate result details
          String winnerTeamName = '';
          String margin = '';
          String? winnerTeamId;
          
          if (targetReached) {
            winnerTeamName = isTeam1Batting ? match.team1Name : match.team2Name;
            winnerTeamId = isTeam1Batting ? match.team1Id : match.team2Id;
            int wicketsLeft = maxWickets - newWickets;
            margin = '$wicketsLeft wickets';
            
            await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
          } else if (isAllOut || areOversComplete) {
            // Check if scores are tied (runs == target - 1)
            // Or if batting team lost (runs < target - 1)
            if (newRuns < dynamicTarget - 1) {
              winnerTeamName = isTeam1Batting ? match.team2Name : match.team1Name;
              winnerTeamId = isTeam1Batting ? match.team2Id : match.team1Id;
              int runDiff = (dynamicTarget - 1) - newRuns;
              margin = '$runDiff runs';
              
              await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
            } else {
              // MATCH TIED - Ask for Super Over
              if (onMatchTie != null) {
                final updatedMatch = match.copyWith(
                  team1Score: isTeam1Batting ? newBattingTeamScore : newBowlingTeamScore,
                  team2Score: isTeam1Batting ? newBowlingTeamScore : newBattingTeamScore,
                );
                onMatchTie!(updatedMatch);
                return; // Let UI handle decision
              }
              
              // Fallback: End as tie
              winnerTeamName = 'Match Tied';
              margin = '0 runs';
              await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
            }
          }
        }
      } else if (match.currentInnings == 3) {
        if (match.matchFormat == 'Test') {
           if (isAllOut) _commentaryService.speakEvent('Innings over. All out.', 0);
           return;
        }

        // SUPER OVER - First batting team
        if (isAllOut || areOversComplete) {
          _commentaryService.speakEvent('Super Over innings complete.', 0);
          // UI will handle transition to second team batting
        }
      } else if (match.currentInnings == 4) {
        if (match.matchFormat == 'Test') {
           // Test Match Chase Logic
           final dynamicTarget = match.target ?? 0;
           bool targetReached = newRuns >= dynamicTarget;
           
           if (targetReached || isAllOut) {
              String winnerTeamName = '';
              String margin = '';
              String? winnerTeamId;
              
              if (targetReached) {
                 winnerTeamName = isTeam1Batting ? match.team1Name : match.team2Name;
                 winnerTeamId = isTeam1Batting ? match.team1Id : match.team2Id;
                 int wicketsLeft = maxWickets - newWickets;
                 margin = '$wicketsLeft wickets';
                 await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
              } else if (isAllOut) {
                 winnerTeamName = isTeam1Batting ? match.team2Name : match.team1Name;
                 winnerTeamId = isTeam1Batting ? match.team2Id : match.team1Id;
                 int runDiff = (dynamicTarget - 1) - newRuns;
                 margin = '$runDiff runs';
                 await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
              }
           }
           return;
        }

        // SUPER OVER - Chasing team
        final opponentScore = isTeam1Batting ? match.team2Score : match.team1Score;
        final dynamicTarget = opponentScore.runs + 1;
        
        bool targetReached = newRuns >= dynamicTarget;
        
        if (targetReached || isAllOut || areOversComplete) {
          String winnerTeamName = '';
          String margin = '';
          String? winnerTeamId;
          
          if (targetReached) {
            winnerTeamName = isTeam1Batting ? match.team1Name : match.team2Name;
            winnerTeamId = isTeam1Batting ? match.team1Id : match.team2Id;
            int wicketsLeft = 2 - newWickets; // Super Over has only 2 wickets
            margin = 'Super Over ($wicketsLeft wickets)';
            
            await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
          } else if (isAllOut || areOversComplete) {
            if (newRuns < dynamicTarget - 1) {
              winnerTeamName = isTeam1Batting ? match.team2Name : match.team1Name;
              winnerTeamId = isTeam1Batting ? match.team2Id : match.team1Id;
              int runDiff = (dynamicTarget - 1) - newRuns;
              margin = 'Super Over ($runDiff runs)';
              
              await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
            } else {
              // Super Over also tied! Ask admin what to do
              if (onSuperOverTie != null) {
                final updatedMatch = match.copyWith(
                  team1Score: isTeam1Batting ? newBattingTeamScore : newBowlingTeamScore,
                  team2Score: isTeam1Batting ? newBowlingTeamScore : newBattingTeamScore,
                  ballByBall: updatedBallByBall,
                );
                onSuperOverTie!(updatedMatch);
                return; // Let UI handle decision
              }
              // Fallback: End as tie
              winnerTeamName = 'Match Tied';
              margin = 'Super Over Tied';
              await _completeMatch(match, winnerTeamName, margin, winnerTeamId, isTeam1Batting, newBattingTeamScore, newBowlingTeamScore, updatedBallByBall);
            }
          }
        }
      }
      
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Super Over callbacks
  Function(MatchModel)? onMatchTie;
  Function(MatchModel)? onSuperOverTie;

  /// Resolve tie - either start Super Over or end as tie
  Future<void> resolveTie(MatchModel match, bool playSuperOver) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      if (!playSuperOver) {
        // End as Tie
        final matchResult = MatchResult(
          winner: 'Match Tied',
          margin: '0 runs',
          manOfMatch: '',
        );

        await _dataService.updateMatch(match.id, {
          'status': 'completed',
          'result': matchResult.toMap(),
          'winnerTeam': 'Match Tied',
          'winnerTeamId': null,
          'winningMargin': '0 runs',
          'team1Score': match.team1Score.toMap(),
          'team2Score': match.team2Score.toMap(),
        });

        // Update team stats for tie
        if (match.team1Id.isNotEmpty) {
          await _dataService.updateTeamMatchStats(
            teamId: match.team1Id, isWinner: false, isTie: true,
          );
        }
        if (match.team2Id.isNotEmpty) {
          await _dataService.updateTeamMatchStats(
            teamId: match.team2Id, isWinner: false, isTie: true,
          );
        }
        
        _commentaryService.speakEvent('Match over. It is a tie!', 0);

      } else {
        // START SUPER OVER
        // Save main match scores
        final mainScores = {
          'team1': match.team1Score.toMap(),
          'team2': match.team2Score.toMap(),
        };

        // Reset scores but keep team players for Super Over
        final team1SOScore = TeamScore(
          runs: 0, 
          wickets: 0, 
          overs: 0,
          batters: match.team1Score.batters.map((b) => BatterStats(playerId: b.playerId, playerName: b.playerName)).toList(),
          bowlers: match.team1Score.bowlers.map((b) => BowlerStats(playerId: b.playerId, playerName: b.playerName)).toList(),
        );
        
        final team2SOScore = TeamScore(
          runs: 0, 
          wickets: 0, 
          overs: 0,
          batters: match.team2Score.batters.map((b) => BatterStats(playerId: b.playerId, playerName: b.playerName)).toList(),
          bowlers: match.team2Score.bowlers.map((b) => BowlerStats(playerId: b.playerId, playerName: b.playerName)).toList(),
        );

        // Clear current player selections
        _currentStrikerId = null;
        _currentNonStrikerId = null;
        _currentBowlerId = null;
        _lastOverBowlerId = null;
        _undoStack.clear();
        _undoStateStack.clear();
        
        await _dataService.updateMatch(match.id, {
          'currentInnings': 3,
          'oversPerSide': 1, // Super Over is 1 over
          'currentOver': 0,
          'currentBall': 0,
          'target': null,
          'team1Score': team1SOScore.toMap(),
          'team2Score': team2SOScore.toMap(),
          'currentBattingTeam': 'team1',
          'bowlingTeam': 'team2',
          'currentStrikerId': null,
          'currentNonStrikerId': null,
          'currentBowlerId': null,
          'mainMatchScores': mainScores,
          'isSuperOver': true,
        });

        _commentaryService.speakEvent('Super Over starting! Team 1 bats first.', 0);
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error in resolveTie: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resolve Super Over tie - either play another Super Over or end as tie
  Future<void> resolveSuperOverTie(MatchModel match, {required bool playAnother}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      if (!playAnother) {
        // Declare Match as Tie
        final isTeam1Batting = match.currentBattingTeam == 'team1';
        await _completeMatch(
          match,
          'Match Tied',
          'Super Over Tied',
          null, // No winner
          isTeam1Batting,
          isTeam1Batting ? match.team1Score : match.team2Score,
          isTeam1Batting ? match.team2Score : match.team1Score,
          match.ballByBall,
        );
        _commentaryService.speakEvent('Match over. It is a tie after Super Over!', 0);
      } else {
        // Play Another Super Over
        final nextSONumber = (match.superOverNumber) + 1;
        
        // Reset scores for new Super Over but keep team players
        final team1SOScore = TeamScore(
          runs: 0, 
          wickets: 0, 
          overs: 0,
          batters: match.team1Score.batters.map((b) => BatterStats(playerId: b.playerId, playerName: b.playerName)).toList(),
          bowlers: match.team1Score.bowlers.map((b) => BowlerStats(playerId: b.playerId, playerName: b.playerName)).toList(),
        );
        
        final team2SOScore = TeamScore(
          runs: 0, 
          wickets: 0, 
          overs: 0,
          batters: match.team2Score.batters.map((b) => BatterStats(playerId: b.playerId, playerName: b.playerName)).toList(),
          bowlers: match.team2Score.bowlers.map((b) => BowlerStats(playerId: b.playerId, playerName: b.playerName)).toList(),
        );

        // Clear current player selections
        _currentStrikerId = null;
        _currentNonStrikerId = null;
        _currentBowlerId = null;
        _lastOverBowlerId = null;
        _undoStack.clear();
        _undoStateStack.clear();
        
        await _dataService.updateMatch(match.id, {
          'currentInnings': 3, // Reset to Super Over innings 1 (batting first)
          'oversPerSide': 1, // Super Over is 1 over
          'currentOver': 0,
          'currentBall': 0,
          'target': null,
          'team1Score': team1SOScore.toMap(),
          'team2Score': team2SOScore.toMap(),
          'currentBattingTeam': 'team1',
          'bowlingTeam': 'team2',
          'currentStrikerId': null,
          'currentNonStrikerId': null,
          'currentBowlerId': null,
          'superOverNumber': nextSONumber,
        });

        _commentaryService.speakEvent('Super Over number $nextSONumber starting! Team 1 bats first.', 0);
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error in resolveSuperOverTie: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> _completeMatch(
    MatchModel match, 
    String winnerTeamName, 
    String margin, 
    String? winnerTeamId,
    bool isTeam1Batting,
    TeamScore newBattingTeamScore,
    TeamScore newBowlingTeamScore,
    List<BallEvent> currentBallByBall,
  ) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final finalMessage = winnerTeamName == 'Match Tied' 
          ? 'Match over. It is a tie!' 
          : 'Match over. $winnerTeamName won by $margin!';

      _commentaryService.speakEvent(finalMessage, 0);
      
      // Update status AND result to completed
      final matchResult = MatchResult(
        winner: winnerTeamName,
        margin: margin,
        manOfMatch: _calculateManOfMatch(match, winnerTeamId),
      );
      final finalBallByBall = List<BallEvent>.from(currentBallByBall);
      
      final updateData = {
        'status': 'completed',
        'result': {
          'winner': winnerTeamName,
          'margin': margin,
          'manOfMatch': _calculateManOfMatch(match, winnerTeamId),
        },
        'winnerTeam': winnerTeamName,
        'winnerTeamId': winnerTeamId,
        'winningMargin': margin,
        isTeam1Batting ? 'team1Score' : 'team2Score': newBattingTeamScore.toMap(),
        isTeam1Batting ? 'team2Score' : 'team1Score': newBowlingTeamScore.toMap(),
        'ballByBall': finalBallByBall.map((e) => e.toMap()).toList(),
      };


      await _dataService.updateMatch(match.id, updateData);
      
      // Insert Match End Event
      await _addSystemEvent(match, finalMessage, 
          isTeam1Batting ? newBattingTeamScore : newBowlingTeamScore, 
          isTeam1Batting ? newBowlingTeamScore : newBattingTeamScore,
          isMatchEnd: true,
          existingBallByBall: finalBallByBall,
      );
      
      // Process stats
      final finalMatch = match.copyWith(
          team1Score: isTeam1Batting ? newBattingTeamScore : newBowlingTeamScore,
          team2Score: isTeam1Batting ? newBowlingTeamScore : newBattingTeamScore,
          ballByBall: finalBallByBall,
          status: 'completed',
          result: matchResult,
      );
      
      await _statsService.processMatchCompletion(finalMatch);
      
      // Notify followers of Man of the Match achievement
      if (matchResult.manOfMatch != null && matchResult.manOfMatch!.isNotEmpty && winnerTeamId != null) {
        // Find the player ID for the Man of the Match
        String? momPlayerId;
        
        // Search in team1
        for (var batter in finalMatch.team1Score.batters) {
          if (batter.playerName == matchResult.manOfMatch) {
            momPlayerId = batter.playerId;
            break;
          }
        }
        if (momPlayerId == null) {
          for (var bowler in finalMatch.team1Score.bowlers) {
            if (bowler.playerName == matchResult.manOfMatch) {
              momPlayerId = bowler.playerId;
              break;
            }
          }
        }
        
        // Search in team2
        if (momPlayerId == null) {
          for (var batter in finalMatch.team2Score.batters) {
            if (batter.playerName == matchResult.manOfMatch) {
              momPlayerId = batter.playerId;
              break;
            }
          }
        }
        if (momPlayerId == null) {
          for (var bowler in finalMatch.team2Score.bowlers) {
            if (bowler.playerName == matchResult.manOfMatch) {
              momPlayerId = bowler.playerId;
              break;
            }
          }
        }
        
        if (momPlayerId != null && momPlayerId.isNotEmpty && !momPlayerId.startsWith('p_')) {
          await _dataService.notifyFollowersOfAchievement(
            playerId: momPlayerId,
            playerName: matchResult.manOfMatch!,
            achievementTitle: 'Man of the Match',
            matchId: match.id,
          );
        }
      }
      
      if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
        await _updateTournamentOnMatchComplete(
          match,
          winnerTeamId,
          isTeam1Batting ? newBattingTeamScore : newBowlingTeamScore,
          isTeam1Batting ? newBowlingTeamScore : newBattingTeamScore,
        );
      }

      // Update team match stats (matchesPlayed, matchesWon, matchesLost)
      final isTie = winnerTeamName == 'Match Tied';
      if (match.team1Id.isNotEmpty) {
        await _dataService.updateTeamMatchStats(
          teamId: match.team1Id,
          isWinner: winnerTeamId == match.team1Id,
          isTie: isTie,
        );
      }
      if (match.team2Id.isNotEmpty) {
        await _dataService.updateTeamMatchStats(
          teamId: match.team2Id,
          isWinner: winnerTeamId == match.team2Id,
          isTie: isTie,
        );
      }
      
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Undo the last ball
  Future<bool> undoLastBall(MatchModel match) async {
    if (_isLoading) return false;
    if (_undoStack.isEmpty || _undoStateStack.isEmpty) {
      return false;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _undoStack.removeLast();
      final lastState = _undoStateStack.removeLast();
      
      // Restore previous state
      final previousScore = TeamScore.fromMap(lastState['teamScore']);
      final previousBowlingScore = TeamScore.fromMap(lastState['bowlingScore']);
      final previousOver = lastState['currentOver'] as int;
      final previousBall = lastState['currentBall'] as int;
      _currentStrikerId = lastState['currentStrikerId'] as String?;
      _currentNonStrikerId = lastState['currentNonStrikerId'] as String?;
      _currentBowlerId = lastState['currentBowlerId'] as String?;
      _lastOverBowlerId = lastState['lastOverBowlerId'] as String?;
      
      bool isTeam1Batting = match.currentBattingTeam == 'team1';
      
      // Prepare ball-by-ball update (remove last ball)
      final updatedBallByBall = List<BallEvent>.from(match.ballByBall);
      if (updatedBallByBall.isNotEmpty) {
        updatedBallByBall.removeLast();
      }

      Map<String, dynamic> updateData = {
        'currentOver': previousOver,
        'currentBall': previousBall,
        'currentStrikerId': _currentStrikerId,
        'currentNonStrikerId': _currentNonStrikerId,
        'currentBowlerId': _currentBowlerId,
        isTeam1Batting ? 'team1Score' : 'team2Score': previousScore.toMap(),
        isTeam1Batting ? 'team2Score' : 'team1Score': previousBowlingScore.toMap(),
        'ballByBall': updatedBallByBall.map((e) => e.toMap()).toList(),
      };

      // If match was completed, revert status to live and clear winner
      if (match.status == 'completed') {
        updateData['status'] = 'live'; 
        updateData['result'] = null; // Clear result map
        updateData['winnerTeam'] = null;
        updateData['winnerTeamId'] = null;
        updateData['winningMargin'] = '';
      }

      // Update Firebase with previous state
      await _dataService.updateMatch(match.id, updateData);
      
      _commentaryService.speakEvent('Ball undone', 0);
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Undo error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update a specific ball event and recalculate match state
  Future<void> updateBallEvent(MatchModel match, int ballIndex, BallEvent updatedBall) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final updatedBallByBall = List<BallEvent>.from(match.ballByBall);
      if (ballIndex >= 0 && ballIndex < updatedBallByBall.length) {
        updatedBallByBall[ballIndex] = updatedBall;
      }

      // Recalculate match model from updated history
      final recalculatedMatch = match.copyWith(ballByBall: updatedBallByBall).recalculateFromBallByBall();

      // Prepare update payload
      final updateData = {
        'ballByBall': recalculatedMatch.ballByBall.map((e) => e.toMap()).toList(),
        'team1Score': recalculatedMatch.team1Score.toMap(),
        'team2Score': recalculatedMatch.team2Score.toMap(),
        'currentOver': recalculatedMatch.currentOver,
        'currentBall': recalculatedMatch.currentBall,
        'currentStrikerId': recalculatedMatch.currentStrikerId,
        'currentNonStrikerId': recalculatedMatch.currentNonStrikerId,
      };

      // Push to Firebase
      await _dataService.updateMatch(match.id, updateData);
      
      // Optionally notify stats service to re-process if match is completed
      if (recalculatedMatch.status == 'completed') {
        await _statsService.processMatchCompletion(recalculatedMatch);
      }

      _commentaryService.speakEvent('Ball history updated', 0);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Edit ball error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sync ball history manually (recalculates everything)
  Future<void> syncBallHistory(MatchModel match) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final recalculatedMatch = match.recalculateFromBallByBall();
      
      final updateData = {
        'team1Score': recalculatedMatch.team1Score.toMap(),
        'team2Score': recalculatedMatch.team2Score.toMap(),
        'currentOver': recalculatedMatch.currentOver,
        'currentBall': recalculatedMatch.currentBall,
        'currentStrikerId': recalculatedMatch.currentStrikerId,
        'currentNonStrikerId': recalculatedMatch.currentNonStrikerId,
      };

      await _dataService.updateMatch(match.id, updateData);
      _commentaryService.speakEvent('Scores synced with history', 0);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _saveStateForUndo(MatchModel match, TeamScore currentScore, TeamScore bowlingScore) {
    _undoStateStack.add({
      'teamScore': currentScore.toMap(),
      'bowlingScore': bowlingScore.toMap(),
      'currentOver': match.currentOver,
      'currentBall': match.currentBall,
      'currentStrikerId': _currentStrikerId ?? match.currentStrikerId,
      'currentNonStrikerId': _currentNonStrikerId ?? match.currentNonStrikerId,
      'currentBowlerId': _currentBowlerId ?? match.currentBowlerId,
      'lastOverBowlerId': _lastOverBowlerId,
    });
  }

  Future<void> scoreWide(MatchModel match, {int additionalRuns = 0}) async {
    await scoreBall(match, runs: 0, extraType: 'wide', extraRuns: 1 + additionalRuns);
  }

  Future<void> scoreNoBall(MatchModel match, {int batsmanRuns = 0}) async {
    await scoreBall(match, runs: batsmanRuns, extraType: 'no-ball', extraRuns: 1);
  }

  Future<void> scoreLegBye(MatchModel match, {required int runs}) async {
    await scoreBall(match, runs: 0, extraType: 'leg-bye', extraRuns: runs);
  }

  Future<void> scoreBye(MatchModel match, {required int runs}) async {
    await scoreBall(match, runs: 0, extraType: 'bye', extraRuns: runs);
  }

  Future<void> endOver(MatchModel match, String nextBowlerId) async {
    changeBowler(nextBowlerId);
  }

  Future<void> changeInnings(MatchModel match) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final isTeam1Batting = match.currentBattingTeam == 'team1';
      final newBattingTeam = isTeam1Batting ? 'team2' : 'team1';
      final newBowlingTeam = isTeam1Batting ? 'team1' : 'team2';
      
      _currentStrikerId = null;
      _currentNonStrikerId = null;
      _currentBowlerId = null;
      _lastOverBowlerId = null;
      _undoStack.clear();
      _undoStateStack.clear();
      
      int targetRuns = 0;
      if (match.currentInnings == 1) {
         final firstInningsScore = isTeam1Batting ? match.team1Score : match.team2Score;
         targetRuns = firstInningsScore.runs + 1;
      } else if (match.currentInnings == 3) {
         final firstInningsScore = isTeam1Batting ? match.team1Score : match.team2Score;
         targetRuns = firstInningsScore.runs + 1; // Super over target
      }
      
      await _dataService.updateMatch(match.id, {
        'currentInnings': match.currentInnings + 1,
        'currentBattingTeam': newBattingTeam,
        'bowlingTeam': newBowlingTeam,
        'currentOver': 0,
        'currentBall': 0,
        'currentStrikerId': null,
        'currentNonStrikerId': null,
        'currentBowlerId': null,
        if (targetRuns > 0) 'target': targetRuns,
      });
      _commentaryService.speakEvent('Innings change. $newBattingTeam to bat.', 0);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper to check for milestones and return commentary string suffix
  String _checkMilestones(List<BatterStats> batters, String strikerId, int runsScored) {
    if (runsScored == 0) return "";
    
    final batter = batters.firstWhere((b) => b.playerId == strikerId, orElse: () => BatterStats(playerId: '', playerName: ''));
    if (batter.playerId.isEmpty) return "";
    
    // Check if milestone reached THIS ball
    // Previous runs = current - runsScored
    // Wait, batter.runs is already updated. 
    int prevRuns = batter.runs - runsScored;
    
    if (prevRuns < 50 && batter.runs >= 50 && batter.runs < 100) {
      return " \n\n🎉 MAGNIFICENT 50 for ${batter.playerName.toUpperCase()}!";
    } else if (prevRuns < 100 && batter.runs >= 100) {
      return " \n\n🙌 SENSATIONAL CENTURY! 100 up for ${batter.playerName.toUpperCase()}!";
    }
    return "";
  }
  
  // Helper to add system event (like innings break)
  Future<void> _addSystemEvent(
    MatchModel match,
    String message,
    TeamScore team1Score,
    TeamScore team2Score, {
    bool isMatchEnd = false,
    List<BallEvent>? existingBallByBall,
  }) async {
     
     // We create a "fake" ball event for the commentary feed
     final systemEvent = BallEvent(
        ballNumber: 0,
        overNumber: 0, // 0 implies special event
        battingTeam: match.currentBattingTeam == 'team1' ? match.team1Id : match.team2Id, // associate with current team
        bowlerId: '',
        bowlerName: '',
        batsmanId: '',
        batsmanName: '',
        runs: 0,
        extraRuns: 0,
        extraType: null,
        wicket: null,
        commentary: message, // The message
        timestamp: DateTime.now(),
        isLegalBall: false,
     );
     
     final sourceBallByBall = existingBallByBall ?? match.ballByBall;
     final updatedBallByBall = [...sourceBallByBall, systemEvent];
     
     // Update just the ballByBall list roughly
     await _dataService.updateMatch(match.id, {
        'ballByBall': updatedBallByBall.map((e) => e.toMap()).toList(),
     });
     
     // Also update local match model reference if needed, but provider consumers will fetch update
  }

  String _generateCommentary({
    required int overNumber,
    required int ballNumber,
    required String bowlerName,
    required String batsmanName,
    required int runs, 
    required String? extraType, 
    required int extraRuns, 
    required bool isWicket, 
    String? wicketType,
    String? fielderName,
  }) {
    // 1. Build Prefix: "6.5 Bowler to Batsman, "
    final prefix = "$overNumber.$ballNumber $bowlerName to $batsmanName, ";
    
    // 2. Determine Result string
    String result = "";
    
    if (isWicket) {
      String wType = (wicketType ?? 'out').toLowerCase();
      String details = "out";
      
      // Use realistic wicket commentary
      result = _getWicketCommentary(wType, fielderName, batsmanName);
    } else if (extraType != null) {
      if (extraType == 'wide') {
        result = "wide"; 
      } else if (extraType == 'no-ball') {
        result = "no ball";
      } else if (extraType == 'bye') {
         result = "$extraRuns bye${extraRuns > 1 ? 's' : ''}";
      } else if (extraType == 'leg-bye') {
         result = "$extraRuns leg bye${extraRuns > 1 ? 's' : ''}";
      }
    } else {
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
        result = "$runs runs";
      }
    }

    return "$prefix$result";
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
  }

  // Dot Ball (0 runs)
  static const List<String> _dotBallPhrases = [
    "no run, solid defensive shot.",
    "no run, driven straight to the fielder.",
    "no run, beaten! That was a ripper.",
    "no run, left alone outside off.",
    "no run, straight to the man at point.",
    "no run, watchful start, respects the good length.",
    "no run, huge appeal for LBW but turned down.",
    "no run, finds the fielder at cover.",
    "no run, nicely bowled, swings away late.",
    "no run, blocked back to the bowler."
  ];

  // Single (1 run)
  static const List<String> _singlePhrases = [
    "1 run, pushed into the gap for a single.",
    "1 run, quick single taken, good running.",
    "1 run, worked away to deep square leg.",
    "1 run, tapped to cover, they scamper through.",
    "1 run, edged but safe, they get a single.",
    "1 run, gentle push to mid-on.",
    "1 run, driven down the ground for one.",
    "1 run, glided down to third man."
  ];

  // Two Runs
  static const List<String> _twoRunPhrases = [
    "2 runs, play it fine, excellent running between the wickets.",
    "2 runs, driven through the covers, they'll come back for two.",
    "2 runs, in the air but safe! Clears the infield.",
    "2 runs, worked into the leg side, easy couple.",
    "2 runs, misfield allows them to come back for the second."
  ];
  
  // Three Runs
  static const List<String> _threeRunPhrases = [
     "3 runs, great shot! The fielder chases it down just inside the rope.",
     "3 runs, superb timing, just stopped before the boundary.",
     "3 runs, long chase for the fielder, good commitment."
  ];

  // Four (4 runs)
  static const List<String> _fourPhrases = [
    "FOUR, glorious cover drive! Textbook stuff.",
    "FOUR, smashed past the bowler! No chance for mid-off.",
    "FOUR, edged but it runs away to the third man boundary!",
    "FOUR, pulled away disdainfully over mid-wicket.",
    "FOUR, elegant flick through square leg.",
    "FOUR, pure timing! Races across the turf.",
    "FOUR, cut away fiercely past point.",
    "FOUR, straight drive! That's as straight as an arrow.",
    "FOUR, finds the gap perfectly.",
    "FOUR, poor delivery, punished."
  ];

  // Six (6 runs)
  static const List<String> _sixPhrases = [
    "SIX, that's gone into orbit! Huge hit.",
    "SIX, massive strike over long-on!",
    "SIX, clean hit, sails comfortably over the ropes.",
    "SIX, pickup shot over square leg! What a beauty.",
    "SIX, out of the stadium! That is enormous.",
    "SIX, straight down the ground, into the sightscreen!",
    "SIX, maximum! He's picked the length early.",
    "SIX, muscle! Power-hitting at its best."
  ];
  
  // Wickets
  String _getWicketCommentary(String? type, String? fielder, String batter) {
     String wType = (type ?? 'out').toLowerCase();
     
     if (wType == 'bowled') {
       return "OUT! Bowled him! Cleaned him up with a beauty.";
     } else if (wType.contains('caught')) {
       final pos = _getRandomShotDirection().replaceFirst('to ', 'at ').replaceFirst('through ', 'at ');
       return "OUT! Caught! Up in the air... and taken safely ${fielder != null ? 'by $fielder' : '$pos'}.";
     } else if (wType == 'lbw') {
        return "OUT! LBW! Plumb in front, the finger goes up.";
     } else if (wType.contains('run out')) {
        return "OUT! Run out! A mix-up in the middle.";
     } else if (wType == 'stumped') {
        return "OUT! Stumped! Beaten in flight and the keeper does the rest.";
     }
     return "OUT! $batter has to walk back.";
  }

  String _getRandomShotDirection() {
    const directions = [
      "through covers",
      "to deep mid wicket",
      "over long on",
      "past point",
      "down the ground",
      "through mid-wicket",
      "over square leg",
      "towards third man",
      "through extra cover",
      "over long off",
      "to deep extra cover",
      "past short fine leg"
    ];
    // Simple random pick
    return (List.of(directions)..shuffle()).first;
  }
  
  void _playCommentary(
    int runs, 
    String? extraType, 
    int extraRuns, 
    bool isWicket, {
    String? wicketType,
    String? fielderName,
  }) {
    if (isWicket) {
      final type = wicketType ?? 'wicket';
      _commentaryService.speakEvent(fielderName != null ? '$type by $fielderName' : type, 0);
    } else if (runs == 4 && extraType == null) {
      _commentaryService.speakEvent('four', 4);
    } else if (runs == 6 && extraType == null) {
      _commentaryService.speakEvent('six', 6);
    } else if (extraType == 'wide') {
      _commentaryService.speakEvent('wide', extraRuns);
    } else if (extraType == 'no-ball') {
      _commentaryService.speakEvent('No ball', extraRuns);
    }
  }
  
  /// Set current players on crease and bowling
  /// Optionally resolves and links temporary IDs to real users for live match visibility
  Future<void> setCurrentPlayers({
    String? strikerId,
    String? strikerName,
    String? nonStrikerId,
    String? nonStrikerName,
    String? bowlerId,
    String? bowlerName,
    String? matchId,
  }) async {
    if (strikerId != null) {
      _currentStrikerId = strikerId;
      if (matchId != null && strikerName != null) {
        _resolveAndLink(matchId, strikerId, strikerName);
      }
    }
    
    if (nonStrikerId != null) {
      _currentNonStrikerId = nonStrikerId;
      if (matchId != null && nonStrikerName != null) {
        _resolveAndLink(matchId, nonStrikerId, nonStrikerName);
      }
    }
    
    if (bowlerId != null) {
      _currentBowlerId = bowlerId;
      if (matchId != null && bowlerName != null) {
        _resolveAndLink(matchId, bowlerId, bowlerName);
      }
    }
    
    notifyListeners();
  }

  /// Internal helper to resolve and link a player without blocking the UI
  void _resolveAndLink(String matchId, String playerId, String playerName) {
    _dataService.resolveAndLinkPlayerToMatch(matchId, playerId, playerName).then((resolvedId) {
      if (resolvedId != null && resolvedId != playerId) {
        // If it was resolved to a NEW ID, we should update our local state
        if (_currentStrikerId == playerId) _currentStrikerId = resolvedId;
        if (_currentNonStrikerId == playerId) _currentNonStrikerId = resolvedId;
        if (_currentBowlerId == playerId) _currentBowlerId = resolvedId;
        notifyListeners();
      }
    });
  }
  
  /// Swap striker and non-striker
  void _swapStrike() {
    final temp = _currentStrikerId;
    _currentStrikerId = _currentNonStrikerId;
    _currentNonStrikerId = temp;
  }
  
  /// Manually swap strike
  void swapStrike() {
    _swapStrike();
    notifyListeners();
  }
  
  /// Change bowler
  /// Optionally resolves and links temporary IDs to real users
  void changeBowler(String newBowlerId, {String? bowlerName, String? matchId}) {
    _lastOverBowlerId = _currentBowlerId;
    _currentBowlerId = newBowlerId;
    
    if (matchId != null && bowlerName != null) {
      _resolveAndLink(matchId, newBowlerId, bowlerName);
    }
    
    notifyListeners();
  }

  void toggleCommentary(bool enable) {
    _commentaryService.toggle(enable);
    notifyListeners();
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Update tournament data when a match completes
  /// - Updates fixture status to 'completed'
  /// - Updates points table with wins/losses/NRR
  Future<void> _updateTournamentOnMatchComplete(
    MatchModel match,
    String? winnerTeamId,
    TeamScore team1FinalScore,
    TeamScore team2FinalScore,
  ) async {
    try {
      debugPrint('📊 Updating tournament ${match.tournamentId} after match ${match.id} completed');
      
      // Fetch the tournament
      final tournament = await _dataService.getTournament(match.tournamentId!);
      if (tournament == null) {
        debugPrint('❌ Tournament not found: ${match.tournamentId}');
        return;
      }
      
      // 1. Update fixture status and scores
      final updatedFixtures = tournament.fixtures.map((fixture) {
        if (fixture.matchId == match.id) {
          // Format score strings for display (e.g., "145/6 (18.2)")
          String formatScore(TeamScore score) {
            return '${score.runs}/${score.wickets} (${score.overs.toStringAsFixed(1)})';
          }
          
          return fixture.copyWith(
            status: 'completed',
            winnerId: winnerTeamId,
            team1Score: formatScore(team1FinalScore),
            team2Score: formatScore(team2FinalScore),
          );
        }
        return fixture;
      }).toList();
      
      // 2. Update leaderboard (top run scorers and wicket takers)
      final updatedRunScorers = _updateLeaderboard(
        tournament.topRunScorers,
        match,
        team1FinalScore,
        team2FinalScore,
        isRuns: true,
      );
      
      final updatedWicketTakers = _updateLeaderboard(
        tournament.topWicketTakers,
        match,
        team1FinalScore,
        team2FinalScore,
        isRuns: false,
      );
      
      // 2b. Update sixes and fours leaderboard
      final updatedSixHitters = _updateBattingLeaderboard(
        tournament.topSixHitters,
        match,
        team1FinalScore,
        team2FinalScore,
        statExtractor: (batter) => batter.sixes,
      );
      
      final updatedFourHitters = _updateBattingLeaderboard(
        tournament.topFourHitters,
        match,
        team1FinalScore,
        team2FinalScore,
        statExtractor: (batter) => batter.fours,
      );
      
      // 2c. Update new bowling leaderboards
      final updatedBestEconomy = _updateEconomyLeaderboard(
        tournament.bestEconomy,
        match,
        team1FinalScore,
        team2FinalScore,
      );
      
      final updatedBestBowlingFigures = _updateBowlingFiguresLeaderboard(
        tournament.bestBowlingFigures,
        match,
        team1FinalScore,
        team2FinalScore,
      );
      
      // 3. Save to Firebase (Fixtures & Leaderboard)
      await _dataService.updateTournament(tournament.id, {
        'fixtures': updatedFixtures.map((f) => f.toMap()).toList(),
        'topRunScorers': updatedRunScorers.map((e) => e.toMap()).toList(),
        'topWicketTakers': updatedWicketTakers.map((e) => e.toMap()).toList(),
        'topSixHitters': updatedSixHitters.map((e) => e.toMap()).toList(),
        'topFourHitters': updatedFourHitters.map((e) => e.toMap()).toList(),
        'bestEconomy': updatedBestEconomy.map((e) => e.toMap()).toList(),
        'bestBowlingFigures': updatedBestBowlingFigures.map((e) => e.toMap()).toList(),
      });
      
      // 4. Update Points Table (Recalculate entirely for accuracy)
      await _dataService.updateTournamentStandings(tournament.id);
      
      debugPrint('✅ Tournament ${tournament.name} updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating tournament: $e');
    }
  }
  
  /// Convert overs (e.g., 19.4) to total balls
  int _oversToBalls(double overs) {
    int completeOvers = overs.floor();
    int extraBalls = ((overs - completeOvers) * 10).round();
    return (completeOvers * 6) + extraBalls;
  }
  
  /// Update tournament leaderboard with match stats
  List<TournamentLeaderboardEntry> _updateLeaderboard(
    List<TournamentLeaderboardEntry> existing,
    MatchModel match,
    TeamScore team1Score,
    TeamScore team2Score, {
    required bool isRuns,
  }) {
    // Create a map for quick lookup
    final leaderboard = <String, TournamentLeaderboardEntry>{};
    for (var entry in existing) {
      leaderboard[entry.playerId] = entry;
    }
    
    // Process team 1 batters/bowlers
    if (isRuns) {
      for (var batter in team1Score.batters) {
        if (batter.playerId.isEmpty || batter.playerId.startsWith('p_')) continue;
        final current = leaderboard[batter.playerId];
        leaderboard[batter.playerId] = TournamentLeaderboardEntry(
          playerId: batter.playerId,
          playerName: batter.playerName,
          teamId: match.team1Id,
          teamName: match.team1Name,
          value: (current?.value ?? 0) + batter.runs,
          matches: (current?.matches ?? 0) + 1,
        );
      }
      for (var batter in team2Score.batters) {
        if (batter.playerId.isEmpty || batter.playerId.startsWith('p_')) continue;
        final current = leaderboard[batter.playerId];
        leaderboard[batter.playerId] = TournamentLeaderboardEntry(
          playerId: batter.playerId,
          playerName: batter.playerName,
          teamId: match.team2Id,
          teamName: match.team2Name,
          value: (current?.value ?? 0) + batter.runs,
          matches: (current?.matches ?? 0) + 1,
        );
      }
    } else {
      // Wickets - check bowlers in the BATTING team's score (they bowled to the other team)
      for (var bowler in team2Score.bowlers) {
        if (bowler.playerId.isEmpty || bowler.playerId.startsWith('p_')) continue;
        final current = leaderboard[bowler.playerId];
        leaderboard[bowler.playerId] = TournamentLeaderboardEntry(
          playerId: bowler.playerId,
          playerName: bowler.playerName,
          teamId: match.team1Id,
          teamName: match.team1Name,
          value: (current?.value ?? 0) + bowler.wickets,
          matches: (current?.matches ?? 0) + 1,
        );
      }
      for (var bowler in team1Score.bowlers) {
        if (bowler.playerId.isEmpty || bowler.playerId.startsWith('p_')) continue;
        final current = leaderboard[bowler.playerId];
        leaderboard[bowler.playerId] = TournamentLeaderboardEntry(
          playerId: bowler.playerId,
          playerName: bowler.playerName,
          teamId: match.team2Id,
          teamName: match.team2Name,
          value: (current?.value ?? 0) + bowler.wickets,
          matches: (current?.matches ?? 0) + 1,
        );
      }
    }
    
    // Sort by value (descending) and keep top 10
    final sorted = leaderboard.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).toList();
  }
  
  /// Update batting leaderboard for sixes/fours using a custom stat extractor
  List<TournamentLeaderboardEntry> _updateBattingLeaderboard(
    List<TournamentLeaderboardEntry> existing,
    MatchModel match,
    TeamScore team1Score,
    TeamScore team2Score, {
    required int Function(BatterStats) statExtractor,
  }) {
    final leaderboard = <String, TournamentLeaderboardEntry>{};
    for (var entry in existing) {
      leaderboard[entry.playerId] = entry;
    }
    
    for (var batter in team1Score.batters) {
      if (batter.playerId.isEmpty || batter.playerId.startsWith('p_')) continue;
      final statValue = statExtractor(batter);
      if (statValue == 0) continue;
      final current = leaderboard[batter.playerId];
      leaderboard[batter.playerId] = TournamentLeaderboardEntry(
        playerId: batter.playerId,
        playerName: batter.playerName,
        teamId: match.team1Id,
        teamName: match.team1Name,
        value: (current?.value ?? 0) + statValue,
        matches: (current?.matches ?? 0) + 1,
      );
    }
    for (var batter in team2Score.batters) {
      if (batter.playerId.isEmpty || batter.playerId.startsWith('p_')) continue;
      final statValue = statExtractor(batter);
      if (statValue == 0) continue;
      final current = leaderboard[batter.playerId];
      leaderboard[batter.playerId] = TournamentLeaderboardEntry(
        playerId: batter.playerId,
        playerName: batter.playerName,
        teamId: match.team2Id,
        teamName: match.team2Name,
        value: (current?.value ?? 0) + statValue,
        matches: (current?.matches ?? 0) + 1,
      );
    }
    
    final sorted = leaderboard.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).toList();
  }
  
  /// Update bowling leaderboard for Best Economy
  List<TournamentLeaderboardEntry> _updateEconomyLeaderboard(
    List<TournamentLeaderboardEntry> existing,
    MatchModel match,
    TeamScore team1Score,
    TeamScore team2Score,
  ) {
    final leaderboard = <String, TournamentLeaderboardEntry>{};
    for (var entry in existing) {
      leaderboard[entry.playerId] = entry;
    }
    
    // Helper to process bowlers
    void processBowlers(List<BowlerStats> bowlers, String teamId, String teamName) {
      for (var bowler in bowlers) {
        if (bowler.playerId.isEmpty || bowler.playerId.startsWith('p_')) continue;
        // Minimum 2 overs bowled to qualify for economy stats
        if (bowler.overs < 2.0) continue; 
        
        final current = leaderboard[bowler.playerId];
        
        // Let's aggregate total runs and over correctly across tournament matches
        // To do this simply, we store 'total runs given' in value, 'total balls' in matches 
        // Then calculate economy: (runs / (balls/6))
        
        // value = total runs
        // matches = total balls (calculate from overs: 2.1 overs = 13 balls)
        int currentBalls = (bowler.overs.floor() * 6) + ((bowler.overs - bowler.overs.floor()) * 10).round();
        int totalRuns = (current?.value ?? 0) + bowler.runs;
        int totalBalls = (current?.matches ?? 0) + currentBalls;
        
        double economy = (totalRuns / (totalBalls / 6.0));
        
        leaderboard[bowler.playerId] = TournamentLeaderboardEntry(
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
    
    // Team 1 bowlers bowled to Team 2
    processBowlers(team1Score.bowlers, match.team1Id, match.team1Name);
    // Team 2 bowlers bowled to Team 1
    processBowlers(team2Score.bowlers, match.team2Id, match.team2Name);
    
    final sorted = leaderboard.values.toList()
      // Sort ascending, lowest economy first
      ..sort((a, b) => a.average.compareTo(b.average));
    
    return sorted.take(10).toList();
  }

  /// Update bowling leaderboard for Best Bowling Figures in a match
  List<TournamentLeaderboardEntry> _updateBowlingFiguresLeaderboard(
    List<TournamentLeaderboardEntry> existing,
    MatchModel match,
    TeamScore team1Score,
    TeamScore team2Score,
  ) {
    // Best bowling figures is a single spell stat. E.g. "5/12"
    // So we don't aggregate across matches. We just check if their spell this match is better than their historically saved best spell, or better than others in leaderboard.
    
    // Using a list instead of map since a player theoretically could have multiple entries, but let's just keep their best 1.
    final bestSpells = <String, TournamentLeaderboardEntry>{};
    for (var entry in existing) {
      bestSpells[entry.playerId] = entry;
    }
    
    void processBowlers(List<BowlerStats> bowlers, String teamId, String teamName) {
      for (var bowler in bowlers) {
        if (bowler.playerId.isEmpty || bowler.playerId.startsWith('p_')) continue;
        if (bowler.wickets == 0) continue; // Must take at least 1 wicket
        
        final currentBest = bestSpells[bowler.playerId];
        
        bool isBetterSpell = false;
        if (currentBest == null) {
          isBetterSpell = true;
        } else {
          // Compare spells. More wickets = better. Tiebreaker = fewer runs.
          if (bowler.wickets > currentBest.value) {
            isBetterSpell = true;
          } else if (bowler.wickets == currentBest.value && bowler.runs < currentBest.matches) {
            // Using `matches` to store the runs for the "Best Figures" entry temporarily.
            isBetterSpell = true; 
          }
        }
        
        if (isBetterSpell) {
          bestSpells[bowler.playerId] = TournamentLeaderboardEntry(
            playerId: bowler.playerId,
            playerName: bowler.playerName,
            teamId: teamId,
            teamName: teamName,
            value: bowler.wickets,
            matches: bowler.runs, // store runs here purely for sorting/tiebreakers
            description: '${bowler.wickets}/${bowler.runs} (${bowler.overs.toStringAsFixed(1)})',
          );
        }
      }
    }
    
    processBowlers(team1Score.bowlers, match.team1Id, match.team1Name);
    processBowlers(team2Score.bowlers, match.team2Id, match.team2Name);
    
    final sorted = bestSpells.values.toList()
      ..sort((a, b) {
        // Sort descending by Wickets (value), then ascending by Runs (matches)
        int wicketCompare = b.value.compareTo(a.value);
        if (wicketCompare != 0) return wicketCompare;
        return a.matches.compareTo(b.matches); 
      });
      
    return sorted.take(10).toList();
  }

  
  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }
}
