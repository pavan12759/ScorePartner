import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Flagship Live Broadcast Overlay for "ScorePartner Live+".
/// Inspired by modern high-energy cricket broadcast design philosophy (clean, colorful, glassmorphic).
/// Uses large team logo visual identity instead of team name text beside scores.
class ScorePartnerLiveOverlay extends StatefulWidget {
  final MatchModel match;
  final OverlayThemeData? theme;
  final int viewerCount;
  final String networkQuality;

  const ScorePartnerLiveOverlay({
    super.key,
    required this.match,
    this.theme,
    this.viewerCount = 12450,
    this.networkQuality = 'HD 60FPS',
  });

  @override
  State<ScorePartnerLiveOverlay> createState() =>
      _ScorePartnerLiveOverlayState();
}

class _ScorePartnerLiveOverlayState extends State<ScorePartnerLiveOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBattingTeam1 = widget.match.currentBattingTeam == 'team1';
    final battingScore = isBattingTeam1
        ? widget.match.team1Score
        : widget.match.team2Score;
    final bowlingScore = isBattingTeam1
        ? widget.match.team2Score
        : widget.match.team1Score;
    final battingTeamName = isBattingTeam1
        ? widget.match.team1Name
        : widget.match.team2Name;
    final bowlingTeamName = isBattingTeam1
        ? widget.match.team2Name
        : widget.match.team1Name;

    // Striker and Non-Striker
    final strikerList = battingScore.batters
        .where((b) => b.playerId == widget.match.currentStrikerId)
        .toList();
    final nonStrikerList = battingScore.batters
        .where((b) => b.playerId == widget.match.currentNonStrikerId)
        .toList();

    final striker = strikerList.isNotEmpty ? strikerList.first : null;
    final nonStriker = nonStrikerList.isNotEmpty ? nonStrikerList.first : null;

    // Current Bowler
    final bowlerList = bowlingScore.bowlers
        .where((b) => b.playerId == widget.match.currentBowlerId)
        .toList();
    final bowler = bowlerList.isNotEmpty ? bowlerList.first : null;

    // Ball history for last 6 balls
    final recentBalls = _getCurrentOverBalls();

    return Column(
      children: [
        // 1. TOP TELEMETRY BAR
        _buildTopBar(),

        const Spacer(),

        // 2. MAIN CENTER HUD (LEFT TEAM, CENTER STATS, RIGHT TEAM)
        _buildMainHUD(
          battingTeamName: battingTeamName,
          bowlingTeamName: bowlingTeamName,
          battingScore: battingScore,
          bowlingScore: bowlingScore,
          striker: striker,
          nonStriker: nonStriker,
          bowler: bowler,
          recentBalls: recentBalls,
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 1. TOP BAR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildTopBar() {
    final theme = widget.theme ?? OverlayThemes.scorePartnerLivePlus;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: const Color(0xCC0F172A),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The wide bar has several fixed telemetry groups. Switch before
                // the center match-details slot becomes too narrow on scaled web
                // viewports and embedded half-screen previews.
                if (constraints.maxWidth < 1000) {
                  return _buildCompactTopBar(constraints.maxWidth);
                }

                final showLiveIndicator = constraints.maxWidth >= 240;
                final showTelemetry = constraints.maxWidth >= 500;

                return Row(
                  children: [
                    // ScorePartner Live+ Brand Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.primaryColor, theme.gradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Colors.white, size: 12.sp),
                          if (constraints.maxWidth >= 220) ...[
                            SizedBox(width: 3.w),
                            Text(
                              'SCOREPARTNER LIVE+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),

                    // Match details (Tournament / Venue / Format)
                    Expanded(
                      child: Row(
                        children: [
                          if (widget.match.tournamentName != null &&
                              widget.match.tournamentName!.isNotEmpty) ...[
                            Flexible(
                              child: Text(
                                widget.match.tournamentName!.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 9.sp,
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              '${widget.match.matchFormat.toUpperCase()} MATCH',
                              style: TextStyle(
                                color: theme.highlightColor,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.match.ground.isNotEmpty) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 9.sp,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.match.ground,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9.sp,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // LIVE Indicator Pulsing
                    if (showLiveIndicator)
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(4.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.6),
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
                                  color: Colors.white,
                                  shape: BoxShape.circle,
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
                      ),

                    if (showTelemetry) ...[
                      SizedBox(width: 8.w),

                      // Viewer Count Badge
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            color: Colors.white70,
                            size: 10.sp,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            _formatViewerCount(widget.viewerCount),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(width: 8.w),

                      // HD 60FPS Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 5.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          widget.networkQuality,
                          style: TextStyle(
                            color: const Color(0xFF10B981),
                            fontSize: 7.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTopBar(double maxWidth) {
    final theme = widget.theme ?? OverlayThemes.scorePartnerLivePlus;
    final showBrandIcon = maxWidth >= 48;
    final showLiveIndicator = maxWidth >= 150;

    return Row(
      children: [
        if (showBrandIcon) ...[
          Icon(Icons.bolt, color: theme.primaryColor, size: 16),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            _compactTopBarDetails(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showLiveIndicator) ...[
          const SizedBox(width: 4),
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _compactTopBarDetails() {
    final tournamentName = widget.match.tournamentName;
    if (tournamentName != null && tournamentName.isNotEmpty) {
      return '${widget.match.matchFormat.toUpperCase()} - $tournamentName';
    }
    return '${widget.match.matchFormat.toUpperCase()} MATCH';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 2. MAIN CENTER HUD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildMainHUD({
    required String battingTeamName,
    required String bowlingTeamName,
    required TeamScore battingScore,
    required TeamScore bowlingScore,
    required BatterStats? striker,
    required BatterStats? nonStriker,
    required BowlerStats? bowler,
    required List<BallEvent> recentBalls,
  }) {
    final theme = widget.theme ?? OverlayThemes.scorePartnerLivePlus;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useCompactLayout =
              constraints.maxWidth < 900 ||
              theme.layoutType == 'half_screen_compact';
          final useUltraCompactLayout = constraints.maxWidth < 180;

          return ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.glassBlur > 0 ? theme.glassBlur : 12.0,
                sigmaY: theme.glassBlur > 0 ? theme.glassBlur : 12.0,
              ),
              child: Container(
                height: max(36.0, 44.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.backgroundColor.withOpacity(theme.transparency),
                      theme.gradientStart.withOpacity(theme.transparency),
                      theme.gradientEnd.withOpacity(theme.transparency),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: theme.borderColor,
                    width: theme.borderWidth > 0 ? theme.borderWidth : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (theme.hasGlow ? theme.glowColor : Colors.black)
                          .withOpacity(0.4),
                      blurRadius: theme.shadowBlur > 0
                          ? theme.shadowBlur
                          : 12.0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: useUltraCompactLayout
                    ? _buildUltraCompactMainHUD(
                        battingScore: battingScore,
                        bowlingScore: bowlingScore,
                      )
                    : useCompactLayout
                    ? _buildCompactMainHUD(
                        battingTeamName: battingTeamName,
                        bowlingTeamName: bowlingTeamName,
                        battingScore: battingScore,
                        bowlingScore: bowlingScore,
                        bowler: bowler,
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLeftTeamPanel(battingTeamName, battingScore),
                          _buildPanelDivider(),
                          Expanded(
                            flex: 6,
                            child: _buildCenterPanel(striker, nonStriker),
                          ),
                          _buildPanelDivider(),
                          _buildRightTeamPanel(
                            bowlingTeamName,
                            bowler,
                            recentBalls,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUltraCompactMainHUD({
    required TeamScore battingScore,
    required TeamScore bowlingScore,
  }) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${battingScore.runs}/${battingScore.wickets}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(width: 1, height: 22, color: Colors.white24),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${bowlingScore.runs}/${bowlingScore.wickets}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMainHUD({
    required String battingTeamName,
    required String bowlingTeamName,
    required TeamScore battingScore,
    required TeamScore bowlingScore,
    required BowlerStats? bowler,
  }) {
    final theme = widget.theme ?? OverlayThemes.scorePartnerLivePlus;

    return Row(
      children: [
        Expanded(
          child: _buildCompactTeamSummary(
            teamCode: _getTeamCode(battingTeamName),
            primaryText: '${battingScore.runs}/${battingScore.wickets}',
            secondaryText: '${battingScore.oversDisplay} OVS',
            accentColor: theme.primaryColor,
          ),
        ),
        _buildPanelDivider(),
        Expanded(
          child: _buildCompactTeamSummary(
            teamCode: _getTeamCode(bowlingTeamName),
            primaryText: bowler == null
                ? '${bowlingScore.runs}/${bowlingScore.wickets}'
                : '${bowler.wickets}-${bowler.runs}',
            secondaryText: bowler == null
                ? '${bowlingScore.oversDisplay} OVS'
                : '${bowler.oversDisplay} OVS',
            accentColor: theme.highlightColor,
            label: bowler?.playerName,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTeamSummary({
    required String teamCode,
    required String primaryText,
    required String secondaryText,
    required Color accentColor,
    String? label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.25),
              border: Border.all(color: accentColor, width: 1.2),
            ),
            child: Text(
              teamCode,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ?? primaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label == null
                      ? secondaryText
                      : '$primaryText  $secondaryText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// LEFT TEAM PANEL: Compact Team Logo, Score, Overs, CRR, Powerplay
  Widget _buildLeftTeamPanel(String teamName, TeamScore score) {
    final teamCode = _getTeamCode(teamName);
    final crr = widget.match.currentRunRate;
    final theme = widget.theme ?? OverlayThemes.scorePartnerLivePlus;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.gradientStart, theme.gradientEnd],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Team Logo Badge
          Container(
            width: 30.h,
            height: 30.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.highlightColor],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              teamCode,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score Runs / Wickets
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${score.runs}/${score.wickets}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                    child: Text(
                      '${score.oversDisplay} OVS',
                      style: TextStyle(
                        color: const Color(0xFF38BDF8),
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'CRR: ${crr.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                    child: Text(
                      'P1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w900,
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

  /// CENTER PANEL: Striker & Non-Striker with avatars, Runs(Balls), SR, Target
  Widget _buildCenterPanel(BatterStats? striker, BatterStats? nonStriker) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        children: [
          // STRIKER
          if (striker != null)
            Expanded(
              child: _buildPlayerCard(
                name: striker.playerName,
                runs: striker.runs,
                balls: striker.balls,
                fours: striker.fours,
                sixes: striker.sixes,
                isOnStrike: true,
              ),
            ),

          if (striker != null && nonStriker != null)
            Container(
              width: 1,
              height: 22.h,
              color: Colors.white.withOpacity(0.12),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
            ),

          // NON-STRIKER
          if (nonStriker != null)
            Expanded(
              child: _buildPlayerCard(
                name: nonStriker.playerName,
                runs: nonStriker.runs,
                balls: nonStriker.balls,
                fours: nonStriker.fours,
                sixes: nonStriker.sixes,
                isOnStrike: false,
              ),
            ),

          // PARTNERSHIP & TARGET INFOS
          if (widget.match.target != null) ...[
            Container(
              width: 1,
              height: 22.h,
              color: Colors.white.withOpacity(0.12),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'TGT',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 7.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${widget.match.target}',
                  style: TextStyle(
                    color: const Color(0xFFF43F5E),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required int runs,
    required int balls,
    required int fours,
    required int sixes,
    required bool isOnStrike,
  }) {
    final sr = balls > 0 ? (runs / balls * 100).toStringAsFixed(1) : '0.0';

    return Row(
      children: [
        // Compact Player Avatar
        Container(
          width: 24.h,
          height: 24.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnStrike
                ? const Color(0xFF22C55E).withOpacity(0.2)
                : Colors.white10,
            border: Border.all(
              color: isOnStrike ? const Color(0xFF22C55E) : Colors.white24,
              width: isOnStrike ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.person,
            color: isOnStrike ? const Color(0xFF22C55E) : Colors.white70,
            size: 13.sp,
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isOnStrike)
                    Container(
                      width: 4.w,
                      height: 4.w,
                      margin: EdgeInsets.only(right: 3.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isOnStrike ? Colors.white : Colors.white70,
                        fontSize: 10.sp,
                        fontWeight: isOnStrike
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$runs',
                    style: TextStyle(
                      color: const Color(0xFFFACC15),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    ' ($balls)',
                    style: TextStyle(color: Colors.white54, fontSize: 8.sp),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'SR $sr',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 7.sp,
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

  /// RIGHT TEAM PANEL: Compact Opponent Logo, Bowler Photo/Name, Figures (W-R), Economy, Last 6 Balls
  Widget _buildRightTeamPanel(
    String bowlingTeamName,
    BowlerStats? bowler,
    List<BallEvent> recentBalls,
  ) {
    final opponentCode = _getTeamCode(bowlingTeamName);
    final theme = widget.theme ?? OverlayThemes.scorePartnerLivePlus;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bowler != null) ...[
            // Bowler Avatar
            Container(
              width: 24.h,
              height: 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.6),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.sports_baseball,
                color: const Color(0xFFEF4444),
                size: 13.sp,
              ),
            ),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 110.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bowler.playerName,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
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
                        style: TextStyle(color: Colors.white60, fontSize: 8.sp),
                      ),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          'ECO ${bowler.economy.toStringAsFixed(1)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 7.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
          ],

          // Last 6 Balls Animated Pills
          Row(
            children: recentBalls
                .map((ball) => _buildBallEventPill(ball))
                .toList(),
          ),

          SizedBox(width: 6.w),

          // Compact Opponent Team Logo Badge
          Container(
            width: 30.h,
            height: 30.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.highlightColor, theme.secondaryColor],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: theme.highlightColor.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              opponentCode,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ball event pill with custom color animations
  Widget _buildBallEventPill(BallEvent ball) {
    Color bg;
    Color fg;
    String text;

    if (ball.wicket != null) {
      bg = const Color(0xFFEF4444);
      fg = Colors.white;
      text = 'W';
    } else if (ball.runs == 6) {
      bg = const Color(0xFFF59E0B);
      fg = Colors.black;
      text = '6';
    } else if (ball.runs == 4) {
      bg = const Color(0xFFF97316);
      fg = Colors.white;
      text = '4';
    } else if (ball.runs == 3) {
      bg = const Color(0xFFA855F7);
      fg = Colors.white;
      text = '3';
    } else if (ball.runs == 2) {
      bg = const Color(0xFF06B6D4);
      fg = Colors.white;
      text = '2';
    } else if (ball.runs == 1) {
      bg = const Color(0xFF3B82F6);
      fg = Colors.white;
      text = '1';
    } else if (ball.extraType == 'wide') {
      bg = const Color(0xFFEAB308);
      fg = Colors.black;
      text = 'Wd';
    } else if (ball.extraType == 'no-ball') {
      bg = const Color(0xFFF97316);
      fg = Colors.white;
      text = 'Nb';
    } else {
      bg = Colors.white.withOpacity(0.12);
      fg = Colors.white54;
      text = '•';
    }

    return Container(
      width: 16.w,
      height: 16.w,
      margin: EdgeInsets.only(left: 2.w),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: ball.runs >= 4 || ball.wicket != null
            ? [BoxShadow(color: bg.withOpacity(0.8), blurRadius: 4)]
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 3. BOTTOM BAR TICKER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildBottomTicker() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xCC0F172A),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.subtitles,
                  color: const Color(0xFFFF8D48),
                  size: 14.sp,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'LIVE COMMENTARY: Great delivery outside off-stump, batsman defends cleanly back to bowler.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 12.w),
                // Weather / Wind Telemetry
                Row(
                  children: [
                    Icon(
                      Icons.wb_sunny,
                      color: const Color(0xFFFACC15),
                      size: 12.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '28°C',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.air,
                      color: const Color(0xFF38BDF8),
                      size: 12.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '12 km/h NW',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelDivider() {
    return Container(
      width: 1,
      height: 32.h,
      color: Colors.white.withOpacity(0.12),
    );
  }

  String _getTeamCode(String teamName) {
    if (teamName.isEmpty) return 'SP';
    final parts = teamName.trim().split(' ');
    if (parts.length >= 3) {
      return '${parts[0][0]}${parts[1][0]}${parts[2][0]}'.toUpperCase();
    } else if (parts.length == 2) {
      return '${parts[0][0]}${parts[1][0]}${parts[1][1]}'.toUpperCase();
    }
    return teamName.substring(0, min(3, teamName.length)).toUpperCase();
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  List<BallEvent> _getCurrentOverBalls() {
    if (widget.match.ballByBall.isEmpty) return [];

    final battingTeamId = widget.match.currentBattingTeam == 'team1'
        ? widget.match.team1Id
        : widget.match.team2Id;
    final inningsBalls = widget.match.ballByBall
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
    return currentOverBalls.length <= 6
        ? currentOverBalls
        : currentOverBalls.sublist(currentOverBalls.length - 6);
  }
}
