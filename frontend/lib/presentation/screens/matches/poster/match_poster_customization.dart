import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'match_summary_theme.dart';

/// Poster customization state. This is purely visual configuration —
/// it NEVER modifies match statistics.
class MatchPosterCustomization extends ChangeNotifier {
  // Theme
  MatchSummaryTheme _selectedTheme = MatchSummaryThemes.classic;
  MatchSummaryTheme get selectedTheme => _selectedTheme;
  set selectedTheme(MatchSummaryTheme theme) {
    _selectedTheme = theme;
    _invalidateCache();
    notifyListeners();
  }

  // Aspect ratio
  PosterAspectRatio _aspectRatio = PosterAspectRatio.portrait4x5;
  PosterAspectRatio get aspectRatio => _aspectRatio;
  set aspectRatio(PosterAspectRatio ratio) {
    _aspectRatio = ratio;
    _invalidateCache();
    notifyListeners();
  }

  // Background
  PosterBackgroundType _backgroundType = PosterBackgroundType.defaultBg;
  PosterBackgroundType get backgroundType => _backgroundType;
  set backgroundType(PosterBackgroundType type) {
    _backgroundType = type;
    _invalidateCache();
    notifyListeners();
  }

  Uint8List? _customBackgroundImage;
  Uint8List? get customBackgroundImage => _customBackgroundImage;
  set customBackgroundImage(Uint8List? image) {
    _customBackgroundImage = image;
    _invalidateCache();
    notifyListeners();
  }

  double _backgroundBlurAmount = 8.0;
  double get backgroundBlurAmount => _backgroundBlurAmount;
  set backgroundBlurAmount(double amount) {
    _backgroundBlurAmount = amount;
    _invalidateCache();
    notifyListeners();
  }

  double _backgroundDarkOverlay = 0.6;
  double get backgroundDarkOverlay => _backgroundDarkOverlay;
  set backgroundDarkOverlay(double overlay) {
    _backgroundDarkOverlay = overlay;
    _invalidateCache();
    notifyListeners();
  }

  // Font family
  String _fontFamily = 'Poppins';
  String get fontFamily => _fontFamily;
  set fontFamily(String family) {
    _fontFamily = family;
    _invalidateCache();
    notifyListeners();
  }

  // Card style
  PosterCardStyle _cardStyle = PosterCardStyle.rounded;
  PosterCardStyle get cardStyle => _cardStyle;
  set cardStyle(PosterCardStyle style) {
    _cardStyle = style;
    _invalidateCache();
    notifyListeners();
  }

  // Team logo size
  PosterLogoSize _teamLogoSize = PosterLogoSize.medium;
  PosterLogoSize get teamLogoSize => _teamLogoSize;
  set teamLogoSize(PosterLogoSize size) {
    _teamLogoSize = size;
    _invalidateCache();
    notifyListeners();
  }

  // Score emphasis
  PosterScoreEmphasis _scoreEmphasis = PosterScoreEmphasis.bold;
  PosterScoreEmphasis get scoreEmphasis => _scoreEmphasis;
  set scoreEmphasis(PosterScoreEmphasis emphasis) {
    _scoreEmphasis = emphasis;
    _invalidateCache();
    notifyListeners();
  }

  // Accent style
  PosterAccentStyle _accentStyle = PosterAccentStyle.solid;
  PosterAccentStyle get accentStyle => _accentStyle;
  set accentStyle(PosterAccentStyle style) {
    _accentStyle = style;
    _invalidateCache();
    notifyListeners();
  }

  // Border style
  PosterBorderStyle _borderStyle = PosterBorderStyle.none;
  PosterBorderStyle get borderStyle => _borderStyle;
  set borderStyle(PosterBorderStyle style) {
    _borderStyle = style;
    _invalidateCache();
    notifyListeners();
  }

  // Shadow style
  PosterShadowStyle _shadowStyle = PosterShadowStyle.subtle;
  PosterShadowStyle get shadowStyle => _shadowStyle;
  set shadowStyle(PosterShadowStyle style) {
    _shadowStyle = style;
    _invalidateCache();
    notifyListeners();
  }

