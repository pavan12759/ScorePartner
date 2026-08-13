import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Cricbuzz/ICC-inspired compact scoreboard overlay widget.
/// Displays team scores with colored accent strips, overs, run rate,
/// and match situation — clean, professional broadcast aesthetics.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cornerRadius),
      child: BackdropFilter(
        filter: theme.glassBlur > 0
            ? ImageFilter.blur(
                sigmaX: theme.glassBlur, sigmaY: theme.glassBlur)
            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor.withOpacity(theme.transparency),
            borderRadius: BorderRadius.circular(theme.cornerRadius),
            border: theme.borderWidth > 0
                ? Border.all(
                    color: theme.borderColor.withOpacity(0.2),
                    width: theme.borderWidth * 0.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(theme.shadowOpacity),
                blurRadius: theme.shadowBlur,
                offset: const Offset(0, 4),
              ),
              if (theme.hasGlow)
                BoxShadow(
                  color: theme.glowColor.withOpacity(0.2),
                  blurRadius: theme.glowRadius,
                  spreadRadius: 1,
                ),
            ],
            gradient: theme.gradientStart != theme.gradientEnd
                ? LinearGradient(
                    colors: [
                      theme.gradientStart.withOpacity(theme.transparency),
                      theme.gradientEnd.withOpacity(theme.transparency),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live indicator + match info
              if (showLiveIndicator) _buildLiveBar(),
              // Score content
              _buildScoreContent(),
              // Bottom info bar
              _buildBottomInfoBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // LIVE badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.w,
                  height: 5.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 3.w),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Viewer count
          if (viewerCount > 0) ...[
            Icon(Icons.visibility,
                color: theme.textColor.withOpacity(0.4), size: 10.sp),
            SizedBox(width: 3.w),
            Text(
              _formatViewerCount(viewerCount),
              style: TextStyle(
                color: theme.textColor.withOpacity(0.5),
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8.w),
          ],
          // Tournament name
          if (match.tournamentName != null &&
              match.tournamentName!.isNotEmpty)
            Flexible(
              child: Text(
                match.tournamentName!.toUpperCase(),
                style: TextStyle(
                  color: theme.highlightColor.withOpacity(0.7),
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          Text(
            '${match.matchFormat.toUpperCase()}',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.3),
              fontSize: 7.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreContent() {
    final team1 = match.team1Score;
    final team2 = match.team2Score;
    final isBattingTeam1 = match.currentBattingTeam == 'team1';
    final battingScore = isBattingTeam1 ? team1 : team2;
    final battingName = isBattingTeam1 ? match.team1Name : match.team2Name;
    final bowlingName = isBattingTeam1 ? match.team2Name : match.team1Name;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Batting Team Row
          Expanded(
            child: _buildTeamRow(
              teamName: battingName,
              score: battingScore,
              isBatting: true,
              accentColor: theme.primaryColor,
            ),
          ),
          SizedBox(width: 12.w),
          // Bowling Team Badge
          Container(
            width: 32.h,
            height: 32.h,
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
              bowlingName.isNotEmpty
                  ? bowlingName.substring(0, 1).toUpperCase()
                  : 'T',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 4.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: theme.highlightColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow({
    required String teamName,
    required TeamScore score,
    required bool isBatting,
    required Color accentColor,
  }) {
    return Row(
      children: [
        // Team color accent strip
        Container(
          width: 3.w,
          height: 30.h,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        // Team name column
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _abbreviateTeamName(teamName),
                style: TextStyle(
                  color: isBatting
                      ? theme.teamNameColor
                      : theme.teamNameColor.withOpacity(0.7),
                  fontSize: theme.teamNameFontSize.sp,
                  fontWeight: theme.teamNameFontWeight,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isBatting)
                Row(
                  children: [
                    Container(
                      width: 4.w,
                      height: 4.w,
                      margin: EdgeInsets.only(right: 3.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'BATTING',
                      style: TextStyle(
                        color: const Color(0xFF22C55E),
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Score display
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${score.runs}',
              style: TextStyle(
                color: isBatting
                    ? theme.scoreColor
                    : theme.scoreColor.withOpacity(0.7),
                fontSize: theme.scoreFontSize.sp,
                fontWeight: theme.scoreFontWeight,
                fontFamily: theme.scoreFontFamily,
              ),
            ),
            Text(
              '/${score.wickets}',
              style: TextStyle(
                color: theme.scoreColor.withOpacity(isBatting ? 0.6 : 0.4),
                fontSize: (theme.scoreFontSize * 0.55).sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(width: 8.w),
        // Overs badge
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '${_formatOvers(score.overs)} ov',
            style: TextStyle(
              color: accentColor,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoChip('CRR', crr.toStringAsFixed(2),
              const Color(0xFF38BDF8)),
          if (match.currentInnings == 2 && rrr > 0)
            _buildInfoChip(
                'RRR',
                rrr.toStringAsFixed(2),
                rrr > crr
                    ? const Color(0xFFF43F5E)
                    : const Color(0xFF22C55E)),
          if (target != null && match.currentInnings == 2)
            _buildInfoChip(
                'Target', '$target', const Color(0xFFFACC15)),
          if (match.currentInnings == 2 && match.runsRequired > 0)
            _buildInfoChip(
                'Need',
                '${match.runsRequired} off ${match.ballsRemaining}',
                const Color(0xFFF97316)),
          _buildInfoChip(
              'Overs', '${match.oversPerSide}', Colors.white38),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: theme.textColor.withOpacity(0.35),
            fontSize: 8.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: accentColor,
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _abbreviateTeamName(String name) {
    if (name.length <= 15) return name;
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
