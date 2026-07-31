import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Batsman info strip showing current batsmen with runs, balls, SR, 4s, 6s.
/// Highlights on-strike batsman with an animated indicator.
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
    final nonStrikerBatter = nonStriker.isNotEmpty ? nonStriker.first : null;

    if (strikerBatter == null && nonStrikerBatter == null) {
      return const SizedBox.shrink();
    }

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
              Icon(Icons.sports_cricket, color: theme.highlightColor, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                'BATSMEN',
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.6),
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text('R', style: _headerStyle()),
              SizedBox(width: 16.w),
              Text('B', style: _headerStyle()),
              SizedBox(width: 12.w),
              Text('SR', style: _headerStyle()),
              SizedBox(width: 8.w),
              Text('4s', style: _headerStyle()),
              SizedBox(width: 8.w),
              Text('6s', style: _headerStyle()),
            ],
          ),
          SizedBox(height: 4.h),
          Divider(height: 1, color: theme.dividerColor),
          SizedBox(height: 4.h),
          // Striker
          if (strikerBatter != null)
            _buildBatterRow(strikerBatter, isOnStrike: true),
          if (strikerBatter != null && nonStrikerBatter != null)
            SizedBox(height: 4.h),
          // Non-striker
          if (nonStrikerBatter != null)
            _buildBatterRow(nonStrikerBatter, isOnStrike: false),
        ],
      ),
    );
  }

  Widget _buildBatterRow(BatterStats batter, {required bool isOnStrike}) {
    final sr = batter.balls > 0 ? (batter.runs / batter.balls * 100) : 0.0;

    return Row(
      children: [
        // Strike indicator
        if (isOnStrike)
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.highlightColor,
              boxShadow: [
                BoxShadow(
                  color: theme.highlightColor.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          )
        else
          SizedBox(width: 6.w),
        SizedBox(width: 6.w),
        // Name
        Expanded(
          child: Text(
            batter.playerName,
            style: TextStyle(
              color: isOnStrike ? theme.textColor : theme.textColor.withOpacity(0.7),
              fontSize: 11.sp,
              fontWeight: isOnStrike ? FontWeight.w700 : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Stats
        SizedBox(
          width: 28.w,
          child: Text(
            '${batter.runs}',
            style: TextStyle(
              color: theme.scoreColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 28.w,
          child: Text(
            '${batter.balls}',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.6),
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 32.w,
          child: Text(
            sr.toStringAsFixed(1),
            style: TextStyle(
              color: sr > 150
                  ? const Color(0xFF4CAF50)
                  : sr < 80
                      ? const Color(0xFFFF5722)
                      : theme.textColor.withOpacity(0.6),
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 20.w,
          child: Text(
            '${batter.fours}',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.5),
              fontSize: 10.sp,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 20.w,
          child: Text(
            '${batter.sixes}',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.5),
              fontSize: 10.sp,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
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