  // Color scheme override
  ColorSchemeType _colorScheme = ColorSchemeType.theme;
  ColorSchemeType get colorScheme => _colorScheme;
  set colorScheme(ColorSchemeType scheme) {
    _colorScheme = scheme;
    _invalidateCache();
    notifyListeners();
  }

  // Top Sponsors (multiple) - up to 4
  List<Uint8List?> _topSponsors = [null, null, null, null];
  List<Uint8List?> get topSponsors => _topSponsors;
  set topSponsors(List<Uint8List?> sponsors) {
    _topSponsors = sponsors;
    _invalidateCache();
    notifyListeners();
  }

  // Bottom Sponsors (multiple) - up to 4
  List<Uint8List?> _bottomSponsors = [null, null, null, null];
  List<Uint8List?> get bottomSponsors => _bottomSponsors;
  set bottomSponsors(List<Uint8List?> sponsors) {
    _bottomSponsors = sponsors;
    _invalidateCache();
    notifyListeners();
  }

  // Legacy single sponsor (for backward compatibility)
  Uint8List? _sponsorImage;
  Uint8List? get sponsorImage => _sponsorImage;
  set sponsorImage(Uint8List? image) {
    _sponsorImage = image;
    _invalidateCache();
    notifyListeners();
  }

  // Sponsor layout options
  SponsorLayout _sponsorLayout = SponsorLayout.horizontal;
  SponsorLayout get sponsorLayout => _sponsorLayout;
  set sponsorLayout(SponsorLayout layout) {
    _sponsorLayout = layout;
    _invalidateCache();
    notifyListeners();
  }

  double _sponsorHeight = 30.0;
  double get sponsorHeight => _sponsorHeight;
  set sponsorHeight(double height) {
    _sponsorHeight = height;
    _invalidateCache();
    notifyListeners();
  }

  double _sponsorSpacing = 16.0;
  double get sponsorSpacing => _sponsorSpacing;
  set sponsorSpacing(double spacing) {
    _sponsorSpacing = spacing;
    _invalidateCache();
    notifyListeners();
  }

  // === Visibility toggles (never affect data) ===
  bool _showTopBatters = true;
  bool get showTopBatters => _showTopBatters;
  set showTopBatters(bool val) { _showTopBatters = val; _invalidateCache(); notifyListeners(); }

  bool _showTopBowlers = true;
  bool get showTopBowlers => _showTopBowlers;
  set showTopBowlers(bool val) { _showTopBowlers = val; _invalidateCache(); notifyListeners(); }

  bool _showPlayerOfMatch = true;
  bool get showPlayerOfMatch => _showPlayerOfMatch;
  set showPlayerOfMatch(bool val) { _showPlayerOfMatch = val; _invalidateCache(); notifyListeners(); }

  bool _showPartnership = false;
  bool get showPartnership => _showPartnership;
  set showPartnership(bool val) { _showPartnership = val; _invalidateCache(); notifyListeners(); }

  bool _showMatchResult = true;
  bool get showMatchResult => _showMatchResult;
  set showMatchResult(bool val) { _showMatchResult = val; _invalidateCache(); notifyListeners(); }

  bool _showTournamentLogo = true;
  bool get showTournamentLogo => _showTournamentLogo;
  set showTournamentLogo(bool val) { _showTournamentLogo = val; _invalidateCache(); notifyListeners(); }

  bool _showSponsorLogo = false;
  bool get showSponsorLogo => _showSponsorLogo;
  set showSponsorLogo(bool val) { _showSponsorLogo = val; _invalidateCache(); notifyListeners(); }

  bool _showQrCode = false;
  bool get showQrCode => _showQrCode;
  set showQrCode(bool val) { _showQrCode = val; _invalidateCache(); notifyListeners(); }

  // Cache invalidation tracking
  int _cacheVersion = 0;
  int get cacheVersion => _cacheVersion;

