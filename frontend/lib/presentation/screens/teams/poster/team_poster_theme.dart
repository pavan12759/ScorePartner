import 'package:flutter/material.dart';

/// Pre-configured high-aesthetic themes for Team Squad Posters
class TeamPosterTheme {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> backgroundGradient;
  final Color cardBackground;
  final Color cardBorder;
  final Color accentColor;
  final Color secondaryAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color bannerColor;
  final Color goldAccent;
  final Color badgeBackground;

  const TeamPosterTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.backgroundGradient,
    required this.cardBackground,
    required this.cardBorder,
    required this.accentColor,
    required this.secondaryAccent,
    this.textPrimary = Colors.white,
    this.textSecondary = const Color(0xFFCBD5E1),
    required this.bannerColor,
    this.goldAccent = const Color(0xFFFFD700),
    required this.badgeBackground,
  });

  static const List<TeamPosterTheme> allThemes = [
    TeamPosterTheme(
      id: 'midnight_gold',
      name: 'Midnight Gold',
      icon: Icons.shield,
      backgroundGradient: [
        Color(0xFF080C14),
        Color(0xFF111827),
        Color(0xFF0B0F19),
      ],
      cardBackground: Color(0xFF162032),
      cardBorder: Color(0x55F59E0B),
      accentColor: Color(0xFFFFB800),
      secondaryAccent: Color(0xFFFF9100),
      bannerColor: Color(0xFF1E293B),
      goldAccent: Color(0xFFFFD700),
      badgeBackground: Color(0x33FFB800),
    ),
    TeamPosterTheme(
      id: 'royal_blue',
      name: 'Royal Blue',
      icon: Icons.sports_cricket,
      backgroundGradient: [
        Color(0xFF041226),
        Color(0xFF0A2552),
        Color(0xFF061836),
      ],
      cardBackground: Color(0xFF0D316E),
      cardBorder: Color(0x5538BDF8),
      accentColor: Color(0xFF38BDF8),
      secondaryAccent: Color(0xFF818CF8),
      bannerColor: Color(0xFF0B2554),
      goldAccent: Color(0xFFFFD700),
      badgeBackground: Color(0x3338BDF8),
    ),
    TeamPosterTheme(
      id: 'crimson_flame',
      name: 'Crimson Blaze',
      icon: Icons.local_fire_department,
      backgroundGradient: [
        Color(0xFF1C0408),
        Color(0xFF3A0B14),
        Color(0xFF150205),
      ],
      cardBackground: Color(0xFF480F1A),
      cardBorder: Color(0x55F87171),
      accentColor: Color(0xFFEF4444),
      secondaryAccent: Color(0xFFF59E0B),
      bannerColor: Color(0xFF380D15),
      goldAccent: Color(0xFFFFD700),
      badgeBackground: Color(0x33EF4444),
    ),
    TeamPosterTheme(
      id: 'emerald_pitch',
      name: 'Emerald Pitch',
      icon: Icons.grass,
      backgroundGradient: [
        Color(0xFF021711),
        Color(0xFF063325),
        Color(0xFF021912),
      ],
      cardBackground: Color(0xFF094333),
      cardBorder: Color(0x5534D399),
      accentColor: Color(0xFF10B981),
      secondaryAccent: Color(0xFFFBBF24),
      bannerColor: Color(0xFF063B2C),
      goldAccent: Color(0xFFFFD700),
      badgeBackground: Color(0x3310B981),
    ),
    TeamPosterTheme(
      id: 'scorepartner_blaze',
      name: 'ScorePartner Orange',
      icon: Icons.bolt,
      backgroundGradient: [
        Color(0xFF140D08),
        Color(0xFF28150A),
        Color(0xFF100A06),
      ],
      cardBackground: Color(0xFF2E190E),
      cardBorder: Color(0x66FF6B35),
      accentColor: Color(0xFFFF6B35),
      secondaryAccent: Color(0xFFFFB703),
      bannerColor: Color(0xFF24130A),
      goldAccent: Color(0xFFFFB800),
      badgeBackground: Color(0x33FF6B35),
    ),
    TeamPosterTheme(
      id: 'cyber_violet',
      name: 'Neon Violet',
      icon: Icons.auto_awesome,
      backgroundGradient: [
        Color(0xFF0D061E),
        Color(0xFF1E0E3D),
        Color(0xFF0A0417),
      ],
      cardBackground: Color(0xFF291452),
      cardBorder: Color(0x55C084FC),
      accentColor: Color(0xFFA855F7),
      secondaryAccent: Color(0xFFEC4899),
      bannerColor: Color(0xFF200F40),
      goldAccent: Color(0xFFFFD700),
      badgeBackground: Color(0x33A855F7),
    ),
  ];

  static TeamPosterTheme get defaultTheme => allThemes.first;
}

enum PosterFormat {
  auto('Full Poster', null),
  portrait4x5('Instagram 4:5', 4 / 5),
  story9x16('Story 9:16', 9 / 16);

  final String label;
  final double? ratio;
  const PosterFormat(this.label, this.ratio);
}
