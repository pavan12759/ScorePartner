import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Full-screen broadcast animations for cricket events.
/// FOUR! — boundary rope flash with green burst
/// SIX! — fireworks with arc trajectory
/// WICKET! — stump shatter with red flash
/// HAT TRICK! — golden hat celebration
/// CENTURY! — confetti + 💯 burst
/// FIFTY! — star burst
/// POWERPLAY! — electric border
/// MATCH WINNER! — trophy + confetti
class BroadcastAnimationWidget extends StatefulWidget {
  final String? animationType;
  final VoidCallback? onComplete;
  final Duration duration;

  const BroadcastAnimationWidget({
    super.key,
    this.animationType,
    this.onComplete,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<BroadcastAnimationWidget> createState() =>
      _BroadcastAnimationWidgetState();
}

class _BroadcastAnimationWidgetState extends State<BroadcastAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  final math.Random _rng = math.Random();

  // Particles for confetti/fireworks
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mainController.isCompleted) {
            widget.onComplete?.call();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(BroadcastAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationType != null &&
        widget.animationType != oldWidget.animationType) {
      _generateParticles();
      _mainController.reset();
      _mainController.forward();
      _particleController.reset();
      _particleController.forward();
    }
  }

  void _generateParticles() {
    _particles.clear();
    final count =
        widget.animationType == 'century' || widget.animationType == 'winner'
        ? 60
        : 30;
    for (int i = 0; i < count; i++) {
      _particles.add(
        _Particle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble() * 0.3,
          vx: (_rng.nextDouble() - 0.5) * 2,
          vy: _rng.nextDouble() * 3 + 1,
          size: _rng.nextDouble() * 8 + 3,
          color: _getParticleColor(),
          rotation: _rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  Color _getParticleColor() {
    final colors = switch (widget.animationType) {
      'boundary' => [
        const Color(0xFF4CAF50),
        const Color(0xFF8BC34A),
        const Color(0xFFCDDC39),
      ],
      'maximum' => [
        const Color(0xFFFF9800),
        const Color(0xFFFF5722),
        const Color(0xFFFFEB3B),
        const Color(0xFFE91E63),
      ],
      'wicket' => [
        const Color(0xFFFF3B30),
        const Color(0xFFFF6B6B),
        const Color(0xFFFF9500),
      ],
      'hat_trick' => [
        const Color(0xFFFFD700),
        const Color(0xFFFFC107),
        const Color(0xFFFF8F00),
      ],
      'century' => [
        const Color(0xFFFFD700),
        const Color(0xFFE91E63),
        const Color(0xFF9C27B0),
        const Color(0xFF2196F3),
        const Color(0xFF4CAF50),
      ],
      'fifty' => [
        const Color(0xFF2196F3),
        const Color(0xFF03A9F4),
        const Color(0xFF00BCD4),
      ],
      'winner' => [
        const Color(0xFFFFD700),
        const Color(0xFFE91E63),
        const Color(0xFF9C27B0),
        const Color(0xFF2196F3),
      ],
      _ => [Colors.white, Colors.grey],
    };
    return colors[_rng.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animationType == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _particleController]),
      builder: (context, child) {
        if (!_mainController.isAnimating && !_mainController.isCompleted) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background flash
              if (_mainController.value < 0.15)
                Opacity(
                  opacity: (1 - _mainController.value / 0.15) * 0.3,
                  child: Container(color: _getFlashColor()),
                ),

              // Particles
              ...(_particles.map((p) => _buildParticle(p))),

              // Main text
              Center(
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: Opacity(
                      opacity: _fadeAnim.value.clamp(0.0, 1.0),
                      child: _buildMainContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticle(_Particle p) {
    final progress = _particleController.value;
    final x = p.x + p.vx * progress * 0.1;
    final y = p.y + p.vy * progress * 0.15;

    return Positioned(
      left: x * MediaQuery.of(context).size.width,
      top: y * MediaQuery.of(context).size.height,
      child: Opacity(
        opacity: (1 - progress).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: p.rotation + progress * math.pi * 2,
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              color: p.color,
              borderRadius: BorderRadius.circular(p.size * 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final (_, text, color) = switch (widget.animationType) {
      'boundary' => ('4️⃣', 'FOUR!', const Color(0xFF4CAF50)),
      'maximum' => ('6️⃣', 'SIX!', const Color(0xFFFF9800)),
      'wicket' => ('🔴', 'WICKET!', const Color(0xFFFF3B30)),
      'hat_trick' => ('🎩', 'HAT TRICK!', const Color(0xFFFFD700)),
      'century' => ('💯', 'CENTURY!', const Color(0xFFFFD700)),
      'fifty' => ('⭐', 'FIFTY!', const Color(0xFF2196F3)),
      'powerplay' => ('⚡', 'POWERPLAY!', const Color(0xFF9C27B0)),
      'winner' => ('🏆', 'MATCH WINNER!', const Color(0xFFFFD700)),
      _ => ('🏏', '', Colors.white),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_eventIcon(), color: color, size: 64.sp),
        SizedBox(height: 8.h),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 36.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [
              Shadow(color: color, blurRadius: 20),
              Shadow(color: color.withOpacity(0.5), blurRadius: 40),
              const Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _eventIcon() {
    return switch (widget.animationType) {
      'boundary' => Icons.looks_4,
      'maximum' => Icons.looks_6,
      'wicket' => Icons.sports_baseball,
      'hat_trick' || 'winner' => Icons.emoji_events,
      'century' => Icons.workspace_premium,
      'fifty' => Icons.star,
      'powerplay' => Icons.bolt,
      _ => Icons.sports_cricket,
    };
  }

  Color _getFlashColor() {
    return switch (widget.animationType) {
      'boundary' => const Color(0xFF4CAF50),
      'maximum' => const Color(0xFFFF9800),
      'wicket' => const Color(0xFFFF3B30),
      'hat_trick' => const Color(0xFFFFD700),
      'century' => const Color(0xFFFFD700),
      'fifty' => const Color(0xFF2196F3),
      'powerplay' => const Color(0xFF9C27B0),
      'winner' => const Color(0xFFFFD700),
      _ => Colors.white,
    };
  }
}

class _Particle {
  final double x, y, vx, vy, size, rotation;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
  });
}
