import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../widgets/mvp_calculator_widget.dart';
import '../../widgets/key_moments_widget.dart';
import '../../widgets/dls_calculator_widget.dart';

/// Match Summary Screen - Post-match summary with analytics
class MatchSummaryScreen extends StatelessWidget {
  final String matchId;

  const MatchSummaryScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final dataService = FirebaseDataService.instance;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Match Summary'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?q=80&w=2000&auto=format&fit=crop'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.75), BlendMode.srcOver),
          ),
        ),
        child: FutureBuilder<MatchModel?>(
        future: dataService.getMatchById(matchId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final match = snapshot.data!;
          final result = match.result;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Result Card
                _buildResultCard(match, result),
                SizedBox(height: 20.h),

                // Score Comparison
                _buildScoreComparison(match),
                SizedBox(height: 20.h),

                // Manhattan Chart
                _buildSectionTitle('Manhattan Chart'),
                SizedBox(height: 8.h),
                ManhattanChart(ballByBall: match.ballByBall, oversPerSide: match.oversPerSide),
                SizedBox(height: 20.h),

                // Run Rate Chart
                _buildSectionTitle('Run Rate'),
                SizedBox(height: 8.h),
                _buildRunRateCard(match),
                SizedBox(height: 20.h),

                // Top Performers
                _buildSectionTitle('Top Performers'),
                SizedBox(height: 8.h),
                _buildTopPerformers(match),
                SizedBox(height: 20.h),

                // MVP Ratings
                MvpRatingCard(match: match, maxPlayers: 10),
                SizedBox(height: 20.h),

                // Key Moments
                KeyMomentsCard(match: match, showAll: true),
                SizedBox(height: 20.h),

                // DLS Calculator
                DlsCalculatorCard(match: match),
                SizedBox(height: 20.h),

                // Man of the Match
                if (result != null && result.manOfMatch.isNotEmpty) ...[
                  _buildSectionTitle('Man of the Match'),
                  SizedBox(height: 8.h),
                  _buildManOfMatch(result.manOfMatch),
                ],
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildResultCard(MatchModel match, MatchResult? result) {
    final winner = match.winnerTeam ?? (result?.winner ?? 'Match In Progress');
    final margin = match.winningMargin.isNotEmpty ? match.winningMargin : (result?.margin ?? '');
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  winner.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          if (winner != 'Match Tied' && margin.isNotEmpty)
            Text(
              'won by $margin',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          SizedBox(height: 12.h),
          Text(
            match.matchName,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 14.sp, color: Colors.grey[400]),
              SizedBox(width: 4.w),
              Text(
                match.ground,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreComparison(MatchModel match) {
    // Determine which team batted first
    bool team1BattedFirst = true;
    
    if (match.currentInnings == 1) {
      team1BattedFirst = match.currentBattingTeam == 'team1';
    } else if (match.currentInnings == 2) {
      team1BattedFirst = match.currentBattingTeam != 'team1';
    } else if (match.tossWinnerId != null && match.tossDecision != null) {
      if (match.tossWinnerId == match.team1Id) {
        team1BattedFirst = match.tossDecision == 'bat';
      } else {
        team1BattedFirst = match.tossDecision == 'field';
      }
    }

    final firstInningsTeam = team1BattedFirst ? match.team1Name : match.team2Name;
    final secondInningsTeam = team1BattedFirst ? match.team2Name : match.team1Name;
    final firstInningsScore = team1BattedFirst ? match.team1Score : match.team2Score;
    final secondInningsScore = team1BattedFirst ? match.team2Score : match.team1Score;

    return Column(
      children: [
        // 1st Innings
        _buildInningsCard(
          inningsLabel: '1ST INNINGS',
          teamName: firstInningsTeam,
          score: firstInningsScore,
          isWinner: firstInningsTeam == (match.winnerTeam ?? match.result?.winner),
        ),
        SizedBox(height: 12.h),
        // 2nd Innings
        _buildInningsCard(
          inningsLabel: '2ND INNINGS',
          teamName: secondInningsTeam,
          score: secondInningsScore,
          isWinner: secondInningsTeam == (match.winnerTeam ?? match.result?.winner),
        ),
      ],
    );
  }

  Widget _buildInningsCard({
    required String inningsLabel,
    required String teamName,
    required TeamScore score,
    bool isWinner = false,
  }) {
    final runRate = score.overs > 0 ? score.runs / score.overs : 0.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: isWinner
            ? Border.all(color: AppTheme.primaryOrange.withOpacity(0.3), width: 1.5.w)
            : null,
      ),
      child: Column(
        children: [
          // Innings Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isWinner
                    ? [AppTheme.primaryOrange, const Color(0xFFE65100)]
                    : [Colors.grey[700]!, Colors.grey[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  inningsLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                if (isWinner)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      'WINNER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Team Name & Score
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    teamName.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.sp,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.runs}/${score.wickets}',
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '(${score.oversDisplay} ov, RR: ${runRate.toStringAsFixed(2)})',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryOrange,
      ),
    );
  }

  Widget _buildRunRateCard(MatchModel match) {
    final team1RR = match.team1Score.overs > 0
        ? match.team1Score.runs / match.team1Score.overs
        : 0.0;
    final team2RR = match.team2Score.overs > 0
        ? match.team2Score.runs / match.team2Score.overs
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildRunRateStat(match.team1Name, team1RR),
            Container(height: 40.h, width: 1.w, color: Colors.grey[300]),
            _buildRunRateStat(match.team2Name, team2RR),
          ],
        ),
      ),
    );
  }

  Widget _buildRunRateStat(String team, double runRate) {
    return Column(
      children: [
        Text(team, style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 4.h),
        Text(
          runRate.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
        Text('Run Rate', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTopPerformers(MatchModel match) {
    final team1ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team1']!
        : match.team1Score;
    final team2ScoreToUse = match.isSuperOver && match.mainMatchScores != null
        ? match.mainMatchScores!['team2']!
        : match.team2Score;

    // Get top batter and bowler from both teams
    final allBatters = [...team1ScoreToUse.batters, ...team2ScoreToUse.batters];
    final allBowlers = [...team1ScoreToUse.bowlers, ...team2ScoreToUse.bowlers];

    allBatters.sort((a, b) => b.runs.compareTo(a.runs));
    allBowlers.sort((a, b) => b.wickets.compareTo(a.wickets));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            if (allBatters.isNotEmpty)
              _buildPerformerRow(
                '🏏',
                'Top Scorer',
                allBatters.first.playerName,
                '${allBatters.first.runs} (${allBatters.first.balls})',
              ),
            if (allBatters.isNotEmpty && allBowlers.isNotEmpty)
              Divider(height: 20.h),
            if (allBowlers.isNotEmpty)
              _buildPerformerRow(
                '🎯',
                'Top Bowler',
                allBowlers.first.playerName,
                '${allBowlers.first.wickets}/${allBowlers.first.runs}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformerRow(String emoji, String label, String name, String stat) {
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 24.sp)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Text(
          stat,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildManOfMatch(String name) {
    return Card(
      elevation: 3,
      color: Colors.amber.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star, color: Colors.white, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Man of the Match', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                Text(
                  name,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Manhattan Chart Widget - Shows runs per over as bars
class ManhattanChart extends StatelessWidget {
  final List<BallEvent> ballByBall;
  final int oversPerSide;

  const ManhattanChart({
    super.key,
    required this.ballByBall,
    required this.oversPerSide,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate runs per over
    final Map<int, int> runsPerOver = {};
    for (var ball in ballByBall) {
      final over = ball.overNumber;
      runsPerOver[over] = (runsPerOver[over] ?? 0) + ball.runs;
    }

    if (runsPerOver.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Center(
            child: Text(
              'No ball data available',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    final maxRuns = runsPerOver.values.fold(0, (max, v) => v > max ? v : max);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: SizedBox(
          height: 150.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(oversPerSide, (index) {
              final runs = runsPerOver[index] ?? 0;
              final heightPercent = maxRuns > 0 ? runs / maxRuns : 0.0;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$runs',
                        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        height: 100.h * heightPercent,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.8),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${index + 1}',
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
