import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CinematicOverlayPainter extends CustomPainter {
  final String overlayStyle; // 'glowing_border', 'orange_particles', 'spotlight_focus', 'stadium_light', 'all'
  final Color themeColor;
  final double animationValue; // For micro-animations like particles floating or borders pulsing

  CinematicOverlayPainter({
    required this.overlayStyle,
    required this.themeColor,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. SPOTLIGHT FOCUS: Creates a central halo highlighting the player
    if (overlayStyle == 'spotlight_focus' || overlayStyle == 'all') {
      final spotlightPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.65,
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      
      canvas.drawRect(rect, spotlightPaint);
    }

    // 2. STADIUM LIGHTS: Stadium beam flares from the top corners
    if (overlayStyle == 'stadium_light' || overlayStyle == 'all') {
      final lightPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.8, -0.9), // Top-left
          radius: 0.5,
          colors: [
            Colors.white.withOpacity(0.3),
            themeColor.withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect);
      
      canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), size.width * 0.6, lightPaint);

      final lightPaint2 = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.8, -0.9), // Top-right
          radius: 0.5,
          colors: [
            Colors.white.withOpacity(0.25),
            themeColor.withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect);
      
      canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), size.width * 0.5, lightPaint2);
    }

    // 3. ORANGE CINEMATIC PARTICLES: Floating cinematic dust/ember particles
    if (overlayStyle == 'orange_particles' || overlayStyle == 'all') {
      final particlePaint = Paint()..style = PaintingStyle.fill;
      final random = math.Random(42); // Seeded for deterministic paths

      for (int i = 0; i < 28; i++) {
        // Floating path based on seed and animationValue
        final xSeed = random.nextDouble();
        final ySeed = random.nextDouble();
        final sizeSeed = random.nextDouble();
        final opacitySeed = random.nextDouble();

        final double x = size.width * ((xSeed + (animationValue * 0.05)) % 1.0);
        final double y = size.height * ((ySeed - (animationValue * 0.15)) % 1.0);
        final double radius = 2.0 + (sizeSeed * 4.0);
        final double opacity = 0.15 + (opacitySeed * 0.55) * (0.5 + 0.5 * math.sin(animationValue * 5.0 + i));

        particlePaint.color = themeColor.withOpacity(opacity);
        canvas.drawCircle(Offset(x, y), radius, particlePaint);

        // Add a small glowing aura around some particles
        if (i % 3 == 0) {
          final glowPaint = Paint()
            ..color = themeColor.withOpacity(opacity * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
          canvas.drawCircle(Offset(x, y), radius * 2.2, glowPaint);
        }
      }
    }

    // 4. GLOWING BORDERS: Dynamic neon futuristic borders
    if (overlayStyle == 'glowing_border' || overlayStyle == 'all') {
      final borderPath = Path()
        ..addRRect(RRect.fromRectAndRadius(rect.deflate(6.0), Radius.circular(20.0)));

      // Draw the deep glowing aura first (blurs the paint)
      final borderGlowPaint = Paint()
        ..color = themeColor.withOpacity(0.5 + 0.2 * math.sin(animationValue * 4.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      
      canvas.drawPath(borderPath, borderGlowPaint);

      // Draw the bright sharp inner line
      final borderSharpPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawPath(borderPath, borderSharpPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CinematicOverlayPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.overlayStyle != overlayStyle ||
        oldDelegate.themeColor != themeColor;
  }
}
