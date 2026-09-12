import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_models.dart';

/// Player entity card displayed in AI chat responses
class AIPlayerCard extends StatelessWidget {
  final AIEntity entity;
  final VoidCallback onTap;

  const AIPlayerCard({super.key, required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = entity.data ?? {};
    final name = data['name'] ?? entity.title;
    final role = data['role'] ?? '';
    final battingStyle = data['battingStyle'] ?? '';
    final location = data['location'] ?? '';
    final tStats = data['tennisBallStats'];
    final lStats = data['leatherBallStats'];
    final stats = tStats ?? lStats;
    final rankTitle = data['rankTitle'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h, top: 4.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                // Player avatar
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.person, color: AppTheme.primaryOrange, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                // Name + Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (role.isNotEmpty || battingStyle.isNotEmpty)
                        Text(
                          [role, battingStyle].where((s) => s.isNotEmpty).join(' • '),
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                        ),
                      if (location.isNotEmpty)
                        Text(
                          '📍 $location',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                if (rankTitle.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      rankTitle,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Stats row
          if (stats != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Matches', '${stats['matchesPlayed'] ?? 0}', isDark),
                  _statItem('Runs', '${stats['totalRuns'] ?? 0}', isDark),
                  _statItem('Wickets', '${stats['totalWickets'] ?? 0}', isDark),
                  _statItem('HS', '${stats['highestScore'] ?? 0}', isDark),
                ],
              ),
            ),

          // View Player button
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(14.r),
              bottomRight: Radius.circular(14.r),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View Player', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4.w),
                  Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryOrange, size: 16.sp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
      ],
    );
  }
}
