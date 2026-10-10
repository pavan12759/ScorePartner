import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ─── Brand Colors ───
  static const Color primaryOrange = Color(0xFFFF8D48);
  static const Color deepOrange = Color(0xFFFFDBCA);
  static const Color stadiumOrange = primaryOrange;

  // ─── Light Palette ───
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF666666);

  // ─── Dark Palette (Instagram / Cricbuzz inspired) ───
  // True black scaffold like Instagram
  static const Color darkScaffold = Color(0xFF000000);
  // Elevated surface – slightly lighter for cards/sheets
  static const Color darkSurface = Color(0xFF121212);
  // Card / tile background
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color deepBlack = Color(0xFF000000);
  // Raised container (e.g. search bars, input fields)
  static const Color darkContainer = Color(0xFF262626);
  // Subtle border / divider on dark
  static const Color darkBorder = Color(0xFF2E2E2E);
  // Secondary text on dark
  static const Color darkSubtitle = Color(0xFF8E8E8E);
  // AppBar on dark – same as scaffold for seamless look
  static const Color darkAppBar = Color(0xFF000000);

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkScaffold, Color(0xFF0A0A0A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ══════════════════════════════════════════════════════════
  // LIGHT THEME
  // ══════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: pureWhite,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: deepOrange,
        surface: pureWhite,
        surfaceContainerHighest: lightGrey,
        error: Colors.red,
        onPrimary: pureWhite,
        onSecondary: pureWhite,
        onSurface: Color(0xFF1A1A1A),
        outline: Color(0xFFE0E0E0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryOrange),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: pureWhite,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: pureWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(fontSize: 14, color: darkGrey),
      ),
      dividerColor: const Color(0xFFEEEEEE),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: pureWhite,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: pureWhite,
        selectedItemColor: primaryOrange,
        unselectedItemColor: darkGrey,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: pureWhite,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryOrange;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryOrange.withOpacity(0.4);
          return Colors.grey.shade300;
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // DARK THEME  (Instagram / Cricbuzz style)
  // ══════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: darkScaffold,
      colorScheme: const ColorScheme.dark(
        primary: primaryOrange,
        secondary: Color(0xFFFFAB76),
        surface: darkSurface,
        surfaceContainerHighest: darkContainer,
        error: Color(0xFFCF6679),
        onPrimary: pureWhite,
        onSecondary: pureWhite,
        onSurface: Color(0xFFF5F5F5),
        outline: darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkAppBar,
        foregroundColor: pureWhite,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryOrange),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 0.5),
        ),
        color: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: darkCard,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkContainer,
        hintStyle: const TextStyle(color: darkSubtitle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: pureWhite),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pureWhite),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pureWhite),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: pureWhite),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFE0E0E0)),
        bodyMedium: TextStyle(fontSize: 14, color: darkSubtitle),
      ),
      dividerColor: darkBorder,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: pureWhite,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkScaffold,
        selectedItemColor: primaryOrange,
        unselectedItemColor: darkSubtitle,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryOrange;
          return darkSubtitle;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryOrange.withOpacity(0.4);
          return darkContainer;
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ThemeHelper – semantic, theme-aware color accessors
// ══════════════════════════════════════════════════════════
// Usage:  final th = ThemeHelper.of(context);
//         Container(color: th.cardColor)
//         Text('Hi', style: TextStyle(color: th.textPrimary))

class ThemeHelper {
  final BuildContext _context;
  ThemeHelper._(this._context);

  factory ThemeHelper.of(BuildContext context) => ThemeHelper._(context);

  ThemeData get _theme => Theme.of(_context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get isDark => _theme.brightness == Brightness.dark;

  // ─── Backgrounds ───
  /// Scaffold background
  Color get scaffoldBg => _theme.scaffoldBackgroundColor;

  /// Card / elevated tile background
  Color get cardColor => isDark ? AppTheme.darkCard : AppTheme.pureWhite;

  /// Input field / search bar / chip background
  Color get containerColor => isDark ? AppTheme.darkContainer : AppTheme.lightGrey;

  /// Surface (dialogs, sheets)
  Color get surfaceColor => _cs.surface;

  // ─── Text ───
  /// Primary text (headings, body)
  Color get textPrimary => _cs.onSurface;

  /// Card / Surface Background
  Color get cardBg => isDark ? AppTheme.darkCard : AppTheme.pureWhite;

  /// Secondary / subtitle text
  Color get textSecondary => isDark ? AppTheme.darkSubtitle : AppTheme.darkGrey;

  /// Hint text in input fields
  Color get hintColor => isDark ? const Color(0xFF6E6E6E) : const Color(0xFF9E9E9E);

  // ─── Borders & Dividers ───
  Color get borderColor => isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0);
  Color get dividerColor => _theme.dividerColor;

  // ─── Icons ───
  Color get iconColor => isDark ? const Color(0xFFB0B0B0) : const Color(0xFF757575);
  Color get iconActiveColor => AppTheme.primaryOrange;

  // ─── Misc ───
  /// Shimmer / skeleton base color
  Color get shimmerBase => isDark ? AppTheme.darkContainer : Colors.grey.shade200;
  Color get shimmerHighlight => isDark ? AppTheme.darkCard : Colors.grey.shade100;

  /// Shadow color
  Color get shadowColor => isDark ? Colors.black54 : Colors.black.withOpacity(0.08);

  /// Overlay for bottom sheets (transparent background)
  Color get sheetBg => isDark ? AppTheme.darkCard : AppTheme.pureWhite;

  /// AppBar background
  Color get appBarBg => isDark ? AppTheme.darkAppBar : AppTheme.pureWhite;

  /// AppBar title color
  Color get appBarTitle => isDark ? AppTheme.pureWhite : const Color(0xFF1A1A1A);
}
