import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Flagship Live Broadcast Overlay — Cricbuzz / ICC Live Score inspired.
/// 
/// Architecture:
///   ┌─────────────────────────────────────────────────────────┐
///   │  TOP: Tournament • Match Format • Venue • LIVE badge   │
///   ├─────────────────────────────────────────────────────────┤
///   │                     (spacer)                            │
///   ├─────────────────────────────────────────────────────────┤
///   │  MATCH SITUATION BAR: CRR • RRR • Target • Need        │
///   ├─────────────┬───────────────────────────┬───────────────┤
///   │  TEAM 1     │    BATSMEN + BOWLER       │  THIS OVER    │
///   │  Score/Wkts │    Striker  / Non-striker  │  Ball pills   │
///   │  Overs      │    Current Bowler figures  │               │
///   ├─────────────┤                           ├───────────────┤
///   │  TEAM 2     │                           │               │
///   │  Score/Wkts │                           │               │
///   └─────────────┴───────────────────────────┴───────────────┘
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
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _liveDotController;
  late Animation<double> _liveDotAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _liveDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _liveDotAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _liveDotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveDotController.dispose();
    super.dispose();
  }

  OverlayThemeData get _theme =>
      widget.theme ?? OverlayThemes.scorePartnerLivePlus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TOP HEADER BAR
        _buildTopHeaderBar(),
        const Spacer(),
        // MAIN SCOREBOARD
        _buildMainScoreboard(),
        SizedBox(height: 6.h),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TOP HEADER BAR — Tournament, Format, Venue, LIVE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildTopHeaderBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xE60D1117),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 260) {
                  return _buildCompactTopBar();
                }
                return Row(
                  children: [
                    // Brand badge
                    _buildBrandBadge(constraints.maxWidth),
                    SizedBox(width: 8.w),
                    // Match info
                    Expanded(child: _buildMatchInfoRow()),
                    SizedBox(width: 6.w),
                    // LIVE indicator
                    _buildLiveBadge(),
                    if (constraints.maxWidth >= 500) ...[
                      SizedBox(width: 8.w),
                      _buildViewerBadge(),
                      SizedBox(width: 6.w),
                      _buildQualityBadge(),
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

  Widget _buildCompactTopBar() {
    return Row(
      children: [
        Icon(Icons.bolt, color: _theme.primaryColor, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _compactMatchInfo(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _buildLiveBadge(),
      ],
    );
  }

  Widget _buildBrandBadge(double parentWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_theme.primaryColor, _theme.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(6.r),
        boxShadow: [
          BoxShadow(
            color: _theme.primaryColor.withOpacity(0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: Colors.white, size: 10.sp),
          if (parentWidth >= 300) ...[
            SizedBox(width: 3.w),
            Text(
              'SCOREPARTNER LIVE+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchInfoRow() {
    final parts = <String>[];
    if (widget.match.tournamentName != null &&
        widget.match.tournamentName!.isNotEmpty) {
      parts.add(widget.match.tournamentName!.toUpperCase());
    }
    parts.add('${widget.match.matchFormat.toUpperCase()} MATCH');
    if (widget.match.ground.isNotEmpty) {
      parts.add(widget.match.ground);
    }

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white54,
        fontSize: 8.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _liveDotAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444),
                const Color(0xFFDC2626),
              ],
            ),
            borderRadius: BorderRadius.circular(4.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444)
                    .withOpacity(0.3 + _liveDotAnimation.value * 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5.w,
                height: 5.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(_liveDotAnimation.value),
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
        );
      },
    );
  }

  Widget _buildViewerBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility, color: Colors.white54, size: 10.sp),
        SizedBox(width: 3.w),
        Text(
          _formatViewerCount(widget.viewerCount),
          style: TextStyle(
            color: Colors.white70,
            fontSize: 8.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(3.r),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Text(
        widget.networkQuality,
        style: TextStyle(
          color: const Color(0xFF10B981),
          fontSize: 7.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // MAIN SCOREBOARD — Cricbuzz/ICC inspired layered bottom bar
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildMainScoreboard() {
    final isBattingTeam1 = widget.match.currentBattingTeam == 'team1';
    final team1Score = widget.match.team1Score;
    final team2Score = widget.match.team2Score;
    final team1Name = widget.match.team1Name;
    final team2Name = widget.match.team2Name;
    final battingScore = isBattingTeam1 ? team1Score : team2Score;
    final bowlingScore = isBattingTeam1 ? team2Score : team1Score;
    final battingName = isBattingTeam1 ? team1Name : team2Name;
    final bowlingName = isBattingTeam1 ? team2Name : team1Name;

    // Striker and Non-Striker
    final striker = battingScore.batters
        .where((b) => b.playerId == widget.match.currentStrikerId)
        .toList();
    final nonStriker = battingScore.batters
        .where((b) => b.playerId == widget.match.currentNonStrikerId)
        .toList();
    final currentStriker = striker.isNotEmpty ? striker.first : null;
    final currentNonStriker = nonStriker.isNotEmpty ? nonStriker.first : null;

    // Current Bowler
    final bowlerList = bowlingScore.bowlers
        .where((b) => b.playerId == widget.match.currentBowlerId)
        .toList();
    final bowler = bowlerList.isNotEmpty ? bowlerList.first : null;

    // Ball history for this over
    final recentBalls = _getCurrentOverBalls();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isUltraCompact = constraints.maxWidth < 200;
          final isCompact = constraints.maxWidth < 700;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // MATCH SITUATION BAR (CRR, RRR, Target, Need)
              _buildMatchSituationBar(battingScore),
              SizedBox(height: 2.h),
              // MAIN SCORE STRIP
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _theme.glassBlur > 0 ? _theme.glassBlur : 14.0,
                    sigmaY: _theme.glassBlur > 0 ? _theme.glassBlur : 14.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _theme.backgroundColor
                              .withOpacity(_theme.transparency),
                          _theme.gradientEnd
                              .withOpacity(_theme.transparency * 0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _theme.borderColor.withOpacity(0.15),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        if (_theme.hasGlow)
                          BoxShadow(
                            color: _theme.glowColor.withOpacity(0.2),
                            blurRadius: _theme.glowRadius,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: isUltraCompact
                        ? _buildUltraCompactScore(
                            team1Name, team2Name,
                            team1Score, team2Score,
                            isBattingTeam1)
                        : isCompact
                            ? _buildCompactScoreStrip(
                                battingName, bowlingName,
                                battingScore,
                                currentStriker,
                                bowler,
                                recentBalls,
                              )
                            : _buildFullScoreStrip(
                                battingName, bowlingName,
                                battingScore,
                                currentStriker,
                                currentNonStriker,
                                bowler,
                                recentBalls,
                              ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ━━━ MATCH SITUATION BAR ━━━

  Widget _buildMatchSituationBar(TeamScore battingScore) {
    final crr = widget.match.currentRunRate;
    final rrr = widget.match.requiredRunRate;
    final target = widget.match.target;
    final isSecondInnings = widget.match.currentInnings == 2;

    final chips = <Widget>[];
    chips.add(_buildSituationChip('CRR', crr.toStringAsFixed(2),
        const Color(0xFF38BDF8)));
    if (isSecondInnings && rrr > 0) {
      chips.add(_buildSituationChip('RRR', rrr.toStringAsFixed(2),
          rrr > crr ? const Color(0xFFF43F5E) : const Color(0xFF22C55E)));
    }
    if (target != null && isSecondInnings) {
      chips.add(
          _buildSituationChip('TARGET', '$target', const Color(0xFFFACC15)));
    }
    if (isSecondInnings && widget.match.runsRequired > 0) {
      chips.add(_buildSituationChip(
          'NEED',
          '${widget.match.runsRequired} off ${widget.match.ballsRemaining}',
          const Color(0xFFF97316)));
    }
    chips.add(_buildSituationChip(
        'OVERS', '${widget.match.oversPerSide}', Colors.white38));

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: const Color(0xCC0A0F1A),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: chips,
          ),
        ),
      ),
    );
  }

  Widget _buildSituationChip(String label, String value, Color accentColor) {
    return Flexible(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 7.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━ ULTRA COMPACT (< 200px width) ━━━

  Widget _buildUltraCompactScore(String battingName, String bowlingName,
      TeamScore battingScore, TeamScore bowlingScore, bool isBattingTeam1) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildMiniTeamScore(
                battingName, battingScore, _theme.primaryColor, true),
          ),
          Container(
              width: 1, height: 28.h, color: Colors.white.withOpacity(0.12)),
          Expanded(
            child: Center(
              child: Container(
                width: 24.h,
                height: 24.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _theme.highlightColor.withOpacity(0.15),
                  border: Border.all(
                    color: _theme.highlightColor.withOpacity(0.4),
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
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTeamScore(
      String name, TeamScore score, Color accent, bool isBatting) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBatting)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                _getTeamCode(name),
                style: TextStyle(
                  color: isBatting ? accent : accent.withOpacity(0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Text(
            '${score.runs}/${score.wickets}',
            style: TextStyle(
              color: isBatting ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ COMPACT SCORE STRIP (< 700px) ━━━

  Widget _buildCompactScoreStrip(
    String battingName,
    String bowlingName,
    TeamScore battingScore,
    BatterStats? striker,
    BowlerStats? bowler,
    List<BallEvent> recentBalls,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BATTING TEAM only (TV Style)
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCompactTeamRow(
                    teamName: battingName,
                    score: battingScore,
                    accentColor: _theme.primaryColor,
                    isBatting: true,
                  ),
                ],
              ),
            ),
          ),
          // Vertical divider
          Container(width: 0.5, color: Colors.white.withOpacity(0.1)),
          // PLAYERS + OVER BALLS + BOWLING TEAM BADGE
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (striker != null || bowler != null)
                          Row(
                            children: [
                              if (striker != null)
                                Expanded(
                                  child: _buildCompactPlayerInfo(
                                    name: striker.playerName,
                                    stat: '${striker.runs}(${striker.balls})',
                                    icon: Icons.sports_cricket,
                                    isStrike: true,
                                  ),
                                ),
                              if (bowler != null) ...[
                                Container(
                                  width: 1,
                                  height: 12.h,
                                  color: Colors.white.withOpacity(0.08),
                                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                                ),
                                Expanded(
                                  child: _buildCompactPlayerInfo(
                                    name: bowler.playerName,
                                    stat:
                                        '${bowler.wickets}-${bowler.runs}(${bowler.oversDisplay})',
                                    icon: Icons.sports_baseball,
                                    isStrike: false,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        SizedBox(height: 3.h),
                        // This over balls row
                        Row(
                          children: [
                            Text(
                              'THIS OVER ',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 6.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            ...recentBalls.take(6).map((b) => _buildBallEventPill(b)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Bowling Team Badge (Far Right)
                  Container(
                    width: 24.h,
                    height: 24.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _theme.highlightColor.withOpacity(0.15),
                      border: Border.all(
                        color: _theme.highlightColor.withOpacity(0.4),
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
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  // Bowling team color strip
                  Container(
                    width: 3.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      color: _theme.highlightColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTeamRow({
    required String teamName,
    required TeamScore score,
    required Color accentColor,
    required bool isBatting,
  }) {
    return Row(
      children: [
        // Team color strip
        Container(
          width: 3.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        SizedBox(width: 5.w),
        // Batting indicator
        if (isBatting)
          Container(
            width: 4.w,
            height: 4.w,
            margin: EdgeInsets.only(right: 3.w),
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          )
        else
          SizedBox(width: 7.w),
        // Team code
        Text(
          _getTeamCode(teamName),
          style: TextStyle(
            color: isBatting ? Colors.white : Colors.white54,
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        // Score
        Text(
          '${score.runs}/${score.wickets}',
          style: TextStyle(
            color: isBatting ? Colors.white : Colors.white70,
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 4.w),
        // Overs
        Text(
          '(${score.oversDisplay})',
          style: TextStyle(
            color: isBatting ? accentColor : Colors.white30,
            fontSize: 7.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }


  Widget _buildCompactPlayerInfo({
    required String name,
    required String stat,
    required IconData icon,
    required bool isStrike,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStrike)
          Container(
            width: 4.w,
            height: 4.w,
            margin: EdgeInsets.only(right: 3.w),
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
        Icon(
          icon,
          color: isStrike
              ? const Color(0xFF22C55E)
              : const Color(0xFFEF4444).withOpacity(0.7),
          size: 9.sp,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isStrike ? Colors.white : Colors.white60,
              fontSize: 8.sp,
              fontWeight: isStrike ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          stat,
          style: TextStyle(
            color: isStrike ? const Color(0xFFFACC15) : Colors.white54,
            fontSize: 8.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ━━━ FULL SCORE STRIP (>= 700px width — landscape/desktop) ━━━

  Widget _buildFullScoreStrip(
    String battingName,
    String bowlingName,
    TeamScore battingScore,
    BatterStats? striker,
    BatterStats? nonStriker,
    BowlerStats? bowler,
    List<BallEvent> recentBalls,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ━━ LEFT: BATTING TEAM ONLY ━━
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            alignment: Alignment.center,
            child: _buildTeamScoreRow(
              name: battingName,
              score: battingScore,
              accentColor: _theme.primaryColor,
              isBatting: true,
            ),
          ),
          // Vertical separator
          Container(width: 0.5, color: Colors.white.withOpacity(0.08)),
          // ━━ CENTER: BATSMEN ━━
          Expanded(
            flex: 5,
            child: _buildBatsmenPanel(striker, nonStriker),
          ),
          // Vertical separator
          Container(width: 0.5, color: Colors.white.withOpacity(0.08)),
          // ━━ RIGHT: BOWLER + THIS OVER ━━
          _buildBowlerAndOverPanel(bowler, recentBalls, bowlingName),
        ],
      ),
    );
  }


  Widget _buildTeamScoreRow({
    required String name,
    required TeamScore score,
    required Color accentColor,
    required bool isBatting,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color accent strip (Cricbuzz-style)
        Container(
          width: 3.w,
          height: 22.h,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        SizedBox(width: 6.w),
        // Team initials circle
        Container(
          width: 24.h,
          height: 24.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBatting ? accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: isBatting ? accentColor.withOpacity(0.4) : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _getTeamCode(name).substring(0, min(2, _getTeamCode(name).length)),
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        // Score column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${score.runs}',
                  style: TextStyle(
                    color: isBatting ? Colors.white : Colors.white70,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '/${score.wickets}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(isBatting ? 0.6 : 0.4),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Text(
                    '${score.oversDisplay} OV',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 7.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ━━━ BATSMEN PANEL ━━━

  Widget _buildBatsmenPanel(
      BatterStats? striker, BatterStats? nonStriker) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: Row(
        children: [
          // Striker
          if (striker != null)
            Expanded(
              child: _buildBatterCard(
                batter: striker,
                isOnStrike: true,
              ),
            ),
          if (striker != null && nonStriker != null)
            Container(
              width: 0.5,
              height: 24.h,
              color: Colors.white.withOpacity(0.08),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
            ),
          // Non-striker
          if (nonStriker != null)
            Expanded(
              child: _buildBatterCard(
                batter: nonStriker,
                isOnStrike: false,
              ),
            ),
          // Target info (second innings)
          if (widget.match.target != null &&
              widget.match.currentInnings == 2) ...[
            Container(
              width: 0.5,
              height: 24.h,
              color: Colors.white.withOpacity(0.08),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TGT',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 7.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${widget.match.target}',
                  style: TextStyle(
                    color: const Color(0xFFF43F5E),
                    fontSize: 13.sp,
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

  Widget _buildBatterCard({
    required BatterStats batter,
    required bool isOnStrike,
  }) {
    final sr = batter.balls > 0
        ? (batter.runs / batter.balls * 100).toStringAsFixed(1)
        : '0.0';

    return Row(
      children: [
        // Strike indicator dot
        if (isOnStrike)
          Container(
            width: 5.w,
            height: 5.w,
            margin: EdgeInsets.only(right: 4.w),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          )
        else
          SizedBox(width: 9.w),
        // Player info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                batter.playerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isOnStrike ? Colors.white : Colors.white60,
                  fontSize: 10.sp,
                  fontWeight:
                      isOnStrike ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${batter.runs}',
                    style: TextStyle(
                      color: const Color(0xFFFACC15),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    ' (${batter.balls})',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8.sp,
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
                      fontSize: 7.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (batter.fours > 0 || batter.sixes > 0) ...[
                    SizedBox(width: 4.w),
                    Text(
                      '${batter.fours}×4 ${batter.sixes}×6',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 6.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

  // ━━━ BOWLER + THIS OVER PANEL ━━━

  Widget _buildBowlerAndOverPanel(
    BowlerStats? bowler,
    List<BallEvent> recentBalls,
    String bowlingTeamName,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
            SizedBox(width: 5.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 90.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bowler.playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${bowler.wickets}-${bowler.runs}',
                        style: TextStyle(
                          color: const Color(0xFFEF4444),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ' (${bowler.oversDisplay})',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 7.sp,
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
          // THIS OVER ball pills
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS OVER',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: recentBalls.isEmpty
                    ? [
                        Text(
                          '—',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 8.sp,
                          ),
                        )
                      ]
                    : recentBalls
                        .take(6)
                        .map((ball) => _buildBallEventPill(ball))
                        .toList(),
              ),
            ],
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

  // ━━━ BALL EVENT PILL ━━━

  Widget _buildBallEventPill(BallEvent ball) {
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
    } else if (ball.runs == 3) {
      bg = const Color(0xFF06B6D4);
      fg = Colors.white;
      text = '3';
    } else if (ball.runs == 2) {
      bg = const Color(0xFF14B8A6);
      fg = Colors.white;
      text = '2';
    } else if (ball.runs == 1) {
      bg = Colors.white.withOpacity(0.15);
      fg = Colors.white70;
      text = '1';
    } else if (ball.extraType == 'wide') {
      bg = const Color(0xFFF59E0B);
      fg = Colors.black;
      text = 'Wd';
    } else if (ball.extraType == 'no-ball') {
      bg = const Color(0xFFF97316);
      fg = Colors.white;
      text = 'Nb';
    } else {
      bg = Colors.white.withOpacity(0.08);
      fg = Colors.white38;
      text = '•';
    }

    final isHighlight = ball.runs >= 4 || ball.wicket != null;

    return Container(
      width: 18.w,
      height: 18.w,
      margin: EdgeInsets.only(left: 2.w),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: bg.withOpacity(0.6),
                  blurRadius: 5,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
        border: isHighlight
            ? Border.all(color: fg.withOpacity(0.3), width: 0.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 7.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ━━━ HELPERS ━━━

  String _getTeamCode(String teamName) {
    if (teamName.isEmpty) return 'SP';
    final parts = teamName.trim().split(' ');
    if (parts.length >= 3) {
      return '${parts[0][0]}${parts[1][0]}${parts[2][0]}'.toUpperCase();
    } else if (parts.length == 2) {
      return '${parts[0][0]}${parts[1][0]}${parts[1].length > 1 ? parts[1][1] : ''}'
          .toUpperCase();
    }
    return teamName.substring(0, min(3, teamName.length)).toUpperCase();
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _compactMatchInfo() {
    final t = widget.match.tournamentName;
    if (t != null && t.isNotEmpty) {
      return '${widget.match.matchFormat.toUpperCase()} - $t';
    }
    return '${widget.match.matchFormat.toUpperCase()} MATCH';
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
