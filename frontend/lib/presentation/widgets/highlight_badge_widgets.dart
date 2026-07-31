import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

enum BadgeType {
  win,
  fifty,
  century,
  wicket,
  mvp,
}

class HighlightBadgeCard extends StatelessWidget {
  final BadgeType type;
  final String title;
  final String description;
  final String matchName;
  final String ground;
  final String date;
  final String? playerName;
  final dynamic playerPhoto; // Can be File, String path, or Uint8List (for web)
  final String? team1Name;
  final String? team2Name;
  final String? team1Score;
  final String? team2Score;

  const HighlightBadgeCard({
    super.key,
    required this.type,
    required this.title,
    required this.description,
    required this.matchName,
    required this.ground,
    required this.date,
    this.playerName,
    this.playerPhoto,
    this.team1Name,
    this.team2Name,
    this.team1Score,
    this.team2Score,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImageProvider();

    return Container(
      width: 400.w,
      height: 500.h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: imageProvider == null ? _getBackgroundGradient() : null,
        image: imageProvider != null
            ? DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: _getShadowColor().withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Geometric Background Accents (only if no image)
          if (imageProvider == null) ...[
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200.w,
                height: 200.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 150.w,
                height: 150.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ],

          // Main Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0.w, vertical: 20.0.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top header: Brand name + Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sports_cricket, color: Colors.amber, size: 18.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'ScorePartner'.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 1),

                // Badge Title & Trophy Icon
                _buildBadgeIconAndHeader(),

                SizedBox(height: 16.h),

                // Player Name & Achievement Description
                if (playerName != null) ...[
                  Text(
                    playerName!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(color: Colors.black38, offset: Offset(0, 2), blurRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Footer Section: Match Details & Scores (Glassmorphism card)
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        matchName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        ground,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (team1Name != null && team2Name != null) ...[
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team1Name!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (team1Score != null)
                                    Text(
                                      team1Score!,
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                'VS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    team2Name!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (team2Score != null)
                                    Text(
                                      team2Score!,
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _getBackgroundGradient() {
    switch (type) {
      case BadgeType.win:
        return const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Deep purple/blue gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeType.fifty:
        return const LinearGradient(
          colors: [Color(0xFF00B4DB), Color(0xFF0083B0)], // Teal/Cyan ocean gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeType.century:
        return const LinearGradient(
          colors: [Color(0xFFF12711), Color(0xFFF5AF19)], // Warm fire/gold gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeType.wicket:
        return const LinearGradient(
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)], // Neon green/mint gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeType.mvp:
        return const LinearGradient(
          colors: [Color(0xFFD4145A), Color(0xFFFBB03B)], // Vibrant pink to orange gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getShadowColor() {
    switch (type) {
      case BadgeType.win:
        return const Color(0xFF4A00E0);
      case BadgeType.fifty:
        return const Color(0xFF0083B0);
      case BadgeType.century:
        return const Color(0xFFF5AF19);
      case BadgeType.wicket:
        return const Color(0xFF11998e);
      case BadgeType.mvp:
        return const Color(0xFFD4145A);
    }
  }

  Widget _buildBadgeIconAndHeader() {
    IconData iconData;
    String badgeText;
    Color iconColor;

    switch (type) {
      case BadgeType.win:
        iconData = Icons.emoji_events;
        badgeText = 'MATCH WINNER';
        iconColor = Colors.amber.shade400;
        break;
      case BadgeType.fifty:
        iconData = Icons.star;
        badgeText = 'HALF CENTURY';
        iconColor = Colors.amber;
        break;
      case BadgeType.century:
        iconData = Icons.workspace_premium;
        badgeText = 'CENTURY HERO';
        iconColor = Colors.amber;
        break;
      case BadgeType.wicket:
        iconData = Icons.local_fire_department;
        badgeText = 'STRIKE BOWLER';
        iconColor = Colors.orangeAccent;
        break;
      case BadgeType.mvp:
        iconData = Icons.emoji_events;
        badgeText = 'MAN OF THE MATCH';
        iconColor = Colors.amber;
        break;
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5.w),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(iconData, color: iconColor, size: 28.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          badgeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            shadows: [
              Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 3),
            ],
          ),
        ),
      ],
    );
  }

  ImageProvider? _resolveImageProvider() {
    if (playerPhoto == null) return null;
    if (playerPhoto is File) {
      return FileImage(playerPhoto as File);
    } else if (playerPhoto is Uint8List) {
      return MemoryImage(playerPhoto as Uint8List);
    } else if (playerPhoto is String) {
      final photoStr = playerPhoto as String;
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
      } else {
        return FileImage(File(photoStr));
      }
    }
    return null;
  }
}
