import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/models/user_model.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/screens/profile/player_profile_screen.dart';
import 'package:scorepatner/presentation/widgets/match_initialization_dialog.dart';

class LiveTab extends StatefulWidget {
  final MatchModel match;
  final Function(int)? onNavigate;

  const LiveTab({super.key, required this.match, this.onNavigate});

  @override
  State<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<LiveTab> with SingleTickerProviderStateMixin {
  MatchModel get match => widget.match;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  ImageProvider _getProfileImageProvider(String url) {
    if (url.isEmpty) return const AssetImage('assets/images/default_avatar.png'); // Fallback though we usually don't reach here if empty is checked
    if (url.trim().startsWith('data:')) {
      try {
        final base64Str = url.split(',').last.trim();
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return const AssetImage('assets/images/default_avatar.png');
      }
    }
    return NetworkImage(url);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  late final ScrollController _scrollController;

  @override
  Widget build(BuildContext context) {
    if (widget.match.status == 'completed') {
      return _buildMatchRecap(context);
    }
    
    final match = widget.match;
    final isTeam1Batting = match.currentBattingTeam == 'team1';
    final battingTeam = isTeam1Batting ? match.team1Score : match.team2Score;
    final bowlingTeam = isTeam1Batting ? match.team2Score : match.team1Score;
    
    // Get current batters (not out and playing)
    final currentBatters = battingTeam.batters.where((b) => b.isPlaying && !b.isOut).toList();
    // Get current bowler
    final currentBowler = bowlingTeam.bowlers.firstWhere(
      (b) => b.isBowling, 
      orElse: () => BowlerStats(playerId: '', playerName: 'TBA'),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batters Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFFD6DBE9)),
            ),
            child: Column(
              children: [
                _buildBatterHeader(),
                 if (currentBatters.isEmpty)
                   Padding(padding: EdgeInsets.all(24.w), child: Text("No batters on crease", style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic)))
                else
                   ...currentBatters.map((b) => _buildBatterRow(b)).toList(),
                   
                if (battingTeam.extras.total > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF5F5F5), width: 1.w)),
                    ),
                    child: Row(
                      children: [
                        Text('EXTRAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.sp, color: Colors.grey, letterSpacing: 1)),
                        const Spacer(),
                        Text(
                          '${battingTeam.extras.total} (b ${battingTeam.extras.byes}, lb ${battingTeam.extras.legByes}, w ${battingTeam.extras.wides}, nb ${battingTeam.extras.noBalls}, p 0)',
                          style: TextStyle(fontSize: 12.sp, color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                if (match.currentPartnership != null || currentBatters.length == 2)
                  Builder(
                    builder: (context) {
                      int pRuns = 0;
                      int pBalls = 0;
                      String pNames = '';
                      if (match.currentPartnership != null) {
                        pRuns = match.currentPartnership!.runs;
                        pBalls = match.currentPartnership!.balls;
                        pNames = '${match.currentPartnership!.batter1Name.split(' ').last} ${match.currentPartnership!.batter1Runs}(${match.currentPartnership!.batter1Balls}) & ${match.currentPartnership!.batter2Name.split(' ').last} ${match.currentPartnership!.batter2Runs}(${match.currentPartnership!.batter2Balls})';
                      } else {
                        int b1Runs = 0, b1Balls = 0, b2Runs = 0, b2Balls = 0;
                        final currentBattingTeamId = match.currentBattingTeam == 'team1' ? match.team1Id : match.team2Id;
                        final currentInningsBalls = match.ballByBall.where((b) => b.battingTeam == currentBattingTeamId).toList();
                        for (int i = currentInningsBalls.length - 1; i >= 0; i--) {
                          final ball = currentInningsBalls[i];
                          if (ball.wicket != null) break;
                          
                          pRuns += ball.totalRuns;
                          final isLegalOrBye = ball.extraType == null || ball.extraType == 'lb' || ball.extraType == 'b';
                          if (isLegalOrBye) {
                            pBalls++;
                          }
                          
                          if (currentBatters.length == 2) {
                            if (ball.batsmanId == currentBatters[0].playerId) {
                              b1Runs += ball.runs;
                              if (isLegalOrBye) b1Balls++;
                            } else if (ball.batsmanId == currentBatters[1].playerId) {
                              b2Runs += ball.runs;
                              if (isLegalOrBye) b2Balls++;
                            }
                          }
                        }
                        if (currentBatters.length == 2) {
                          pNames = '${currentBatters[0].playerName.split(' ').last} $b1Runs($b1Balls) & ${currentBatters[1].playerName.split(' ').last} $b2Runs($b2Balls)';
                        }
                      }
                      
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFF5F5F5), width: 1.w)),
                        ),
                        child: Row(
                          children: [
                            Text('PARTNERSHIP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.sp, color: Colors.grey, letterSpacing: 1)),
                            SizedBox(width: 12.w),
                            Text(
                              '$pRuns ($pBalls)',
                              style: TextStyle(fontSize: 13.sp, color: Colors.black87, fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                pNames.toUpperCase(),
                                style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Last Wicket Card
          if (match.lastWicket != null)
            _buildLastWicketCard(match.lastWicket!),

          SizedBox(height: 24.h),

          // Bowler Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFFD6DBE9)),
            ),
            child: Column(
              children: [
                _buildBowlerHeader(),
                _buildBowlerRow(currentBowler),
              ],
            ),
          ),
          
          SizedBox(height: 24.h),
          // Recent Balls Section
          _buildRecentBallsSection(),

          SizedBox(height: 24.h),
           
          // Live Commentary Feed
          _buildLiveCommentaryFeed(),
          
          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  // --- Match Recap UI ---

  Widget _buildMatchRecap(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildResultBanner(),
          SizedBox(height: 20.h),
          
          if (match.result?.manOfMatch != null && match.result!.manOfMatch.isNotEmpty)
            _buildPlayerOfTheMatchCard(match.result!.manOfMatch, '', 'PLAYER OF THE MATCH', null, null),
          
          if (match.result?.manOfMatch != null && match.result!.manOfMatch.isNotEmpty)
            SizedBox(height: 20.h),
            
          _buildTopPerformances(),
          SizedBox(height: 20.h),
          
          _buildMatchHighlightsStats(),
          SizedBox(height: 20.h),
          
          _buildTurningPoint(),
          SizedBox(height: 20.h),
          
          _buildMiniScoreSummary(),
          SizedBox(height: 24.h),
          
          _buildLiveCommentaryFeed(),
          SizedBox(height: 24.h),
          
          // Share Button
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share summary feature coming soon!')),
              );
            },
            icon: Icon(Icons.share, color: Colors.white),
            label: Text('Share Match Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              elevation: 2,
            ),
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  
  Widget _buildResultBanner() {
    String resultText = 'Match Completed';
    
    // Check if result is explicitly set
    if (match.result != null && match.result!.winner.isNotEmpty) {
      if (match.result!.winner.toLowerCase() == 'draw' || match.result!.winner.toLowerCase() == 'tie') {
         resultText = 'Match Tied';
      } else {
         final margin = match.result!.margin.isNotEmpty ? ' by ${match.result!.margin}' : '';
         resultText = '${match.result!.winner} won$margin';
      }
    } else if (match.winnerTeamId != null && match.winnerTeamId!.isNotEmpty) {
       // Fallback to evaluating winnerTeamId
       String winnerName = match.winnerTeamId == match.team1Id ? match.team1Name : match.team2Name;
       final margin = match.winningMarginField != null && match.winningMarginField!.isNotEmpty ? ' by ${match.winningMarginField}' : '';
       resultText = '$winnerName won$margin';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            resultText.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryOrange,
              letterSpacing: 0.5,
            ),
          ),
          if (match.target != null && match.target! > 0) ...[
            SizedBox(height: 8.h),
            Text(
              'Target: ${match.target}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTopPerformances() {
    final team1ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team1']!
        : match.team1Score;
    final team2ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team2']!
        : match.team2Score;

    // 1. Gather all batters and bowlers
    List<BatterStats> allBatters = [...team1ScoreToUse.batters, ...team2ScoreToUse.batters];
    List<BowlerStats> allBowlers = [...team1ScoreToUse.bowlers, ...team2ScoreToUse.bowlers];

    // 2. Find Top Batter (Highest runs, then least balls)
    BatterStats? topBatter;
    if (allBatters.isNotEmpty) {
      allBatters.sort((a, b) {
        if (a.runs != b.runs) return b.runs.compareTo(a.runs);
        return a.balls.compareTo(b.balls); // Less balls is better if runs are equal
      });
      if (allBatters.first.runs > 0) topBatter = allBatters.first;
    }

    // 3. Find Top Bowler (Most wickets, then lowest runs, then least balls)
    BowlerStats? topBowler;
    if (allBowlers.isNotEmpty) {
      allBowlers.sort((a, b) {
        if (a.wickets != b.wickets) return b.wickets.compareTo(a.wickets);
        if (a.runs != b.runs) return a.runs.compareTo(b.runs);
        return a.balls.compareTo(b.balls);
      });
      if (allBowlers.first.wickets > 0 || allBowlers.first.balls > 0) topBowler = allBowlers.first;
    }

    // 4. Find Best Strike Rate (Min 10 balls faced)
    BatterStats? bestSrBatter;
    final eligibleBatters = allBatters.where((b) => b.balls >= 10).toList();
    if (eligibleBatters.isNotEmpty) {
      eligibleBatters.sort((a, b) => b.strikeRate.compareTo(a.strikeRate));
      bestSrBatter = eligibleBatters.first;
    } else if (allBatters.isNotEmpty) {
      // Fallback if no one played 10 balls, just find max SR
      final fallbackBatters = allBatters.where((b) => b.balls > 0).toList();
      if (fallbackBatters.isNotEmpty) {
         fallbackBatters.sort((a, b) => b.strikeRate.compareTo(a.strikeRate));
         bestSrBatter = fallbackBatters.first;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text('Top Performances', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        ),
        if (topBatter != null)
          _buildPerformanceCard(
            title: 'TOP BATTER',
            playerName: topBatter.playerName,
            playerId: topBatter.playerId,
            details: '${topBatter.runs} (${topBatter.balls}) – SR ${topBatter.strikeRate.toStringAsFixed(1)}',
          ),
        if (topBowler != null)
          _buildPerformanceCard(
            title: 'TOP BOWLER',
            playerName: topBowler.playerName,
            playerId: topBowler.playerId,
            details: '${topBowler.oversDisplay}–${topBowler.maidens}–${topBowler.runs}–${topBowler.wickets}',
          ),
        if (bestSrBatter != null)
          _buildPerformanceCard(
            title: 'BEST STRIKE RATE',
            playerName: bestSrBatter.playerName,
            playerId: bestSrBatter.playerId,
            details: 'SR ${bestSrBatter.strikeRate.toStringAsFixed(1)} (${bestSrBatter.runs} off ${bestSrBatter.balls})',
          ),
      ],
    );
  }

  Widget _buildPerformanceCard({required String title, required String playerName, required String playerId, required String details}) {
    return GestureDetector(
      onTap: () {
        String idToUse = playerId.isNotEmpty ? playerId : playerName;
        if (idToUse.isNotEmpty) {
          _navigateToPlayerProfile(idToUse, context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player profile is not available or not linked.')),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player Avatar Bubble with FutureBuilder to load profile image
          FutureBuilder<UserModel?>(
            future: FirebaseDataService.instance.findUserByAnyId(playerId),
            builder: (context, snapshot) {
              Widget placeholder = Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(Icons.person, color: Colors.grey.shade400, size: 24.sp),
              );

              if (!snapshot.hasData || snapshot.data!.profileImageUrl.isEmpty) {
                return placeholder;
              }
              
              return Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                  image: DecorationImage(
                    image: _getProfileImageProvider(snapshot.data!.profileImageUrl),
                    fit: BoxFit.cover,
                  )
                ),
              );
            }
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title, 
                  style: TextStyle(
                    color: Colors.grey.shade600, 
                    fontSize: 11.sp, 
                    fontWeight: 
                    FontWeight.bold, 
                    letterSpacing: 1.0
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  playerName,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16.sp, 
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            details, 
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              fontSize: 14.sp, 
              color: Colors.grey.shade800
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildMatchHighlightsStats() {
    final team1ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team1']!
        : match.team1Score;
    final team2ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team2']!
        : match.team2Score;

    int totalSixes = 0;
    int totalFours = 0;
    
    for (var b in team1ScoreToUse.batters) { totalSixes += b.sixes; totalFours += b.fours; }
    for (var b in team2ScoreToUse.batters) { totalSixes += b.sixes; totalFours += b.fours; }
    

    
    int totalExtras = team1ScoreToUse.extras.total + team2ScoreToUse.extras.total;
    int totalWickets = team1ScoreToUse.wickets + team2ScoreToUse.wickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text('Match Highlights', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        ),
        Row(
          children: [
            Expanded(child: _buildHighlightGridCard('🔥 Total Fours', '$totalFours', AppTheme.primaryOrange)),
            SizedBox(width: 12.w),
            Expanded(child: _buildHighlightGridCard('💥 Total Sixes', '$totalSixes', Colors.purple)),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
             Expanded(child: _buildHighlightGridCard('🎁 Extras Given', '$totalExtras', Colors.teal)),
             SizedBox(width: 12.w),
             Expanded(child: _buildHighlightGridCard('🎯 Total Wickets', '$totalWickets', Colors.red)),
          ],
        )
      ],
    );
  }

  Widget _buildHighlightGridCard(String label, String value, Color themeColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: themeColor.withOpacity(0.1), width: 2.w),
        boxShadow: [
          BoxShadow(color: themeColor.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: themeColor)),
          SizedBox(height: 6.h),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildTurningPoint() {
    // A simple heuristic: find the over with the most wickets.
    // If no wickets, find over with most runs.
    if (match.ballByBall.isEmpty) return SizedBox.shrink();

    Map<int, int> wicketsPerOver = {};
    Map<int, int> runsPerOver = {};
    
    for (var ball in match.ballByBall) {
      wicketsPerOver[ball.overNumber] = (wicketsPerOver[ball.overNumber] ?? 0) + (ball.wicket != null ? 1 : 0);
      runsPerOver[ball.overNumber] = (runsPerOver[ball.overNumber] ?? 0) + ball.runs + ball.extraRuns;
    }

    int maxWickets = 0;
    int maxWicketsOver = -1;
    
    wicketsPerOver.forEach((over, wickets) {
      if (wickets > maxWickets) {
        maxWickets = wickets;
        maxWicketsOver = over;
      }
    });

    String turningPointText = '';
    if (maxWickets >= 2) {
       turningPointText = 'Over ${maxWicketsOver + 1} – $maxWickets wickets fell, changing the momentum!';
    } else {
       // Fallback to highest run over if no multi-wicket overs
       int maxRuns = 0;
       int maxRunsOver = -1;
       runsPerOver.forEach((over, runs) {
         if (runs > maxRuns) {
           maxRuns = runs;
           maxRunsOver = over;
         }
       });
       if (maxRuns > 15) {
          turningPointText = 'Over ${maxRunsOver + 1} – A massive $maxRuns runs were scored, accelerating the innings!';
       } else {
          return SizedBox.shrink(); // No clear turning point found
       }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text('Turning Point', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        ),
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryOrange.withOpacity(0.15),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ]
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.show_chart, color: Colors.white, size: 28.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  turningPointText,
                  style: TextStyle(fontSize: 15.sp, height: 1.4, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniScoreSummary() {
    final team1ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team1']!
        : match.team1Score;
    final team2ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team2']!
        : match.team2Score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text('Innings Summary', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        ),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildMiniTeamRow(match.team1Name, team1ScoreToUse),
              Divider(height: 24.h),
              _buildMiniTeamRow(match.team2Name, team2ScoreToUse),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTeamRow(String teamName, TeamScore score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(teamName, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
        Text(
          '${score.runs}/${score.wickets} (${score.overs})',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBestPerformerSection() {
    // Only show Player of the Match section after match is completed
    if (match.status != 'completed') {
      return SizedBox.shrink();
    }

    // 1. Check if Man of the Match is declared
    if (match.result?.manOfMatch != null && match.result!.manOfMatch.isNotEmpty) {
      String declaredName = match.result!.manOfMatch.trim().toLowerCase();
      String matchedPlayerId = '';
      
      bool isMatch(String name) {
        String n = name.trim().toLowerCase();
        return n == declaredName || n.contains(declaredName) || declaredName.contains(n);
      }
      
      // Try to find the player ID by searching players in both teams
      for (var b in match.team1Score.batters) { if (isMatch(b.playerName)) matchedPlayerId = b.playerId; }
      if (matchedPlayerId.isEmpty) {
        for (var b in match.team2Score.batters) { if (isMatch(b.playerName)) matchedPlayerId = b.playerId; }
      }
      if (matchedPlayerId.isEmpty) {
        for (var b in match.team1Score.bowlers) { if (isMatch(b.playerName)) matchedPlayerId = b.playerId; }
      }
      if (matchedPlayerId.isEmpty) {
        for (var b in match.team2Score.bowlers) { if (isMatch(b.playerName)) matchedPlayerId = b.playerId; }
      }

      return _buildPlayerOfTheMatchCard(match.result!.manOfMatch, matchedPlayerId, 'PLAYER OF THE MATCH', null, null);
    }

    // 2. Calculate Player of the Match based on performance (Fallback for live/unsaved)
    
    // Determine winning team based on scores or result if available
    // If match won, we should know who won.
    TeamScore? winningTeamScore;
    
    if (match.winnerTeamId == match.team1Id) {
       winningTeamScore = match.team1Score;
    } else if (match.winnerTeamId == match.team2Id) {
       winningTeamScore = match.team2Score;
    }
    
    // If we don't know winner yet (e.g. just completed in memory), try to deduce
    if (winningTeamScore == null) {
       // Simple deduction if status is completed
       if (match.team1Score.runs > match.team2Score.runs) winningTeamScore = match.team1Score;
       else if (match.team2Score.runs > match.team1Score.runs) winningTeamScore = match.team2Score;
       else return SizedBox.shrink(); // Tie or unknown
    }

    BatterStats? bestBatter;
    double bestBatterPoints = -1;
    
    // Check Batters of WINNING TEAM ONLY
    for (var b in winningTeamScore.batters) {
      double points = (b.runs * 1.0) + (b.fours * 1) + (b.sixes * 2);
      if (points > bestBatterPoints) { bestBatterPoints = points; bestBatter = b; }
    }

    BowlerStats? bestBowler;
    double bestBowlerPoints = -1;

    // Check Bowlers of WINNING TEAM ONLY
    for (var b in winningTeamScore.bowlers) {
      double points = (b.wickets * 20.0) + (b.maidens * 10);
      if (points > bestBowlerPoints) { bestBowlerPoints = points; bestBowler = b; }
    }

    // Determine absolute best performer as Player of the Match
    if (bestBowlerPoints > bestBatterPoints && bestBowler != null) {
      return _buildPlayerOfTheMatchCard(
        bestBowler.playerName, 
        bestBowler.playerId,
        'PLAYER OF THE MATCH', 
        '${bestBowler.wickets} Wickets', 
        '${bestBowler.runs} Runs Given'
      );
    } else if (bestBatter != null) {
       return _buildPlayerOfTheMatchCard(
        bestBatter.playerName, 
        bestBatter.playerId,
        'PLAYER OF THE MATCH', 
        '${bestBatter.runs} Runs', 
        '(${bestBatter.balls} Balls)'
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildPlayerOfTheMatchCard(String playerName, String playerId, String title, String? stat1, String? stat2) {
    return GestureDetector(
      onTap: () {
        String idToUse = playerId.isNotEmpty ? playerId : playerName;
        if (idToUse.isNotEmpty) {
          _navigateToPlayerProfile(idToUse, context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player profile is not available or not linked.')),
          );
        }
      },
      child: Container(
        width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player avatar
          if (playerId.isNotEmpty)
            FutureBuilder<UserModel?>(
              future: FirebaseDataService.instance.findUserByAnyId(playerId),
              builder: (context, snapshot) {
                 Widget placeholder = Container(
                   width: 60.w,
                   height: 60.h,
                   decoration: BoxDecoration(
                     color: Colors.grey.shade100,
                     shape: BoxShape.circle,
                     border: Border.all(color: Colors.grey.shade300),
                   ),
                   child: Icon(Icons.person, color: Colors.grey.shade400, size: 30.sp),
                 );
                 
                 if (!snapshot.hasData || snapshot.data!.profileImageUrl.isEmpty) {
                    return placeholder;
                 }
                 
                 return Container(
                   width: 60.w,
                   height: 60.h,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(color: Colors.grey.shade300),
                     image: DecorationImage(
                       image: _getProfileImageProvider(snapshot.data!.profileImageUrl),
                       fit: BoxFit.cover,
                     )
                   ),
                 );
              }
            )
          else
            Container(
              width: 60.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.person, color: Colors.grey.shade400, size: 30.sp),
            ),
          SizedBox(width: 16.w),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  playerName,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (stat1 != null || stat2 != null) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      if (stat1 != null)
                        Text(
                          stat1,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                          ),
                        ),
                      if (stat1 != null && stat2 != null)
                        Text(
                          ' • ',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      if (stat2 != null)
                        Text(
                          stat2,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 13.sp,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Action icon (like a chevron to view profile)
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    ));
  }

  Widget _buildBatterHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.r),
          topRight: Radius.circular(8.r),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text('BATTER', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A3365), letterSpacing: 1)),
           Row(
             children: [
                SizedBox(width: 35.w, child: Text("R", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 35.w, child: Text("B", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 35.w, child: Text("4S", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 35.w, child: Text("6S", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 45.w, child: Text("SR", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
             ],
           )
        ],
      ),
    );
  }

  Widget _buildBatterRow(BatterStats batter) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: batter.isOnStrike ? const Color(0xFFFFF7E6) : Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFD6DBE9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToPlayerProfile(batter.playerId, context),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      batter.playerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: batter.isOut ? Colors.grey : AppTheme.primaryOrange,
                        decoration: batter.isOut ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (batter.isOnStrike)
                    Container(
                      margin: EdgeInsets.only(left: 6.w),
                      child: Icon(Icons.sports_cricket, size: 14.sp, color: AppTheme.primaryOrange),
                    ),
                ],
              ),
            ),
          ),
          Row(
            children: [
               SizedBox(width: 35.w, child: Text('${batter.runs}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 14.sp))),
               SizedBox(width: 35.w, child: Text('${batter.balls}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14.sp))),
               SizedBox(width: 35.w, child: Text('${batter.fours}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14.sp))),
               SizedBox(width: 35.w, child: Text('${batter.sixes}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14.sp))),
               SizedBox(width: 45.w, child: Text(batter.strikeRate.toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: Colors.black87, fontWeight: FontWeight.w500))),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _buildBowlerHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.r),
          topRight: Radius.circular(8.r),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text('BOWLER', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A3365), letterSpacing: 1)),
           Row(
             children: [
                SizedBox(width: 35.w, child: Text("O", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 25.w, child: Text("M", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 35.w, child: Text("R", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 35.w, child: Text("W", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
                SizedBox(width: 45.w, child: Text("ECO", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A3365)))),
             ],
           )
        ],
      ),
    );
  }

  Widget _buildBowlerRow(BowlerStats bowler) {
     return Container(
       padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
       child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToPlayerProfile(bowler.playerId, context),
              child: Text(bowler.playerName, style: TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.primaryOrange, fontSize: 14.sp,
              )),
            )
          ),
          Row(
            children: [
               SizedBox(width: 35.w, child: Text(bowler.oversDisplay, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 14.sp))),
               SizedBox(width: 25.w, child: Text('${bowler.maidens}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14.sp))),
               SizedBox(width: 35.w, child: Text('${bowler.runs}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14.sp))),
               SizedBox(width: 35.w, child: Text('${bowler.wickets}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 14.sp))),
               SizedBox(width: 45.w, child: Text(bowler.economy.toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: Colors.black87, fontWeight: FontWeight.w500))),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _buildRecentBallsSection() {
    final currentTeamId = match.currentBattingTeam == 'team1' ? match.team1Id : match.team2Id;
    
    // Get this over balls
    final thisOverBalls = match.ballByBall.where((b) => 
      b.overNumber == match.currentOver && 
      b.battingTeam == currentTeamId
    ).toList();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFD6DBE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT BALLS (THIS OVER)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: const Color(0xFF1A3365))),
          SizedBox(height: 12.h),
          if (thisOverBalls.isEmpty)
             const Text('No balls bowled yet in this over', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          else
            _buildBallsRow(thisOverBalls),
        ],
      ),
    );
  }

  Widget _buildLiveCommentaryFeed() {
    // Get all balls from the match history
    final allBalls = match.ballByBall.toList(); 
        
    // Show last 30 events (or more users might want to scroll, but let's cap for performance first, or just show all reversed)
    // User asked for "kept two innings comantry one playce", implying full history or at least mixed.
    // Let's show all reversed.
    final displayBalls = allBalls.reversed.toList();
    
    if (displayBalls.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text('FULL MATCH COMMENTARY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: AppTheme.primaryOrange, letterSpacing: 1.2)),
        ),
        SizedBox(height: 12.h),
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
            children: displayBalls.asMap().entries.map((entry) {
              final index = entry.key;
              final ball = entry.value;
              final isLast = index == displayBalls.length - 1;
              
              // Color coding based on event
              Color markerColor = Colors.grey.shade300;
              Color textColor = Colors.black87;
              
              if (ball.wicket != null) {
                markerColor = Colors.red;
                textColor = Colors.red;
              } else if (ball.runs == 4 || ball.runs == 6) {
                markerColor = ball.runs == 6 ? AppTheme.primaryOrange : Colors.blue;
                textColor = markerColor;
              }
              
              return Column(
                children: [
                   Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: isLast && ball.ballNumber != 1 ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ball Number
                        Container(
                          width: 40.w,
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            '${ball.overNumber}.${ball.ballNumber}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.grey),
                          ),
                        ),
                        
                        // Marker
                        Padding(
                          padding: EdgeInsets.only(top: 6.h, right: 12.w),
                          child: CircleAvatar(radius: 3, backgroundColor: markerColor),
                        ),
                        
                        // Commentary Text
                        Expanded(
                          child: Text(
                            ball.commentary,
                            style: TextStyle(
                              fontSize: 13.sp, 
                              color: Colors.black87,
                              fontWeight: ball.wicket != null || ball.runs == 4 || ball.runs == 6 ? FontWeight.w600 : FontWeight.normal,
                              height: 1.4
                            ),
                          ),
                        ),
                        
                        // Runs Badge
                        if (ball.wicket != null || ball.runs > 0 || ball.extraType != null)
                          Container(
                            margin: EdgeInsets.only(left: 8.w),
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                               color: markerColor.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(4.r),
                               border: Border.all(color: markerColor.withOpacity(0.3))
                            ),
                            child: Text(
                              ball.wicket != null ? 'W' : (ball.extraType != null ? ball.extraType![0].toUpperCase() : '${ball.runs}'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp, color: markerColor),
                            ),
                          )
                      ],
                    ),
                  ),
                  
                  // Bowler Change Announcement (if start of over)
                   if (ball.ballNumber == 1)
                     Container(
                       width: double.infinity,
                       padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                       decoration: BoxDecoration(
                         color: Colors.grey.shade50,
                         border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                       ),
                       child: Row(
                         children: [
                           Icon(Icons.sports_cricket, size: 14.sp, color: AppTheme.primaryOrange),
                           SizedBox(width: 8.w),
                           Text(
                             '${ball.bowlerName} into the attack',
                             style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.black54, fontStyle: FontStyle.italic),
                           ),
                         ],
                       ),
                     ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBallsRow(List<BallEvent> balls) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: balls.map((ball) {
          Color bgColor = Colors.white;
          Color textColor = Colors.black87;
          Color borderColor = const Color(0xFFD6DBE9);
          String label = ball.displayString;
          
          if (ball.wicket != null) { 
            bgColor = const Color(0xFFFFEBEE); 
            textColor = Colors.red.shade700;
            borderColor = Colors.red.shade700;
            label = 'W';
          } else if (ball.runs == 4 && ball.extraType == null) { 
            bgColor = const Color(0xFF1565C0);
            textColor = Colors.white; 
            borderColor = const Color(0xFF1565C0);
          } else if (ball.runs == 6 && ball.extraType == null) { 
            bgColor = const Color(0xFF2E7D32);
            textColor = Colors.white; 
            borderColor = const Color(0xFF2E7D32);
          } else if (ball.runs == 0 && ball.extraType == null) {
            bgColor = const Color(0xFFEEF2FA);
            textColor = const Color(0xFF1A3365);
            borderColor = const Color(0xFFD6DBE9);
          } else if (ball.extraType == 'wide' || ball.extraType == 'no-ball') {
            bgColor = Colors.amber.shade700;
            textColor = Colors.white;
            borderColor = Colors.amber.shade900;
          }
          
          return Container(
            margin: EdgeInsets.only(right: 8.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor, width: 1.w),
            ),
            child: Center(
              child: Text(
                label, 
                style: TextStyle(
                  color: textColor, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 13.sp,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildPartnershipCard(Partnership partnership) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16.r),
         boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
         ],
         border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PARTNERSHIP', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange, letterSpacing: 1.5)),
              Text('${partnership.wicketNumber}${_getOrdinalSuffix(partnership.wicketNumber)} Wicket'.toUpperCase(), 
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${partnership.runs}', 
                style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              SizedBox(width: 8.w),
              Text(
                '(${partnership.balls})', 
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          
          // Contribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Row(
              children: [
                Expanded(
                  flex: partnership.batter1Contribution.toInt() == 0 ? 1 : partnership.batter1Contribution.toInt(),
                  child: Container(
                    height: 12.h,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                Container(width: 2.w, height: 12.h, color: Colors.white),
                Expanded(
                  flex: partnership.batter2Contribution.toInt() == 0 ? 1 : partnership.batter2Contribution.toInt(),
                  child: Container(
                    height: 12.h,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          
          // Batter names and individual contributions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToPlayerProfile(partnership.batter1Id, context),
                    child: Text(partnership.batter1Name.split(' ').last.toUpperCase(), 
                      style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryOrange, fontSize: 13.sp, decoration: TextDecoration.underline, decorationColor: Color(0x4DFF9800), decorationStyle: TextDecorationStyle.dotted)),
                  ),
                  Text('${partnership.batter1Runs} (${partnership.batter1Balls})', 
                      style: TextStyle(fontSize: 13.sp, color: Colors.black54, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToPlayerProfile(partnership.batter2Id, context),
                    child: Text(partnership.batter2Name.split(' ').last.toUpperCase(), 
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 13.sp, decoration: TextDecoration.underline, decorationColor: Color(0x4D448AFF), decorationStyle: TextDecorationStyle.dotted)),
                  ),
                  Text('${partnership.batter2Runs} (${partnership.batter2Balls})', 
                      style: TextStyle(fontSize: 13.sp, color: Colors.black54, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSimplePartnershipCard(BatterStats b1, BatterStats b2) {
    final currentBattingTeamId = widget.match.currentBattingTeam == 'team1' ? widget.match.team1Id : widget.match.team2Id;
    final currentInningsBalls = widget.match.ballByBall.where((b) => b.battingTeam == currentBattingTeamId).toList();
    
    int totalRuns = 0;
    int totalBalls = 0;
    int b1Runs = 0;
    
    for (int i = currentInningsBalls.length - 1; i >= 0; i--) {
      final ball = currentInningsBalls[i];
      if (ball.wicket != null) break;
      
      totalRuns += ball.totalRuns;
      if (ball.extraType == null || ball.extraType == 'lb' || ball.extraType == 'b') {
        totalBalls++;
      }
      if (ball.batsmanId == b1.playerId) {
        b1Runs += ball.runs;
      }
    }
    
    final b1Contribution = totalRuns > 0 ? (b1Runs / totalRuns) * 100 : 50.0;
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16.r),
         boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
         ],
         border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text('PARTNERSHIP', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange, letterSpacing: 1.5)),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _navigateToPlayerProfile(b1.playerId, context),
                child: Text(b1.playerName.split(' ').last.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange, fontSize: 14.sp, decoration: TextDecoration.underline, decorationColor: Color(0x4DFF9800), decorationStyle: TextDecorationStyle.dotted)),
              ),
              SizedBox(width: 8.w),
              Text('$totalRuns', style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
              Text(' ($totalBalls)', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _navigateToPlayerProfile(b2.playerId, context),
                child: Text(b2.playerName.split(' ').last.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 14.sp, decoration: TextDecoration.underline, decorationColor: Color(0x4D448AFF), decorationStyle: TextDecorationStyle.dotted)),
              ),
            ],
          ),
          SizedBox(height: 16.h),
           ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Row(
              children: [
                Expanded(
                  flex: b1Contribution.toInt() == 0 ? 1 : b1Contribution.toInt(),
                  child: Container(
                    height: 10.h,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                Container(width: 2.w, height: 10.h, color: Colors.white),
                Expanded(
                  flex: (100 - b1Contribution).toInt() == 0 ? 1 : (100 - b1Contribution).toInt(),
                  child: Container(
                    height: 10.h,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLastWicketCard(LastWicket wicket) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
         color: Colors.red.shade50,
         borderRadius: BorderRadius.circular(16.r),
         boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 4)),
         ],
         border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LAST WICKET', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 1.5)),
              Text('FOW: ${wicket.teamScore}/${wicket.wicketNumber} (${wicket.overs.toStringAsFixed(1)} OV)'.toUpperCase(), 
                  style: TextStyle(fontSize: 11.sp, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToPlayerProfile(wicket.playerId, context),
                      child: Text(
                        wicket.playerName.toUpperCase(), 
                        style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18.sp, letterSpacing: 0.5, color: Colors.black87,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0x4DFF9800),
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      wicket.dismissalString,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13.sp, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 5),
                  ]
                ),
                child: Text(
                  '${wicket.runs} (${wicket.balls})',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildExtrasCard(Extras extras) {
    if (extras.total == 0) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12.r),
         border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('EXTRAS: ', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 12.sp, letterSpacing: 1)),
          Text('${extras.total}', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 15.sp)),
          SizedBox(width: 8.w),
          Container(width: 1.w, height: 16.h, color: Colors.grey.shade300),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              'WD ${extras.wides}, NB ${extras.noBalls}, B ${extras.byes}, LB ${extras.legByes}',
              style: TextStyle(color: Colors.black54, fontSize: 11.sp, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  /// Navigate to player profile when a player name is tapped
  Future<void> _navigateToPlayerProfile(String playerId, BuildContext context) async {
    if (playerId.isEmpty) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      UserModel? user = await FirebaseDataService.instance.findUserByAnyId(playerId);
      
      // Fallback: If not found, assume playerId might actually be the player's name (or a missing ID)
      if (user == null) {
        user = await FirebaseDataService.instance.resolveTemporaryPlayer('', playerId);
      }
      
      if (!context.mounted) return;
      Navigator.pop(context);
      
      if (user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: user!),
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
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading profile')),
        );
      }
    }
  }

  String _formatOvers(int balls) {
    if (balls == 0) return '0.0';
    return '${balls ~/ 6}.${balls % 6}';
  }
}
