import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/services/match_service.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../../../providers/scoring_provider.dart';
import '../../../widgets/player_selection_dialogs.dart';
import '../../../widgets/match_initialization_dialog.dart';
import '../../matches/match_highlights_generator_screen.dart';
import '../../../widgets/dialogs/super_over_tie_dialog.dart';


class MatchScoringTab extends StatefulWidget {
  final MatchModel match;

  const MatchScoringTab({super.key, required this.match});

  @override
  State<MatchScoringTab> createState() => _MatchScoringTabState();
}

class _MatchScoringTabState extends State<MatchScoringTab> {
  bool _hasCheckedInitialization = false;
  int _lastCompletedOver = -1;
  bool _inningsEndDialogShown = false;
  bool _matchEndDialogShown = false;
  int _lastInnings = 1;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScoringProvider>().onMatchTie = _handleMatchTie;
        context.read<ScoringProvider>().onSuperOverTie = _handleSuperOverTie;
      }
    });
  }
  
  void _handleMatchTie(MatchModel match) {
    final provider = context.read<ScoringProvider>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
        title: Row(
          children: [
            Icon(Icons.sports_cricket, color: Colors.amber, size: 28.sp),
            SizedBox(width: 12.w),
            Text('Match Tied!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Scores are level at ${match.team1Score.runs}/${match.team1Score.wickets}.\n\nDo you want to play a Super Over?',
          style: TextStyle(color: Colors.white70, fontSize: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.resolveTie(match, false);
            },
            child: const Text('No, End as Tie', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.resolveTie(match, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Super Over'),
          ),
        ],
      ),
    );
  }

  void _handleSuperOverTie(MatchModel match) async {
    final provider = context.read<ScoringProvider>();
    
    final decision = await showDialog<SuperOverTieDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SuperOverTieDialog(match: match),
    );
    
    if (decision == null) return; // Should not happen (barrierDismissible: false)
    
    switch (decision) {
      case SuperOverTieDecision.playAnother:
        provider.resolveSuperOverTie(match, playAnother: true);
        break;
      case SuperOverTieDecision.declareTie:
        provider.resolveSuperOverTie(match, playAnother: false);
        break;
    }
  }
  

  @override
  Widget build(BuildContext context) {
    // Note: ScoringProvider is provided by the parent LiveScoringScreen
    final match = widget.match;
    final matchService = MatchService();
    
    // Check if match needs initialization (no batters playing)
    _checkMatchInitialization(context, match);
    
    // Check if over completed (for bowler change)
    _checkOverCompletion(context, match);
    
    // Check for innings end
    _checkInningsEnd(context, match);
    
    // Check for match end
    _checkMatchEnd(context, match);
    
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final battingTeamName = isTeam1Batting ? match.team1Name : match.team2Name;
    final bowlingTeamName = isTeam1Batting ? match.team2Name : match.team1Name;
    final score = isTeam1Batting ? match.team1Score : match.team2Score;
    final bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;
    
    // Get current batters
    final currentBatters = score.batters.where((b) => b.isPlaying && !b.isOut).toList();
    final striker = currentBatters.firstWhere((b) => b.isOnStrike, 
        orElse: () => currentBatters.isNotEmpty ? currentBatters.first : BatterStats(playerId: '', playerName: 'Select Striker'));
    final nonStriker = currentBatters.where((b) => !b.isOnStrike).firstOrNull ?? 
        BatterStats(playerId: '', playerName: 'Select Non-Striker');
    
    // Get current bowler
    final currentBowler = bowlingScore.bowlers.firstWhere((b) => b.isBowling, 
        orElse: () => BowlerStats(playerId: '', playerName: 'Select Bowler'));
    
    // Get this over balls
    final thisOverBalls = match.ballByBall.where((b) => 
      b.overNumber == match.currentOver && 
      b.battingTeam == (match.currentBattingTeam == 'team1' ? match.team1Id : match.team2Id)
    ).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Score Card Area with Options Button
          Stack(
            alignment: Alignment.topRight,
            children: [
              _buildScoreHeader(match, battingTeamName, bowlingTeamName, score),
              Padding(
                padding: EdgeInsets.all(8.0.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.swap_horiz, color: Colors.white70),
                      tooltip: 'Swap Strike',
                      onPressed: () {
                        context.read<ScoringProvider>().swapStrike();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Strike swapped'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, color: Colors.white70),
                      onPressed: () => _showMoreOptions(context, matchService),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Current Players Section
          _buildPlayersSection(context, match, striker, nonStriker, currentBowler, score, bowlingScore, thisOverBalls),

          SizedBox(height: 12.h),

          // Scoring Keypad
          Consumer<ScoringProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return Center(child: Padding(
                  padding: EdgeInsets.all(32.0.w),
                  child: CircularProgressIndicator(),
                ));
              }
              
              return _buildScoringKeypad(context, provider, match, score, bowlingScore);
            },
          ),
        ],
      ),
    );
  }
  
  /// Check if match needs initialization (opening batsmen and bowler)
  void _checkMatchInitialization(BuildContext context, MatchModel match) {
    if (_hasCheckedInitialization) return;
    
    final provider = context.read<ScoringProvider>();
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final score = isTeam1Batting ? match.team1Score : match.team2Score;
    final bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;
    
    // Check if batters are playing
    final hasPlayingBatters = score.batters.any((b) => b.isPlaying && !b.isOut);
    final hasBowling = bowlingScore.bowlers.any((b) => b.isBowling);
    
    // If no batters playing and match has no current progress (0 balls), show initialization dialog
    if (!hasPlayingBatters && match.currentOver == 0 && match.currentBall == 0) {
      _hasCheckedInitialization = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => MatchInitializationDialog(match: match),
        );
        
        if (result != null && context.mounted) {
          // Initialize players in provider
          provider.setCurrentPlayers(
            strikerId: result['strikerId'],
            strikerName: result['strikerName'],
            nonStrikerId: result['nonStrikerId'],
            nonStrikerName: result['nonStrikerName'],
            bowlerId: result['bowlerId'],
            bowlerName: result['bowlerName'],
            matchId: match.id,
          );
          
          // Save opening players to Firebase
          await _saveOpeningPlayers(match, result);
          
          // Trigger match start notification to followers
          if (match.currentInnings == 1 && match.currentOver == 0 && match.currentBall == 0) {
            await FirebaseDataService.instance.notifyFollowersOfMatchStart(match);
          }
        }
      });
    } else {
      _hasCheckedInitialization = true;
      // Restore current players to provider from match data
      final striker = score.batters.where((b) => b.isPlaying && b.isOnStrike).firstOrNull;
      final nonStriker = score.batters.where((b) => b.isPlaying && !b.isOnStrike).firstOrNull;
      final bowler = bowlingScore.bowlers.where((b) => b.isBowling).firstOrNull;
      
      if (provider.currentStrikerId == null && striker != null) {
        provider.setCurrentPlayers(
          strikerId: striker.playerId, 
          strikerName: striker.playerName,
          matchId: match.id,
        );
      }
      if (provider.currentNonStrikerId == null && nonStriker != null) {
        provider.setCurrentPlayers(
          nonStrikerId: nonStriker.playerId, 
          nonStrikerName: nonStriker.playerName,
          matchId: match.id,
        );
      }
      if (provider.currentBowlerId == null && bowler != null) {
        provider.setCurrentPlayers(
          bowlerId: bowler.playerId, 
          bowlerName: bowler.playerName,
          matchId: match.id,
        );
      }
    }
  }
  
  Future<void> _saveOpeningPlayers(MatchModel match, Map<String, dynamic> players) async {
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final score = isTeam1Batting ? match.team1Score : match.team2Score;
    final bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;
    
    // Update batting squad - preserve existing but mark openers
    final updatedBatters = [...score.batters];
    
    // Find or add striker
    final strikerId = players['strikerId'];
    final strikerIndex = updatedBatters.indexWhere((b) => b.playerId == strikerId);
    if (strikerIndex >= 0) {
      updatedBatters[strikerIndex] = updatedBatters[strikerIndex].copyWith(
        isPlaying: true,
        isOnStrike: true,
      );
    } else {
      updatedBatters.add(BatterStats(
        playerId: strikerId,
        playerName: players['strikerName'],
        isPlaying: true,
        isOnStrike: true,
      ));
    }
    
    // Find or add non-striker
    final nonStrikerId = players['nonStrikerId'];
    final nonStrikerIndex = updatedBatters.indexWhere((b) => b.playerId == nonStrikerId);
    if (nonStrikerIndex >= 0) {
      updatedBatters[nonStrikerIndex] = updatedBatters[nonStrikerIndex].copyWith(
        isPlaying: true,
        isOnStrike: false,
      );
    } else {
      updatedBatters.add(BatterStats(
        playerId: nonStrikerId,
        playerName: players['nonStrikerName'],
        isPlaying: true,
        isOnStrike: false,
      ));
    }
    
    // Update bowling squad - preserve existing but mark current bowler
    final updatedBowlers = [...bowlingScore.bowlers];
    final bowlerId = players['bowlerId'];
    final bowlerIndex = updatedBowlers.indexWhere((b) => b.playerId == bowlerId);
    if (bowlerIndex >= 0) {
      updatedBowlers[bowlerIndex] = updatedBowlers[bowlerIndex].copyWith(
        isBowling: true,
      );
    } else {
      updatedBowlers.add(BowlerStats(
        playerId: bowlerId,
        playerName: players['bowlerName'],
        isBowling: true,
      ));
    }
    
    // Update batting score
    final updatedBattingScore = score.copyWith(batters: updatedBatters);
    
    // Update bowling score
    final updatedBowlingScore = bowlingScore.copyWith(bowlers: updatedBowlers);
    
    // Save to Firebase
    await FirebaseDataService.instance.updateMatch(match.id, {
      isTeam1Batting ? 'team1Score' : 'team2Score': updatedBattingScore.toMap(),
      isTeam1Batting ? 'team2Score' : 'team1Score': updatedBowlingScore.toMap(),
    });
  }
  
  /// Check if innings has ended and prompt for transition
  void _checkInningsEnd(BuildContext context, MatchModel match) {
    if (match.matchFormat == 'Test') {
       if (match.currentInnings < 4 && !_inningsEndDialogShown) {
         final isTeam1Batting = match.currentBattingTeam == 'team1';
         final score = isTeam1Batting ? match.team1Score : match.team2Score;
         final isAllOut = score.wickets >= 10; // Simple check for now
         
         if (isAllOut) {
            _inningsEndDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showInningsEndDialog(context, match, score);
            });
         }
       }
    } else {
      // Limited Overs Logic
      // Check for end of 1st innings
      if (match.currentInnings == 1 && !_inningsEndDialogShown) {
        final isTeam1Batting = match.currentBattingTeam == 'team1';
        final score = isTeam1Batting ? match.team1Score : match.team2Score;
        
        final isAllOut = score.wickets >= 10 && score.wickets > 0;
        final areOversComplete = score.overs >= match.oversPerSide;
        
        if (isAllOut || areOversComplete) {
          _inningsEndDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showInningsEndDialog(context, match, score);
          });
        }
      }
    }
    
    // Reset flag on innings change
    if (match.currentInnings != _lastInnings) {
      // Transition just happened (e.g. 1->2, or 3->4)
      _lastInnings = match.currentInnings;
      _inningsEndDialogShown = false; // Reset for potential use if needed
      _hasCheckedInitialization = false; // Allow initialization check for new innings
      _lastCompletedOver = -1; // Reset for new innings
    }
  }

  /// Check if match has ended and show result dialog
  void _checkMatchEnd(BuildContext context, MatchModel match) {
    if (match.status == 'completed' && !_matchEndDialogShown) {
      _matchEndDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMatchEndDialog(context, match);
      });
    }
  }

  void _showMatchEndDialog(BuildContext context, MatchModel match) {
    final winner = match.winnerTeam ?? 'Match Complete';
    final margin = match.winningMargin;
    final isTied = winner == 'Match Tied';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppTheme.primaryOrange.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Animation
              SizedBox(
                height: 180.h,
                child: lottie.Lottie.network(
                  'https://assets9.lottiefiles.com/packages/lf20_toum7guv.json', // Trophy/Celebration
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.emoji_events, 
                    size: 100.sp, 
                    color: AppTheme.primaryOrange
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                winner,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
              if (!isTied && margin.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  'won by $margin',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              // Match Summary Row
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTeamFinalScore(match.team1Name, match.team1Score),
                    Container(height: 30.h, width: 1.w, color: Colors.grey[300]),
                    _buildTeamFinalScore(match.team2Name, match.team2Score),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              if (FirebaseAuth.instance.currentUser != null &&
                  (match.createdBy == FirebaseAuth.instance.currentUser!.uid ||
                   match.adminIds.contains(FirebaseAuth.instance.currentUser!.uid))) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog first
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MatchHighlightsGeneratorScreen(matchId: match.id),
                        ),
                      );
                    },
                    icon: Icon(Icons.auto_awesome),
                    label: const Text('GENERATE HIGHLIGHTS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOrange,
                      side: BorderSide(color: AppTheme.primaryOrange, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Exit Live Scoring screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Back to Matches',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamFinalScore(String name, TeamScore score) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        SizedBox(height: 4.h),
        Text(
          '${score.runs}/${score.wickets}',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showInningsEndDialog(BuildContext context, MatchModel match, TeamScore score) {
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final teamName = isTeam1Batting ? match.team1Name : match.team2Name;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InningsEndDialog(
        match: match,
        score: score,
        teamName: teamName,
        onStartSecondInnings: () {
          context.read<ScoringProvider>().changeInnings(match);
        },
      ),
    );
  }

  /// Check if over is completed and prompt for next bowler
  void _checkOverCompletion(BuildContext context, MatchModel match) {
    // When ball goes to 0 and over increases, it means over just completed
    if (match.currentBall == 0 && match.currentOver > _lastCompletedOver && match.currentOver > 0) {
      final isTeam1Batting = match.currentBattingTeam == 'team1';
      final score = isTeam1Batting ? match.team1Score : match.team2Score;
      
      // Only prompt for bowler change if innings is still going (not all out or overs complete)
      // FIX: Default to 10 wickets check
      final isAllOut = score.wickets >= 10;
      final areOversComplete = score.overs >= match.oversPerSide;
      if (isAllOut || areOversComplete) return; 
      
      _lastCompletedOver = match.currentOver;
      
      final provider = context.read<ScoringProvider>();
      // isTeam1Batting is already declared above
      final bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Get available bowlers - first check if we have them in the score
        List<BowlerStats> availableBowlers = [...bowlingScore.bowlers];
        
        // If scorecard only has the previous bowler, try to fetch the full team
        final isTeam1Bowling = match.bowlingTeam == 'team1';
        final teamId = isTeam1Bowling ? match.team1Id : match.team2Id;
        
        if (teamId.isNotEmpty && teamId != 't1' && teamId != 't2') {
          final team = await FirebaseDataService.instance.getTeamById(teamId);
          if (team != null) {
            // Find players not already in the bowlers list
            final existingBowlerIds = availableBowlers.map((b) => b.playerId).toSet();
            final teamBowlers = team.players
                .where((p) {
                  final playerId = p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}';
                  return !existingBowlerIds.contains(playerId);
                })
                .map((p) => BowlerStats(
                  playerId: p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}',
                  playerName: p.name,
                ))
                .toList();
            
            availableBowlers.addAll(teamBowlers);
          }
        }
        
        if (!context.mounted) return;

        // NEW: Also check batters list of the bowling team (useful for 2nd innings or if players added via batting)
        // If Team 1 is bowling, their players are in team1Score.batters
        final scoreOfBowlingTeam = isTeam1Batting ? match.team1Score : match.team2Score; // This is BATTING team
        final bowlingTeamScore = isTeam1Batting ? match.team2Score : match.team1Score; // This is BOWLING team
        
        // We want potential bowlers from the team that is currently BOWLING.
        // If it's 2nd innings, the bowling team (Team 1) has already batted, so their players are in team1Score.batters.
        // Even if 1st innings, if we added players to squad, they might be in batters list (as "yet to bat").
        
        final potentialBowlersFromBatting = bowlingTeamScore.batters;
        final existingBowlerIds = availableBowlers.map((b) => b.playerId).toSet();
        
        for (var batter in potentialBowlersFromBatting) {
           if (!existingBowlerIds.contains(batter.playerId) && batter.playerName != 'Batsman') {
             availableBowlers.add(BowlerStats(
               playerId: batter.playerId,
               playerName: batter.playerName,
             ));
             existingBowlerIds.add(batter.playerId); 
           }
        }


        final result = await showDialog<BowlerStats>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => EndOfOverBowlerDialog(
            bowlers: availableBowlers,
            lastBowlerId: provider.currentBowlerId,
          ),
        );
        
        if (result != null && context.mounted) {
          provider.changeBowler(
            result.playerId, 
            bowlerName: result.playerName, 
            matchId: match.id,
          );
          
          // Update bowling state in Firebase
          final updatedBowlers = availableBowlers.map((b) {
            if (b.playerId == result.playerId) {
              return b.copyWith(isBowling: true);
            }
            return b.copyWith(isBowling: false);
          }).toList();
          
          await FirebaseDataService.instance.updateMatch(match.id, {
            'currentBowlerId': result.playerId,
            isTeam1Batting ? 'team2Score' : 'team1Score': bowlingScore.copyWith(bowlers: updatedBowlers).toMap(),
          });
        }
      });
    } else if (_lastCompletedOver < 0) {
      _lastCompletedOver = match.currentOver;
    }
  }
  
  // Cricbuzz-Style Theme Colors
  static const Color _stadiumBlack = Color(0xFF0A0A0F);
  static const Color _charcoal = Color(0xFF141418);
  static const Color _cardDark = Color(0xFF1C1C22);
  static const Color _glowOrange = Color(0xFFFF6B00);
  static const Color _glowOrangeDim = Color(0xFFCC5500);
  static const Color _liveRed = Color(0xFFFF3B30);
  static const Color _successGreen = Color(0xFF34C759);
  static const Color _boundaryBlue = Color(0xFF007AFF);
  static const Color _sixPurple = Color(0xFFAF52DE);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF8E8E93);
  static const Color _glassWhite = Color(0x1AFFFFFF);

  String _getInningsLabel(int innings) {
    if (innings == 1) return '1ST INNINGS';
    if (innings == 2) return '2ND INNINGS';
    return 'INNINGS $innings';
  }      

  Widget _buildScoreHeader(MatchModel match, String battingTeamName, String bowlingTeamName, TeamScore score) {
    final crr = score.overs > 0 ? score.runs / score.overs : 0.0;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        children: [
          // Header Texts
          Text(
            '${match.team1Name} vs ${match.team2Name}'.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            match.matchType.toUpperCase(),
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.sp, letterSpacing: 1),
          ),
          if (match.currentPowerplay != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF063A2D).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.w),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 14.sp, color: Colors.green),
                  SizedBox(width: 6.w),
                  Text(
                    '${match.currentPowerplay!.name.toUpperCase()} (${match.currentPowerplay!.startOver}-${match.currentPowerplay!.endOver})',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 16.h),
          
          // Main Score Card
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    // Batting Team Column
                    Expanded(
                      child: Column(
                        children: [
                          Text(battingTeamName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black87)),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${score.runs}', style: TextStyle(color: Colors.green, fontSize: 44.sp, fontWeight: FontWeight.bold, height: 1.1)),
                              Text('/${score.wickets}', style: TextStyle(color: Colors.black87, fontSize: 24.sp, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('${score.oversDisplay} Overs', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                          SizedBox(height: 8.h),
                          Text('CRR ${crr.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    
                    // VS Circle
                    Container(
                      width: 32.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200, width: 1.w),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                      ),
                      child: Center(
                        child: Text('VS', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: Colors.grey)),
                      ),
                    ),
                    
                    // Bowling Team Column
                    Expanded(
                      child: Column(
                        children: [
                          Text(bowlingTeamName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black87)),
                          SizedBox(height: 8.h),
                          if (match.currentInnings == 1) ...[
                            Text('--', style: TextStyle(color: Colors.black87, fontSize: 36.sp, fontWeight: FontWeight.bold, height: 1.1, letterSpacing: -1)),
                            Text('Yet to bat', style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                            SizedBox(height: 8.h),
                            Text('RRR -', style: TextStyle(color: Colors.grey, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('${match.currentBattingTeam == 'team1' ? match.team2Score.runs : match.team1Score.runs}', style: TextStyle(color: Colors.black87, fontSize: 36.sp, fontWeight: FontWeight.bold, height: 1.1)),
                                Text('/${match.currentBattingTeam == 'team1' ? match.team2Score.wickets : match.team1Score.wickets}', style: TextStyle(color: Colors.black87, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('${match.currentBattingTeam == 'team1' ? match.team2Score.oversDisplay : match.team1Score.oversDisplay} Overs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                            SizedBox(height: 8.h),
                            Text('RRR ${match.requiredRunRate.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Innings Badge (Overlapping bottom)
              Positioned(
                bottom: 0.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064132),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    _getInningsLabel(match.currentInnings).toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
          
          if (match.currentInnings == 2 && match.target != null && match.matchFormat != 'Test') ...[
             SizedBox(height: 12.h),
             Builder(builder: (context) {
               final runsNeeded = match.target! - score.runs;
               
               // Calculate actual balls bowled in the current over
               final overStr = score.overs.toStringAsFixed(1);
               final parts = overStr.split('.');
               final completedOvers = int.parse(parts[0]);
               final ballsInCurrentOver = parts.length > 1 ? int.parse(parts[1]) : 0;
               final ballsBowled = (completedOvers * 6) + ballsInCurrentOver;
               
               final totalBalls = match.oversPerSide * 6;
               final ballsRemaining = totalBalls - ballsBowled;
               
               if (runsNeeded <= 0 || ballsRemaining <= 0) return SizedBox.shrink();
               
               return Container(
                 padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.9),
                   borderRadius: BorderRadius.circular(20.r),
                 ),
                 child: Text(
                   '$battingTeamName needs $runsNeeded runs in $ballsRemaining balls',
                   style: TextStyle(
                     color: Color(0xFF064132),
                     fontSize: 14.sp,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               );
             }),
          ],

          SizedBox(height: 12.h),

          // Stats Bar Card
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumnCricbuzz('CRR', crr.toStringAsFixed(2)),
                Container(height: 36.h, width: 1.w, color: Colors.grey.shade200),
                _buildStatColumnCricbuzz(
                  'EXTRAS', 
                  '${score.extras.total}', 
                  subtext: '(B ${score.extras.byes}, LB ${score.extras.legByes}, WD ${score.extras.wides}, NB ${score.extras.noBalls})'
                ),
                Container(height: 36.h, width: 1.w, color: Colors.grey.shade200),
                _buildStatColumnCricbuzz('OVERS', '${match.oversPerSide}'),
              ],
            ),
          ),
          
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _buildStatColumnCricbuzz(String label, String value, {String? subtext}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 10.sp, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        SizedBox(height: 2.h),
        Text(value, style: TextStyle(color: Colors.black87, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        if (subtext != null) ...[
          SizedBox(height: 2.h),
          Text(subtext, style: TextStyle(color: Colors.grey, fontSize: 9.sp, fontWeight: FontWeight.w500)),
        ]
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(color: _glowOrange, fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildTestMatchStatus(MatchModel match) {
    String label = 'STATUS';
    String value = '-';
    
    if (match.currentInnings == 1) {
      label = '1ST INNS';
      value = 'InProgress';
    } else if (match.currentInnings == 2) {
      // Trail/Lead
      final battingTeamScore = match.currentBattingTeam == 'team1' ? match.team1Score : match.team2Score;
      final bowlingTeamScore = match.currentBattingTeam == 'team1' ? match.team2FirstInningsScore : match.team1FirstInningsScore; // Opponent 1st innings
      
      final diff = battingTeamScore.runs - (bowlingTeamScore?.runs ?? 0);
      if (diff < 0) {
        label = 'TRAIL BY';
        value = '${-diff}';
      } else {
        label = 'LEAD BY';
        value = '$diff';
      }
    } else if (match.currentInnings == 3) {
      // Inn 3: Team 1 batting (usually). 
      // Lead = (T1_Inn1 + T1_Inn2_Current) - T2_Inn1
      final t1Inn1 = match.team1FirstInningsScore?.runs ?? 0;
      final t1Inn2 = match.team1Score.runs;
      final t2Inn1 = match.team2FirstInningsScore?.runs ?? 0;
      
      final lead = (t1Inn1 + t1Inn2) - t2Inn1;
       if (lead < 0) {
        label = 'TRAIL BY';
        value = '${-lead}';
      } else {
        label = 'LEAD BY';
        value = '$lead';
      }
    } else if (match.currentInnings == 4) {
      // Inn 4: Chase
      final target = match.target ?? 0;
      final runsInfo = match.requiredRunRate; // Not useful for Test
      final runsNeeded = target - (match.currentBattingTeam == 'team1' ? match.team1Score.runs : match.team2Score.runs);
      label = 'NEED';
      value = '$runsNeeded';
    }

    return _buildStatColumn(label, value);
  }
  
  Widget _buildGlassStatCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w600, letterSpacing: 1)),
          SizedBox(height: 2.h),
          Text(value, style: TextStyle(color: color, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'monospace',
            shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)])),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
        SizedBox(height: 2.h),
        Text(value, style: TextStyle(color: color, fontSize: 18.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildPlayersSection(
    BuildContext context, 
    MatchModel match,
    BatterStats striker, 
    BatterStats nonStriker, 
    BowlerStats bowler,
    TeamScore battingScore,
    TeamScore bowlingScore,
    List<BallEvent> thisOverBalls,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Batsmen Panel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports_cricket, size: 14.sp, color: Color(0xFF064132)),
                      SizedBox(width: 6.w),
                      Text('BATSMEN', style: TextStyle(color: Color(0xFF064132), fontSize: 11.sp, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildBatsmanRowCricbuzz(striker, isStriker: true, onTap: () => _showBatterSelector(context, match, battingScore, 'striker')),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Divider(height: 1.h, color: Color(0xFFF5F5F5)),
                  ),
                  _buildBatsmanRowCricbuzz(nonStriker, isStriker: false, onTap: () => _showBatterSelector(context, match, battingScore, 'non-striker')),
                ],
              ),
            ),
            Container(width: 1.w, color: Colors.grey.shade200, margin: EdgeInsets.symmetric(horizontal: 12.w)),
            // Bowler Panel
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports_baseball, size: 14.sp, color: Color(0xFF064132)),
                      SizedBox(width: 6.w),
                      Text('BOWLER', style: TextStyle(color: Color(0xFF064132), fontSize: 11.sp, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildBowlerRowCricbuzz(bowler, onTap: () => _showBowlerSelector(context, match, bowlingScore)),
                  const Spacer(),
                  SizedBox(height: 12.h),
                  // This Over inline
                  Row(
                    children: [
                      Text('This Over:', style: TextStyle(color: Colors.grey, fontSize: 10.sp, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: thisOverBalls.map((b) => _buildMiniBallCircle(b)).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatsmanRowCricbuzz(BatterStats batter, {required bool isStriker, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (isStriker)
            Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: Icon(Icons.star, size: 10.sp, color: Colors.white),
            )
          else
            SizedBox(width: 20.w),
          Expanded(
            child: Text(
              batter.playerName,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13.sp,
                fontWeight: isStriker ? FontWeight.bold : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${batter.runs}',
                style: TextStyle(color: Colors.black87, fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
              Text(
                ' (${batter.balls})',
                style: TextStyle(color: Colors.grey, fontSize: 10.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerRowCricbuzz(BowlerStats bowler, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              bowler.playerName,
              style: TextStyle(color: Colors.black87, fontSize: 13.sp, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${bowler.oversDisplay}-${bowler.maidens}-${bowler.runs}-${bowler.wickets}',
            style: TextStyle(color: Colors.green, fontSize: 12.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBallCircle(BallEvent ball) {
    Color bgColor = Colors.grey.shade200;
    Color textColor = Colors.black87;
    String label = '${ball.runs}';
    
    if (ball.wicket != null) {
      bgColor = Colors.red;
      textColor = Colors.white;
      label = 'W';
    } else if (ball.extraType == 'wide') {
      bgColor = Colors.orange;
      textColor = Colors.white;
      label = ball.totalRuns > 1 ? 'WD+${ball.totalRuns - 1}' : 'WD';
    } else if (ball.extraType == 'no-ball') {
      bgColor = Colors.orange;
      textColor = Colors.white;
      label = ball.totalRuns > 1 ? 'NB+${ball.runs}' : 'NB';
    } else if (ball.extraType == 'bye' || ball.extraType == 'leg-bye') {
      bgColor = Colors.purple.shade100;
      textColor = Colors.purple.shade800;
      label = '${ball.totalRuns}${ball.extraType == 'leg-bye' ? 'LB' : 'B'}';
    } else if (ball.runs == 4) {
      bgColor = Colors.blue;
      textColor = Colors.white;
      label = '4';
    } else if (ball.runs == 6) {
      bgColor = Colors.green;
      textColor = Colors.white;
      label = '6';
    }

    return Container(
      margin: EdgeInsets.only(right: 4.w),
      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9.r)),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: textColor, fontSize: 8.sp, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  
  Widget _buildCyberPlayerCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String stats,
    required String detail,
    required bool isActive,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(isActive ? 0.5 : 0.2)),
          boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18.sp, color: color),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: isActive ? color : _textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(stats, style: TextStyle(fontSize: 14.sp, color: _textPrimary, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                      SizedBox(width: 8.w),
                      Text(detail, style: TextStyle(fontSize: 10.sp, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18.sp, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerChip(BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isActive,
    Color? color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color ?? (isActive ? _glowOrange.withOpacity(0.1) : _cardDark),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isActive ? _glowOrange.withOpacity(0.5) : _textSecondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: isActive ? _glowOrange : _textSecondary),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: isActive ? _glowOrange : _textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(fontSize: 11.sp, color: _textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 14.sp, color: _textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
  
  void _showBatterSelector(BuildContext context, MatchModel match, TeamScore battingScore, String type) async {
    final provider = context.read<ScoringProvider>();
    final excludeId = type == 'striker' ? provider.currentNonStrikerId : provider.currentStrikerId;
    
    // Get batters - first check if we have them in the score, otherwise fetch from team
    List<BatterStats> availableBatters = [...battingScore.batters];
    
    // If no batters in score, try to fetch from team
    if (availableBatters.isEmpty) {
      final isTeam1Batting = match.currentBattingTeam == 'team1';
      final teamId = isTeam1Batting ? match.team1Id : match.team2Id;
      
      if (teamId.isNotEmpty && teamId != 't1' && teamId != 't2') {
        final team = await FirebaseDataService.instance.getTeamById(teamId);
        if (team != null) {
          availableBatters = team.players.map((p) => BatterStats(
            playerId: p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}',
            playerName: p.name,
          )).toList();
        }
      }
    }
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => PlayerSelectionDialog(
        title: type == 'striker' ? 'Select Striker' : 'Select Non-Striker',
        batters: availableBatters,
        excludePlayerId: excludeId,
        showBatters: true,
        showBowlers: false,
      ),
    );
    
    if (result != null && result['player'] is BatterStats) {
      final batter = result['player'] as BatterStats;
      final isNew = result['isNew'] == true;
      final isTeam1Batting = match.currentBattingTeam == 'team1';
      
      // Always update the match with the selected player
      final currentScore = isTeam1Batting ? match.team1Score : match.team2Score;
      final existingBatter = currentScore.batters.where((b) => b.playerId == batter.playerId).firstOrNull;
      
      if (existingBatter == null || isNew) {
        // Add new player to match batters
        final newBatter = batter.copyWith(isPlaying: true, isOnStrike: type == 'striker');
        final updatedBatters = [...currentScore.batters.where((b) => b.playerId != batter.playerId), newBatter];
        final updatedScore = currentScore.copyWith(batters: updatedBatters);
        
        await FirebaseDataService.instance.updateMatch(match.id, {
          isTeam1Batting ? 'team1Score' : 'team2Score': updatedScore.toMap(),
        });
      }
      
      if (type == 'striker') {
        provider.setCurrentPlayers(
          strikerId: batter.playerId, 
          strikerName: batter.playerName,
          matchId: match.id,
        );
      } else {
        provider.setCurrentPlayers(
          nonStrikerId: batter.playerId, 
          nonStrikerName: batter.playerName,
          matchId: match.id,
        );
      }
    }
  }
  
  void _showBowlerSelector(BuildContext context, MatchModel match, TeamScore bowlingScore) async {
    final provider = context.read<ScoringProvider>();
    
    // Get bowlers - first check if we have them in the score, otherwise fetch from team
    List<BowlerStats> availableBowlers = [...bowlingScore.bowlers];
    
    // If no bowlers in score, try to fetch from team
    if (availableBowlers.isEmpty) {
      final isTeam1Bowling = match.bowlingTeam == 'team1';
      final teamId = isTeam1Bowling ? match.team1Id : match.team2Id;
      
      if (teamId.isNotEmpty && teamId != 't1' && teamId != 't2') {
        final team = await FirebaseDataService.instance.getTeamById(teamId);
        if (team != null) {
          availableBowlers = team.players.map((p) => BowlerStats(
            playerId: p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}',
            playerName: p.name,
          )).toList();
        }
      }
    }
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => PlayerSelectionDialog(
        title: 'Select Bowler',
        bowlers: availableBowlers,
        excludePlayerId: provider.lastOverBowlerId, // Can't bowl consecutive overs
        showBatters: false,
        showBowlers: true,
      ),
    );
    
    if (result != null && result['player'] is BowlerStats) {
      final bowler = result['player'] as BowlerStats;
      final isNew = result['isNew'] == true;
      final isTeam1Bowling = match.bowlingTeam == 'team1';
      
      // Always update the match with the selected bowler
      final currentScore = isTeam1Bowling ? match.team1Score : match.team2Score;
      final existingBowler = currentScore.bowlers.where((b) => b.playerId == bowler.playerId).firstOrNull;
      
      if (existingBowler == null || isNew) {
        // Add new bowler to match
        final newBowler = bowler.copyWith(isBowling: true);
        final updatedBowlers = [...currentScore.bowlers.where((b) => b.playerId != bowler.playerId), newBowler];
        final updatedScore = currentScore.copyWith(bowlers: updatedBowlers);
        
        await FirebaseDataService.instance.updateMatch(match.id, {
          isTeam1Bowling ? 'team1Score' : 'team2Score': updatedScore.toMap(),
        });
      }
      
      provider.setCurrentPlayers(
        bowlerId: bowler.playerId, 
        bowlerName: bowler.playerName,
        matchId: match.id,
      );
    }
  }
  
  Widget _buildThisOverSection(BuildContext context, List<BallEvent> balls, MatchModel match) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      color: _stadiumBlack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('OVER ${match.currentOver + 1}', 
                    style: TextStyle(color: _glowOrange, fontWeight: FontWeight.bold, fontSize: 12.sp, letterSpacing: 1.5,
                      shadows: [Shadow(color: _glowOrange.withOpacity(0.5), blurRadius: 6)])),
                  SizedBox(width: 12.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: _glassWhite,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text('${balls.length}/6', style: TextStyle(color: _textSecondary, fontSize: 11.sp, fontFamily: 'monospace')),
                  ),
                ],
              ),
              if (balls.length >= 6)
                SizedBox.shrink(),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 42.h,
            child: balls.isEmpty 
              ? Center(child: Text('AWAITING DELIVERY', style: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 12.sp, letterSpacing: 1)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: balls.length,
                  itemBuilder: (context, index) {
                    final ball = balls[index];
                    return _buildCyberBallChip(ball);
                  },
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCyberBallChip(BallEvent ball) {
    Color color = _glowOrange;
    String label = ball.displayString;
    
    if (ball.wicket != null) { 
      color = _liveRed;
      label = 'W';
    } else if (ball.runs == 4 && ball.extraType == null) { 
      color = const Color(0xFF3B82F6);
    } else if (ball.runs == 6 && ball.extraType == null) { 
      color = _sixPurple;
    } else if (ball.extraType == 'wide' || ball.extraType == 'no-ball') {
      color = _glowOrangeDim;
    } else if (ball.extraType == 'bye' || ball.extraType == 'leg-bye') {
      color = const Color(0xFFA855F7);
    } else if (ball.runs == 0) {
      color = _textSecondary;
    }
    
    return Container(
      margin: EdgeInsets.only(right: 10.w),
      constraints: BoxConstraints(minWidth: 42),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5.w),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10)],
      ),
      child: Center(
        child: Text(
          label, 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: 'monospace',
            shadows: [Shadow(color: color.withOpacity(0.7), blurRadius: 6)]),
        ),
      ),
    );
  }
  
  Widget _buildBallChip(BallEvent ball) {
    Color bgColor = _cardDark;
    Color textColor = _textPrimary;
    String label = ball.displayString;
    
    if (ball.wicket != null) { 
      bgColor = _liveRed.withOpacity(0.2);
      textColor = _liveRed;
      label = 'W';
    } else if (ball.runs == 4 && ball.extraType == null) { 
      bgColor = const Color(0xFF3B82F6).withOpacity(0.2);
      textColor = const Color(0xFF3B82F6);
    } else if (ball.runs == 6 && ball.extraType == null) { 
      bgColor = _sixPurple.withOpacity(0.2);
      textColor = _sixPurple;
    } else if (ball.extraType == 'wide' || ball.extraType == 'no-ball') {
      bgColor = _glowOrangeDim.withOpacity(0.2);
      textColor = _glowOrangeDim;
    } else if (ball.extraType == 'bye' || ball.extraType == 'leg-bye') {
      bgColor = const Color(0xFFA855F7).withOpacity(0.2);
      textColor = const Color(0xFFA855F7);
    }
    
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      constraints: BoxConstraints(minWidth: 36),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: textColor.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          label, 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.sp),
        ),
      ),
    );
  }
  
  void _showEndOverDialog(BuildContext context, MatchModel match) async {
    final provider = context.read<ScoringProvider>();
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;
    
    final result = await showDialog<BowlerStats>(
      context: context,
      builder: (ctx) => ChangeBowlerDialog(
        bowlers: bowlingScore.bowlers,
        currentBowlerId: provider.currentBowlerId,
        lastOverBowlerId: provider.currentBowlerId, // Current bowler can't bowl next over
      ),
    );
    
    if (result != null) {
      await provider.endOver(match, result.playerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.playerName} will bowl the next over'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Widget _buildTargetInfo(MatchModel match) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text('Need', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
              Text('${match.runsRequired}', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(width: 1.w, height: 30.h, color: Colors.orange.shade200),
          Column(
            children: [
              Text('From', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
              Text('${match.ballsRemaining}', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(width: 1.w, height: 30.h, color: Colors.orange.shade200),
          Column(
            children: [
              Text('RRR', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
              Text(match.requiredRunRate.toStringAsFixed(2), 
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoringKeypad(
    BuildContext context, 
    ScoringProvider provider, 
    MatchModel match,
    TeamScore battingScore,
    TeamScore bowlingScore,
  ) {
    // Check end conditions
    final maxWickets = match.currentInnings > 2 ? 2 : 10; // Super Over = 2 wickets
    final isAllOut = battingScore.wickets >= maxWickets;
    final areOversComplete = battingScore.overs >= match.oversPerSide;
    final targetReached = (match.currentInnings == 2 || match.currentInnings == 4) && battingScore.runs >= (match.target ?? 0);
    final matchFinished = match.status == 'completed';
    final isSuperOver = match.currentInnings >= 3;
    
    // Determine the result state for display
    if (matchFinished || isAllOut || areOversComplete || targetReached) {
      String message = "";
      
      // For 1st innings end, show innings complete
      if (match.currentInnings == 1 && (isAllOut || areOversComplete)) {
        message = "INNINGS COMPLETE";
        
        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_cardDark, _stadiumBlack], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            boxShadow: [BoxShadow(color: _glowOrange.withOpacity(0.1), blurRadius: 20, offset: Offset(0, -5))],
          ),
          child: Column(
            children: [
              Text(message, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: _liveRed, letterSpacing: 2,
                shadows: [Shadow(color: _liveRed.withOpacity(0.5), blurRadius: 12)])),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: _buildNeonButton(
                  'START 2ND INNINGS',
                  () => _showInningsEndDialog(context, match, battingScore),
                  _glowOrange,
                ),
              ),
            ],
          ),
        );
      }
      
      // For Super Over 1st innings (innings 3) end
      if (match.currentInnings == 3 && (isAllOut || areOversComplete)) {
        message = "SUPER OVER\n${battingScore.runs}/${battingScore.wickets}";
        
        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_cardDark, _stadiumBlack], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 20, offset: Offset(0, -5))],
          ),
          child: Column(
            children: [
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2,
                shadows: [Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 12)])),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: _buildNeonButton(
                  'START CHASE',
                  () => context.read<ScoringProvider>().changeInnings(match),
                  Colors.amber,
                ),
              ),
            ],
          ),
        );
      }
      
      // For 2nd innings end or Super Over chase (innings 4)
      if (matchFinished && match.winnerTeam != null) {
        message = match.winnerTeam == 'Match Tied'
            ? "MATCH TIED"
            : "${match.winnerTeam!.toUpperCase()} WON\nBY ${match.winningMargin.toUpperCase()}";
      } else if (targetReached) {
        final winningTeam = match.currentBattingTeam == 'team1' ? match.team1Name : match.team2Name;
        final remainingWickets = maxWickets - battingScore.wickets;
        final marginText = isSuperOver ? 'Super Over ($remainingWickets wickets)' : '$remainingWickets WICKETS';
        message = "${winningTeam.toUpperCase()} WON\nBY $marginText";
      } else if (isAllOut || areOversComplete) {
        final target = match.target ?? 0;
        if (battingScore.runs == target - 1) {
          message = isSuperOver ? "SUPER OVER TIED" : "MATCH TIED";
        } else {
          final winningTeam = match.currentBattingTeam == 'team1' ? match.team2Name : match.team1Name;
          final runDiff = (target - 1) - battingScore.runs;
          final marginText = isSuperOver ? 'Super Over ($runDiff runs)' : '$runDiff RUNS';
          message = "${winningTeam.toUpperCase()} WON\nBY $marginText";
        }
      }

      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_cardDark, _stadiumBlack], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          boxShadow: [BoxShadow(color: _glowOrange.withOpacity(0.1), blurRadius: 20, offset: Offset(0, -5))],
        ),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: _liveRed, letterSpacing: 2,
              shadows: [Shadow(color: _liveRed.withOpacity(0.5), blurRadius: 12)])),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: _buildNeonButton(
                'VIEW RESULT',
                () => _showMatchEndDialog(context, match),
                _glowOrange,
              ),
            ),
            if (FirebaseAuth.instance.currentUser != null &&
                (match.createdBy == FirebaseAuth.instance.currentUser!.uid ||
                 match.adminIds.contains(FirebaseAuth.instance.currentUser!.uid))) ...[
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: _buildNeonButton(
                  'GENERATE HIGHLIGHTS',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchHighlightsGeneratorScreen(matchId: match.id),
                      ),
                    );
                  },
                  Colors.amber,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Row 1: Singles/Dots
            Row(
              children: [
                Expanded(child: _buildPillBtn('0', () => provider.scoreBall(match, runs: 0), bgColor: Colors.white, textColor: Colors.black87, borderColor: Colors.grey.shade300)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('1', () => provider.scoreBall(match, runs: 1), bgColor: Colors.white, textColor: Colors.black87, borderColor: Colors.grey.shade300)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('2', () => provider.scoreBall(match, runs: 2), bgColor: Colors.white, textColor: Colors.black87, borderColor: Colors.grey.shade300)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('3', () => provider.scoreBall(match, runs: 3), bgColor: Colors.white, textColor: Colors.black87, borderColor: Colors.grey.shade300)),
              ],
            ),
            SizedBox(height: 12.h),
            // Row 2: Boundaries
            Row(
              children: [
                Expanded(child: _buildPillBtn('4', () => provider.scoreBall(match, runs: 4), bgColor: Colors.blue, textColor: Colors.white)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('6', () => provider.scoreBall(match, runs: 6), bgColor: Colors.green, textColor: Colors.white)),
              ],
            ),
            SizedBox(height: 12.h),
            // Row 2: Extras
            Row(
              children: [
                Expanded(child: _buildPillBtn('WIDE', () => _showWideDialog(context, provider, match), bgColor: Colors.orange.shade50, textColor: Colors.orange.shade800, borderColor: Colors.orange.shade200)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('NO BALL', () => _showNoBallDialog(context, provider, match), bgColor: Colors.orange.shade50, textColor: Colors.orange.shade800, borderColor: Colors.orange.shade200)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('BYES', () => _showByeDialog(context, provider, match, false), bgColor: Colors.orange.shade50, textColor: Colors.orange.shade800, borderColor: Colors.orange.shade200)),
                SizedBox(width: 8.w),
                Expanded(child: _buildPillBtn('LEG BYES', () => _showByeDialog(context, provider, match, true), bgColor: Colors.orange.shade50, textColor: Colors.orange.shade800, borderColor: Colors.orange.shade200)),
              ],
            ),
            SizedBox(height: 12.h),
            // Row 3: Wicket & Undo
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildPillBtn('WICKET', () => _showWicketDialog(context, provider, match, battingScore, bowlingScore), bgColor: Colors.red, textColor: Colors.white),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildPillBtn(
                    'UNDO',
                    () async {
                      final success = await provider.undoLastBall(match);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Last ball undone'), duration: Duration(seconds: 1)),
                        );
                      }
                    },
                    bgColor: Colors.white,
                    textColor: provider.canUndo ? Colors.black87 : Colors.grey,
                    borderColor: Colors.grey.shade300,
                    icon: Icons.undo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBtn(
    String label, 
    VoidCallback onTap, {
    required Color bgColor, 
    required Color textColor, 
    Color? borderColor,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.r),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: [
            if (borderColor == null) // Add slight shadow for solid colored buttons
              BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 16.sp),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildNeonButton(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.15)]),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.6), width: 2.w),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)],
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: color, fontSize: 16.sp, fontWeight: FontWeight.bold, letterSpacing: 2,
            shadows: [Shadow(color: color.withOpacity(0.7), blurRadius: 8)])),
        ),
      ),
    );
  }

  
  void _showWideDialog(BuildContext context, ScoringProvider provider, MatchModel match) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wide Ball', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildExtraOption('WD', () {
                  Navigator.pop(ctx);
                  provider.scoreWide(match, additionalRuns: 0);
                }),
                _buildExtraOption('WD+1', () {
                  Navigator.pop(ctx);
                  provider.scoreWide(match, additionalRuns: 1);
                }),
                _buildExtraOption('WD+2', () {
                  Navigator.pop(ctx);
                  provider.scoreWide(match, additionalRuns: 2);
                }),
                _buildExtraOption('WD+3', () {
                  Navigator.pop(ctx);
                  provider.scoreWide(match, additionalRuns: 3);
                }),
                _buildExtraOption('WD+4', () {
                  Navigator.pop(ctx);
                  provider.scoreWide(match, additionalRuns: 4);
                }),
              ],
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
  
  void _showNoBallDialog(BuildContext context, ScoringProvider provider, MatchModel match) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No Ball', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildExtraOption('NB', () {
                  Navigator.pop(ctx);
                  provider.scoreNoBall(match, batsmanRuns: 0);
                }),
                _buildExtraOption('NB+1', () {
                  Navigator.pop(ctx);
                  provider.scoreNoBall(match, batsmanRuns: 1);
                }),
                _buildExtraOption('NB+2', () {
                  Navigator.pop(ctx);
                  provider.scoreNoBall(match, batsmanRuns: 2);
                }),
                _buildExtraOption('NB+4', () {
                  Navigator.pop(ctx);
                  provider.scoreNoBall(match, batsmanRuns: 4);
                }),
                _buildExtraOption('NB+6', () {
                  Navigator.pop(ctx);
                  provider.scoreNoBall(match, batsmanRuns: 6);
                }),
              ],
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
  
  void _showByeDialog(BuildContext context, ScoringProvider provider, MatchModel match, bool isLegBye) {
    final title = isLegBye ? 'Leg Bye' : 'Bye';
    final prefix = isLegBye ? 'LB' : 'B';
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildExtraOption('${prefix}1', () {
                  Navigator.pop(ctx);
                  if (isLegBye) {
                    provider.scoreLegBye(match, runs: 1);
                  } else {
                    provider.scoreBye(match, runs: 1);
                  }
                }),
                _buildExtraOption('${prefix}2', () {
                  Navigator.pop(ctx);
                  if (isLegBye) {
                    provider.scoreLegBye(match, runs: 2);
                  } else {
                    provider.scoreBye(match, runs: 2);
                  }
                }),
                _buildExtraOption('${prefix}3', () {
                  Navigator.pop(ctx);
                  if (isLegBye) {
                    provider.scoreLegBye(match, runs: 3);
                  } else {
                    provider.scoreBye(match, runs: 3);
                  }
                }),
                _buildExtraOption('${prefix}4', () {
                  Navigator.pop(ctx);
                  if (isLegBye) {
                    provider.scoreLegBye(match, runs: 4);
                  } else {
                    provider.scoreBye(match, runs: 4);
                  }
                }),
              ],
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExtraOption(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        minimumSize: Size(70, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
  
  void _showWicketDialog(
    BuildContext context, 
    ScoringProvider provider, 
    MatchModel match,
    TeamScore battingScore,
    TeamScore bowlingScore,
  ) async {
    // 0. Get current batsmen
    final currentBatters = battingScore.batters.where((b) => b.isPlaying && !b.isOut).toList();
    if (currentBatters.length < 2) return; // Should not happen
    
    final striker = currentBatters.firstWhere((b) => b.isOnStrike, orElse: () => currentBatters[0]);
    final nonStriker = currentBatters.firstWhere((b) => !b.isOnStrike, orElse: () => currentBatters[1]);

    // Step 1: Show dismissal type dialog
    final dismissalResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const DismissalTypeDialog(),
    );
    
    if (dismissalResult == null || !context.mounted) return;
    
    final String dismissalType = dismissalResult['type'];
    final bool needsFielder = dismissalResult['needsFielder'] ?? false;
    String? playerOutId;
    String? fielderName;
    bool crossed = false;
    int runsCompleted = 0;

    // Step 2: "Who is out?" (Crucial for Run Out, useful for others)
    if (dismissalType == 'run_out') {
      playerOutId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WhoIsOutDialog(striker: striker, nonStriker: nonStriker),
      );
      if (playerOutId == null || !context.mounted) return;

      // Ask for runs completed
      runsCompleted = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const RunOutRunsDialog(),
      ) ?? 0;
    } else {
      playerOutId = striker.playerId; // Default for most wickets
    }
    
    // Step 3: "Did they cross?" (For Caught and Run Out)
    if ((dismissalType == 'caught' || dismissalType == 'run_out') && context.mounted) {
      crossed = await showDialog<bool>(
        context: context,
        builder: (ctx) => const CrossingDialog(),
      ) ?? false;
    }

    // Step 4: If caught/stumped/run out, ask for fielder
    if (needsFielder && context.mounted) {
      // Get fielding team players
      List<BowlerStats> fieldingPlayers = [...bowlingScore.bowlers];
      
      // If no bowlers in score, try to fetch from team
      if (fieldingPlayers.isEmpty) {
        final isTeam1Bowling = match.bowlingTeam == 'team1';
        final teamId = isTeam1Bowling ? match.team1Id : match.team2Id;
        
        if (teamId.isNotEmpty && teamId != 't1' && teamId != 't2') {
          final team = await FirebaseDataService.instance.getTeamById(teamId);
          if (team != null) {
            fieldingPlayers = team.players.map((p) => BowlerStats(
              playerId: p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}',
              playerName: p.name,
            )).toList();
          }
        }
      }
      
      if (context.mounted) {
        final fielderLabel = dismissalType == 'stumped' ? 'Wicket Keeper' : 'Fielder';
        fielderName = await showDialog<String>(
          context: context,
          builder: (context) => FielderSelectionDialog(
            fieldingTeamPlayers: fieldingPlayers,
            fielderLabel: fielderLabel,
          ),
        );
        
        if (fielderName == null || !context.mounted) return;
      }
    }
    
    // Step 5: Score the wicket ball
    await provider.scoreBall(
      match, 
      runs: runsCompleted, 
      isWicket: true, 
      wicketType: dismissalType,
      fielderId: fielderName,
      playerOutId: playerOutId,
      crossed: crossed,
    );
    
    // Step 6: Show next batsman selection
    if (context.mounted) {
      await _showNewBatsmanDialog(context, provider, match, battingScore, playerOutId);
    }
  }
  
  Future<void> _showNewBatsmanDialog(
    BuildContext context, 
    ScoringProvider provider, 
    MatchModel initialMatch,
    TeamScore initialBattingScore,
    String? playerOutId,
  ) async {
    // Fetch latest match data to avoid overwriting wicket count from scoreBall
    final match = await FirebaseDataService.instance.getMatchById(initialMatch.id) ?? initialMatch;
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final battingScore = isTeam1Batting ? match.team1Score : match.team2Score;
    
    final teamName = isTeam1Batting ? match.team1Name : match.team2Name;
    final teamId = isTeam1Batting ? match.team1Id : match.team2Id;
    
    // Get available batters - those not currently playing and not out
    List<BatterStats> availableBatters = battingScore.batters.where(
      (b) => !b.isPlaying && !b.isOut
    ).toList();
    
    // If no available batters, try to fetch from team
    if (availableBatters.isEmpty && teamId.isNotEmpty && teamId != 't1' && teamId != 't2') {
      final team = await FirebaseDataService.instance.getTeamById(teamId);
      if (team != null) {
        // Find players not already in the match batters list
        final existingPlayerIds = battingScore.batters.map((b) => b.playerId).toSet();
        final teamBatters = team.players
            .where((p) {
              final playerId = p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}';
              return !existingPlayerIds.contains(playerId);
            })
            .map((p) => BatterStats(
              playerId: p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}',
              playerName: p.name,
            ))
            .toList();
        
        availableBatters.addAll(teamBatters);
      }
    }
    
    if (!context.mounted) return;
    
    final result = await showDialog<BatterStats>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NextBatsmanDialog(
        availableBatters: availableBatters,
        teamName: teamName,
      ),
    );
    
    if (result != null && context.mounted) {
      // Determine strike for the new batsman
      // If striker was out, new batsman usually takes strike (unless crossed in run out)
      // The provider already handled 'crossed' swap, so we just need to see who is currently 'isOnStrike'
      // in the latest match data for the remaining player.
      
      final remainingPlayer = battingScore.batters.firstWhere((b) => b.isPlaying && !b.isOut && b.playerId != playerOutId);
      final newBatterIsOnStrike = !remainingPlayer.isOnStrike;

      final newBatter = result.copyWith(isPlaying: true, isOnStrike: newBatterIsOnStrike);
      
      final updatedBatters = battingScore.batters.map((b) {
        return b; // Keep existing striker/non-striker as they are (one is OUT, one is STILL PLAYING)
      }).toList();
      
      // Add new batter if not already in list, else update
      final index = updatedBatters.indexWhere((b) => b.playerId == newBatter.playerId);
      if (index >= 0) {
        updatedBatters[index] = newBatter;
      } else {
        updatedBatters.add(newBatter);
      }
      
      // Save to Firebase
      final updatedScore = battingScore.copyWith(batters: updatedBatters);
      await FirebaseDataService.instance.updateMatch(match.id, {
        isTeam1Batting ? 'team1Score' : 'team2Score': updatedScore.toMap(),
        'currentStrikerId': newBatterIsOnStrike ? newBatter.playerId : remainingPlayer.playerId,
        'currentNonStrikerId': newBatterIsOnStrike ? remainingPlayer.playerId : newBatter.playerId,
      });
      
      // Update provider
      provider.setCurrentPlayers(
        strikerId: newBatterIsOnStrike ? newBatter.playerId : remainingPlayer.playerId,
        nonStrikerId: newBatterIsOnStrike ? remainingPlayer.playerId : newBatter.playerId,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.playerName} is the new batsman'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Widget _buildDismissalChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.red.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.red : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  void _showMoreOptions(BuildContext context, MatchService matchService) async {
    final provider = context.read<ScoringProvider>();
    final match = widget.match;
    
    if (match == null || !context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.repeat, color: AppTheme.primaryOrange),
              title: const Text('End Over'),
              subtitle: const Text('Change to next bowler'),
              onTap: () {
                Navigator.pop(context);
                _showEndOverDialog(context, match);
              },
            ),
            // Allow declaring/changing innings if not the final innings
            if (match.matchFormat == 'Test' ? match.currentInnings < 4 : match.currentInnings == 1)
              ListTile(
                leading: Icon(Icons.flag, color: Colors.orange),
                title: Text(match.matchFormat == 'Test' ? 'Declare Innings' : 'Change Innings'),
                subtitle: const Text('End current innings manually'),
                onTap: () async {
                  Navigator.pop(context);
                  _showInningsChangeDialog(context, provider, match);
                },
              ),
            ListTile(
              leading: Icon(Icons.flag, color: Colors.red),
              title: const Text('End Match'),
              subtitle: const Text('Complete the match with result'),
              onTap: () {
                Navigator.pop(context);
                _showEndMatchDialog(context, match);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showInningsChangeDialog(BuildContext context, ScoringProvider provider, MatchModel match) async {
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final battingScore = isTeam1Batting ? match.team1Score : match.team2Score;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => InningsChangeDialog(
        team1Name: isTeam1Batting ? match.team1Name : match.team2Name,
        team2Name: isTeam1Batting ? match.team2Name : match.team1Name,
        team1Score: battingScore.runs,
        team1Wickets: battingScore.wickets,
        team1Overs: battingScore.overs,
      ),
    );
    
    if (result == true) {
      await provider.changeInnings(match);
      if (context.mounted) {
        final nextInns = match.currentInnings + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Innings $nextInns started.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  void _showEndMatchDialog(BuildContext context, MatchModel match) {
    // TODO: Implement end match dialog with result selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('End match functionality coming soon')),
    );
  }
}
