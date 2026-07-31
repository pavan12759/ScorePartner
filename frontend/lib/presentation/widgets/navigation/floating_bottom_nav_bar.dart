import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  /// Horizontal margin from screen edges
  final double horizontalMargin;

  /// Bottom margin from screen edge
  final double bottomMargin;

  /// Height of the navigation bar
  final double height;

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
    this.horizontalMargin = 40,
    this.bottomMargin = 20,
    this.height = 56,
    this.borderRadius = 30,
  });

  @override
  Widget build(BuildContext context) {
    // Orange theme colors for attractive look
    final bgColor = backgroundColor ?? Colors.white;  // White background
    final activeBgColor = activeBackgroundColor ?? const Color(0xFFFF6B35);  // Vibrant orange
    final activeIconCol = activeIconColor ?? Colors.white;
    final inactiveIconCol = inactiveIconColor ?? const Color(0xFF8B8B9E);

    return Container(
      margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, bottomMargin),
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Primary soft shadow for floating effect
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
          // Secondary subtle shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
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
                  ? EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h)
                  : EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? widget.activeBackgroundColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(25.r),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.activeBackgroundColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
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
                          size: 20.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          widget.item.label,
                          style: TextStyle(
                            color: widget.activeIconColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
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
