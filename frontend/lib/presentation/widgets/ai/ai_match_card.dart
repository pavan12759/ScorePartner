import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_models.dart';

/// Match entity card displayed in AI chat responses
class AIMatchCard extends StatelessWidget {
  final AIEntity entity;
  final VoidCallback onTap;

  const AIMatchCard({super.key, required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = entity.data ?? {};
    final team1Name = data['team1Name'] ?? 'Team 1';
    final team2Name = data['team2Name'] ?? 'Team 2';
    final t1Score = data['team1Score'];
    final t2Score = data['team2Score'];
    final status = data['status'] ?? '';
    final result = data['result'];
    final tournamentName = data['tournamentName'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h, top: 4.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.sports_cricket, color: AppTheme.primaryOrange, size: 16.sp),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    status == 'live' ? '🔴 LIVE' : status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: status == 'live' ? Colors.red : AppTheme.primaryOrange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (tournamentName.isNotEmpty)
                  Text(
                    tournamentName,
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Scores
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Column(
              children: [
                _buildTeamRow(team1Name, t1Score, isDark),
                SizedBox(height: 6.h),
                _buildTeamRow(team2Name, t2Score, isDark),
              ],
            ),
          ),

          // Result
          if (result != null && result['summary'] != null)
            Padding(
              padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 8.h),
              child: Text(
                result['summary'],
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Go to Match button
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
                border: Border(
                  top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Go to Match',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

  Widget _buildTeamRow(String name, dynamic score, bool isDark) {
    final runs = score is Map ? (score['runs'] ?? 0) : 0;
    final wickets = score is Map ? (score['wickets'] ?? 0) : 0;
    final overs = score is Map ? (score['overs'] ?? 0) : 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        if (runs > 0 || wickets > 0)
          Text(
            '$runs/$wickets',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        if (overs > 0)
          Text(
            ' ($overs ov)',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey,
            ),
          ),
      ],
    );
  }
}
