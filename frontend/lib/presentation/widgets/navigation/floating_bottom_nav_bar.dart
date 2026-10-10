import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/app_responsive.dart';

/// A modern floating bottom navigation bar with smooth animations.
///
/// This widget creates a pill-shaped navigation bar that floats above the
/// content with a soft shadow effect. Each navigation item animates smoothly
/// when selected.
///
/// Example usage:
/// ```dart
/// FloatingBottomNavBar(
///   currentIndex: _currentIndex,
///   onTap: (index) => setState(() => _currentIndex = index),
///   items: [
///     FloatingNavItem(icon: Icons.home, label: 'Home'),
///     FloatingNavItem(icon: Icons.play_circle_outline, label: 'Reels'),
///     FloatingNavItem(icon: Icons.sports_cricket, label: 'Matches'),
///     FloatingNavItem(icon: Icons.person_outline, label: 'Profile'),
///   ],
/// )
/// ```
class FloatingBottomNavBar extends StatelessWidget {
  /// Currently selected tab index
  final int currentIndex;

  /// Callback when a tab is tapped
  final ValueChanged<int> onTap;

  /// List of navigation items
  final List<FloatingNavItem> items;

  /// Background color of the navigation bar
  final Color? backgroundColor;

  /// Color of the active item background
  final Color? activeBackgroundColor;

  /// Color of the active icon
  final Color? activeIconColor;

  /// Color of inactive icons
  final Color? inactiveIconColor;

  /// Horizontal margin from screen edges (defaults to responsive)
  final double? horizontalMargin;

  /// Bottom margin from screen edge
  final double bottomMargin;

  /// Height of the navigation bar (defaults to responsive)
  final double? height;

  /// Border radius of the pill shape
  final double borderRadius;

  const FloatingBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.activeBackgroundColor,
    this.activeIconColor,
    this.inactiveIconColor,
    this.horizontalMargin,
    this.bottomMargin = 20,
    this.height,
    this.borderRadius = 35,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // iPhone-style liquid frosted glass colors
    final defaultFrostedColor = isDark 
        ? const Color(0xFF1E1E28).withOpacity(0.80) 
        : Colors.white.withOpacity(0.78);
    final bgColor = backgroundColor ?? defaultFrostedColor;
    final activeBgColor = activeBackgroundColor ?? const Color(0xFFFF6B35);
    final activeIconCol = activeIconColor ?? Colors.white;
    final inactiveIconCol = inactiveIconColor ?? (isDark ? const Color(0xFFA0A0B4) : const Color(0xFF7A7A8E));

    // Adapt margins and height to screen size for responsive layout
    final responsive = AppResponsive.of(context);
    final adaptiveHMargin = horizontalMargin ?? responsive.navHorizontalMargin;
    final adaptiveHeight = height ?? responsive.navBarHeight;

    return Container(
      margin: EdgeInsets.fromLTRB(adaptiveHMargin, 0, adaptiveHMargin, bottomMargin),
      constraints: BoxConstraints(minHeight: adaptiveHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Soft ambient shadow for floating depth
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // Subtle warm glow under active orange theme
          BoxShadow(
            color: activeBgColor.withOpacity(isDark ? 0.12 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(minHeight: adaptiveHeight),
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.68),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                items.length,
                (index) => _NavItemButton(
                  item: items[index],
                  isActive: currentIndex == index,
                  onTap: () => onTap(index),
                  activeBackgroundColor: activeBgColor,
                  activeIconColor: activeIconCol,
                  inactiveIconColor: inactiveIconCol,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Data class representing a single navigation item
class FloatingNavItem {
  /// Icon to display
  final IconData icon;

  /// Optional active icon (different from inactive)
  final IconData? activeIcon;

  /// Label for accessibility
  final String label;

  const FloatingNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Individual navigation button with animations
class _NavItemButton extends StatefulWidget {
  final FloatingNavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeBackgroundColor;
  final Color activeIconColor;
  final Color inactiveIconColor;

  const _NavItemButton({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.activeBackgroundColor,
    required this.activeIconColor,
    required this.inactiveIconColor,
  });

  @override
  State<_NavItemButton> createState() => _NavItemButtonState();
}

class _NavItemButtonState extends State<_NavItemButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isActive
        ? (widget.item.activeIcon ?? widget.item.icon)
        : widget.item.icon;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: widget.item.label,
        button: true,
        selected: widget.isActive,
        child: ScaleTransition(
          scale: _scaleAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: widget.isActive
                  ? EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h)
                  : EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: widget.isActive
                    ? const LinearGradient(
                        colors: [Color(0xFFFF7A45), Color(0xFFFF521B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.isActive ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(25.r),
                border: widget.isActive
                    ? Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1.0,
                      )
                    : null,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF521B).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: widget.isActive
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: widget.activeIconColor,
                          size: 21.sp,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            widget.item.label,
                            style: TextStyle(
                              color: widget.activeIconColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      icon,
                      color: widget.inactiveIconColor,
                      size: 22.sp,
                    ),
            ),
        ),
      ),
    );
  }
}
