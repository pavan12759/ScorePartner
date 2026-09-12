import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_models.dart';

/// News article card displayed in AI chat responses
class AINewsCard extends StatelessWidget {
  final AIEntity entity;
  final VoidCallback onTap;

  const AINewsCard({super.key, required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = entity.data ?? {};
    final title = data['title'] ?? entity.title;
    final summary = data['summary'] ?? '';
    final source = data['source'] ?? 'Unknown';
    final publishedAt = data['publishedAt'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String timeAgo = '';
    try {
      if (publishedAt.isNotEmpty) {
        final dt = DateTime.parse(publishedAt);
        timeAgo = timeago.format(dt);
      }
    } catch (_) {
      timeAgo = publishedAt;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article, color: AppTheme.primaryOrange, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text('📰', style: TextStyle(fontSize: 14.sp)),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    summary,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'Source: $source',
                        style: TextStyle(fontSize: 10.sp, color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Spacer(),
                    if (timeAgo.isNotEmpty)
                      Text(timeAgo, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                  ],
                ),
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
                  Text('Read Full News', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4.w),
                  Icon(Icons.open_in_new, color: AppTheme.primaryOrange, size: 14.sp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