  void _invalidateCache() {
    _cacheVersion++;
  }

  // Card border radius based on card style
  double get cardBorderRadius {
    switch (_cardStyle) {
      case PosterCardStyle.rounded:
        return 16;
      case PosterCardStyle.sharp:
        return 4;
      case PosterCardStyle.pill:
        return 24;
    }
  }

  // Logo size in pixels
  double get logoSizePixels {
    switch (_teamLogoSize) {
      case PosterLogoSize.small:
        return 36;
      case PosterLogoSize.medium:
        return 48;
      case PosterLogoSize.large:
        return 64;
    }
  }

  // Score font weight
  FontWeight get scoreFontWeight {
    switch (_scoreEmphasis) {
      case PosterScoreEmphasis.normal:
        return FontWeight.w600;
      case PosterScoreEmphasis.bold:
        return FontWeight.w800;
      case PosterScoreEmphasis.extraBold:
        return FontWeight.w900;
    }
  }

  // Score font size multiplier
  double get scoreFontSizeMultiplier {
    switch (_scoreEmphasis) {
      case PosterScoreEmphasis.normal:
        return 1.0;
      case PosterScoreEmphasis.bold:
        return 1.15;
      case PosterScoreEmphasis.extraBold:
        return 1.3;
    }
  }

  /// Available font families (approved app fonts)
  static const List<String> availableFonts = [
    'Poppins',
    'Rajdhani',
    'Oswald',
    'Inter',
    'Bebas Neue',
    'Outfit',
    'Roboto',
  ];
}

/// Export aspect ratios
enum PosterAspectRatio {
  square1x1(1.0, '1:1', 'Instagram Post'),
  portrait4x5(0.8, '4:5', 'Instagram Portrait'),
  story9x16(0.5625, '9:16', 'Story / Status'),
  landscape16x9(16.0 / 9.0, '16:9', 'YouTube / TV'),
  standard(0.65, 'Dynamic (Auto-fit)', 'Keeps text large');

  final double ratio; // width / height
  final String label;
  final String description;

  const PosterAspectRatio(this.ratio, this.label, this.description);

  /// Get pixel dimensions for export (based on width)
  Size getExportSize({double width = 1080}) {
    return Size(width, width / ratio);
  }
}

enum PosterBackgroundType {
  defaultBg('Default'),
  gradient('Gradient'),
  stadium('Stadium'),
  customImage('Custom Image');

  final String label;
  const PosterBackgroundType(this.label);
}

enum PosterCardStyle {
  rounded('Rounded'),
  sharp('Sharp'),
  pill('Pill');

  final String label;
  const PosterCardStyle(this.label);
}

enum PosterLogoSize {
  small('Small'),
  medium('Medium'),
  large('Large');

  final String label;
  const PosterLogoSize(this.label);
}

enum PosterScoreEmphasis {
  normal('Normal'),
  bold('Bold'),
  extraBold('Extra Bold');

  final String label;
  const PosterScoreEmphasis(this.label);
}

enum PosterAccentStyle {
  solid('Solid'),
  gradient('Gradient'),
  glow('Glow');

  final String label;
  const PosterAccentStyle(this.label);
}

enum SponsorLayout {
  horizontal('Horizontal Row'),
  vertical('Vertical Stack'),
  grid('Grid');

  final String label;
  const SponsorLayout(this.label);
}

enum PosterBorderStyle {
  none('None'),
  thin('Thin'),
  thick('Thick'),
  doubleLine('Double Line');

  final String label;
  const PosterBorderStyle(this.label);
}

enum PosterShadowStyle {
  none('None'),
  subtle('Subtle'),
  medium('Medium'),
  strong('Strong'),
  glow('Glow');

  final String label;
  const PosterShadowStyle(this.label);
}

enum ColorSchemeType {
  theme('Theme Default'),
  dark('Dark'),
  light('Light'),
  team1('Team 1 Colors'),
  team2('Team 2 Colors'),
  custom('Custom');

  final String label;
  const ColorSchemeType(this.label);
}
