import 'dart:ui';

import 'package:flutter/material.dart';

/// Base overlay theme data class for all broadcast overlay themes.
/// Each theme defines colors, fonts, layout, animations, and effects
/// that transform the score overlay appearance.

class OverlayThemeData {
  final String id;
  final String name;
  final String category;
  final String description;
  final bool isPremium;

  // Colors
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final Color scoreColor;
  final Color teamNameColor;
  final Color highlightColor;
  final Color dividerColor;

  // Gradient
  final Color gradientStart;
  final Color gradientEnd;
  final double gradientAngle; // degrees

  // Typography
  final String fontFamily;
  final String scoreFontFamily;
  final double scoreFontSize;
  final double teamNameFontSize;
  final double labelFontSize;
  final FontWeight scoreFontWeight;
  final FontWeight teamNameFontWeight;

  // Layout
  final String
  layoutType; // 'bottom_bar', 'floating_cards', 'corner_hud', 'top_banner', 'side_panel', 'l_shaped', 'island', 'scattered', 'full_width'
  final double cornerRadius;
  final double padding;
  final double spacing;
  final double scoreBoxHeight;

  // Effects
  final double transparency;
  final double glassBlur;
  final double glassSaturation;
  final double shadowBlur;
  final double shadowOpacity;
  final Color shadowColor;
  final double borderWidth;
  final Color borderColor;
  final bool hasGlow;
  final Color glowColor;
  final double glowRadius;

  // Animation
  final Duration animationDuration;
  final Duration transitionDuration;
  final Curve animationCurve;

  // Special Effects
  final bool hasScanlines;
  final bool hasNeonBorder;
  final bool hasShimmer;
  final bool hasParticles;

  const OverlayThemeData({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    this.isPremium = false,
    // Colors
    this.primaryColor = const Color(0xFFFF8D48),
    this.secondaryColor = const Color(0xFFFFDBCA),
    this.accentColor = const Color(0xFFFFFFFF),
    this.backgroundColor = const Color(0xFF1A1A2E),
    this.textColor = const Color(0xFFFFFFFF),
    this.scoreColor = const Color(0xFFFFFFFF),
    this.teamNameColor = const Color(0xFFFFFFFF),
    this.highlightColor = const Color(0xFFFF8D48),
    this.dividerColor = const Color(0x33FFFFFF),
    // Gradient
    this.gradientStart = const Color(0xFFFF8D48),
    this.gradientEnd = const Color(0xFFFF6B35),
    this.gradientAngle = 135.0,
    // Typography
    this.fontFamily = 'Inter',
    this.scoreFontFamily = 'Inter',
    this.scoreFontSize = 28.0,
    this.teamNameFontSize = 14.0,
    this.labelFontSize = 11.0,
    this.scoreFontWeight = FontWeight.w800,
    this.teamNameFontWeight = FontWeight.w700,
    // Layout
    this.layoutType = 'bottom_bar',
    this.cornerRadius = 12.0,
    this.padding = 12.0,
    this.spacing = 8.0,
    this.scoreBoxHeight = 140.0,
    // Effects
    this.transparency = 0.92,
    this.glassBlur = 0.0,
    this.glassSaturation = 1.0,
    this.shadowBlur = 8.0,
    this.shadowOpacity = 0.3,
    this.shadowColor = const Color(0xFF000000),
    this.borderWidth = 0.0,
    this.borderColor = const Color(0x33FFFFFF),
    this.hasGlow = false,
    this.glowColor = const Color(0xFFFF8D48),
    this.glowRadius = 8.0,
    // Animation
    this.animationDuration = const Duration(milliseconds: 600),
    this.transitionDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOutCubic,
    // Special
    this.hasScanlines = false,
    this.hasNeonBorder = false,
    this.hasShimmer = false,
    this.hasParticles = false,
  });
  double get blurSigma => glassBlur;

