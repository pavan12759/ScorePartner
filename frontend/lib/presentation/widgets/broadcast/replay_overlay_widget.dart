import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/broadcast_highlight_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// ReplayOverlayWidget — Displays "REPLAY" TV banner overlay with slow-motion badge
class ReplayOverlayWidget extends StatefulWidget {
  final BroadcastHighlight highlight;
  final OverlayThemeData theme;
  final VoidCallback? onDismiss;

  const ReplayOverlayWidget({
    super.key,
    required this.highlight,
    required this.theme,
    this.onDismiss,
  });

  @override
  State<ReplayOverlayWidget> createState() => _ReplayOverlayWidgetState();
}

class _ReplayOverlayWidgetState extends State<ReplayOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120.h,
      left: 20.w,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3B30), Color(0xFFFF5E55)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B30).withOpacity(0.6 * _pulseAnim.value),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay, color: Colors.white, size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  'REPLAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.highlight.title.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
