import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/services/star_calculator.dart';

/// A visual badge that displays the player's warrior rank with
/// an animated aura glow, title, and star progress bar.
class RankBadge extends StatefulWidget {
  final int stars;
  final List<String> unlockedTitles;
  final bool showProgress;
  final bool compact;

  const RankBadge({
    super.key,
    required this.stars,
    this.unlockedTitles = const [],
    this.showProgress = true,
    this.compact = false,
  });

  @override
  State<RankBadge> createState() => _RankBadgeState();

  // Converts color name from StarCalculator to a Flutter Color
  static Color _getColor(String colorName) {
    switch (colorName) {
      case 'green':       return const Color(0xFF4CAF50);
      case 'blue':        return const Color(0xFF2196F3);
      case 'purple':      return const Color(0xFF9C27B0);
      case 'orange':      return const Color(0xFFFF9800);
      case 'crimson':     return const Color(0xFFDC143C);
      case 'gold':        return const Color(0xFFFFD700);
      case 'bronzeGold':  return const Color(0xFFCD7F32);
      case 'flame':       return const Color(0xFFFF4500);
      case 'goldCrown':   return const Color(0xFFFFD700);
      default:            return const Color(0xFF4CAF50);
    }
  }

  static Gradient? _getGradient(String colorName) {
    if (colorName == 'flame') {
      return const LinearGradient(
        colors: [Color(0xFFFF4500), Color(0xFFFF8C00), Color(0xFFFFD700)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (colorName == 'goldCrown') {
      return const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return null;
  }

  static Widget _buildCompactBadge(String title, String emoji, Color color, Gradient? gradient) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.5), width: 1.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 4.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: gradient != null ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadgeState extends State<RankBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = StarCalculator.getRankForStars(widget.stars);
    final title = rank['title'] as String;
    final emoji = rank['emoji'] as String;
    final colorName = rank['color'] as String;
    final color = RankBadge._getColor(colorName);
    final gradient = RankBadge._getGradient(colorName);
    final progress = StarCalculator.getRankProgress(widget.stars);

    // Find the latest epic title (not a rank title)
    final epicTitles = widget.unlockedTitles.where((t) => 
      !StarCalculator.ranks.any((r) => r['title'] == t)
    ).toList();
    final latestEpicTitle = epicTitles.isNotEmpty ? epicTitles.last : null;

    if (widget.compact) {
      return RankBadge._buildCompactBadge(title, emoji, color, gradient);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: gradient ?? LinearGradient(
              colors: [color.withOpacity(0.15 * _animation.value), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: color.withOpacity(0.4 * _animation.value), 
              width: 1.5.w + (0.5 * _animation.value),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3 * _animation.value),
                blurRadius: 15 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: gradient != null ? Colors.white : color,
                  letterSpacing: 0.5,
                  shadows: [
                    if (gradient != null)
                      const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1)),
                  ],
                ),
              ),
            ],
          ),
          if (latestEpicTitle != null) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(color: color.withOpacity(0.2), width: 0.5.w),
              ),
              child: Text(
                '✦ $latestEpicTitle ✦',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          SizedBox(height: 8.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⭐', style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 4.w),
              Text(
                '${widget.stars} Stars',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: gradient != null ? Colors.white70 : color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          if (widget.showProgress) ...[
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
