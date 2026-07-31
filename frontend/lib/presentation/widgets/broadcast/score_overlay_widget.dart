import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Main scoreboard overlay widget — displays team logos, names,
/// runs/wickets, overs, run rate, target, and live indicator.
/// Adapts appearance to the selected overlay theme.
class ScoreOverlayWidget extends StatelessWidget {
  final MatchModel match;
  final OverlayThemeData theme;
  final int viewerCount;
  final bool showLiveIndicator;

  const ScoreOverlayWidget({
    super.key,
    required this.match,
    required this.theme,
    this.viewerCount = 0,
    this.showLiveIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return _buildThemedContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live indicator + viewer count
          if (showLiveIndicator) _buildLiveBar(),
          SizedBox(height: 4.h),
          // Score content
          _buildScoreContent(),
        ],
      ),
    );
  }

  Widget _buildThemedContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cornerRadius),
      child: BackdropFilter(
        filter: theme.glassBlur > 0
            ? ImageFilter.blur(sigmaX: theme.glassBlur, sigmaY: theme.glassBlur)
            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor.withOpacity(theme.transparency),
            borderRadius: BorderRadius.circular(theme.cornerRadius),
            border: theme.borderWidth > 0
                ? Border.all(
                    color: theme.borderColor,
                    width: theme.borderWidth,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(theme.shadowOpacity),
                blurRadius: theme.shadowBlur,
                offset: const Offset(0, 2),
              ),
              if (theme.hasGlow)
                BoxShadow(
                  color: theme.glowColor,
                  blurRadius: theme.glowRadius,
                  spreadRadius: 1,
                ),
            ],
            gradient: theme.gradientStart != theme.gradientEnd
                ? LinearGradient(
                    colors: [theme.gradientStart, theme.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          padding: EdgeInsets.all(theme.padding),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLiveBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LIVE indicator
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B30).withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6.w,
                height: 6.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // Viewer count
        if (viewerCount > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, color: theme.textColor.withOpacity(0.7), size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                _formatViewerCount(viewerCount),
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.7),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        // Match info
        if (match.tournamentName != null && match.tournamentName!.isNotEmpty)
          Flexible(
            child: Text(
              match.tournamentName!,
              style: TextStyle(
                color: theme.highlightColor,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildScoreContent() {
    final team1 = match.team1Score;
    final team2 = match.team2Score;
    final isBattingTeam1 = match.currentBattingTeam == 'team1';
    final battingScore = isBattingTeam1 ? team1 : team2;
    final bowlingScore = isBattingTeam1 ? team2 : team1;
    final battingName = isBattingTeam1 ? match.team1Name : match.team2Name;
    final bowlingName = isBattingTeam1 ? match.team2Name : match.team1Name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Team 1 row (batting)
        _buildTeamRow(
          teamName: battingName,
          score: battingScore,
          isBatting: true,
          isTeam1: isBattingTeam1,
        ),
        SizedBox(height: 6.h),
        // Divider
        Container(
          height: 0.5,
          color: theme.dividerColor,
        ),
        SizedBox(height: 6.h),
        // Team 2 row (bowling)
        _buildTeamRow(
          teamName: bowlingName,
          score: bowlingScore,
          isBatting: false,
          isTeam1: !isBattingTeam1,
        ),
        SizedBox(height: 8.h),
        // Bottom info bar (CRR, RRR, Target)
        _buildBottomInfoBar(),
      ],
    );
  }

  Widget _buildTeamRow({
    required String teamName,
    required TeamScore score,
    required bool isBatting,
    required bool isTeam1,
  }) {
    return Row(
      children: [
        // Team color dot
        Container(
          width: 4.w,
          height: 28.h,
          decoration: BoxDecoration(
            color: isTeam1 ? theme.primaryColor : theme.highlightColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8.w),
        // Team name
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _abbreviateTeamName(teamName),
                style: TextStyle(
                  color: theme.teamNameColor,
                  fontSize: theme.teamNameFontSize.sp,
                  fontWeight: theme.teamNameFontWeight,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isBatting)
                Text(
                  'Batting',
                  style: TextStyle(
                    color: theme.highlightColor,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        // Score
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${score.runs}',
              style: TextStyle(
                color: theme.scoreColor,
                fontSize: theme.scoreFontSize.sp,
                fontWeight: theme.scoreFontWeight,
                fontFamily: theme.scoreFontFamily,
              ),
            ),
            Text(
              '/${score.wickets}',
              style: TextStyle(
                color: theme.scoreColor.withOpacity(0.7),
                fontSize: (theme.scoreFontSize * 0.65).sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 10.w),
        // Overs
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${_formatOvers(score.overs)} ov',
            style: TextStyle(
              color: theme.highlightColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfoBar() {
    final crr = match.currentRunRate;
    final rrr = match.requiredRunRate;
    final target = match.target;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoChip('CRR', crr.toStringAsFixed(2)),
        if (match.currentInnings == 2 && rrr > 0)
          _buildInfoChip('RRR', rrr.toStringAsFixed(2)),
        if (target != null && match.currentInnings == 2)
          _buildInfoChip('Target', '$target'),
        if (match.currentInnings == 2 && match.runsRequired > 0)
          _buildInfoChip('Need', '${match.runsRequired} off ${match.ballsRemaining}'),
        _buildInfoChip('Overs', '${match.oversPerSide}'),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: theme.textColor.withOpacity(0.5),
            fontSize: 9.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _abbreviateTeamName(String name) {
    if (name.length <= 15) return name;
    // Try to create a 3-letter abbreviation
    final words = name.split(' ');
    if (words.length >= 2) {
      return words.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    }
    return name.substring(0, 3).toUpperCase();
  }

  String _formatOvers(double overs) {
    final completed = overs.floor();
    final balls = ((overs - completed) * 10).round();
    return '$completed.$balls';
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
