import 'package:flutter/material.dart';

/// Lightweight responsive design utility for ScorePartner.
///
/// Provides device type detection, adaptive spacing, and responsive helpers.
/// Usage:
/// ```dart
/// final responsive = AppResponsive.of(context);
/// if (responsive.isSmallPhone) { ... }
/// padding: EdgeInsets.all(responsive.padding),
/// ```
class AppResponsive {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  late final double textScale;

  AppResponsive.of(this.context) {
    final mq = MediaQuery.of(context);
    screenWidth = mq.size.width;
    screenHeight = mq.size.height;
    textScale = mq.textScaler.scale(1.0);
  }

  // ── Device type detection ──

  /// Very small phones (≤ 360px width), e.g. Galaxy S5, iPhone SE
  bool get isSmallPhone => screenWidth <= 360;

  /// Standard phones (361–412px width), e.g. iPhone 13, Pixel 6
  bool get isPhone => screenWidth > 360 && screenWidth <= 412;

  /// Large phones / phablets (413–599px width)
  bool get isLargePhone => screenWidth > 412 && screenWidth < 600;

  /// Tablets (600–959px width)
  bool get isTablet => screenWidth >= 600 && screenWidth < 960;

  /// Desktop / wide screens (960px+ width)
  bool get isDesktop => screenWidth >= 960;

  /// Any phone-sized device (≤ 599px)
  bool get isPhoneSize => screenWidth < 600;

  /// Whether text scaling is elevated (user has accessibility text size)
  bool get hasLargeText => textScale > 1.15;

  /// Whether text scaling is very elevated
  bool get hasVeryLargeText => textScale > 1.5;

  // ── Adaptive spacing ──

  /// Standard padding that adapts to screen size
  double get padding {
    if (isSmallPhone) return 12.0;
    if (isPhoneSize) return 16.0;
    if (isTablet) return 20.0;
    return 24.0;
  }

  /// Small padding
  double get paddingSmall {
    if (isSmallPhone) return 6.0;
    if (isPhoneSize) return 8.0;
    return 12.0;
  }

  /// Large padding
  double get paddingLarge {
    if (isSmallPhone) return 16.0;
    if (isPhoneSize) return 20.0;
    if (isTablet) return 28.0;
    return 32.0;
  }

  /// Horizontal padding for screen edges
  double get horizontalPadding {
    if (isSmallPhone) return 12.0;
    if (isPhoneSize) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }

  // ── Adaptive sizing ──

  /// Card width for horizontal lists (adapts to screen)
  double get matchCardWidth {
    if (isSmallPhone) return screenWidth * 0.82;
    if (isPhoneSize) return screenWidth * 0.80;
    if (isTablet) return 340.0;
    return 360.0;
  }

  /// Height for horizontal match list sections
  double get matchListHeight {
    if (hasVeryLargeText) return 265.0;
    if (hasLargeText) return 245.0;
    return 225.0;
  }

  /// Bottom navigation horizontal margin
  double get navHorizontalMargin {
    if (isSmallPhone) return 20.0;
    if (isPhoneSize) return 30.0;
    if (isLargePhone) return 36.0;
    if (isTablet) return screenWidth * 0.16;
    return screenWidth * 0.22;
  }

  /// Bottom navigation bar height
  double get navBarHeight {
    if (hasLargeText) return 68.0;
    return 60.0;
  }

  /// Max content width (useful for tablets/desktop to avoid too-wide layouts)
  double get maxContentWidth {
    if (isDesktop) return 800.0;
    if (isTablet) return 600.0;
    return double.infinity;
  }

  // ── Helper methods ──

  /// Returns a value based on device type (phone/tablet/desktop)
  T value<T>({
    required T phone,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? phone;
    if (isTablet) return tablet ?? phone;
    return phone;
  }

  /// Returns number of columns for grid layouts
  int get gridColumns {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    if (isLargePhone) return 2;
    return 1;
  }
}

/// Extension on BuildContext for quick responsive access
extension ResponsiveContext on BuildContext {
  AppResponsive get responsive => AppResponsive.of(this);
}
