import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';
import 'dart:math';

/// Cricbuzz/ICC-inspired premium broadcast bottom bar overlay.
/// 
/// Layout:
/// ┌──────────┬─────────────────────────┬────────┬────────────────────────┐
/// │ TEAM     │  BATSMEN (Strike + NS)  │ TARGET │  BOWLER + THIS OVER   │
/// │ SCORE    │  Name  Runs(Balls) SR   │  num   │  Name  W-R(O)  ●●●●● │
/// └──────────┴─────────────────────────┴────────┴────────────────────────┘
class TvBottomBarOverlayWidget extends StatelessWidget {
  final MatchModel match;
  final OverlayThemeData theme;
  final int viewerCount;

  const TvBottomBarOverlayWidget({
    super.key,
    required this.match,
    required this.theme,
    this.viewerCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isBattingTeam1 = match.currentBattingTeam == 'team1';
    final battingScore = isBattingTeam1 ? match.team1Score : match.team2Score;
    final bowlingScore = isBattingTeam1 ? match.team2Score : match.team1Score;
    final battingTeamName =
        isBattingTeam1 ? match.team1Name : match.team2Name;
    final bowlingTeamName =
        isBattingTeam1 ? match.team2Name : match.team1Name;

    // Striker and Non-Striker
    final strikerList = battingScore.batters
        .where((b) => b.playerId == match.currentStrikerId)
        .toList();
    final nonStrikerList = battingScore.batters
        .where((b) => b.playerId == match.currentNonStrikerId)
        .toList();

    final striker = strikerList.isNotEmpty ? strikerList.first : null;
    final nonStriker =
        nonStrikerList.isNotEmpty ? nonStrikerList.first : null;

    // Current Bowler
    final bowlerList = bowlingScore.bowlers
        .where((b) => b.playerId == match.currentBowlerId)
        .toList();
    final bowler = bowlerList.isNotEmpty ? bowlerList.first : null;

    // Recent balls
    final recentBalls = _getCurrentOverBalls();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xF00D1117),
                  Color(0xF01A1F2E),
                  Color(0xF00D1117),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Team & Score Badge
                  _buildScoreSection(battingTeamName, battingScore),
                  _buildDivider(),
                  // 2. Batsmen Section
                  Expanded(
                    flex: 5,
                    child: _buildBatsmenSection(striker, nonStriker),
                  ),
                  if (match.target != null) ...[
                    _buildDivider(),
                    // 3. Target Badge
                    _buildTargetSection(match.target!),
                  ],
                  _buildDivider(),
                  // 4. Bowler & Over Balls Section
                  Expanded(
                    flex: 5,
                    child: _buildBowlerSection(
                        bowler, recentBalls, bowlingTeamName),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(String teamName, TeamScore score) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.3),
            theme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Team color strip
          Container(
            width: 3.w,
            height: 32.h,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Team circle badge
          Container(
            width: 28.h,
            height: 28.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.15),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              teamName.isNotEmpty
                  ? teamName.substring(0, 1).toUpperCase()
                  : 'T',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    teamName
                        .substring(0, min(3, teamName.length))
                        .toUpperCase(),
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${score.runs}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '/${score.wickets}',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3.r),
                ),
                child: Text(
                  '${score.oversDisplay} OV',
                  style: TextStyle(
                    color: const Color(0xFF38BDF8),
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmenSection(
      BatterStats? striker, BatterStats? nonStriker) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: Row(
        children: [
          if (striker != null)
            Expanded(
                child: _buildBatterCard(striker, isOnStrike: true)),
          if (striker != null && nonStriker != null)
            Container(
              width: 0.5,
              height: 20.h,
              color: Colors.white.withOpacity(0.08),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
            ),
          if (nonStriker != null)
            Expanded(
                child:
                    _buildBatterCard(nonStriker, isOnStrike: false)),
        ],
      ),
    );
  }

