import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_models.dart';

/// Tournament entity card displayed in AI chat responses
class AITournamentCard extends StatelessWidget {
  final AIEntity entity;
  final VoidCallback onTap;

  const AITournamentCard({super.key, required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = entity.data ?? {};
    final name = data['name'] ?? entity.title;
    final status = data['status'] ?? '';
    final location = data['location'] ?? '';
    final format = data['format'] ?? '';
    final teamCount = data['registeredTeamCount'] ?? data['maxTeams'] ?? 0;
    final matchCount = data['matchCount'] ?? 0;
    final overs = data['overs'] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    switch (status) {
      case 'ongoing':
        statusColor = Colors.green;
        break;
      case 'completed':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = AppTheme.primaryOrange;
    }

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
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.emoji_events, color: AppTheme.primaryOrange, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                          if (format.isNotEmpty) ...[
                            SizedBox(width: 6.w),
                            Text(format.toUpperCase(), style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                          ],
                        ],
                      ),
                      if (location.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text('📍 $location', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Teams', '$teamCount', isDark),
                _stat('Matches', '$matchCount', isDark),
                if (overs > 0) _stat('Overs', '$overs', isDark),
              ],
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14.r), bottomRight: Radius.circular(14.r)),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Go to Tournament', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 13.sp, fontWeight: FontWeight.w600)),
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

  Widget _stat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
      ],
    );
  }
}
