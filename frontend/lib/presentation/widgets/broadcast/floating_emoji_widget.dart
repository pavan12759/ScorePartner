import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated floating emoji reactions that rise from the bottom of the screen.
/// Emojis float upward with slight horizontal sway and fade out.
class FloatingEmojiWidget extends StatefulWidget {
  final List<String> recentEmojis; // list of emoji strings to animate
  final VoidCallback? onTapReaction;

  const FloatingEmojiWidget({
    super.key,
    this.recentEmojis = const [],
    this.onTapReaction,
  });

  @override
  State<FloatingEmojiWidget> createState() => FloatingEmojiWidgetState();
}

class FloatingEmojiWidgetState extends State<FloatingEmojiWidget>
    with TickerProviderStateMixin {
  final List<_FloatingEmoji> _activeEmojis = [];
  final math.Random _rng = math.Random();
  int _lastCount = 0;

  static const List<String> availableEmojis = ['❤️', '🔥', '👏', '😮', '🏏', '🎉'];

  @override
  void didUpdateWidget(FloatingEmojiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Add new emojis when the list grows
    if (widget.recentEmojis.length > _lastCount) {
      final newCount = widget.recentEmojis.length - _lastCount;
      for (int i = 0; i < math.min(newCount, 5); i++) {
        _spawnEmoji(widget.recentEmojis[widget.recentEmojis.length - 1 - i]);
      }
    }
    _lastCount = widget.recentEmojis.length;
  }

  void _spawnEmoji(String emoji) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000 + _rng.nextInt(1000)),
    );

    final floatingEmoji = _FloatingEmoji(
      emoji: emoji,
      controller: controller,
      startX: 0.7 + _rng.nextDouble() * 0.25, // right side
      swayAmount: (_rng.nextDouble() - 0.5) * 0.1,
      scale: 0.8 + _rng.nextDouble() * 0.5,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _activeEmojis.remove(floatingEmoji);
          });
        }
        controller.dispose();
      }
    });

    if (mounted) {
      setState(() {
        _activeEmojis.add(floatingEmoji);
        // Cap active emojis
        while (_activeEmojis.length > 20) {
          final old = _activeEmojis.removeAt(0);
          old.controller.dispose();
        }
      });
    }

    controller.forward();
  }

  /// Trigger a manual emoji reaction
  void triggerEmoji(String emoji) {
    _spawnEmoji(emoji);
  }

  @override
  void dispose() {
    for (final e in _activeEmojis) {
      e.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Floating emojis
        ..._activeEmojis.map((e) => _buildFloatingEmoji(e)),

        // Reaction bar at bottom-right
        Positioned(
          right: 8.w,
          bottom: 8.h,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableEmojis.map((emoji) {
              return Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: GestureDetector(
                  onTap: () {
                    _spawnEmoji(emoji);
                    widget.onTapReaction?.call();
                  },
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: TextStyle(fontSize: 20.sp)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingEmoji(_FloatingEmoji e) {
    return AnimatedBuilder(
      animation: e.controller,
      builder: (context, child) {
        final progress = e.controller.value;
        final screenSize = MediaQuery.of(context).size;

        // Rise from bottom to top
        final y = screenSize.height * (1 - progress * 0.8);
        // Slight horizontal sway
        final x = screenSize.width * e.startX +
            math.sin(progress * math.pi * 3) * screenSize.width * e.swayAmount;
        // Fade out in last 30%
        final opacity = progress > 0.7 ? (1 - (progress - 0.7) / 0.3) : 1.0;
        // Scale pulse
        final scale = e.scale * (1 + math.sin(progress * math.pi * 2) * 0.1);

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Text(
                e.emoji,
                style: TextStyle(fontSize: 28.sp),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingEmoji {
  final String emoji;
  final AnimationController controller;
  final double startX;
  final double swayAmount;
  final double scale;

  _FloatingEmoji({
    required this.emoji,
    required this.controller,
    required this.startX,
    required this.swayAmount,
    required this.scale,
  });
}