  Widget _buildBatterCard(BatterStats batter,
      {required bool isOnStrike}) {
    final sr = batter.balls > 0
        ? (batter.runs / batter.balls * 100).toStringAsFixed(0)
        : '0';

    return Row(
      children: [
        // Strike indicator
        if (isOnStrike)
          Container(
            width: 5.w,
            height: 5.w,
            margin: EdgeInsets.only(right: 5.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          )
        else
          SizedBox(width: 10.w),
        // Player info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                batter.playerName,
                style: TextStyle(
                  color: isOnStrike ? Colors.white : Colors.white60,
                  fontSize: 11.sp,
                  fontWeight:
                      isOnStrike ? FontWeight.w800 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${batter.runs}',
                          style: TextStyle(
                            color: const Color(0xFFFACC15),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: ' (${batter.balls})',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'SR $sr',
                    style: TextStyle(
                      color: _getStrikeRateColor(
                          batter.balls > 0
                              ? batter.runs / batter.balls * 100
                              : 0),
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStrikeRateColor(double sr) {
    if (sr >= 150) return const Color(0xFF22C55E);
    if (sr >= 100) return const Color(0xFF38BDF8);
    if (sr >= 70) return Colors.white38;
    return const Color(0xFFF43F5E).withOpacity(0.7);
  }

  Widget _buildTargetSection(int target) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E).withOpacity(0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TARGET',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 7.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            '$target',
            style: TextStyle(
              color: const Color(0xFFF43F5E),
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (match.runsRequired > 0)
            Text(
              'Need ${match.runsRequired}',
              style: TextStyle(
                color: const Color(0xFFF97316),
                fontSize: 7.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBowlerSection(BowlerStats? bowler,
      List<BallEvent> recentBalls, String bowlingTeamName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: Row(
        children: [
          if (bowler != null) ...[
            // Bowler icon
            Container(
              width: 22.h,
              height: 22.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.sports_baseball,
                color: const Color(0xFFEF4444),
                size: 11.sp,
              ),
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bowler.playerName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        '${bowler.wickets}-${bowler.runs}',
                        style: TextStyle(
                          color: const Color(0xFFEF4444),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ' (${bowler.oversDisplay})',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8.sp,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'E${bowler.economy.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: _getEconomyColor(bowler.economy),
                          fontSize: 7.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
          ],
          // Over balls dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children:
                recentBalls.map((ball) => _buildBallPill(ball)).toList(),
          ),
          SizedBox(width: 8.w),
          // Bowling Team Badge (Far Right)
          Container(
            width: 28.h,
            height: 28.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.highlightColor.withOpacity(0.15),
              border: Border.all(
                color: theme.highlightColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              bowlingTeamName.isNotEmpty
                  ? bowlingTeamName.substring(0, 1).toUpperCase()
                  : 'T',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Team color strip (Right side)
          Container(
            width: 3.w,
            height: 32.h,
            decoration: BoxDecoration(
              color: theme.highlightColor,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: theme.highlightColor.withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEconomyColor(double eco) {
    if (eco <= 6.0) return const Color(0xFF22C55E);
    if (eco <= 8.0) return const Color(0xFF38BDF8);
    if (eco <= 10.0) return const Color(0xFFFACC15);
    return const Color(0xFFF43F5E);
  }

  Widget _buildBallPill(BallEvent ball) {
    Color bg;
    Color fg;
    String text;

    if (ball.wicket != null) {
      bg = const Color(0xFFEF4444);
      fg = Colors.white;
      text = 'W';
    } else if (ball.runs == 6) {
      bg = const Color(0xFF8B5CF6);
      fg = Colors.white;
      text = '6';
    } else if (ball.runs == 4) {
      bg = const Color(0xFF3B82F6);
      fg = Colors.white;
      text = '4';
    } else if (ball.extraType == 'wide') {
      bg = const Color(0xFFF59E0B);
      fg = Colors.black;
      text = 'Wd';
    } else if (ball.extraType == 'no-ball') {
      bg = const Color(0xFFF97316);
      fg = Colors.white;
      text = 'Nb';
    } else if (ball.runs == 0) {
      bg = Colors.white.withOpacity(0.08);
      fg = Colors.white38;
      text = '•';
    } else {
      bg = Colors.white.withOpacity(0.15);
      fg = Colors.white70;
      text = '${ball.runs}';
    }

    final isHighlight = ball.runs >= 4 || ball.wicket != null;

    return Container(
      width: 20.w,
      height: 20.w,
      margin: EdgeInsets.only(left: 2.w),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: bg.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 8.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 0.5,
      color: Colors.white.withOpacity(0.06),
    );
  }

  List<BallEvent> _getCurrentOverBalls() {
    if (match.ballByBall.isEmpty) return [];

    final battingTeamId = match.currentBattingTeam == 'team1'
        ? match.team1Id
        : match.team2Id;
    final inningsBalls = match.ballByBall
        .where((b) => b.battingTeam == battingTeamId)
        .toList();

    if (inningsBalls.isEmpty) return [];

    int legalBalls = 0;
    int currentOver = 0;
    for (final ball in inningsBalls) {
      if (ball.isLegalBall) {
        legalBalls++;
        if (legalBalls >= 6) {
          currentOver++;
          legalBalls = 0;
        }
      }
    }

    final currentOverBalls = <BallEvent>[];
    int count = 0;
    int overIdx = 0;
    for (final ball in inningsBalls) {
      if (overIdx == currentOver) {
        currentOverBalls.add(ball);
      }
      if (ball.isLegalBall) {
        count++;
        if (count >= 6) {
          overIdx++;
          count = 0;
        }
      }
    }
    return currentOverBalls;
  }
}
