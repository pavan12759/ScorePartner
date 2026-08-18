import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/team_logo_widget.dart';

/// Defines a visual theme for the match summary poster.
/// Each theme is purely decorative — it never touches match data.
class MatchSummaryTheme {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  // Colors
  final Color backgroundColor;
  final Color cardColor;
  final Color accentColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color scoreHighlightColor;
  final Color dividerColor;
  final Color sectionHeaderColor;

  // Gradient
  final LinearGradient backgroundGradient;
  final LinearGradient? cardGradient;
  final LinearGradient? headerGradient;

  // Style flags
  final bool isGlassmorphic;
  final bool isDark;
  final double cardOpacity;
  final double cardBlur;
  final double cardBorderOpacity;

  const MatchSummaryTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.cardColor,
    required this.accentColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.scoreHighlightColor,
    required this.dividerColor,
    required this.sectionHeaderColor,
    required this.backgroundGradient,
    this.cardGradient,
    this.headerGradient,
    this.isGlassmorphic = false,
    this.isDark = false,
    this.cardOpacity = 1.0,
    this.cardBlur = 0.0,
    this.cardBorderOpacity = 0.1,
  });

  /// Card decoration based on theme style
  BoxDecoration get cardDecoration {
    if (isGlassmorphic) {
      return BoxDecoration(
        color: cardColor.withOpacity(cardOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(cardBorderOpacity),
          width: 1,
        ),
      );
    }
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      gradient: cardGradient,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Generate a team-color based theme from two team names
  static MatchSummaryTheme teamColorsTheme(
      String team1Name, String team2Name) {
    final team1Colors = TeamLogoWidget.gradientForName(team1Name);
    final team2Colors = TeamLogoWidget.gradientForName(team2Name);
    final primary = team1Colors[0];
    final secondary = team2Colors[0];

    return MatchSummaryTheme(
      id: 'team_colors',
      name: 'Team Colors',
      description: 'Auto-generated from team colors',
      icon: Icons.palette,
      backgroundColor: const Color(0xFF1A1A2E),
      cardColor: Colors.white.withOpacity(0.08),
      accentColor: primary,
      textPrimaryColor: Colors.white,
      textSecondaryColor: Colors.white70,
      scoreHighlightColor: primary,
      dividerColor: Colors.white24,
      sectionHeaderColor: primary,
      backgroundGradient: LinearGradient(
        colors: [
          primary.withOpacity(0.8),
          const Color(0xFF1A1A2E),
          secondary.withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      headerGradient: LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      isGlassmorphic: true,
      isDark: true,
      cardOpacity: 0.12,
      cardBlur: 10,
      cardBorderOpacity: 0.15,
    );
  }
}

/// All 8 predefined themes
class MatchSummaryThemes {
  static const classic = MatchSummaryTheme(
    id: 'classic',
    name: 'ScorePartner Classic',
    description: 'Clean and minimal',
    icon: Icons.wb_sunny_outlined,
    backgroundColor: Color(0xFFFFF8F2),
    cardColor: Colors.white,
    accentColor: AppTheme.primaryOrange,
    textPrimaryColor: Color(0xFF1A1A2E),
    textSecondaryColor: Color(0xFF666666),
    scoreHighlightColor: AppTheme.primaryOrange,
    dividerColor: Color(0xFFE0E0E0),
    sectionHeaderColor: AppTheme.primaryOrange,
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFFFF8F2), Color(0xFFFFF0E6)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    headerGradient: LinearGradient(
      colors: [AppTheme.primaryOrange, Color(0xFFFF6B2C)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  );

  static const stadiumNight = MatchSummaryTheme(
    id: 'stadium_night',
    name: 'Stadium Night',
    description: 'Premium broadcast look',
    icon: Icons.nightlight_round,
    backgroundColor: Color(0xFF0A1628),
    cardColor: Color(0xFF122040),
    accentColor: Color(0xFFFFB347),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFB0BEC5),
    scoreHighlightColor: Color(0xFFFFB347),
    dividerColor: Color(0xFF1E3A5F),
    sectionHeaderColor: Color(0xFFFFB347),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0A1628)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF122040), Color(0xFF0E1A30)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  static const glassLive = MatchSummaryTheme(
    id: 'glass_live',
    name: 'Glass Live',
    description: 'Glassmorphism style',
    icon: Icons.blur_on,
    backgroundColor: Color(0xFF1A1A2E),
    cardColor: Colors.white,
    accentColor: AppTheme.primaryOrange,
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFB0B0B0),
    scoreHighlightColor: AppTheme.primaryOrange,
    dividerColor: Color(0x33FFFFFF),
    sectionHeaderColor: AppTheme.primaryOrange,
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    isGlassmorphic: true,
    isDark: true,
    cardOpacity: 0.1,
    cardBlur: 15,
    cardBorderOpacity: 0.2,
  );

  static const cricketGreen = MatchSummaryTheme(
    id: 'cricket_green',
    name: 'Cricket Green',
    description: 'Pitch-inspired design',
    icon: Icons.grass,
    backgroundColor: Color(0xFF1B5E20),
    cardColor: Color(0xFF2E7D32),
    accentColor: Color(0xFFA5D6A7),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFE8F5E9),
    scoreHighlightColor: Colors.white,
    dividerColor: Color(0x44FFFFFF),
    sectionHeaderColor: Color(0xFFA5D6A7),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF1B5E20)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF2E7D32), Color(0xFF256D29)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFF388E3C), Color(0xFF2E7D32)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  static const neonNight = MatchSummaryTheme(
    id: 'neon_night',
    name: 'Neon Night',
    description: 'Electric highlights',
    icon: Icons.electric_bolt,
    backgroundColor: Color(0xFF0D0D0D),
    cardColor: Color(0xFF1A1A1A),
    accentColor: Color(0xFF00E5FF),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFF9E9E9E),
    scoreHighlightColor: Color(0xFF00E5FF),
    dividerColor: Color(0xFF333333),
    sectionHeaderColor: Color(0xFFFF1744),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF0D0D0D), Color(0xFF1A0A2E), Color(0xFF0D0D0D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF1A1A1A), Color(0xFF1A1025)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    isDark: true,
  );

  static const goldChampions = MatchSummaryTheme(
    id: 'gold_champions',
    name: 'Gold Champions',
    description: 'Best for finals',
    icon: Icons.emoji_events,
    backgroundColor: Color(0xFF1A1A1A),
    cardColor: Color(0xFF262626),
    accentColor: Color(0xFFFFD700),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFBDBDBD),
    scoreHighlightColor: Color(0xFFFFD700),
    dividerColor: Color(0xFF444444),
    sectionHeaderColor: Color(0xFFFFD700),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2000), Color(0xFF1A1A1A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF262626), Color(0xFF2A2200)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  static const cleanWhite = MatchSummaryTheme(
    id: 'clean_white',
    name: 'Clean White',
    description: 'Social-media friendly',
    icon: Icons.crop_square,
    backgroundColor: Colors.white,
    cardColor: Color(0xFFF8F9FA),
    accentColor: Color(0xFF424242),
    textPrimaryColor: Color(0xFF212121),
    textSecondaryColor: Color(0xFF757575),
    scoreHighlightColor: Color(0xFF212121),
    dividerColor: Color(0xFFE0E0E0),
    sectionHeaderColor: Color(0xFF424242),
    backgroundGradient: LinearGradient(
      colors: [Colors.white, Color(0xFFF5F5F5)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const royalPurple = MatchSummaryTheme(
    id: 'royal_purple',
    name: 'Royal Purple',
    description: 'Premium velvet feel',
    icon: Icons.diamond,
    backgroundColor: Color(0xFF1A0033),
    cardColor: Color(0xFF2D004D),
    accentColor: Color(0xFFBB86FC),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFE1BEE7),
    scoreHighlightColor: Color(0xFFBB86FC),
    dividerColor: Color(0xFF4A148C),
    sectionHeaderColor: Color(0xFFBB86FC),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF1A0033), Color(0xFF2D004D), Color(0xFF1A0033)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF2D004D), Color(0xFF1A0033)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFFBB86FC), Color(0xFF7B1FA2)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  static const sunsetOrange = MatchSummaryTheme(
    id: 'sunset_orange',
    name: 'Sunset Orange',
    description: 'Warm evening glow',
    icon: Icons.wb_sunny,
    backgroundColor: Color(0xFF2E1400),
    cardColor: Color(0xFF4A2400),
    accentColor: Color(0xFFFF9800),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFFFCC80),
    scoreHighlightColor: Color(0xFFFF9800),
    dividerColor: Color(0xFFBF360C),
    sectionHeaderColor: Color(0xFFFF9800),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF2E1400), Color(0xFF4A2400), Color(0xFF2E1400)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF4A2400), Color(0xFF3E2000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFFFF9800), Color(0xFFE65100)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  static const oceanBlue = MatchSummaryTheme(
    id: 'ocean_blue',
    name: 'Ocean Blue',
    description: 'Deep sea vibes',
    icon: Icons.water_drop,
    backgroundColor: Color(0xFF001F3F),
    cardColor: Color(0xFF003366),
    accentColor: Color(0xFF00BFFF),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFF87CEEB),
    scoreHighlightColor: Color(0xFF00BFFF),
    dividerColor: Color(0xFF001A33),
    sectionHeaderColor: Color(0xFF00BFFF),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF001F3F), Color(0xFF003366), Color(0xFF001F3F)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF003366), Color(0xFF00264D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFF00BFFF), Color(0xFF0077BE)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  static const monochrome = MatchSummaryTheme(
    id: 'monochrome',
    name: 'Monochrome',
    description: 'Classic B&W print style',
    icon: Icons.format_color_reset,
    backgroundColor: Colors.white,
    cardColor: Color(0xFFF5F5F5),
    accentColor: Colors.black,
    textPrimaryColor: Colors.black,
    textSecondaryColor: Color(0xFF666666),
    scoreHighlightColor: Colors.black,
    dividerColor: Color(0xFFCCCCCC),
    sectionHeaderColor: Colors.black,
    backgroundGradient: LinearGradient(
      colors: [Colors.white, Color(0xFFF0F0F0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const fieryRed = MatchSummaryTheme(
    id: 'fiery_red',
    name: 'Fiery Red',
    description: 'High intensity match',
    icon: Icons.local_fire_department,
    backgroundColor: Color(0xFF3E0000),
    cardColor: Color(0xFF5D0000),
    accentColor: Color(0xFFFF3D00),
    textPrimaryColor: Colors.white,
    textSecondaryColor: Color(0xFFFF8A65),
    scoreHighlightColor: Color(0xFFFF3D00),
    dividerColor: Color(0xFFB71C1C),
    sectionHeaderColor: Color(0xFFFF3D00),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF3E0000), Color(0xFF5D0000), Color(0xFF3E0000)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    cardGradient: LinearGradient(
      colors: [Color(0xFF5D0000), Color(0xFF4A0000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFFFF3D00), Color(0xFFDD2C00)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    isDark: true,
  );

  /// All static themes (Team Colors is generated dynamically)
  static List<MatchSummaryTheme> get allStatic => [
        classic,
        stadiumNight,
        glassLive,
        cricketGreen,
        neonNight,
        goldChampions,
        cleanWhite,
        royalPurple,
        sunsetOrange,
        oceanBlue,
        monochrome,
        fieryRed,
      ];

  /// Get all themes including dynamic team colors theme
  static List<MatchSummaryTheme> allWithTeamColors(
      String team1Name, String team2Name) {
    return [
      ...allStatic,
      MatchSummaryTheme.teamColorsTheme(team1Name, team2Name),
    ];
  }
}
