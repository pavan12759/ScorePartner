import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/achievement_model.dart';
import '../../data/models/user_model.dart';
import 'dart:convert';

class AchievementShareCard extends StatelessWidget {
  final PlayerAchievement achievement;
  final UserModel user;

  const AchievementShareCard({
    super.key,
    required this.achievement,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? getProfileImageProvider(String url) {
      if (url.isEmpty) return null;
      if (url.trim().startsWith('data:')) {
        try {
          final base64Str = url.split(',').last.trim();
          return MemoryImage(base64Decode(base64Str));
        } catch (_) {
          return null;
        }
      }
      return NetworkImage(url);
    }

    return Container(
      width: 350.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E), // Dark Blue/Black
            Color(0xFF16213E),
            Color(0xFF0F3460),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppTheme.stadiumOrange.withOpacity(0.5), width: 2.w),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Branding
          Container(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_cricket, color: AppTheme.stadiumOrange, size: 24.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'SCOREPARTNER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.stadiumOrange,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'ACHIEVEMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 30.h),

          // Badge Icon with Glow
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.stadiumOrange.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                achievement.badgeIcon,
                style: TextStyle(fontSize: 60.sp),
              ),
            ),
          ),

          SizedBox(height: 24.h),

          // Title & Description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                Text(
                  achievement.title.replaceAll(achievement.badgeIcon, '').trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  achievement.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 30.h),

          // Stats Section (if any)
          if (achievement.stats.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: achievement.stats.entries.map((e) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          e.value.toString(),
                          style: TextStyle(
                            color: AppTheme.stadiumOrange,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          e.key.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10.sp,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const Divider(color: Colors.white10),

          // Footer with Player Info
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: getProfileImageProvider(user.profileImageUrl),
                  backgroundColor: AppTheme.stadiumOrange,
                  child: user.profileImageUrl.isEmpty
                      ? Text(user.name[0].toUpperCase(), style: TextStyle(color: Colors.white))
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        'Earned on ${_formatDate(achievement.earnedAt)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                // QR Code Placeholder or App Logo
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Icon(Icons.qr_code_2, color: Colors.black, size: 32.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
