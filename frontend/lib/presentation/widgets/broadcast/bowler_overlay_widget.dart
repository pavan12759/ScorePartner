import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Bowler info strip showing current bowler with overs, maidens, runs, wickets, economy.
/// Also displays the current over balls visualization.
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
        color: theme.backgroundColor.withOpacity(theme.transparency * 0.9),
        borderRadius: BorderRadius.circular(theme.cornerRadius * 0.8),
        border: theme.borderWidth > 0
            ? Border.all(color: theme.borderColor.withOpacity(0.5), width: theme.borderWidth * 0.5)
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.sports_baseball, color: theme.highlightColor, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                'BOWLER',
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.6),
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text('O', style: _headerStyle()),
              SizedBox(width: 14.w),
              Text('M', style: _headerStyle()),
              SizedBox(width: 12.w),
              Text('R', style: _headerStyle()),
              SizedBox(width: 12.w),
              Text('W', style: _headerStyle()),
              SizedBox(width: 8.w),
              Text('Econ', style: _headerStyle()),
            ],
          ),
          SizedBox(height: 4.h),
          Divider(height: 1, color: theme.dividerColor),
          SizedBox(height: 4.h),
          // Bowler row
          _buildBowlerRow(bowler),
          SizedBox(height: 6.h),
          // Current over balls
          _buildCurrentOverBalls(),
        ],
      ),
    );
  }

  Widget _buildBowlerRow(BowlerStats bowler) {
    final economy = bowler.economy;

    return Row(
      children: [
        // Bowling indicator
        Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4CAF50),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.5),
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
              color: theme.textColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Stats
        SizedBox(
          width: 24.w,
          child: Text(
            bowler.oversDisplay,
            style: TextStyle(
              color: theme.textColor.withOpacity(0.7),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 24.w,
          child: Text(
            '${bowler.maidens}',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.6),
              fontSize: 11.sp,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 24.w,
          child: Text(
            '${bowler.runs}',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.7),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 24.w,
          child: Text(
            '${bowler.wickets}',
            style: TextStyle(
              color: bowler.wickets > 0 ? theme.highlightColor : theme.textColor.withOpacity(0.6),
              fontSize: 11.sp,
              fontWeight: bowler.wickets > 0 ? FontWeight.w800 : FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 32.w,
          child: Text(
            economy.toStringAsFixed(1),
            style: TextStyle(
              color: economy > 10
                  ? const Color(0xFFFF5722)
                  : economy < 6
                      ? const Color(0xFF4CAF50)
                      : theme.textColor.withOpacity(0.6),
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentOverBalls() {
    // Get balls from current over
    final currentOverBalls = _getCurrentOverBalls();

    if (currentOverBalls.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          'This Over: ',
          style: TextStyle(
            color: theme.textColor.withOpacity(0.4),
            fontSize: 8.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        ...currentOverBalls.map((ball) => Padding(
              padding: EdgeInsets.only(right: 4.w),
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
      bgColor = const Color(0xFFFF3B30);
      textColor = Colors.white;
      label = 'W';
    } else if (ball.runs == 6) {
      bgColor = const Color(0xFF9C27B0);
      textColor = Colors.white;
      label = '6';
    } else if (ball.runs == 4) {
      bgColor = const Color(0xFF2196F3);
      textColor = Colors.white;
      label = '4';
    } else if (ball.extraType == 'wide') {
      bgColor = const Color(0xFFFF9800);
      textColor = Colors.white;
      label = 'Wd';
    } else if (ball.extraType == 'no-ball') {
      bgColor = const Color(0xFFFF9800);
      textColor = Colors.white;
      label = 'Nb';
    } else if (ball.runs == 0) {
      bgColor = theme.textColor.withOpacity(0.15);
      textColor = theme.textColor.withOpacity(0.6);
      label = '0';
    } else {
      bgColor = theme.textColor.withOpacity(0.2);
      textColor = theme.textColor;
      label = '${ball.runs}';
    }

    return Container(
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 8.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<BallEvent> _getCurrentOverBalls() {
    if (match.ballByBall.isEmpty) return [];

    final battingTeamId = match.currentBattingTeam == 'team1' ? match.team1Id : match.team2Id;
    final inningsBalls = match.ballByBall
        .where((b) => b.battingTeam == battingTeamId)
        .toList();

    if (inningsBalls.isEmpty) return [];

    // Get current over number
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

    // Collect balls from current over
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



  TextStyle _headerStyle() {
    return TextStyle(
      color: theme.textColor.withOpacity(0.4),
      fontSize: 8.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }
}
