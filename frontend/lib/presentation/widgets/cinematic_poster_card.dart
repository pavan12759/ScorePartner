import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'cinematic_overlay_painter.dart';

class CinematicPosterCard extends StatefulWidget {
  final dynamic photo; // File, Uint8List, or String base64/url
  final String playerName;
  final String achievementTitle;
  final String achievementDesc;
  final String badgeName; // e.g. "Boundary Beast 💥"
  final String badgeType; // 'batsman', 'bowler', 'team'
  final String overlayStyle; // 'glowing_border', 'orange_particles', 'spotlight_focus', 'stadium_light', 'all'
  final String shareFormat; // 'instagram_story', 'instagram_post', 'whatsapp_status', 'match_poster', 'trophy_card', 'mvp_card', 'banner'
  final String tournamentName;
  final String date;

  const CinematicPosterCard({
    super.key,
    required this.photo,
    required this.playerName,
    required this.achievementTitle,
    required this.achievementDesc,
    required this.badgeName,
    required this.badgeType,
    required this.overlayStyle,
    required this.shareFormat,
    required this.tournamentName,
    required this.date,
  });

  @override
  State<CinematicPosterCard> createState() => _CinematicPosterCardState();
}

class _CinematicPosterCardState extends State<CinematicPosterCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get aspect ratio and sizing based on format
    final Size size = _getCardDimensions();
    final ImageProvider? imageProvider = _resolveImageProvider();
    final Color badgeColor = _getBadgeColor();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: size.width,
          height: size.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.w),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withOpacity(0.2),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // BACKGROUND: Raw Photo with dark gradient map overlay
              if (imageProvider != null)
                Positioned.fill(
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.broken_image, color: Colors.white24, size: 50.sp),
                    ),
                  ),
                ),

              // Gradient filter to give cinematic dramatic lighting
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.25),
                        Colors.black.withOpacity(0.9),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // CUSTOM PAINTER: Stadium lights, glowing border, orange embers particles
              Positioned.fill(
                child: CustomPaint(
                  painter: CinematicOverlayPainter(
                    overlayStyle: widget.overlayStyle,
                    themeColor: badgeColor,
                    animationValue: _animationController.value,
                  ),
                ),
              ),

              // STYLIZED ELEMENTS LAYOUT based on format aspect ratios
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
                  child: _buildLayoutContent(badgeColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dimension helpers for the 7 templates
  Size _getCardDimensions() {
    switch (widget.shareFormat) {
      case 'instagram_story':
      case 'whatsapp_status':
        return Size(360, 640); // 9:16 Aspect
      case 'instagram_post':
        return Size(360, 450); // 4:5 Aspect
      case 'match_poster':
        return Size(480, 290); // Horizontal Poster
      case 'banner':
        return Size(480, 240); // Widescreen Widespan
      case 'trophy_card':
      case 'mvp_card':
      default:
        return Size(340, 480); // Standard High-end tall card
    }
  }

  // Main UI composition matching selected layout
  Widget _buildLayoutContent(Color themeColor) {
    final bool isWide = widget.shareFormat == 'match_poster' || widget.shareFormat == 'banner';
    
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left portion: Player Name & Stats
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeaderStrip(),
                SizedBox(height: 12.h),
                _buildPlayerNameDisplay(),
                SizedBox(height: 6.h),
                _buildDescriptionBox(),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          // Right portion: Big Glowing Badge & Details
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCinematicBadge(themeColor, scale: 0.95),
                SizedBox(height: 12.h),
                _buildFooterTournamentText(),
              ],
            ),
          ),
        ],
      );
    }

    // Tall layouts (Stories, Posts, Cards)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHeaderStrip(),
        const Spacer(flex: 2),
        
        // Massive Cinematic Badge
        _buildCinematicBadge(themeColor, scale: 1.15),
        const Spacer(flex: 2),

        // Player Name & stats
        _buildPlayerNameDisplay(),
        SizedBox(height: 8.h),

        // Achievements Description in a beautiful soft glass container
        _buildDescriptionBox(),
        
        const Spacer(flex: 3),
        _buildFooterTournamentText(),
      ],
    );
  }

  Widget _buildHeaderStrip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.sports_cricket, color: Colors.amber, size: 14.sp),
            SizedBox(width: 4.w),
            Text(
              'ScorePartner'.toUpperCase(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        Text(
          widget.date.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.55),
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerNameDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.playerName.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: widget.shareFormat.contains('story') ? 24 : 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(0, 3), blurRadius: 6),
              Shadow(color: _getBadgeColor().withOpacity(0.6), offset: Offset(0, 0), blurRadius: 10),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: _getBadgeColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: _getBadgeColor().withOpacity(0.4), width: 0.8.w),
          ),
          child: Text(
            widget.achievementTitle.toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Text(
          widget.achievementDesc,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.95),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterTournamentText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.tournamentName.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.85),
            fontSize: 11.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'ScorePartner Cricket League'.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.amber.withOpacity(0.65),
            fontSize: 8.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCinematicBadge(Color themeColor, {double scale = 1.0}) {
    IconData iconData;
    switch (widget.badgeType) {
      case 'batsman':
        iconData = Icons.flash_on;
        break;
      case 'bowler':
        iconData = Icons.local_fire_department;
        break;
      case 'team':
      default:
        iconData = Icons.emoji_events;
        break;
    }

    // Dynamic scale oscillation for animated effect
    final double pulseScale = scale * (1.0 + 0.04 * math.sin(_animationController.value * 2.0 * math.pi));

    return Transform.scale(
      scale: pulseScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72.w,
            height: 72.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  themeColor,
                  themeColor.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 58.w,
              height: 58.h,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                shape: BoxShape.circle,
                border: Border.all(color: themeColor, width: 2.0.w),
              ),
              child: Icon(
                iconData,
                color: themeColor,
                size: 28.sp,
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            widget.badgeName.toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              shadows: [
                Shadow(color: themeColor, offset: Offset.zero, blurRadius: 8),
                const Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Resolves local or global types to specific images
  ImageProvider? _resolveImageProvider() {
    if (widget.photo == null) return null;
    if (widget.photo is File) {
      return kIsWeb ? null : FileImage(widget.photo as File);
    } else if (widget.photo is Uint8List) {
      return MemoryImage(widget.photo as Uint8List);
    } else if (widget.photo is String) {
      final photoStr = widget.photo as String;
      if (photoStr.isEmpty) return null;
      if (photoStr.startsWith('http') || photoStr.startsWith('https')) {
        return NetworkImage(photoStr);
      } else if (photoStr.startsWith('data:')) {
        try {
          final base64Str = photoStr.split(',').last;
          final bytes = base64Decode(base64Str);
          return MemoryImage(bytes);
        } catch (_) {
          return null;
        }
      } else if (!kIsWeb) {
        return FileImage(File(photoStr));
      }
    }
    return null;
  }

  Color _getBadgeColor() {
    switch (widget.badgeType) {
      case 'batsman':
        return Colors.orangeAccent;
      case 'bowler':
        return Colors.cyanAccent;
      case 'team':
      default:
        return Colors.amberAccent;
    }
  }
}
