import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Cricbuzz/ICC-inspired batsman info strip.
/// Shows current batsmen with runs, balls, SR, 4s, 6s in a clean
/// professional broadcast layout with on-strike indicator and
/// color-coded strike rate performance.
class BatsmanOverlayWidget extends StatelessWidget {
  final MatchModel match;
  final OverlayThemeData theme;

  const BatsmanOverlayWidget({
    super.key,
    required this.match,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final battingScore = match.currentBattingTeam == 'team1'
        ? match.team1Score
        : match.team2Score;

    // Find current batsmen
    final striker = battingScore.batters
        .where((b) => b.playerId == match.currentStrikerId)
        .toList();
    final nonStriker = battingScore.batters
        .where((b) => b.playerId == match.currentNonStrikerId)
        .toList();

    final strikerBatter = striker.isNotEmpty ? striker.first : null;
    final nonStrikerBatter =
        nonStriker.isNotEmpty ? nonStriker.first : null;

    if (strikerBatter == null && nonStrikerBatter == null) {
      return const SizedBox.shrink();
    }

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
          // Header with accent strip
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
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.sports_cricket,
                    color: const Color(0xFF22C55E), size: 11.sp),
                SizedBox(width: 4.w),
                Text(
                  'BATTING',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // Column headers
                _buildColumnHeader('R', 28.w),
                _buildColumnHeader('B', 28.w),
                _buildColumnHeader('SR', 32.w),
                _buildColumnHeader('4s', 20.w),
                _buildColumnHeader('6s', 20.w),
              ],
            ),
          ),
          // Batsmen rows
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Striker
                if (strikerBatter != null)
                  _buildBatterRow(strikerBatter, isOnStrike: true),
                if (strikerBatter != null && nonStrikerBatter != null)
                  Container(
                    height: 0.5,
                    margin: EdgeInsets.symmetric(vertical: 3.h),
                    color: Colors.white.withOpacity(0.04),
                  ),
                // Non-striker
                if (nonStrikerBatter != null)
                  _buildBatterRow(nonStrikerBatter, isOnStrike: false),
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

  Widget _buildBatterRow(BatterStats batter, {required bool isOnStrike}) {
    final sr =
        batter.balls > 0 ? (batter.runs / batter.balls * 100) : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        children: [
          // Strike indicator
          if (isOnStrike)
            Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            )
          else
            SizedBox(width: 5.w),
          SizedBox(width: 6.w),
          // Name
          Expanded(
            child: Text(
              batter.playerName,
              style: TextStyle(
                color: isOnStrike ? Colors.white : Colors.white60,
                fontSize: 11.sp,
                fontWeight:
                    isOnStrike ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Runs
          SizedBox(
            width: 28.w,
            child: Text(
              '${batter.runs}',
              style: TextStyle(
                color: const Color(0xFFFACC15),
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Balls
          SizedBox(
            width: 28.w,
            child: Text(
              '${batter.balls}',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Strike Rate (color-coded)
          SizedBox(
            width: 32.w,
            child: Text(
              sr.toStringAsFixed(1),
              style: TextStyle(
                color: _getStrikeRateColor(sr),
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // 4s
          SizedBox(
            width: 20.w,
            child: Text(
              '${batter.fours}',
              style: TextStyle(
                color: batter.fours > 0
                    ? const Color(0xFF3B82F6)
                    : Colors.white24,
                fontSize: 10.sp,
                fontWeight:
                    batter.fours > 0 ? FontWeight.w700 : FontWeight.w400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // 6s
          SizedBox(
            width: 20.w,
            child: Text(
              '${batter.sixes}',
              style: TextStyle(
                color: batter.sixes > 0
                    ? const Color(0xFF8B5CF6)
                    : Colors.white24,
                fontSize: 10.sp,
                fontWeight:
                    batter.sixes > 0 ? FontWeight.w700 : FontWeight.w400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStrikeRateColor(double sr) {
    if (sr >= 150) return const Color(0xFF22C55E);
    if (sr >= 100) return const Color(0xFF38BDF8);
    if (sr >= 70) return Colors.white38;
    return const Color(0xFFF43F5E).withOpacity(0.7);
  }
}
