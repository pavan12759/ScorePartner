import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Cricbuzz/ICC-inspired bowler info strip.
/// Shows current bowler with overs, maidens, runs, wickets, economy
/// and "this over" ball visualization with color-coded economy and
/// glowing wicket/boundary ball pills.
class BowlerOverlayWidget extends StatelessWidget {
  final MatchModel match;
  final OverlayThemeData theme;

  const BowlerOverlayWidget({
    super.key,
    required this.match,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bowlingScore = match.currentBattingTeam == 'team1'
        ? match.team2Score
        : match.team1Score;

    // Find current bowler
    final bowlerList = bowlingScore.bowlers
        .where((b) => b.playerId == match.currentBowlerId)
        .toList();
    final bowler = bowlerList.isNotEmpty ? bowlerList.first : null;

    if (bowler == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(theme.transparency * 0.92),
        borderRadius: BorderRadius.circular(theme.cornerRadius * 0.8),
        border: theme.borderWidth > 0
            ? Border.all(
                color: theme.borderColor.withOpacity(0.15),
                width: 0.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(theme.cornerRadius * 0.8),
                topRight: Radius.circular(theme.cornerRadius * 0.8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.sports_baseball,
                    color: const Color(0xFFEF4444), size: 11.sp),
                SizedBox(width: 4.w),
                Text(
                  'BOWLING',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                _buildColumnHeader('O', 24.w),
                _buildColumnHeader('M', 24.w),
                _buildColumnHeader('R', 24.w),
                _buildColumnHeader('W', 24.w),
                _buildColumnHeader('Econ', 32.w),
              ],
            ),
          ),
          // Bowler row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBowlerRow(bowler),
                SizedBox(height: 5.h),
                // Current over balls with "THIS OVER" label
                _buildCurrentOverBalls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white30,
          fontSize: 7.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildBowlerRow(BowlerStats bowler) {
    final economy = bowler.economy;

    return Row(
      children: [
        // Active bowling indicator
        Container(
          width: 5.w,
          height: 5.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF4444),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(width: 6.w),
        // Name
        Expanded(
          child: Text(
            bowler.playerName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Overs
        SizedBox(
          width: 24.w,
          child: Text(
            bowler.oversDisplay,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // Maidens
        SizedBox(
          width: 24.w,
          child: Text(
            '${bowler.maidens}',
            style: TextStyle(
              color: bowler.maidens > 0
                  ? const Color(0xFF22C55E)
                  : Colors.white30,
              fontSize: 11.sp,
              fontWeight: bowler.maidens > 0
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // Runs
        SizedBox(
          width: 24.w,
          child: Text(
            '${bowler.runs}',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // Wickets (highlighted)
        SizedBox(
          width: 24.w,
          child: Text(
            '${bowler.wickets}',
            style: TextStyle(
              color: bowler.wickets > 0
                  ? const Color(0xFFF43F5E)
                  : Colors.white30,
              fontSize: 11.sp,
              fontWeight: bowler.wickets > 0
                  ? FontWeight.w900
                  : FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // Economy (color-coded)
        SizedBox(
          width: 32.w,
          child: Text(
            economy.toStringAsFixed(1),
            style: TextStyle(
              color: _getEconomyColor(economy),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getEconomyColor(double eco) {
    if (eco <= 6.0) return const Color(0xFF22C55E);
    if (eco <= 8.0) return const Color(0xFF38BDF8);
    if (eco <= 10.0) return const Color(0xFFFACC15);
    return const Color(0xFFF43F5E);
  }

  Widget _buildCurrentOverBalls() {
    final currentOverBalls = _getCurrentOverBalls();

    if (currentOverBalls.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(3.r),
          ),
          child: Text(
            'THIS OVER',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 6.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        ...currentOverBalls.map((ball) => Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: _buildBallDot(ball),
            )),
      ],
    );
  }

  Widget _buildBallDot(BallEvent ball) {
    Color bgColor;
    Color textColor;
    String label;

    if (ball.wicket != null) {
      bgColor = const Color(0xFFEF4444);
      textColor = Colors.white;
      label = 'W';
    } else if (ball.runs == 6) {
      bgColor = const Color(0xFF8B5CF6);
      textColor = Colors.white;
      label = '6';
    } else if (ball.runs == 4) {
      bgColor = const Color(0xFF3B82F6);
      textColor = Colors.white;
      label = '4';
    } else if (ball.extraType == 'wide') {
      bgColor = const Color(0xFFF59E0B);
      textColor = Colors.black;
      label = 'Wd';
    } else if (ball.extraType == 'no-ball') {
      bgColor = const Color(0xFFF97316);
      textColor = Colors.white;
      label = 'Nb';
    } else if (ball.runs == 0) {
      bgColor = Colors.white.withOpacity(0.08);
      textColor = Colors.white38;
      label = '•';
    } else {
      bgColor = Colors.white.withOpacity(0.15);
      textColor = Colors.white70;
      label = '${ball.runs}';
    }

    final isHighlight = ball.runs >= 4 || ball.wicket != null;

    return Container(
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: bgColor.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 8.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
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
