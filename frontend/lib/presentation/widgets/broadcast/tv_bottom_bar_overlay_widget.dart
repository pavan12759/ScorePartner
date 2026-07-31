import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';
import 'dart:math';

/// A premium, ultra-aesthetic broadcast bottom bar with glassmorphism,
/// glowing accents, modern typography, and structured stats sections.
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
    // Current inning and team logic
    final isBattingTeam1 = match.currentBattingTeam == 'team1';
    final battingScore = isBattingTeam1 ? match.team1Score : match.team2Score;
    final bowlingScore = isBattingTeam1 ? match.team2Score : match.team1Score;
    final battingTeamName = isBattingTeam1 ? match.team1Name : match.team2Name;
    final bowlingTeamName = isBattingTeam1 ? match.team2Name : match.team1Name;

    // Striker and Non-Striker
    final strikerList = battingScore.batters.where((b) => b.playerId == match.currentStrikerId).toList();
    final nonStrikerList = battingScore.batters.where((b) => b.playerId == match.currentNonStrikerId).toList();
    
    final striker = strikerList.isNotEmpty ? strikerList.first : null;
    final nonStriker = nonStrikerList.isNotEmpty ? nonStrikerList.first : null;

    // Current Bowler
    final bowlerList = bowlingScore.bowlers.where((b) => b.playerId == match.currentBowlerId).toList();
    final bowler = bowlerList.isNotEmpty ? bowlerList.first : null;
    
    // Recent balls
    final recentBalls = _getCurrentOverBalls();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 52.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xEE0F172A),
                  const Color(0xEE1E293B),
                  const Color(0xEE0F172A),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
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
                  child: _buildBowlerSection(bowler, recentBalls, bowlingTeamName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(String teamName, TeamScore score) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.9),
            theme.gradientEnd.withOpacity(0.7),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Team Circle Avatar
          Container(
            width: 32.h,
            height: 32.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              teamName.isNotEmpty ? teamName.substring(0, 1).toUpperCase() : 'T',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    teamName.substring(0, min(3, teamName.length)).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${score.runs}/${score.wickets}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '${score.oversDisplay} OVS',
                      style: TextStyle(
                        color: const Color(0xFF38BDF8),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmenSection(BatterStats? striker, BatterStats? nonStriker) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          if (striker != null)
            Expanded(child: _buildBatterCard(striker, isOnStrike: true)),
          if (striker != null && nonStriker != null)
            Container(
              width: 1,
              height: 20.h,
              color: Colors.white.withOpacity(0.12),
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),
          if (nonStriker != null)
            Expanded(child: _buildBatterCard(nonStriker, isOnStrike: false)),
        ],
      ),
    );
  }

  Widget _buildBatterCard(BatterStats batter, {required bool isOnStrike}) {
    return Row(
      children: [
        if (isOnStrike)
          Container(
            width: 6.w,
            height: 6.w,
            margin: EdgeInsets.only(right: 6.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.8),
                  blurRadius: 6,
                )
              ],
            ),
          ),
        Expanded(
          child: Text(
            batter.playerName,
            style: TextStyle(
              color: isOnStrike ? Colors.white : Colors.white70,
              fontSize: 12.sp,
              fontWeight: isOnStrike ? FontWeight.w800 : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 4.w),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${batter.runs}',
                style: TextStyle(
                  color: const Color(0xFFFACC15),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' (${batter.balls})',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSection(int target) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0x44000000),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TARGET',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            '$target',
            style: TextStyle(
              color: const Color(0xFFF43F5E),
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerSection(BowlerStats? bowler, List<BallEvent> recentBalls, String bowlingTeamName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          if (bowler != null) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bowler.playerName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${bowler.wickets}-${bowler.runs} (${bowler.oversDisplay})',
                  style: TextStyle(
                    color: const Color(0xFFE2E8F0),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(width: 10.w),
          ],

          // Over balls dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: recentBalls.map((ball) => _buildBallPill(ball)).toList(),
            ),
          ),
        ],
      ),
    );
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
      bg = const Color(0xFFA855F7);
      fg = Colors.white;
      text = '6';
    } else if (ball.runs == 4) {
      bg = const Color(0xFF3B82F6);
      fg = Colors.white;
      text = '4';
    } else if (ball.extraType == 'wide') {
      bg = const Color(0xFFF97316);
      fg = Colors.white;
      text = 'Wd';
    } else if (ball.extraType == 'no-ball') {
      bg = const Color(0xFFF97316);
      fg = Colors.white;
      text = 'Nb';
    } else if (ball.runs == 0) {
      bg = Colors.white.withOpacity(0.1);
      fg = Colors.white54;
      text = '•';
    } else {
      bg = Colors.white.withOpacity(0.2);
      fg = Colors.white;
      text = '${ball.runs}';
    }

    return Container(
      width: 20.w,
      height: 20.w,
      margin: EdgeInsets.only(left: 3.w),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: ball.runs >= 4 || ball.wicket != null
            ? [BoxShadow(color: bg.withOpacity(0.6), blurRadius: 4)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24.h,
      color: Colors.white.withOpacity(0.12),
    );
  }

  List<BallEvent> _getCurrentOverBalls() {
    if (match.ballByBall.isEmpty) return [];

    final battingTeamId = match.currentBattingTeam == 'team1' ? match.team1Id : match.team2Id;
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

