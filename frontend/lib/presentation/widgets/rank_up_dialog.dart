import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/services/star_calculator.dart';

/// Animated dialog that celebrates a player reaching a new warrior rank.
/// Shows a dramatic reveal with glow, confetti feel, and the unlock message.
class RankUpDialog extends StatefulWidget {
  final int newStars;
  final String oldRankTitle;

  const RankUpDialog({
    super.key,
    required this.newStars,
    required this.oldRankTitle,
  });

  /// Show the rank-up dialog if a rank change happened.
  /// Returns true if a rank-up was shown.
  static Future<bool> showIfRankUp(BuildContext context, int oldStars, int newStars) async {
    final rankUp = StarCalculator.checkRankUp(oldStars, newStars);
    if (rankUp == null) return false;

    final oldRank = StarCalculator.getRankForStars(oldStars);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Rank Up',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return RankUpDialog(
          newStars: newStars,
          oldRankTitle: oldRank['title'] as String,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
    return true;
  }

  @override
  State<RankUpDialog> createState() => _RankUpDialogState();
}

class _RankUpDialogState extends State<RankUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color _getColor(String colorName) {
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

  @override
  Widget build(BuildContext context) {
    final rank = StarCalculator.getRankForStars(widget.newStars);
    final title = rank['title'] as String;
    final emoji = rank['emoji'] as String;
    final colorName = rank['color'] as String;
    final message = rank['message'] as String;
    final color = _getColor(colorName);

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 32.w),
            padding: EdgeInsets.all(28.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: color.withOpacity(_glowAnimation.value),
                width: 2.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_glowAnimation.value * 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                '⭐ RANK UP! ⭐',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 20.h),

              // Old rank → New rank
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.oldRankTitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white.withOpacity(0.5),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(Icons.arrow_forward, color: color, size: 20.sp),
                ],
              ),
              SizedBox(height: 12.h),

              // New rank emoji + title
              Text(emoji, style: TextStyle(fontSize: 48.sp)),
              SizedBox(height: 8.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 16.h),

              // Unlock message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 12.h),

              // Star count
              Text(
                '⭐ ${widget.newStars} Stars',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              SizedBox(height: 24.h),

              // Dismiss
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.local_fire_department, color: color),
                label: Text('Continue', style: TextStyle(fontSize: 16.sp)),
                style: FilledButton.styleFrom(
                  backgroundColor: color.withOpacity(0.2),
                  foregroundColor: color,
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r),
                    side: BorderSide(color: color.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
