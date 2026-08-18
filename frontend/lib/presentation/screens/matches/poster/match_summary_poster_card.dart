import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scorepatner/data/models/match_summary_poster_data.dart';
import 'package:scorepatner/presentation/widgets/team_logo_widget.dart';
import 'package:intl/intl.dart';
import 'match_summary_theme.dart';
import 'match_poster_customization.dart';

/// The renderable poster card widget.
/// This widget builds the visual poster from read-only data.
/// Wrap with Screenshot controller for export.
class MatchSummaryPosterCard extends StatelessWidget {
  final MatchSummaryPosterData data;
  final MatchSummaryTheme theme;
  final MatchPosterCustomization customization;
  final String? team1LogoUrl;
  final String? team2LogoUrl;
  final String matchId;

  const MatchSummaryPosterCard({
    super.key,
    required this.data,
    required this.theme,
    required this.customization,
    this.team1LogoUrl,
    this.team2LogoUrl,
    required this.matchId,
  });

  TextStyle _textStyle({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    final fontFamily = customization.fontFamily;
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? theme.textPrimaryColor,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ===== STYLE HELPERS =====
  Border? _getCardBorder() {
    switch (customization.borderStyle) {
      case PosterBorderStyle.none:
        return null;
      case PosterBorderStyle.thin:
        return Border.all(color: theme.dividerColor, width: 1);
      case PosterBorderStyle.thick:
        return Border.all(color: theme.dividerColor, width: 2);
      case PosterBorderStyle.doubleLine:
        return Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
          bottom: BorderSide(color: theme.dividerColor, width: 1),
          left: BorderSide(color: theme.dividerColor, width: 1),
          right: BorderSide(color: theme.dividerColor, width: 1),
        );
    }
  }

  List<BoxShadow> _getCardShadow() {
    switch (customization.shadowStyle) {
      case PosterShadowStyle.none:
        return [];
      case PosterShadowStyle.subtle:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case PosterShadowStyle.medium:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case PosterShadowStyle.strong:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case PosterShadowStyle.glow:
        return [
          BoxShadow(
            color: theme.accentColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 0),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
    }
  }

  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: theme.cardColor.withOpacity(theme.isGlassmorphic ? 0.85 : 1),
      borderRadius: BorderRadius.circular(customization.cardBorderRadius),
      border: _getCardBorder(),
      boxShadow: _getCardShadow(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: theme.backgroundGradient,
      ),
      child: Stack(
        children: [
          // Custom background image overlay
          if (customization.backgroundType == PosterBackgroundType.customImage &&
              customization.customBackgroundImage != null)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: customization.backgroundBlurAmount,
                      sigmaY: customization.backgroundBlurAmount,
                    ),
                    child: Image.memory(
                      customization.customBackgroundImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    color: Colors.black
                        .withOpacity(customization.backgroundDarkOverlay),
                  ),
                ],
              ),
            ),
          // Stadium background pattern
          if (customization.backgroundType == PosterBackgroundType.stadium)
            Positioned.fill(
              child: CustomPaint(
                painter: _StadiumPatternPainter(
                  color: theme.accentColor.withOpacity(0.05),
                ),
              ),
            ),
          // Main content
          LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Sponsors
                          if (customization.showSponsorLogo && customization.topSponsors.any((s) => s != null)) ...[
                            _buildSponsorRow(customization.topSponsors.where((s) => s != null).toList(), isTop: true),
                            const SizedBox(height: 16),
                          ],
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildTeamScores(),
                          if (customization.showTopBatters &&
                              (data.team1TopBatters.isNotEmpty || data.team2TopBatters.isNotEmpty)) ...[
                            const SizedBox(height: 20),
                            _buildTopBatters(),
                          ],
                          if (customization.showTopBowlers &&
                              (data.team1TopBowlers.isNotEmpty || data.team2TopBowlers.isNotEmpty)) ...[
                            const SizedBox(height: 20),
                            _buildTopBowlers(),
                          ],
                          if (customization.showPlayerOfMatch &&
                              data.manOfMatchName.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildManOfMatch(),
                          ],
                          if (data.hadSuperOver) ...[
                            const SizedBox(height: 16),
                            _buildSuperOverSection(),
                          ],
                          if (customization.showMatchResult) ...[
                            const SizedBox(height: 20),
                            _buildMatchResult(),
                          ],
                          const SizedBox(height: 20),
                          _buildFooter(),
                          // Bottom Sponsors
                          if (customization.showSponsorLogo && customization.bottomSponsors.any((s) => s != null)) ...[
                            const SizedBox(height: 16),
                            _buildSponsorRow(customization.bottomSponsors.where((s) => s != null).toList(), isTop: false),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===== HEADER =====
  Widget _buildHeader() {
    final dateStr = DateFormat('dd MMM yyyy').format(data.date);
    return Column(
      children: [
        // ScorePartner brand
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: theme.headerGradient ??
                LinearGradient(
                  colors: [theme.accentColor, theme.accentColor.withOpacity(0.8)],
                ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'SCOREPARTNER',
            style: _textStyle(
              size: 11,
              weight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Tournament name
        if (data.tournamentName != null &&
            data.tournamentName!.isNotEmpty &&
            customization.showTournamentLogo) ...[
          Text(
            data.tournamentName!.toUpperCase(),
            style: _textStyle(
              size: 13,
              weight: FontWeight.w700,
              color: theme.textSecondaryColor,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
        ],
        // Match title and date
        Text(
          '${data.matchTitle} • $dateStr',
          style: _textStyle(
            size: 11,
            weight: FontWeight.w500,
            color: theme.textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        // Ground
        if (data.ground.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            data.ground,
            style: _textStyle(
              size: 10,
              weight: FontWeight.w400,
              color: theme.textSecondaryColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ===== TEAM SCORES =====
  Widget _buildTeamScores() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _getCardDecoration(),
      child: Row(
        children: [
          // Team 1
          Expanded(child: _buildTeamScoreColumn(
            teamName: data.team1Name,
            score: data.team1Score,
            logoUrl: team1LogoUrl,
            isWinner: data.winnerTeamName != null &&
                data.team1Name.toLowerCase() ==
                    data.winnerTeamName!.toLowerCase(),
          )),
          // VS divider
          Container(
            width: 1,
            height: 70,
            color: theme.dividerColor,
          ),
          // Team 2
          Expanded(child: _buildTeamScoreColumn(
            teamName: data.team2Name,
            score: data.team2Score,
            logoUrl: team2LogoUrl,
            isWinner: data.winnerTeamName != null &&
                data.team2Name.toLowerCase() ==
                    data.winnerTeamName!.toLowerCase(),
          )),
        ],
      ),
    );
  }

  Widget _buildTeamScoreColumn({
    required String teamName,
    required dynamic score,
    String? logoUrl,
    bool isWinner = false,
  }) {
    final runs = score.runs;
    final wickets = score.wickets;
    final oversDisplay = score.oversDisplay;
    final scoreSize = 22.0 * customization.scoreFontSizeMultiplier;

    return Column(
      children: [
        // Team logo
        TeamLogoWidget(
          logoUrl: logoUrl,
          teamName: teamName,
          size: customization.logoSizePixels,
        ),
        const SizedBox(height: 8),
        // Team name
        Text(
          teamName.toUpperCase(),
          style: _textStyle(
            size: 12,
            weight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Score
        Text(
          '$runs/$wickets',
          style: _textStyle(
            size: scoreSize,
            weight: customization.scoreFontWeight,
            color: isWinner ? theme.scoreHighlightColor : theme.textPrimaryColor,
          ),
        ),
        // Overs
        Text(
          '$oversDisplay Overs',
          style: _textStyle(
            size: 10,
            weight: FontWeight.w500,
            color: theme.textSecondaryColor,
          ),
        ),
        if (isWinner) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '✓ WINNER',
              style: _textStyle(
                size: 8,
                weight: FontWeight.w700,
                color: theme.accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===== TOP BATTERS =====
  Widget _buildTopBatters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('⭐', 'TOP BATTERS'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.team1TopBatters.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTeamSubHeader(data.team1Name),
                      const SizedBox(height: 8),
                      for (int i = 0; i < data.team1TopBatters.length; i++) ...[
                        if (i > 0) Divider(color: theme.dividerColor, height: 16),
                        _buildBatterRow(data.team1TopBatters[i], isTop: i == 0),
                      ],
                    ],
                  ),
                ),
              if (data.team1TopBatters.isNotEmpty && data.team2TopBatters.isNotEmpty)
                const SizedBox(width: 16),
              if (data.team2TopBatters.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTeamSubHeader(data.team2Name),
                      const SizedBox(height: 8),
                      for (int i = 0; i < data.team2TopBatters.length; i++) ...[
                        if (i > 0) Divider(color: theme.dividerColor, height: 16),
                        _buildBatterRow(data.team2TopBatters[i], isTop: i == 0),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatterRow(TopBatterData batter, {bool isTop = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    batter.playerName,
                    style: _textStyle(
                      size: isTop ? 14 : 12,
                      weight: isTop ? FontWeight.w700 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (isTop) ...[
                const SizedBox(height: 2),
                Text(
                  batter.detailDisplay,
                  style: _textStyle(
                    size: 9,
                    weight: FontWeight.w400,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          batter.scoreDisplay,
          style: _textStyle(
            size: isTop ? 16 : 13,
            weight: FontWeight.w800,
            color: theme.scoreHighlightColor,
          ),
        ),
      ],
    );
  }

  // ===== TOP BOWLERS =====
  Widget _buildTopBowlers() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('🔥', 'TOP BOWLERS'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.team1TopBowlers.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTeamSubHeader(data.team1Name),
                      const SizedBox(height: 8),
                      for (int i = 0; i < data.team1TopBowlers.length; i++) ...[
                        if (i > 0) Divider(color: theme.dividerColor, height: 16),
                        _buildBowlerRow(data.team1TopBowlers[i], isTop: i == 0),
                      ],
                    ],
                  ),
                ),
              if (data.team1TopBowlers.isNotEmpty && data.team2TopBowlers.isNotEmpty)
                const SizedBox(width: 16),
              if (data.team2TopBowlers.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTeamSubHeader(data.team2Name),
                      const SizedBox(height: 8),
                      for (int i = 0; i < data.team2TopBowlers.length; i++) ...[
                        if (i > 0) Divider(color: theme.dividerColor, height: 16),
                        _buildBowlerRow(data.team2TopBowlers[i], isTop: i == 0),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSubHeader(String teamName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        teamName.toUpperCase(),
        style: _textStyle(
          size: 9,
          weight: FontWeight.w800,
          color: theme.accentColor,
        ),
      ),
    );
  }

  Widget _buildBowlerRow(TopBowlerData bowler, {bool isTop = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    bowler.playerName,
                    style: _textStyle(
                      size: isTop ? 14 : 12,
                      weight: isTop ? FontWeight.w700 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (isTop) ...[
                const SizedBox(height: 2),
                Text(
                  bowler.detailDisplay,
                  style: _textStyle(
                    size: 9,
                    weight: FontWeight.w400,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          bowler.figuresDisplay,
          style: _textStyle(
            size: isTop ? 16 : 13,
            weight: FontWeight.w800,
            color: theme.scoreHighlightColor,
          ),
        ),
      ],
    );
  }

  // ===== MAN OF THE MATCH =====
  Widget _buildManOfMatch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration().copyWith(
        border: Border.all(
          color: theme.accentColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _buildSectionHeader('🏆', 'PLAYER OF THE MATCH'),
          const SizedBox(height: 12),
          // Player avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.accentColor, theme.accentColor.withOpacity(0.7)],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                data.manOfMatchName.isNotEmpty
                    ? data.manOfMatchName[0].toUpperCase()
                    : '?',
                style: _textStyle(
                  size: 22,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.manOfMatchName,
            style: _textStyle(
              size: 16,
              weight: FontWeight.w800,
            ),
          ),
          if (data.manOfMatchTeam.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              data.manOfMatchTeam,
              style: _textStyle(
                size: 11,
                weight: FontWeight.w500,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Performance summary
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (data.manOfMatchBatting != null) ...[
                Text(
                  data.manOfMatchBatting!.scoreDisplay,
                  style: _textStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: theme.scoreHighlightColor,
                  ),
                ),
              ],
              if (data.manOfMatchBatting != null &&
                  data.manOfMatchBowling != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '+',
                    style: _textStyle(
                      size: 12,
                      weight: FontWeight.w600,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
              if (data.manOfMatchBowling != null) ...[
                Text(
                  data.manOfMatchBowling!.figuresDisplay,
                  style: _textStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: theme.scoreHighlightColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===== SUPER OVER =====
  Widget _buildSuperOverSection() {
    if (data.superOverTeam1Score == null || data.superOverTeam2Score == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(theme.isGlassmorphic ? 0.08 : 1),
        borderRadius: BorderRadius.circular(customization.cardBorderRadius),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'SUPER OVER',
            style: _textStyle(
              size: 10,
              weight: FontWeight.w800,
              color: theme.sectionHeaderColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${data.team1Name}  ${data.superOverTeam1Score!.runs}/${data.superOverTeam1Score!.wickets}',
                style: _textStyle(
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'vs',
                  style: _textStyle(
                    size: 10,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ),
              Text(
                '${data.team2Name}  ${data.superOverTeam2Score!.runs}/${data.superOverTeam2Score!.wickets}',
                style: _textStyle(
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== MATCH RESULT =====
  Widget _buildMatchResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: theme.headerGradient ??
            LinearGradient(
              colors: [theme.accentColor, theme.accentColor.withOpacity(0.8)],
            ),
        borderRadius: BorderRadius.circular(customization.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: theme.accentColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        data.resultText,
        style: _textStyle(
          size: 15,
          weight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ===== FOOTER =====
  Widget _buildFooter() {
    return Column(
      children: [
        // Top Sponsors
        if (customization.showSponsorLogo && 
            customization.topSponsors.any((s) => s != null)) ...[
          _buildSponsorRow(customization.topSponsors.where((s) => s != null).toList(), isTop: true),
          const SizedBox(height: 12),
        ],
        // QR Code
        if (customization.showQrCode) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: 'https://scorepartner.in/match/$matchId',
              version: QrVersions.auto,
              size: 60,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Color(0xFF1A1A2E),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan to view full scorecard',
            style: _textStyle(
              size: 8,
              weight: FontWeight.w400,
              color: theme.textSecondaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Bottom Sponsors
        if (customization.showSponsorLogo && 
            customization.bottomSponsors.any((s) => s != null)) ...[
          _buildSponsorRow(customization.bottomSponsors.where((s) => s != null).toList(), isTop: false),
          const SizedBox(height: 12),
        ],
        // Legacy single sponsor (backward compatibility)
        if (customization.showSponsorLogo && customization.sponsorImage != null &&
            customization.topSponsors.every((s) => s == null) &&
            customization.bottomSponsors.every((s) => s == null)) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              customization.sponsorImage!,
              height: customization.sponsorHeight,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Branding
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 2,
              color: theme.dividerColor,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Scored on ScorePartner',
                style: _textStyle(
                  size: 9,
                  weight: FontWeight.w500,
                  color: theme.textSecondaryColor.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 2,
              color: theme.dividerColor,
            ),
          ],
        ),
      ],
    );
  }

  // ===== HELPERS =====
  Widget _buildSectionHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          title,
          style: _textStyle(
            size: 11,
            weight: FontWeight.w800,
            color: theme.sectionHeaderColor,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ===== SPONSOR ROW =====
  Widget _buildSponsorRow(List<Uint8List?> sponsors, {required bool isTop}) {
    if (sponsors.isEmpty) return const SizedBox.shrink();

    final maxSponsors = 4;
    final displaySponsors = sponsors.take(maxSponsors).toList();
    final layout = customization.sponsorLayout;
    final height = customization.sponsorHeight;
    final spacing = customization.sponsorSpacing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(customization.cardBorderRadius),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (layout == SponsorLayout.horizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: displaySponsors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sponsor = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(right: index < displaySponsors.length - 1 ? spacing : 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        sponsor!,
                        height: height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else if (layout == SponsorLayout.vertical)
            Column(
              children: displaySponsors.asMap().entries.map((entry) {
                final index = entry.key;
                final sponsor = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < displaySponsors.length - 1 ? spacing / 2 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      sponsor!,
                      height: height,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              }).toList(),
            )
          else // grid
            Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing / 2,
              children: displaySponsors.map((sponsor) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    sponsor!,
                    height: height,
                    fit: BoxFit.contain,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Paints subtle stadium arc patterns for the stadium background
class _StadiumPatternPainter extends CustomPainter {
  final Color color;

  _StadiumPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw oval arcs resembling stadium seating
    for (int i = 0; i < 5; i++) {
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.3),
        width: size.width * (0.4 + i * 0.3),
        height: size.height * (0.2 + i * 0.15),
      );
      canvas.drawArc(rect, 0.2, 2.7, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
