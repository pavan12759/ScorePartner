import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium 3-second splash screen for ScorePartner.
///
/// The animated bat and ball are drawn as simple flat orange shapes
/// matching the icon exactly. After merging, the actual app_icon.png
/// image is shown for pixel-perfect accuracy.
class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _master;

  // Timeline
  late Animation<double> _bgGlow;
  late Animation<double> _ballPath;
  late Animation<double> _batPath;
  late Animation<double> _elementsOpacity; // bat+ball fade out
  late Animation<double> _iconOpacity; // icon image fades in
  late Animation<double> _iconScale; // bounce
  late Animation<double> _starburst;
  late Animation<double> _iconShrink; // 1=large, 0=small in row
  late Animation<double> _textReveal;
  late Animation<double> _textSlide;
  late Animation<double> _shine;
  late Animation<double> _holdPulse;
  late Animation<double> _fadeOut;

  bool _showChild = false;

  double _f(int ms) => ms / 3400.0;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    _bgGlow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.7), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.5), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(0, _f(1700), curve: Curves.easeInOut),
    ));

    // Ball: 300ms → 1100ms
    _ballPath = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(300), _f(1100), curve: Curves.easeOutCubic),
    ));

    // Bat: 600ms → 1100ms
    _batPath = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(600), _f(1100), curve: Curves.easeOutCubic),
    ));

    // Elements fade out: 1000ms → 1300ms
    _elementsOpacity = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1000), _f(1300), curve: Curves.easeIn),
    ));

    // Icon fades in: 1000ms → 1300ms
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1000), _f(1300), curve: Curves.easeOut),
    ));

    // Icon bounce: 1200ms → 1700ms
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.7, end: 1.1)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.1, end: 0.96)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.96, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 25),
    ]).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1200), _f(1700), curve: Curves.linear),
    ));

    // Starburst: 1200ms → 1900ms
    _starburst = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1200), _f(1900), curve: Curves.easeInOut),
    ));

    // Icon shrinks to row: 1700ms → 1950ms
    _iconShrink = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1700), _f(1950), curve: Curves.easeInOutCubic),
    ));

    // Text: 1850ms → 2300ms
    _textReveal = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1850), _f(2300), curve: Curves.easeOut),
    ));
    _textSlide = Tween(begin: 20.0, end: 0.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(1850), _f(2300), curve: Curves.easeOutCubic),
    ));

    // Shine: 2300ms → 2700ms
    _shine = Tween(begin: -0.5, end: 1.5).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(2300), _f(2700), curve: Curves.easeInOut),
    ));

    // Pulse: 2600ms → 2900ms
    _holdPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(2600), _f(2900), curve: Curves.easeInOut),
    ));

    // Fade out: 2900ms → 3400ms
    _fadeOut = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _master,
      curve: Interval(_f(2900), 1.0, curve: Curves.easeIn),
    ));

    _master.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showChild = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _master.forward());
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  double _qBez(double a, double cp, double b, double t) {
    final u = 1 - t;
    return u * u * a + 2 * u * t * cp + t * t * b;
  }

  @override
  Widget build(BuildContext context) {
    if (_showChild) return widget.child;

    return AnimatedBuilder(
      animation: _master,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Opacity(
            opacity: _fadeOut.value.clamp(0.0, 1.0),
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              final cx = w / 2;
              final cy = h / 2 - h * 0.03;

              // ── Icon sizing ──
              final largeIconSize = w * 0.40;
              final smallIconSize = w * 0.11;
              final t = 1 - _iconShrink.value;
              final iconSize = _lerp(largeIconSize, smallIconSize, t);

              // ── Logo row layout ──
              final textFs = w * 0.065;
              const gap = 10.0;
              final estTextW = textFs * 7.2;
              final rowW = smallIconSize + gap + estTextW;
              final smallX = cx - rowW / 2 + smallIconSize / 2;
              final iconX = _lerp(cx, smallX, t);
              final iconY = cy;
              final scale = _iconScale.value * _holdPulse.value;

              // ── Ball position on bezier ──
              // Ball target: upper-right area of icon (where ball sits in icon)
              final ballTargetX = cx + largeIconSize * 0.15;
              final ballTargetY = cy - largeIconSize * 0.15;
              final ballStartX = w + 40.0;
              final ballStartY = -40.0;
              final ballCtrlX = cx + w * 0.22;
              final ballCtrlY = cy - h * 0.18;
              final bx = _qBez(ballStartX, ballCtrlX, ballTargetX, _ballPath.value);
              final by = _qBez(ballStartY, ballCtrlY, ballTargetY, _ballPath.value);
              // Ball size matches icon proportions: ~10% of icon size
              final ballDiameter = largeIconSize * 0.16;

              // ── Bat position on bezier ──
              // Bat target: center-left of icon area
              final batTargetX = cx - largeIconSize * 0.05;
              final batTargetY = cy + largeIconSize * 0.05;
              final batStartX = -100.0;
              final batStartY = h + 100.0;
              final batCtrlX = cx - w * 0.1;
              final batCtrlY = cy + h * 0.12;
              final btx = _qBez(batStartX, batCtrlX, batTargetX, _batPath.value);
              final bty = _qBez(batStartY, batCtrlY, batTargetY, _batPath.value);

              // Bat dimensions matching icon proportions
              // In the icon, blade is ~45% of icon height, ~18% wide
              final bladeH = largeIconSize * 0.45;
              final bladeW = largeIconSize * 0.18;
              final handleH = largeIconSize * 0.12;
              final handleW = bladeW * 0.5;

              return Stack(
                children: [
                  // ═══ Background glow + starburst ═══
                  CustomPaint(
                    size: Size(w, h),
                    painter: _BgPainter(
                      glow: _bgGlow.value,
                      cx: iconX,
                      cy: iconY,
                      starburst: _starburst.value,
                      iconSize: iconSize * scale,
                    ),
                  ),

                  // ═══ Ball glow trail ═══
                  if (_ballPath.value > 0.03 && _elementsOpacity.value > 0)
                    CustomPaint(
                      size: Size(w, h),
                      painter: _TrailPainter(
                        p0: Offset(ballStartX, ballStartY),
                        p1: Offset(ballCtrlX, ballCtrlY),
                        p2: Offset(ballTargetX, ballTargetY),
                        progress: _ballPath.value,
                        opacity: _elementsOpacity.value,
                        baseWidth: ballDiameter * 0.6,
                      ),
                    ),

                  // ═══ Bat glow trail ═══
                  if (_batPath.value > 0.03 && _elementsOpacity.value > 0)
                    CustomPaint(
                      size: Size(w, h),
                      painter: _TrailPainter(
                        p0: Offset(batStartX, batStartY),
                        p1: Offset(batCtrlX, batCtrlY),
                        p2: Offset(batTargetX, batTargetY),
                        progress: _batPath.value,
                        opacity: _elementsOpacity.value,
                        baseWidth: bladeW * 0.5,
                      ),
                    ),

                  // ═══ Animated ball (simple flat orange circle) ═══
                  if (_ballPath.value > 0 && _elementsOpacity.value > 0)
                    Positioned(
                      left: bx - ballDiameter / 2,
                      top: by - ballDiameter / 2,
                      child: Opacity(
                        opacity: _elementsOpacity.value,
                        child: Container(
                          width: ballDiameter,
                          height: ballDiameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF8D48),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8D48)
                                    .withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ═══ Animated bat (flat shapes matching icon exactly) ═══
                  if (_batPath.value > 0 && _elementsOpacity.value > 0)
                    Positioned(
                      left: btx,
                      top: bty,
                      child: Opacity(
                        opacity: _elementsOpacity.value,
                        child: Transform.translate(
                          offset: Offset(-bladeW * 0.6, -bladeH * 0.4),
                          child: Transform.rotate(
                            angle: -35 * math.pi / 180,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: bladeW * 1.2,
                              height: bladeH + handleH + 6,
                              child: CustomPaint(
                                painter: _FlatBatPainter(
                                  bladeW: bladeW,
                                  bladeH: bladeH,
                                  handleW: handleW,
                                  handleH: handleH,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ═══ ACTUAL APP ICON IMAGE ═══
                  if (_iconOpacity.value > 0)
                    Positioned(
                      left: iconX - iconSize * scale / 2,
                      top: iconY - iconSize * scale / 2,
                      child: Opacity(
                        opacity: _iconOpacity.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(iconSize * 0.22),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: const Color(0xFFFF8D48).withValues(
                                      alpha: 0.12 * _starburst.value),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(iconSize * 0.22),
                              child: Transform.scale(
                                scale: 1.12, // Zoom in to hide the white border of the image
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ═══ "ScorePartner" text ═══
                  if (_textReveal.value > 0)
                    Positioned(
                      left: cx - rowW / 2 + smallIconSize + gap,
                      top: cy - textFs * 0.5 + _textSlide.value,
                      child: Opacity(
                        opacity: _textReveal.value.clamp(0.0, 1.0),
                        child: Text(
                          'ScorePartner',
                          style: GoogleFonts.fredoka(
                            fontSize: textFs,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D2D2D),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),

                  // ═══ Shine sweep ═══
                  if (_shine.value > -0.5 &&
                      _shine.value < 1.5 &&
                      _textReveal.value > 0.3)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ShinePainter(
                            progress: _shine.value,
                            cx: cx,
                            cy: cy,
                            regionW: rowW + 40,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  FLAT BAT PAINTER – matches the icon's simple shapes exactly
// ═══════════════════════════════════════════════════════════════════════════════
class _FlatBatPainter extends CustomPainter {
  final double bladeW, bladeH, handleW, handleH;

  _FlatBatPainter({
    required this.bladeW,
    required this.bladeH,
    required this.handleW,
    required this.handleH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFFF8D48);
    final cx = size.width / 2;

    // ── Shadow ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 2, bladeH / 2 + 3),
          width: bladeW,
          height: bladeH,
        ),
        Radius.circular(bladeW * 0.22),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Blade: single flat orange rounded rectangle ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, bladeH / 2),
          width: bladeW,
          height: bladeH,
        ),
        Radius.circular(bladeW * 0.22),
      ),
      Paint()..color = color,
    );

    // ── Handle: smaller separate orange rounded rectangle ──
    // Gap between blade and handle (like in the icon)
    final handleTop = bladeH + 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, handleTop + handleH / 2),
          width: handleW,
          height: handleH,
        ),
        Radius.circular(handleW * 0.28),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FlatBatPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Background + Starburst
// ═══════════════════════════════════════════════════════════════════════════════
class _BgPainter extends CustomPainter {
  final double glow, cx, cy, starburst, iconSize;

  _BgPainter({
    required this.glow,
    required this.cx,
    required this.cy,
    required this.starburst,
    required this.iconSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Orange radial glow
    if (glow > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            size.width * 0.7,
            [
              const Color(0xFFFF8D48).withValues(alpha: 0.13 * glow),
              const Color(0xFFFF8D48).withValues(alpha: 0.04 * glow),
              Colors.transparent,
            ],
            [0.0, 0.45, 1.0],
          ),
      );
    }

    // Starburst
    if (starburst > 0.01) {
      final center = Offset(cx, cy);
      final baseR = iconSize * 0.55;

      // Soft glow
      canvas.drawCircle(
        center,
        iconSize * 1.3 * starburst,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            iconSize * 1.3 * starburst,
            [
              const Color(0xFFFF8D48).withValues(alpha: 0.14 * starburst),
              const Color(0xFFFF8D48).withValues(alpha: 0.04 * starburst),
              Colors.transparent,
            ],
            [0.0, 0.5, 1.0],
          ),
      );

      // Rays
      for (int i = 0; i < 24; i++) {
        final angle = (i / 24) * math.pi * 2;
        final rayLen =
            iconSize * (0.3 + 0.15 * math.sin(i * 2.1)) * starburst;
        final dx = math.cos(angle);
        final dy = math.sin(angle);

        canvas.drawLine(
          center + Offset(dx * baseR, dy * baseR),
          center + Offset(dx * (baseR + rayLen), dy * (baseR + rayLen)),
          Paint()
            ..color =
                const Color(0xFFFF8D48).withValues(alpha: 0.1 * starburst)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      // Ground shadow
      if (starburst > 0.3) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy + iconSize * 0.58),
            width: iconSize * 1.2,
            height: 12,
          ),
          Paint()
            ..color =
                const Color(0xFFFF8D48).withValues(alpha: 0.05 * starburst)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Glow trail
// ═══════════════════════════════════════════════════════════════════════════════
class _TrailPainter extends CustomPainter {
  final Offset p0, p1, p2;
  final double progress, opacity, baseWidth;

  _TrailPainter({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.progress,
    required this.opacity,
    required this.baseWidth,
  });

  Offset _qBez(double t) {
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Outer glow
    for (int i = 1; i <= 14; i++) {
      final tt = (progress - i * 0.014).clamp(0.0, 1.0);
      if (tt <= 0) continue;
      final pos = _qBez(tt);
      final fade = 1 - i / 14.0;
      final alpha =
          (0.28 * fade * fade * opacity * (1 - progress * 0.2)).clamp(0.0, 1.0);
      final w = baseWidth * (1.5 + fade * 2.5);

      canvas.drawCircle(
        pos,
        w,
        Paint()
          ..color = const Color(0xFFFF8D48).withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.7),
      );
    }

    // Bright core
    for (int i = 1; i <= 7; i++) {
      final tt = (progress - i * 0.008).clamp(0.0, 1.0);
      if (tt <= 0) continue;
      final pos = _qBez(tt);
      final fade = 1 - i / 7.0;
      final alpha = (0.4 * fade * opacity).clamp(0.0, 1.0);

      canvas.drawCircle(
        pos,
        baseWidth * 0.35 * fade,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.progress != progress || old.opacity != opacity;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Shine sweep
// ═══════════════════════════════════════════════════════════════════════════════
class _ShinePainter extends CustomPainter {
  final double progress, cx, cy, regionW;

  _ShinePainter({
    required this.progress,
    required this.cx,
    required this.cy,
    required this.regionW,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sweepX = cx + (progress - 0.5) * regionW * 1.2;
    final bandW = regionW * 0.1;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-15 * math.pi / 180);
    canvas.translate(-cx, -cy);

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(sweepX, cy),
        width: bandW * 2,
        height: size.height * 0.4,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(sweepX - bandW, 0),
          Offset(sweepX + bandW, 0),
          [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          [0.0, 0.25, 0.5, 0.75, 1.0],
        )
        ..blendMode = BlendMode.softLight,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShinePainter old) =>
      old.progress != progress;
}
