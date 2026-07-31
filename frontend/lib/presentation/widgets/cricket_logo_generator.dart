import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Cricket-themed logo designs that can be rendered as images
class CricketLogoGenerator {
  /// All available logo designs
  static const List<LogoDesign> designs = [
    LogoDesign(
      name: 'Thunder Strikers',
      icon: Icons.flash_on,
      primaryColor: Color(0xFFFF6B35),
      secondaryColor: Color(0xFFFFD700),
      bgGradient: [Color(0xFF1A1A2E), Color(0xFF16213E)],
      shape: LogoShape.shield,
    ),
    LogoDesign(
      name: 'Royal Warriors',
      icon: Icons.shield,
      primaryColor: Color(0xFF6C63FF),
      secondaryColor: Color(0xFFE0C3FC),
      bgGradient: [Color(0xFF0F0C29), Color(0xFF302B63)],
      shape: LogoShape.circle,
    ),
    LogoDesign(
      name: 'Fire Titans',
      icon: Icons.local_fire_department,
      primaryColor: Color(0xFFE63946),
      secondaryColor: Color(0xFFF4845F),
      bgGradient: [Color(0xFF2D1B2E), Color(0xFF4A1942)],
      shape: LogoShape.shield,
    ),
    LogoDesign(
      name: 'Storm Eagles',
      icon: Icons.air,
      primaryColor: Color(0xFF00B4D8),
      secondaryColor: Color(0xFF90E0EF),
      bgGradient: [Color(0xFF0D1B2A), Color(0xFF1B2838)],
      shape: LogoShape.circle,
    ),
    LogoDesign(
      name: 'Golden Lions',
      icon: Icons.pets,
      primaryColor: Color(0xFFFFB703),
      secondaryColor: Color(0xFFFB8500),
      bgGradient: [Color(0xFF1A1A0E), Color(0xFF2E2E16)],
      shape: LogoShape.shield,
    ),
    LogoDesign(
      name: 'Shadow Panthers',
      icon: Icons.visibility,
      primaryColor: Color(0xFF06D6A0),
      secondaryColor: Color(0xFF118AB2),
      bgGradient: [Color(0xFF0B1A1A), Color(0xFF162B2B)],
      shape: LogoShape.circle,
    ),
  ];

  /// Build a logo widget for preview
  static Widget buildLogoPreview(LogoDesign design, String teamName, {double size = 120}) {
    return _CricketLogoWidget(design: design, teamName: teamName, size: size);
  }

  /// Convert a logo widget to image bytes for upload
  static Future<Uint8List?> renderLogoToBytes(LogoDesign design, String teamName) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(512, 512);

      final painter = _CricketLogoPainter(design: design, teamName: teamName);
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final image = await picture.toImage(512, 512);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('❌ Error rendering logo: $e');
      return null;
    }
  }
}

enum LogoShape { shield, circle }

class LogoDesign {
  final String name;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Color> bgGradient;
  final LogoShape shape;

  const LogoDesign({
    required this.name,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.bgGradient,
    required this.shape,
  });
}

/// Widget to display logo preview
class _CricketLogoWidget extends StatelessWidget {
  final LogoDesign design;
  final String teamName;
  final double size;

  const _CricketLogoWidget({required this.design, required this.teamName, required this.size});

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CricketLogoPainter(design: design, teamName: teamName),
    );
  }
}

/// Custom painter for cricket logos
class _CricketLogoPainter extends CustomPainter {
  final LogoDesign design;
  final String teamName;

  _CricketLogoPainter({required this.design, required this.teamName});

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: design.bgGradient,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    if (design.shape == LogoShape.circle) {
      canvas.drawCircle(center, radius, bgPaint);
    } else {
      // Shield shape
      final path = Path();
      path.moveTo(size.width * 0.5, 0);
      path.lineTo(size.width, size.height * 0.15);
      path.lineTo(size.width * 0.93, size.height * 0.65);
      path.lineTo(size.width * 0.5, size.height);
      path.lineTo(size.width * 0.07, size.height * 0.65);
      path.lineTo(0, size.height * 0.15);
      path.close();
      canvas.drawPath(path, bgPaint);
    }

    // Accent ring / border
    final borderPaint = Paint()
      ..color = design.primaryColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03;

    if (design.shape == LogoShape.circle) {
      canvas.drawCircle(center, radius * 0.85, borderPaint);
    }

    // Inner glow circle
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [design.primaryColor.withOpacity(0.15), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));
    canvas.drawCircle(center, radius * 0.6, glowPaint);

    // Cricket ball decoration (small circles)
    final ballPaint = Paint()..color = design.primaryColor.withOpacity(0.3);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.75), size.width * 0.04, ballPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.75), size.width * 0.04, ballPaint);

    // Cricket stumps decoration
    final stumpPaint = Paint()
      ..color = design.secondaryColor.withOpacity(0.2)
      ..strokeWidth = size.width * 0.015
      ..style = PaintingStyle.stroke;
    // Left stump
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.6),
      Offset(size.width * 0.35, size.height * 0.8),
      stumpPaint,
    );
    // Middle stump
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.82),
      stumpPaint,
    );
    // Right stump
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.6),
      Offset(size.width * 0.65, size.height * 0.8),
      stumpPaint,
    );
    // Bails
    canvas.drawLine(
      Offset(size.width * 0.33, size.height * 0.6),
      Offset(size.width * 0.67, size.height * 0.6),
      stumpPaint,
    );

    // Team initials
    final initials = _getInitials(teamName);
    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: design.primaryColor,
          fontSize: size.width * 0.28,
          fontWeight: FontWeight.w900,
          letterSpacing: size.width * 0.02,
          shadows: [
            Shadow(color: design.primaryColor.withOpacity(0.5), blurRadius: 10),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - size.height * 0.08,
      ),
    );

    // "CRICKET" small text at bottom
    final cricketText = TextPainter(
      text: TextSpan(
        text: '★ CRICKET ★',
        style: TextStyle(
          color: design.secondaryColor.withOpacity(0.7),
          fontSize: size.width * 0.07,
          fontWeight: FontWeight.bold,
          letterSpacing: size.width * 0.015,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    cricketText.layout();
    cricketText.paint(
      canvas,
      Offset(
        center.dx - cricketText.width / 2,
        size.height * 0.88,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
