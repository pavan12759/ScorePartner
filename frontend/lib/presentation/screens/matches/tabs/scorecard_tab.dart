import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/screens/profile/player_profile_screen.dart';

import 'package:scorepatner/presentation/widgets/dls_calculator_widget.dart';

class ScorecardTab extends StatefulWidget {
  final MatchModel match;

  const ScorecardTab({super.key, required this.match});
  
  @override
  State<ScorecardTab> createState() => _ScorecardTabState();
}

class _ScorecardTabState extends State<ScorecardTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TeamModel? _team1;
  TeamModel? _team2;
  bool _isLoadingTeams = true;

  @override
  void initState() {
    super.initState();
    _initTabController();
    _fetchTeams();
  }

  void _initTabController() {
    // If super over, we need 4 tabs: 1st Innings, 2nd Innings, SO Inn 1, SO Inn 2
    final isSuperOver = widget.match.isSuperOver || widget.match.currentInnings >= 3;
    final tabCount = isSuperOver ? 4 : 2;
    int initialIndex = 0;
    
    if (isSuperOver) {
      // Default to super over tabs
      initialIndex = widget.match.currentInnings == 4 ? 3 : 2;
    } else {
      initialIndex = widget.match.currentInnings == 2 ? 1 : 0;
    }
    
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: initialIndex);
  }

  Future<void> _fetchTeams() async {
    final service = FirebaseDataService.instance;
    final team1 = await service.getTeamById(widget.match.team1Id);
    final team2 = await service.getTeamById(widget.match.team2Id);
    
    if (mounted) {
      setState(() {
        _team1 = team1;
        _team2 = team2;
        _isLoadingTeams = false;
      });
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperOver = widget.match.isSuperOver || widget.match.currentInnings >= 3;
    
    // Determine which team batted first
    // Determine which team batted first
    bool team1BattedFirst = true;
    
    // Prioritize current game state for active innings to ensure UI matches scoring
    if (widget.match.status == 'live' && (widget.match.currentInnings == 1 || widget.match.currentInnings == 2)) {
      if (widget.match.currentInnings == 1) {
        team1BattedFirst = widget.match.currentBattingTeam == 'team1';
      } else {
        // In 2nd innings, the current batting team is batting 2nd
        // So team1 batted first if team1 is NOT currently batting
        team1BattedFirst = widget.match.currentBattingTeam != 'team1';
      }
    } else if (widget.match.tossWinnerId != null && widget.match.tossDecision != null) {
      if (widget.match.tossWinnerId == widget.match.team1Id) {
        team1BattedFirst = widget.match.tossDecision == 'bat';
      } else {
        team1BattedFirst = widget.match.tossDecision == 'field';
      }
    } else {
      // Fallback for edge cases or non-live matches without toss data
      if (widget.match.currentInnings == 2 && widget.match.currentBattingTeam == 'team1') {
        team1BattedFirst = false;
      }
    }

    // Get main match scores
    final mainTeam1Score = isSuperOver && widget.match.mainMatchScores != null
        ? widget.match.mainMatchScores!['team1']!
        : widget.match.team1Score;
    final mainTeam2Score = isSuperOver && widget.match.mainMatchScores != null
        ? widget.match.mainMatchScores!['team2']!
        : widget.match.team2Score;

    // Build main match innings views
    final firstInningsView = team1BattedFirst 
        ? _buildScorecardView(widget.match.team1Name, widget.match.team2Name, mainTeam1Score, mainTeam2Score, _team1)
        : _buildScorecardView(widget.match.team2Name, widget.match.team1Name, mainTeam2Score, mainTeam1Score, _team2);
        
    final secondInningsView = team1BattedFirst
        ? _buildScorecardView(widget.match.team2Name, widget.match.team1Name, mainTeam2Score, mainTeam1Score, _team2)
        : _buildScorecardView(widget.match.team1Name, widget.match.team2Name, mainTeam1Score, mainTeam2Score, _team1);

    // Build super over views if applicable
    Widget? superOverFirstInningsView;
    Widget? superOverSecondInningsView;
    
    if (isSuperOver) {
      superOverFirstInningsView = _buildScorecardView(
        '${widget.match.team1Name} (SO)',
        '${widget.match.team2Name} (SO)',
        widget.match.team1Score,
        widget.match.team2Score,
        _team1,
        isSuperOverInnings: true,
      );
      superOverSecondInningsView = _buildScorecardView(
        '${widget.match.team2Name} (SO)',
        '${widget.match.team1Name} (SO)',
        widget.match.team2Score,
        widget.match.team1Score,
        _team2,
        isSuperOverInnings: true,
      );
    }

    // Build tabs based on whether it's a super over
    final tabs = isSuperOver
        ? const [
            Tab(text: "1ST INNINGS"),
            Tab(text: "2ND INNINGS"),
            Tab(text: "S.O INN 1"),
            Tab(text: "S.O INN 2"),
          ]
        : const [
            Tab(text: "1ST INNINGS"),
            Tab(text: "2ND INNINGS"),
          ];

    final tabViews = isSuperOver
        ? [
            firstInningsView,
            secondInningsView,
            superOverFirstInningsView!,
            superOverSecondInningsView!,
          ]
        : [
            firstInningsView,
            secondInningsView,
          ];

    return Column(
      children: [
        Container(
          color: Colors.white.withOpacity(0.95),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppTheme.primaryOrange,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, letterSpacing: 0.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp, letterSpacing: 0.5),
            indicatorSize: TabBarIndicatorSize.tab,
            isScrollable: isSuperOver,
            tabs: tabs,
          ),
        ),
        Expanded(
          child: _isLoadingTeams 
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : TabBarView(
                controller: _tabController,
                children: tabViews,
              ),
        )
      ],
    );
  }
  
  Widget _buildScorecardView(String battingTeamName, String bowlingTeamName, TeamScore battingScore, TeamScore bowlingScore, TeamModel? team, {bool isSuperOverInnings = false}) {
    final teamBalls = widget.match.ballByBall.where((b) => b.battingTeam == team?.id).toList();
    
    Map<String, int> battingPositions = {};
    int wicketsFallen = 0;
    
    for (var ball in teamBalls) {
        if (!battingPositions.containsKey(ball.batsmanId)) {
            battingPositions[ball.batsmanId] = wicketsFallen == 0 ? (battingPositions.isEmpty ? 1 : 2) : wicketsFallen + 2;
        }
        
        if (ball.wicket != null) {
            if (!battingPositions.containsKey(ball.wicket!.playerId)) {
                battingPositions[ball.wicket!.playerId] = wicketsFallen == 0 ? (battingPositions.isEmpty ? 1 : 2) : wicketsFallen + 2;
            }
            wicketsFallen++;
        }
    }
    
    // Filter active batters
    final activeBatters = battingScore.batters.where((b) => 
      b.balls > 0 || b.isOut || b.isPlaying || b.isOnStrike
    ).toList();
    
    // Assign missing positions to non-strikers who haven't faced a ball
    List<int> takenPositions = battingPositions.values.toList();
    List<int> availablePositions = [];
    int expectedBatters = wicketsFallen + 2;
    if (activeBatters.length < expectedBatters) expectedBatters = activeBatters.length;
    
    for (int i = 1; i <= expectedBatters; i++) {
        if (!takenPositions.contains(i)) availablePositions.add(i);
    }
    availablePositions.sort();
    
    List<BatterStats> missingBatters = activeBatters.where((b) => !battingPositions.containsKey(b.playerId)).toList();
    for (int i = 0; i < missingBatters.length; i++) {
        battingPositions[missingBatters[i].playerId] = i < availablePositions.length ? availablePositions[i] : 999;
    }
    
    // Sort EXACTLY by batting position (like Cricbuzz)
    activeBatters.sort((a, b) {
        int posA = battingPositions[a.playerId] ?? 999;
        int posB = battingPositions[b.playerId] ?? 999;
        return posA.compareTo(posB);
    });

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Batting Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFD6DBE9)),
              ),
              child: Column(
                children: [
                  // Team Header within the card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: isSuperOverInnings ? const Color(0xFF1976D2) : const Color(0xFFD6E3FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8.r),
                        topRight: Radius.circular(8.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          battingTeamName.toUpperCase(),
                          style: TextStyle(color: isSuperOverInnings ? Colors.white : const Color(0xFF1A3365), fontWeight: FontWeight.w900, fontSize: 15.sp, letterSpacing: 0.5),
                        ),
                        Text(
                          '${battingScore.runs}-${battingScore.wickets} (${battingScore.overs} OV)',
                          style: TextStyle(color: isSuperOverInnings ? Colors.white : const Color(0xFF1A3365), fontWeight: FontWeight.w900, fontSize: 16.sp),
                        ),
                      ],
                    ),
                  ),
                  
                  _buildBatterHeader(),
                  ...activeBatters.map((b) => _buildBatterRow(b, team?.id ?? '')).toList(),
                  
                  Divider(height: 1.h, color: Color(0xFFEEEEEE)),
                  
                  // Extras & Total
                  _buildExtrasRow(battingScore),
                  _buildTotalRow(battingScore),
                ],
              ),
            ),

            if (team != null && !isSuperOverInnings) ...[
               SizedBox(height: 16.h),
               _buildYetToBatSection(activeBatters, team),
            ],
             

             
             SizedBox(height: 24.h),
           
             // Bowling Section
             Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFD6DBE9)),
              ),
              child: Column(
                children: [
                   Container(
                     width: double.infinity,
                     padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                     decoration: BoxDecoration(
                        color: isSuperOverInnings ? const Color(0xFF1976D2) : const Color(0xFFD6E3FF),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8.r),
                          topRight: Radius.circular(8.r),
                        ),
                     ),
                     child: Text(
                       '${bowlingTeamName.toUpperCase()} BOWLERS',
                       style: TextStyle(color: isSuperOverInnings ? Colors.white : const Color(0xFF1A3365), fontWeight: FontWeight.w900, fontSize: 14.sp, letterSpacing: 0.5),
                     ),
                   ),
                   
                   _buildBowlerHeader(),
                   if(bowlingScore.bowlers.isEmpty) 
                      Padding(padding: EdgeInsets.all(24.w), child: Text("No bowling data", style: TextStyle(color: Colors.black38)))
                   else
                      ...bowlingScore.bowlers.where((b) => b.overs > 0 || b.balls > 0 || b.isBowling).map((b) => _buildBowlerRow(b)).toList(),
                ],
              ),
             ),
             
             SizedBox(height: 16.h),
             _buildFallOfWickets(team, battingTeamName),
             
             SizedBox(height: 24.h),
             if (team != null) _buildPartnerships(team, battingScore),
             
             SizedBox(height: 24.h),
             _buildPowerplayInfo(),
              
              SizedBox(height: 24.h),
              DlsCalculatorCard(match: widget.match),
             
             SizedBox(height: 30.h),
        ],
      ),
    );
  }

  Widget _buildFallOfWickets(TeamModel? team, String battingTeamName) {
    if (team == null) return SizedBox.shrink();

    // Calculate FOW from ballByBall
    List<Map<String, dynamic>> fowList = [];
    int runningScore = 0;
    int wickets = 0;
    
    // Filter balls for this team
    // We assume team ID matches battingTeam in ball events. 
    // Since we don't know the exact innings number in this method easily without passing it, 
    // we rely on battingTeamName or ID. 
    // Better: Filter by team ID.
    final teamBalls = widget.match.ballByBall.where((b) => b.battingTeam == team.id).toList();
    
    // Sort just in case, though they should be ordered
    // teamBalls.sort((a, b) => (a.overNumber * 6 + a.ballNumber).compareTo(b.overNumber * 6 + b.ballNumber));

    for (var ball in teamBalls) {
      runningScore += ball.totalRuns;
      if (ball.wicket != null) {
        wickets++;
        fowList.add({
          'score': runningScore,
          'wicket': wickets,
          'player': ball.batsmanName.isNotEmpty ? ball.batsmanName : 'Batter',
          'playerId': ball.batsmanId,
          'over': "${ball.overNumber}.${ball.ballNumber}"
        });
      }
    }

    if (fowList.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FALL OF WICKETS',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: AppTheme.primaryOrange, letterSpacing: 0.5),
          ),
          SizedBox(height: 12.h),
          SizedBox(height: 12.h),
          ...fowList.map((fow) {
             return Padding(
               padding: EdgeInsets.symmetric(vertical: 6.h),
               child: Row(
                 children: [
                   Container(
                     padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                     decoration: BoxDecoration(
                       color: AppTheme.primaryOrange.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(4.r),
                     ),
                     child: Text(
                       "${fow['score']}-${fow['wicket']}",
                       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppTheme.primaryOrange),
                     ),
                   ),
                   SizedBox(width: 12.w),
                   Expanded(
                     child: GestureDetector(
                       onTap: () => _navigateToPlayerProfile(fow['playerId'] ?? ''),
                       child: Text(
                         "${fow['player']}",
                         style: TextStyle(
                           fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.black87,
                           decoration: TextDecoration.underline,
                           decorationColor: Color(0x4DFF9800),
                           decorationStyle: TextDecorationStyle.dotted,
                         ),
                       ),
                     ),
                   ),

                   Text(
                     "Over ${fow['over']}",
                     style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                   ),
                 ],
               ),
             );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPartnerships(TeamModel team, TeamScore battingScore) {
    // Filter partnerships based on players in the current batting score
    final battingPlayerIds = battingScore.batters.map((b) => b.playerId).toSet();
    // Always use robust fallback calculation for partnerships based on ball-by-ball data
    var teamPartnerships = _calculatePartnershipsFallback(team, battingPlayerIds);

    if (teamPartnerships.isEmpty) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'PARTNERSHIPS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: AppTheme.primaryOrange, letterSpacing: 0.5),
            ),
          ),
          const Divider(),
          ...teamPartnerships.map((p) => Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: GestureDetector(
                      onTap: () => _navigateToPlayerProfile(p.batter1Id),
                      child: Text(p.batter1Name, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp, decoration: TextDecoration.underline, decorationColor: Color(0x4DFF9800), decorationStyle: TextDecorationStyle.dotted)),
                    )),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Icon(Icons.compare_arrows, size: 16.sp, color: Colors.grey),
                    ),
                    Expanded(child: GestureDetector(
                      onTap: () => _navigateToPlayerProfile(p.batter2Id),
                      child: Text(p.batter2Name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp, decoration: TextDecoration.underline, decorationColor: Color(0x4DFF9800), decorationStyle: TextDecorationStyle.dotted)),
                    )),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text('${p.runs}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                     Text(' (${p.balls})', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                  ],
                ),
                SizedBox(height: 8.h),
                // Visualization bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: Row(
                    children: [
                      Expanded(
                        flex: p.runs > 0 ? (p.batter1Runs * 100 ~/ p.runs) : 1,
                        child: Container(height: 6.h, color: Colors.blue),
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        flex: p.runs > 0 ? (p.batter2Runs * 100 ~/ p.runs) : 1,
                        child: Container(height: 6.h, color: AppTheme.primaryOrange),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildPowerplayInfo() {
    if (widget.match.powerplayConfig.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POWERPLAY',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: AppTheme.primaryOrange, letterSpacing: 0.5),
          ),
          SizedBox(height: 12.h),
          ...widget.match.powerplayConfig.map((pp) => Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${pp.name} (${pp.startOver}-${pp.endOver})', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp)),
                Text(pp.description ?? 'Mandatory', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  List<Partnership> _calculatePartnershipsFallback(TeamModel team, Set<String> battingPlayerIds) {
    List<Partnership> calculated = [];
    final teamBalls = widget.match.ballByBall.where((b) => b.battingTeam == team.id).toList();
    
    if (teamBalls.isEmpty) return [];

    Set<String> currentPair = {};
    // Try to find the opener non-striker if possible, otherwise we build the pair as they face balls
    
    int runs = 0;
    int balls = 0;
    Map<String, int> batterRuns = {};
    Map<String, int> batterBalls = {};

    for (var ball in teamBalls) {
       currentPair.add(ball.batsmanId);
       // Note: we can't easily find non-striker until they face a ball or are involved in wicket.
       
       runs += ball.totalRuns;
       // Count legal balls for partnership duration? Usually partnership counts all deliveries.
       balls++; 
       
       // Update individual contribution
       int pRuns = ball.runs; 
       // Extras logic: generally extras are credited to team but for partnership contribution usually batter runs are summed. 
       // Total partnership runs include extras. 
       
       batterRuns[ball.batsmanId] = (batterRuns[ball.batsmanId] ?? 0) + pRuns;
       if (ball.extraType == null || ball.extraType == 'lb' || ball.extraType == 'b') {
          batterBalls[ball.batsmanId] = (batterBalls[ball.batsmanId] ?? 0) + 1;
       }

       if (ball.wicket != null) {
          // Partnership ended
          if (currentPair.isNotEmpty) {
             String b1 = currentPair.first;
             String b2 = currentPair.length > 1 ? currentPair.last : 'Unknown';
             
             // Get names
             String b1Name = team.players.firstWhere((p) => p.userId == b1, orElse: () => TeamPlayer(userId: b1, name: 'Batter', role: 'Batsman')).name;
             // If we don't have name in players list (maybe sub?), try ball event name
             if (b1Name == 'Batter' && ball.batsmanId == b1) b1Name = ball.batsmanName;
             
             String b2Name = team.players.firstWhere((p) => p.userId == b2, orElse: () => TeamPlayer(userId: b2, name: 'Batter', role: 'Batsman')).name;

             calculated.add(Partnership(
               batter1Id: b1, batter1Name: b1Name,
               batter2Id: b2, batter2Name: b2Name,
               runs: runs, balls: balls,
               batter1Runs: batterRuns[b1] ?? 0, batter1Balls: batterBalls[b1] ?? 0,
               batter2Runs: batterRuns[b2] ?? 0, batter2Balls: batterBalls[b2] ?? 0,
             ));
          }
          
          // Reset for next partnership
          runs = 0;
          balls = 0;
          batterRuns.clear();
          batterBalls.clear();
          
          // Remove dismissed player
          String dismissedId = ball.wicket!.playerId;
          currentPair.remove(dismissedId);
       }
    }

    // Add current unfinished partnership
    if (runs > 0 || currentPair.isNotEmpty) {
        String b1 = currentPair.isNotEmpty ? currentPair.first : '';
        String b2 = currentPair.length > 1 ? currentPair.last : '';
        if (b1.isNotEmpty) {
           String b1Name = team.players.firstWhere((p) => p.userId == b1, orElse: () => TeamPlayer(userId: b1, name: 'Batter', role: 'Batsman')).name;
             if (b1Name == 'Batter' && teamBalls.last.batsmanId == b1) b1Name = teamBalls.last.batsmanName;

           String b2Name = b2.isNotEmpty ? team.players.firstWhere((p) => p.userId == b2, orElse: () => TeamPlayer(userId: b2, name: 'Batter', role: 'Batsman')).name : 'Partner';

           calculated.add(Partnership(
             batter1Id: b1, batter1Name: b1Name, 
             batter2Id: b2, batter2Name: b2Name,
             runs: runs, balls: balls,
             batter1Runs: batterRuns[b1] ?? 0, batter1Balls: batterBalls[b1] ?? 0,
             batter2Runs: batterRuns[b2] ?? 0, batter2Balls: batterBalls[b2] ?? 0,
             isActive: true
           ));
        }
    }
    
    return calculated.reversed.toList(); // Show latest first? Or chronological? Usually chronological.
    // Let's return reversed to show latest at top like Cricbuzz sometimes, or just standard.
    // User asked for "not showing", standard is chronological list usually 1st wicket, 2nd wicket...
    // But typically Partnership card shows *Active* partnership at top? 
    // The UI iterates and displays them. I'll return in order (1st wkt, 2nd wkt...) 
    // Wait, the UI loop is `...teamPartnerships.map`.
    // I'll return chronological.
    return calculated;
  }

  String _getEnhancedDismissalString(BatterStats b, String battingTeamId) {
    if (!b.isOut) return b.isPlaying ? "not out" : "yet to bat";
    
    try {
       final wicketBallList = widget.match.ballByBall.where(
           (ball) => ball.wicket != null && ball.wicket!.playerId == b.playerId
       ).toList();
       if (wicketBallList.isEmpty) return b.dismissalString;
       final wicketBall = wicketBallList.last;
       
       String type = wicketBall.wicket!.type.toLowerCase();
       String bowler = wicketBall.bowlerName.trim();
       String bowlerId = wicketBall.bowlerId;
       String fielderId = wicketBall.wicket!.fielderId ?? '';
       String fielder = "";
       
       final bowlingTeam = widget.match.team1Id == battingTeamId ? _team2 : _team1;
       
       // Fallback lookup if names are missing in BallEvent
       if (bowlingTeam != null) {
           if (bowler.isEmpty && bowlerId.isNotEmpty) {
               try { bowler = bowlingTeam.players.firstWhere((p) => p.userId == bowlerId).name.trim(); } catch (_) {}
           }
           if (fielderId.isNotEmpty) {
               try { fielder = bowlingTeam.players.firstWhere((p) => p.userId == fielderId).name.trim(); } catch (_) { fielder = fielderId; }
           }
       } else {
           if (fielderId.isNotEmpty) fielder = fielderId;
       }
       
       if (type.contains('caught and bowled') || (type.contains('caught') && fielder == bowler && fielder.isNotEmpty)) {
         return "c & b $bowler";
       }
       if (type.contains('caught') || type == 'c' || type == 'catch') {
         if (fielder.isNotEmpty && bowler.isNotEmpty) return "c $fielder b $bowler";
         if (fielder.isNotEmpty) return "c $fielder";
         if (bowler.isNotEmpty) return "c unknown b $bowler";
         return "caught";
       }
       if (type.contains('bowled') || type == 'b') return "b $bowler";
       if (type.contains('lbw')) return "lbw b $bowler";
       if (type.contains('run out') || type == 'ro') return fielder.isNotEmpty ? "run out ($fielder)" : "run out";
       if (type.contains('stumped') || type == 'st') {
         if (fielder.isNotEmpty && bowler.isNotEmpty) return "st $fielder b $bowler";
         if (fielder.isNotEmpty) return "st $fielder";
         if (bowler.isNotEmpty) return "st b $bowler";
         return "stumped";
       }
       if (type.contains('hit wicket')) return "hit wicket b $bowler";
       return type;
    } catch (e) {
       return b.dismissalString; 
    }
  }

  Widget _buildBatterRow(BatterStats b, String battingTeamId) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: b.isOnStrike ? const Color(0xFFFFF7E6) : Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFD6DBE9), width: 1.w)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToPlayerProfile(b.playerId),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      b.playerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: b.isOut ? Colors.grey : AppTheme.primaryOrange,
                        fontSize: 13.sp,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (b.isOnStrike)
                    Container(
                      margin: EdgeInsets.only(left: 4.w),
                      child: Icon(Icons.sports_cricket, size: 12.sp, color: AppTheme.primaryOrange),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Text(
                (b.isOut || b.isPlaying) ? _getEnhancedDismissalString(b, battingTeamId) : '',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(flex: 1, child: Text('${b.runs}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87))),
          Expanded(flex: 1, child: Text('${b.balls}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.fours}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.sixes}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 2, child: Text(b.strikeRate.toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(fontSize: 11.sp, color: Colors.black87, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
  
  Widget _buildBowlerRow(BowlerStats b) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFD6DBE9), width: 1.w)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5, 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToPlayerProfile(b.playerId),
              child: Text(
                b.playerName, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 13.sp, 
                  color: AppTheme.primaryOrange,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(flex: 1, child: Text(b.oversDisplay, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87))),
          Expanded(flex: 1, child: Text('${b.maidens}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.runs}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.wickets}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87))),
          Expanded(flex: 2, child: Text(b.economy.toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(fontSize: 11.sp, color: Colors.black87, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
  
  Widget _buildExtrasRow(TeamScore score) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('EXTRAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.sp, color: Colors.grey)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              '${score.extras.total} (b ${score.extras.byes}, lb ${score.extras.legByes}, w ${score.extras.wides}, nb ${score.extras.noBalls}, p 0)',
              style: TextStyle(fontSize: 12.sp, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(TeamScore score) {
    double rr = score.overs > 0 ? score.runs / score.overs : 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.08),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8.r), bottomRight: Radius.circular(8.r)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: AppTheme.primaryOrange)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              '${score.runs}-${score.wickets} (${score.overs} OV, RR: ${rr.toStringAsFixed(2)})',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBatterHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FC),
        border: Border(bottom: BorderSide(color: const Color(0xFFD6DBE9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Text('BATTER', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A3365), letterSpacing: 1)),
          ),
          _buildStatHeader('R', flex: 1),
          _buildStatHeader('B', flex: 1),
          _buildStatHeader('4s', flex: 1),
          _buildStatHeader('6s', flex: 1),
          _buildStatHeader('SR', flex: 2),
        ],
      ),
    );
  }

  Widget _buildBowlerHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FC),
        border: Border(bottom: BorderSide(color: const Color(0xFFD6DBE9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('BOWLER', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A3365), letterSpacing: 1)),
          ),
          _buildStatHeader('O', flex: 1),
          _buildStatHeader('M', flex: 1),
          _buildStatHeader('R', flex: 1),
          _buildStatHeader('W', flex: 1),
          _buildStatHeader('ECO', flex: 2),
        ],
      ),
    );
  }

  Widget _buildStatHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1A3365)),
      ),
    );
  }

  Widget _buildYetToBatSection(List<BatterStats> activeBatters, TeamModel team) {
    final playingPlayerIds = activeBatters.map((b) => b.playerId).toSet();
    final yetToBat = team.players.where((p) => !playingPlayerIds.contains(p.userId)).toList();

    if (yetToBat.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12.r),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 8,
             offset: Offset(0, 2),
           ),
         ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              'DID NOT BAT', 
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)
            ),
          ),
          Expanded(
            child: Wrap(
              children: yetToBat.map((p) => Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => _navigateToPlayerProfile(p.userId),
                  child: Text(
                    '${p.name}${p == yetToBat.last ? "" : ","}',
                    style: TextStyle(
                      fontSize: 13.sp, color: Colors.black87, fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0x4DFF9800),
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDismissal(BatterStats b) {
    return b.dismissalString;
  }

  Future<void> _navigateToPlayerProfile(String playerId) async {
    if (playerId.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
    );
    
    try {
      final user = await FirebaseDataService.instance.findUserByAnyId(playerId);
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      
      if (user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: user),
          ),
        );
      } else {
        if (playerId.startsWith('p_') || playerId.startsWith('manual_') || playerId.startsWith('player_')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player profile not available for manually added players')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player profile not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading profile')),
        );
      }
    }
  }
}
