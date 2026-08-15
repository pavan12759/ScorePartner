import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'package:scorepatner/data/models/user_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/screens/profile/player_profile_screen.dart';

/// Detailed Match Scorecard Screen - Shows batting and bowling stats
class MatchScorecardScreen extends StatefulWidget {
  final String matchId;

  const MatchScorecardScreen({super.key, required this.matchId});

  @override
  State<MatchScorecardScreen> createState() => _MatchScorecardScreenState();
}

class _MatchScorecardScreenState extends State<MatchScorecardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  TeamModel? _team1;
  TeamModel? _team2;
  bool _isLoadingTeams = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController1 = ScrollController();
    _scrollController2 = ScrollController();
    _fetchTeams();
  }

  late final ScrollController _scrollController1;
  late final ScrollController _scrollController2;

  Future<void> _fetchTeams() async {
    // Need to get match first to get team IDs
    final match = await _dataService.getMatchById(widget.matchId);
    if (match != null) {
      final team1 = await _dataService.getTeamById(match.team1Id);
      final team2 = await _dataService.getTeamById(match.team2Id);
      
      if (mounted) {
        setState(() {
          _team1 = team1;
          _team2 = team2;
          _isLoadingTeams = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingTeams = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController1.dispose();
    _scrollController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Light background
      appBar: AppBar(
        title: const Text('SCORECARD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
          tabs: const [
            Tab(text: '1ST INNINGS'),
            Tab(text: '2ND INNINGS'),
          ],
        ),
      ),
      body: StreamBuilder<MatchModel?>(
          stream: _dataService.streamMatch(widget.matchId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
            }

            final match = snapshot.data!;

            // Determine who batted first
            // Determine who batted first
          bool team1BattedFirst = true;
          
          // Prioritize current game state for active innings to ensure UI matches scoring
          if (match.status == 'live' && (match.currentInnings == 1 || match.currentInnings == 2)) {
            if (match.currentInnings == 1) {
              team1BattedFirst = match.currentBattingTeam == 'team1';
            } else {
              // In 2nd innings, the current batting team is batting 2nd
              // So team1 batted first if team1 is NOT currently batting
              team1BattedFirst = match.currentBattingTeam != 'team1';
            }
          } else if (match.tossWinnerId != null && match.tossDecision != null) {
            // Fallback to toss logic for completed matches or initial state
            if (match.tossWinnerId == match.team1Id) {
              team1BattedFirst = match.tossDecision == 'bat';
            } else {
              team1BattedFirst = match.tossDecision == 'field';
            }
          }

          return _isLoadingTeams 
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : TabBarView(
                controller: _tabController,
                children: [
                   // 1st Innings
                   team1BattedFirst
                       ? _buildInningsScorecard(match, match.team1Name, match.team1Score, match.team2Score, _team1, _scrollController1)
                       : _buildInningsScorecard(match, match.team2Name, match.team2Score, match.team1Score, _team2, _scrollController1),
                   
                   // 2nd Innings
                   team1BattedFirst
                       ? _buildInningsScorecard(match, match.team2Name, match.team2Score, match.team1Score, _team2, _scrollController2)
                       : _buildInningsScorecard(match, match.team1Name, match.team1Score, match.team2Score, _team1, _scrollController2),
                ],
              );
          },
        ),
    );
  }

  Widget _buildInningsScorecard(
    MatchModel match,
    String battingTeamName,
    TeamScore battingScore,
    TeamScore bowlingScore,
    TeamModel? team,
    ScrollController scrollController,
  ) {
    // Filter active batters
    final activeBatters = battingScore.batters.where((b) => 
      b.balls > 0 || b.isOut || b.isPlaying || b.isOnStrike
    ).toList();

    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // Batting Section
             Container(
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
                 children: [
                   // Team Header
                   Container(
                     width: double.infinity,
                     padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                     decoration: BoxDecoration(
                       gradient: LinearGradient(
                         colors: [AppTheme.primaryOrange, Color(0xFFE65100)],
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                       ),
                       borderRadius: BorderRadius.only(
                         topLeft: Radius.circular(16),
                         topRight: Radius.circular(16),
                       ),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           battingTeamName.toUpperCase(),
                           style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.sp),
                         ),
                         Text(
                           '${battingScore.runs}-${battingScore.wickets} (${battingScore.overs} OV)',
                           style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.sp),
                         ),
                       ],
                     ),
                   ),
                   
                   _buildBatterHeader(),
                   ...activeBatters.map((b) => _buildBatterRow(b)).toList(),
                   
                   Divider(height: 1.h, color: Color(0xFFEEEEEE)),
                   
                   // Extras & Total
                   _buildExtrasRow(battingScore),
                   _buildTotalRow(battingScore),
                 ],
               ),
             ),

            if (team != null) ...[
               SizedBox(height: 16.h),
               _buildYetToBatSection(activeBatters, team),
            ],
             
             SizedBox(height: 24.h),
            
             // Bowling Section
             Container(
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
                 children: [
                   Container(
                     width: double.infinity,
                     padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                     decoration: BoxDecoration(
                       gradient: LinearGradient(
                         colors: [AppTheme.primaryOrange, Color(0xFFE65100)],
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                       ),
                       borderRadius: BorderRadius.only(
                         topLeft: Radius.circular(16),
                         topRight: Radius.circular(16),
                       ),
                     ),
                     child: Text(
                       '${battingTeamName} Bowlers'.toUpperCase(),
                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp),
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
             
             SizedBox(height: 30.h),
             
             // Fall of Wickets
             _buildSectionTitle('Fall of Wickets'),
             SizedBox(height: 8.h),
             _buildFallOfWickets(battingScore.batters),
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
        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange),
      ),
    );
  }

  Widget _buildBatterHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Color(0xFFFFF3E0),
        border: Border(bottom: BorderSide(color: Color(0xFFFFE0B2))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Text('BATTER', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange)),
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
        color: Color(0xFFFFF3E0),
        border: Border(bottom: BorderSide(color: Color(0xFFFFE0B2))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('BOWLER', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange)),
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

  Widget _buildBatterRow(BatterStats b) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1.w)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _navigateToPlayerProfile(b.playerId, context),
                        child: Text(
                          b.playerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: b.isOut ? Colors.black87 : Colors.black,
                            fontSize: 13.sp,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.orange.withOpacity(0.4),
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (b.isOnStrike)
                      const Text(' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
                  ],
                ),
                if (b.isOut) ...[
                  SizedBox(height: 2.h),
                  Text(
                    b.dismissalString,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Expanded(flex: 1, child: Text('${b.runs}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87))),
          Expanded(flex: 1, child: Text('${b.balls}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.fours}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.sixes}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 2, child: Text(b.strikeRate.toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(fontSize: 11.sp, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
  
  Widget _buildBowlerRow(BowlerStats b) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1.w)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5, 
            child: GestureDetector(
              onTap: () => _navigateToPlayerProfile(b.playerId, context),
              child: Text(b.playerName, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black87,
                decoration: TextDecoration.underline,
                decorationColor: Color(0x66FF9800),
                decorationStyle: TextDecorationStyle.dotted,
              )),
            ),
          ),
          Expanded(flex: 1, child: Text(b.oversDisplay, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.maidens}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.runs}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, color: Colors.black54))),
          Expanded(flex: 1, child: Text('${b.wickets}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87))),
          Expanded(flex: 2, child: Text(b.economy.toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(fontSize: 11.sp, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold))),
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
              '${score.extras.total} (b ${score.extras.byes}, lb ${score.extras.legByes}, w ${score.extras.wides}, nb ${score.extras.noBalls})',
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
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
        child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: AppTheme.primaryOrange)),
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
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryOrange,
          letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildFallOfWickets(List<BatterStats> batters) {
    final outBatters = batters.where((b) => b.isOut).toList();
    if (outBatters.isEmpty) {
      return _buildEmptyCard('No wickets fallen yet');
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: outBatters.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final batter = entry.value;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
            ),
            child: Text(
              '${batter.runs}-${idx} (${batter.playerName})',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
  
  Widget _buildYetToBatSection(List<BatterStats> activeBatters, TeamModel team) {
    final playingPlayerIds = activeBatters.map((b) => b.playerId).toSet();
    final yetToBat = team.players.where((p) => !playingPlayerIds.contains(p.userId)).toList();

    if (yetToBat.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
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
                    child: Text(
                      '${p.name}${p == yetToBat.last ? "" : ","}',
                      style: TextStyle(fontSize: 13.sp, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Navigate to player profile when a player name is tapped
  Future<void> _navigateToPlayerProfile(String playerId, BuildContext context) async {
    if (playerId.isEmpty || playerId.startsWith('p_')) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final user = await FirebaseDataService.instance.getUserById(playerId);
      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading
      
      if (user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: user),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player profile not found')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading profile')),
        );
      }
    }
  }
}