  OverlayThemeData copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    bool? isPremium,
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
    Color? backgroundColor,
    Color? textColor,
    Color? scoreColor,
    Color? teamNameColor,
    Color? highlightColor,
    Color? dividerColor,
    Color? gradientStart,
    Color? gradientEnd,
    double? gradientAngle,
    String? fontFamily,
    String? scoreFontFamily,
    double? scoreFontSize,
    double? teamNameFontSize,
    double? labelFontSize,
    FontWeight? scoreFontWeight,
    FontWeight? teamNameFontWeight,
    String? layoutType,
    double? cornerRadius,
    double? padding,
    double? spacing,
    double? scoreBoxHeight,
    double? transparency,
    double? glassBlur,
    double? glassSaturation,
    double? shadowBlur,
    double? shadowOpacity,
    Color? shadowColor,
    double? borderWidth,
    Color? borderColor,
    bool? hasGlow,
    Color? glowColor,
    double? glowRadius,
    Duration? animationDuration,
    Duration? transitionDuration,
    Curve? animationCurve,
    bool? hasScanlines,
    bool? hasNeonBorder,
    bool? hasShimmer,
    bool? hasParticles,
  }) {
    return OverlayThemeData(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      isPremium: isPremium ?? this.isPremium,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      scoreColor: scoreColor ?? this.scoreColor,
      teamNameColor: teamNameColor ?? this.teamNameColor,
      highlightColor: highlightColor ?? this.highlightColor,
      dividerColor: dividerColor ?? this.dividerColor,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      fontFamily: fontFamily ?? this.fontFamily,
      scoreFontFamily: scoreFontFamily ?? this.scoreFontFamily,
      scoreFontSize: scoreFontSize ?? this.scoreFontSize,
      teamNameFontSize: teamNameFontSize ?? this.teamNameFontSize,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      scoreFontWeight: scoreFontWeight ?? this.scoreFontWeight,
      teamNameFontWeight: teamNameFontWeight ?? this.teamNameFontWeight,
      layoutType: layoutType ?? this.layoutType,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      padding: padding ?? this.padding,
      spacing: spacing ?? this.spacing,
      scoreBoxHeight: scoreBoxHeight ?? this.scoreBoxHeight,
      transparency: transparency ?? this.transparency,
      glassBlur: glassBlur ?? this.glassBlur,
      glassSaturation: glassSaturation ?? this.glassSaturation,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowColor: shadowColor ?? this.shadowColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      hasGlow: hasGlow ?? this.hasGlow,
      glowColor: glowColor ?? this.glowColor,
      glowRadius: glowRadius ?? this.glowRadius,
      animationDuration: animationDuration ?? this.animationDuration,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      hasScanlines: hasScanlines ?? this.hasScanlines,
      hasNeonBorder: hasNeonBorder ?? this.hasNeonBorder,
      hasShimmer: hasShimmer ?? this.hasShimmer,
      hasParticles: hasParticles ?? this.hasParticles,
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLAGSHIP OVERLAY THEME: SCOREPARTNER LIVE+
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// OVERLAY THEMES REGISTRY
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Registry of all 15 available broadcast overlay themes
class OverlayThemes {
  // 1. ScorePartner Live+ (Flagship)
  static const scorePartnerLivePlus = OverlayThemeData(
    id: 'scorepartner_live_plus',
    name: 'ScorePartner Live+',
    category: 'Flagship',
    description:
        'Modern, high-energy cricket broadcast overlay with large logo identity and glassmorphism',
    primaryColor: Color(0xFFFF8D48),
    secondaryColor: Color(0xFF0F172A),
    accentColor: Color(0xFFFF8D48),
    backgroundColor: Color(0xDD0F172A),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFF38BDF8),
    dividerColor: Color(0x33FFFFFF),
    gradientStart: Color(0xFF0F172A),
    gradientEnd: Color(0xFF1E293B),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 32.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 24.0,
    padding: 12.0,
    transparency: 0.90,
    glassBlur: 16.0,
    shadowBlur: 16.0,
    borderWidth: 1.0,
    borderColor: Color(0x33FFFFFF),
  );

  // 2. TV Broadcast
  static const tvBroadcast = OverlayThemeData(
    id: 'tv_broadcast',
    name: 'TV Network',
    category: 'Classic',
    description:
        'Clean, professional broadcast look inspired by major sports networks',
    primaryColor: Color(0xFF1565C0),
    secondaryColor: Color(0xFF0D47A1),
    accentColor: Color(0xFFFFD600),
    backgroundColor: Color(0xE6102040),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFFFFD600),
    dividerColor: Color(0x44FFFFFF),
    gradientStart: Color(0xFF1565C0),
    gradientEnd: Color(0xFF0D47A1),
    fontFamily: 'Roboto',
    scoreFontFamily: 'Roboto',
    scoreFontSize: 30.0,
    teamNameFontSize: 13.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'bottom_bar',
    cornerRadius: 12.0,
    padding: 10.0,
    transparency: 0.95,
    shadowBlur: 8.0,
  );

  // 3. Glassmorphism
  static const glassmorphism = OverlayThemeData(
    id: 'glassmorphism',
    name: 'Frosted Glass',
    category: 'Modern',
    description:
        'Frosted glass effect with high blur and translucent white border',
    primaryColor: Color(0x55FFFFFF),
    secondaryColor: Color(0x33FFFFFF),
    accentColor: Color(0xFF00E5FF),
    backgroundColor: Color(0x22FFFFFF),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFF00E5FF),
    dividerColor: Color(0x33FFFFFF),
    gradientStart: Color(0x33FFFFFF),
    gradientEnd: Color(0x11FFFFFF),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w800,
    layoutType: 'scorepartner_live',
    cornerRadius: 20.0,
    padding: 12.0,
    transparency: 0.25,
    glassBlur: 20.0,
    glassSaturation: 1.5,
    shadowBlur: 12.0,
    borderWidth: 1.5,
    borderColor: Color(0x44FFFFFF),
  );

  // 4. Dark Gold
  static const darkGold = OverlayThemeData(
    id: 'dark_gold',
    name: 'Dark Gold',
    category: 'Premium',
    description: 'Luxury dark theme with gold accents for championship matches',
    isPremium: true,
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFC5A059),
    accentColor: Color(0xFFFFE57F),
    backgroundColor: Color(0xF111111),
    textColor: Color(0xFFF5F5F5),
    scoreColor: Color(0xFFFFD700),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFFFFD700),
    dividerColor: Color(0x33FFD700),
    gradientStart: Color(0xFF1A1A1A),
    gradientEnd: Color(0xFF0D0D0D),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 30.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 12.0,
    transparency: 0.95,
    shadowBlur: 8.0,
    borderWidth: 1.5,
    borderColor: Color(0x66FFD700),
    hasGlow: true,
    glowColor: Color(0x33FFD700),
    glowRadius: 8.0,
  );

  // 5. ScorePartner Premium
  static const scorePartnerPremium = OverlayThemeData(
    id: 'scorepartner_premium',
    name: 'ScorePartner Signature',
    category: 'ScorePartner',
    description: 'Signature vibrant orange & deep navy broadcast graphics',
    primaryColor: Color(0xFFFF8D48),
    secondaryColor: Color(0xFFFFDBCA),
    accentColor: Color(0xFFFFFFFF),
    backgroundColor: Color(0xF01A1A2E),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFFFF8D48),
    dividerColor: Color(0x33FF8D48),
    gradientStart: Color(0xFFFF8D48),
    gradientEnd: Color(0xFFFF6B35),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w800,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 12.0,
    transparency: 0.92,
    shadowBlur: 10.0,
    borderWidth: 1.0,
    borderColor: Color(0x33FF8D48),
  );

  // 6. Gaming HUD
  static const gamingHud = OverlayThemeData(
    id: 'gaming_hud',
    name: 'Cyberpunk HUD',
    category: 'Esports',
    description: 'Esports inspired overlay with neon green & pink glow accents',
    primaryColor: Color(0xFF00E676),
    secondaryColor: Color(0xFF00B0FF),
    accentColor: Color(0xFFFF0055),
    backgroundColor: Color(0xF50A0E17),
    textColor: Color(0xFFE0E6ED),
    scoreColor: Color(0xFF00E676),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFFFF0055),
    dividerColor: Color(0x4400E676),
    gradientStart: Color(0xFF0A0E17),
    gradientEnd: Color(0xFF151C2C),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 26.0,
    teamNameFontSize: 13.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 8.0,
    padding: 10.0,
    transparency: 0.95,
    shadowBlur: 6.0,
    borderWidth: 2.0,
    borderColor: Color(0xFF00E676),
    hasNeonBorder: true,
    hasGlow: true,
    glowColor: Color(0x4400E676),
    glowRadius: 10.0,
  );

  // 7. Minimal Clean
  static const minimal = OverlayThemeData(
    id: 'minimal',
    name: 'Minimal Clean',
    category: 'Clean',
    description:
        'Ultra-clean, minimal score overlay focusing on max video visibility',
    primaryColor: Color(0xFFFFFFFF),
    secondaryColor: Color(0xFFB0BEC5),
    accentColor: Color(0xFF263238),
    backgroundColor: Color(0xCC000000),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFCFD8DC),
    highlightColor: Color(0xFF80DEEA),
    dividerColor: Color(0x22FFFFFF),
    gradientStart: Color(0xCC000000),
    gradientEnd: Color(0xCC000000),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 24.0,
    teamNameFontSize: 12.0,
    scoreFontWeight: FontWeight.w700,
    layoutType: 'scorepartner_live',
    cornerRadius: 8.0,
    padding: 8.0,
    transparency: 0.80,
    shadowBlur: 2.0,
  );

  // 8. Tournament Official
  static const tournament = OverlayThemeData(
    id: 'tournament',
    name: 'Official League',
    category: 'Official',
    description:
        'Official tournament broadcast theme with deep blue & magenta accents',
    primaryColor: Color(0xFF3F51B5),
    secondaryColor: Color(0xFF303F9F),
    accentColor: Color(0xFFFF4081),
    backgroundColor: Color(0xEE1A237E),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFE8EAF6),
    highlightColor: Color(0xFFFF4081),
    dividerColor: Color(0x44FFFFFF),
    gradientStart: Color(0xFF1A237E),
    gradientEnd: Color(0xFF283593),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 13.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 10.0,
    transparency: 0.93,
    shadowBlur: 6.0,
  );

  // 9. Neon Nights
  static const neon = OverlayThemeData(
    id: 'neon',
    name: 'Neon Nights',
    category: 'Esports',
    description: 'Vibrant neon purple and electric cyan for night matches',
    isPremium: true,
    primaryColor: Color(0xFFD500F9),
    secondaryColor: Color(0xFF651FFF),
    accentColor: Color(0xFF00E5FF),
    backgroundColor: Color(0xF012002B),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFF00E5FF),
    teamNameColor: Color(0xFFF3E5F5),
    highlightColor: Color(0xFFD500F9),
    dividerColor: Color(0x44D500F9),
    gradientStart: Color(0xFF12002B),
    gradientEnd: Color(0xFF2A004F),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w800,
    layoutType: 'scorepartner_live',
    cornerRadius: 18.0,
    padding: 12.0,
    transparency: 0.90,
    shadowBlur: 10.0,
    borderWidth: 1.5,
    borderColor: Color(0x88D500F9),
    hasNeonBorder: true,
    hasGlow: true,
    glowColor: Color(0x44D500F9),
    glowRadius: 12.0,
  );

  // 10. Retro 80s
  static const retro = OverlayThemeData(
    id: 'retro',
    name: 'Retro 80s',
    category: 'Vintage',
    description: 'Classic amber LED stadium scoreboard theme',
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFFFFAB00),
    accentColor: Color(0xFF76FF03),
    backgroundColor: Color(0xFA1C1917),
    textColor: Color(0xFFFFAB00),
    scoreColor: Color(0xFF76FF03),
    teamNameColor: Color(0xFFFF6D00),
    highlightColor: Color(0xFF76FF03),
    dividerColor: Color(0x33FF6D00),
    gradientStart: Color(0xFF1C1917),
    gradientEnd: Color(0xFF292524),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 30.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 6.0,
    padding: 10.0,
    transparency: 0.98,
    shadowBlur: 4.0,
    borderWidth: 2.0,
    borderColor: Color(0xFFFF6D00),
  );

  // 11. Street Cricket
  static const streetCricket = OverlayThemeData(
    id: 'street_cricket',
    name: 'Street / Gully',
    category: 'Casual',
    description: 'Fun, energetic theme for casual local matches',
    primaryColor: Color(0xFFFF3D00),
    secondaryColor: Color(0xFFFF9100),
    accentColor: Color(0xFFFFEA00),
    backgroundColor: Color(0xEB263238),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFEA00),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFFFF3D00),
    dividerColor: Color(0x33FFFFFF),
    gradientStart: Color(0xFFFF3D00),
    gradientEnd: Color(0xFFFF9100),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 10.0,
    transparency: 0.90,
    shadowBlur: 8.0,
  );

  // 12. Dynamic Island
  static const dynamicIsland = OverlayThemeData(
    id: 'dynamic_island',
    name: 'Capsule Island',
    category: 'Modern',
    description: 'Compact capsule HUD inspired by modern mobile OS UI',
    primaryColor: Color(0xFF000000),
    secondaryColor: Color(0xFF1C1C1E),
    accentColor: Color(0xFF30D158),
    backgroundColor: Color(0xF0000000),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFF30D158),
    teamNameColor: Color(0xFFEBEBF5),
    highlightColor: Color(0xFF0A84FF),
    dividerColor: Color(0x22FFFFFF),
    gradientStart: Color(0xFF000000),
    gradientEnd: Color(0xFF1C1C1E),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 24.0,
    teamNameFontSize: 13.0,
    scoreFontWeight: FontWeight.w800,
    layoutType: 'scorepartner_live',
    cornerRadius: 24.0,
    padding: 10.0,
    transparency: 0.94,
    shadowBlur: 14.0,
    borderWidth: 1.0,
    borderColor: Color(0x33FFFFFF),
  );

  // 13. Transparent Stealth
  static const transparent = OverlayThemeData(
    id: 'transparent',
    name: 'Stealth Floating',
    category: 'Clean',
    description: 'Ultra translucent glass floating over video',
    primaryColor: Color(0xFFFFFFFF),
    secondaryColor: Color(0xFFE0E0E0),
    accentColor: Color(0xFFFFD54F),
    backgroundColor: Color(0x66000000),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFFFFFFF),
    highlightColor: Color(0xFFFFD54F),
    dividerColor: Color(0x22FFFFFF),
    gradientStart: Color(0x66000000),
    gradientEnd: Color(0x44000000),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 32.0,
    teamNameFontSize: 15.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 8.0,
    transparency: 0.40,
    shadowBlur: 12.0,
    shadowOpacity: 0.9,
    shadowColor: Color(0xFF000000),
  );

  // IPL inspired
  static const iplInspired = OverlayThemeData(
    id: 'ipl_inspired',
    name: 'Premier Gold',
    category: 'League Style',
    description:
        'IPL-inspired high-energy gold, royal blue, and floodlight contrast',
    primaryColor: Color(0xFF0288D1),
    secondaryColor: Color(0xFF01579B),
    accentColor: Color(0xFFFFC107),
    backgroundColor: Color(0xEE0D1B2A),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFC107),
    teamNameColor: Color(0xFFE0E0E0),
    highlightColor: Color(0xFFFFC107),
    dividerColor: Color(0x33FFC107),
    gradientStart: Color(0xFF0D1B2A),
    gradientEnd: Color(0xFF1B263B),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 14.0,
    scoreFontWeight: FontWeight.w900,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 10.0,
    transparency: 0.93,
    shadowBlur: 8.0,
    borderWidth: 1.0,
    borderColor: Color(0x44FFC107),
  );

  // 15. The Hundred inspired
  static const hundredInspired = OverlayThemeData(
    id: 'hundred_inspired',
    name: 'Electric 100',
    category: 'League Style',
    description:
        'Bold lime, violet, and coral graphics with a fast modern feel for short-format cricket',
    primaryColor: Color(0xFFB8F500),
    secondaryColor: Color(0xFF32145F),
    accentColor: Color(0xFFFF5C7A),
    backgroundColor: Color(0xF218102D),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFB8F500),
    teamNameColor: Color(0xFFF3E8FF),
    highlightColor: Color(0xFFFF5C7A),
    dividerColor: Color(0x40B8F500),
    gradientStart: Color(0xFF18102D),
    gradientEnd: Color(0xFF4B1F6F),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 32.0,
    teamNameFontSize: 13.0,
    labelFontSize: 9.0,
    scoreFontWeight: FontWeight.w900,
    teamNameFontWeight: FontWeight.w800,
    layoutType: 'scorepartner_live',
    cornerRadius: 14.0,
    padding: 11.0,
    spacing: 8.0,
    scoreBoxHeight: 148.0,
    transparency: 0.94,
    glassBlur: 10.0,
    shadowBlur: 14.0,
    shadowOpacity: 0.45,
    borderWidth: 1.0,
    borderColor: Color(0x66B8F500),
    hasGlow: true,
    glowColor: Color(0x66B8F500),
    glowRadius: 10.0,
    hasNeonBorder: true,
  );

  // 16. BBL inspired
  static const bblInspired = OverlayThemeData(
    id: 'bbl_inspired',
    name: 'Night League',
    category: 'League Style',
    description:
        'A night-stadium look with electric cyan, warm yellow, and deep navy energy',
    primaryColor: Color(0xFF18D7E8),
    secondaryColor: Color(0xFF123D67),
    accentColor: Color(0xFFFFD23F),
    backgroundColor: Color(0xF2081628),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFDCEBFF),
    highlightColor: Color(0xFFFFD23F),
    dividerColor: Color(0x4018D7E8),
    gradientStart: Color(0xFF081628),
    gradientEnd: Color(0xFF14527A),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 31.0,
    teamNameFontSize: 13.0,
    labelFontSize: 9.0,
    scoreFontWeight: FontWeight.w900,
    teamNameFontWeight: FontWeight.w700,
    layoutType: 'scorepartner_live',
    cornerRadius: 12.0,
    padding: 10.0,
    spacing: 8.0,
    scoreBoxHeight: 146.0,
    transparency: 0.94,
    glassBlur: 11.0,
    shadowBlur: 16.0,
    shadowOpacity: 0.5,
    borderWidth: 1.0,
    borderColor: Color(0x5518D7E8),
    hasGlow: true,
    glowColor: Color(0x5518D7E8),
    glowRadius: 11.0,
  );

  // 17. World Cup Broadcast
  static const internationalBroadcast = OverlayThemeData(
    id: 'international_broadcast',
    name: 'World Cup Cyan',
    category: 'Official',
    description: 'World cup broadcast theme with sleek cyan & navy graphics',
    primaryColor: Color(0xFF00B0FF),
    secondaryColor: Color(0xFF0081CB),
    accentColor: Color(0xFF00E676),
    backgroundColor: Color(0xEE0A192F),
    textColor: Color(0xFFFFFFFF),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFF8892B0),
    highlightColor: Color(0xFF64FFDA),
    dividerColor: Color(0x3364FFDA),
    gradientStart: Color(0xFF0A192F),
    gradientEnd: Color(0xFF172A45),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 28.0,
    teamNameFontSize: 13.0,
    scoreFontWeight: FontWeight.w800,
    layoutType: 'scorepartner_live',
    cornerRadius: 16.0,
    padding: 10.0,
    transparency: 0.93,
    shadowBlur: 10.0,
    borderWidth: 1.0,
    borderColor: Color(0x3364FFDA),
  );

  // Full-screen broadcast
  static const fullScreenBroadcast = OverlayThemeData(
    id: 'full_screen_broadcast',
    name: 'Stadium Prime',
    category: 'Broadcast',
    description:
        'A cinematic full-screen scoreboard with deep navy glass, cyan highlights, and broadcast-grade contrast',
    isPremium: true,
    primaryColor: Color(0xFF18D5E8),
    secondaryColor: Color(0xFF0B2236),
    accentColor: Color(0xFFFACC15),
    backgroundColor: Color(0xF20A1622),
    textColor: Color(0xFFF8FAFC),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFE2E8F0),
    highlightColor: Color(0xFF18D5E8),
    dividerColor: Color(0x4018D5E8),
    gradientStart: Color(0xFF0A1622),
    gradientEnd: Color(0xFF123C52),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 34.0,
    teamNameFontSize: 14.0,
    labelFontSize: 10.0,
    scoreFontWeight: FontWeight.w900,
    teamNameFontWeight: FontWeight.w800,
    layoutType: 'full_screen_broadcast',
    cornerRadius: 18.0,
    padding: 14.0,
    spacing: 10.0,
    scoreBoxHeight: 176.0,
    transparency: 0.94,
    glassBlur: 14.0,
    shadowBlur: 18.0,
    shadowOpacity: 0.5,
    borderWidth: 1.0,
    borderColor: Color(0x5518D5E8),
    hasGlow: true,
    glowColor: Color(0x6618D5E8),
    glowRadius: 12.0,
    hasNeonBorder: true,
  );

  // Half-screen compact
  static const halfScreenCompact = OverlayThemeData(
    id: 'half_screen_compact',
    name: 'Half-Screen Compact',
    category: 'Compact',
    description:
        'A restrained half-screen score strip that keeps the score, teams, and live state readable in a split view',
    primaryColor: Color(0xFF22C55E),
    secondaryColor: Color(0xFF12352A),
    accentColor: Color(0xFFF59E0B),
    backgroundColor: Color(0xF2101C1A),
    textColor: Color(0xFFF8FAFC),
    scoreColor: Color(0xFFFFFFFF),
    teamNameColor: Color(0xFFD1FAE5),
    highlightColor: Color(0xFFF59E0B),
    dividerColor: Color(0x4022C55E),
    gradientStart: Color(0xFF101C1A),
    gradientEnd: Color(0xFF173B31),
    fontFamily: 'Inter',
    scoreFontFamily: 'Inter',
    scoreFontSize: 24.0,
    teamNameFontSize: 11.0,
    labelFontSize: 8.0,
    scoreFontWeight: FontWeight.w800,
    teamNameFontWeight: FontWeight.w700,
    layoutType: 'half_screen_compact',
    cornerRadius: 10.0,
    padding: 8.0,
    spacing: 6.0,
    scoreBoxHeight: 96.0,
    transparency: 0.96,
    glassBlur: 8.0,
    shadowBlur: 10.0,
    shadowOpacity: 0.35,
    borderWidth: 1.0,
    borderColor: Color(0x4022C55E),
    hasGlow: true,
    glowColor: Color(0x3322C55E),
    glowRadius: 8.0,
  );

  static const List<OverlayThemeData> all = [
    scorePartnerLivePlus,
    tvBroadcast,
    glassmorphism,
    darkGold,
    scorePartnerPremium,
    gamingHud,
    minimal,
    tournament,
    neon,
    retro,
    streetCricket,
    dynamicIsland,
    transparent,
    iplInspired,
    internationalBroadcast,
    hundredInspired,
    bblInspired,
    fullScreenBroadcast,
    halfScreenCompact,
  ];

  static OverlayThemeData getById(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => scorePartnerLivePlus,
    );
  }
}
