import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryOrange = Color(0xFFFF8D48); // #FF8D48
  static const Color deepOrange = Color(0xFFFFDBCA); // #FFDBCA
  static const Color stadiumOrange = primaryOrange;
  
  // Neutral Colors
  static const Color deepBlack = Color(0xFF1A1A2E);
  static const Color cardDark = Color(0xFF16213E);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF666666);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [deepBlack, Color(0xFF0F0F23)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: lightGrey,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: deepOrange,
        surface: pureWhite,
        background: lightGrey,
        error: Colors.red,
        onPrimary: pureWhite,
        onSecondary: pureWhite,
        onSurface: deepBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryOrange,
        foregroundColor: pureWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: pureWhite,
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
        fillColor: pureWhite,
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
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: deepBlack),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: deepBlack),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: deepBlack),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: deepBlack),
        bodyLarge: TextStyle(fontSize: 16, color: deepBlack),
        bodyMedium: TextStyle(fontSize: 14, color: darkGrey),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: pureWhite,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: pureWhite,
        selectedItemColor: primaryOrange,
        unselectedItemColor: darkGrey,
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: deepBlack,
      colorScheme: const ColorScheme.dark(
        primary: primaryOrange,
        secondary: deepOrange,
        surface: cardDark,
        background: deepBlack,
        error: Colors.redAccent,
        onPrimary: pureWhite,
        onSecondary: pureWhite,
        onSurface: pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: pureWhite,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: cardDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: pureWhite),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pureWhite),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pureWhite),
        bodyLarge: TextStyle(fontSize: 16, color: pureWhite),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }
}
