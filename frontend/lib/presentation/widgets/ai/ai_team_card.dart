import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_models.dart';

/// Team entity card displayed in AI chat responses
class AITeamCard extends StatelessWidget {
  final AIEntity entity;
  final VoidCallback onTap;

  const AITeamCard({super.key, required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = entity.data ?? {};
    final name = data['name'] ?? entity.title;
    final captainName = data['captainName'] ?? '';
    final playerCount = data['playerCount'] ?? 0;
    final matchesPlayed = data['matchesPlayed'] ?? 0;
    final matchesWon = data['matchesWon'] ?? 0;
    final matchesLost = data['matchesLost'] ?? 0;
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
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.groups, color: AppTheme.primaryOrange, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      if (captainName.isNotEmpty)
                        Text('Captain: $captainName', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                      Text('$playerCount Players', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
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
                _stat('Played', '$matchesPlayed', isDark),
                _stat('Won', '$matchesWon', isDark),
                _stat('Lost', '$matchesLost', isDark),
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
                  Text('Open Team', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 13.sp, fontWeight: FontWeight.w600)),
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
