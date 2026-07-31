import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

class NewsTab extends StatelessWidget {
  final MatchModel match;
  
  const NewsTab({super.key, required this.match});
  
  @override
  Widget build(BuildContext context) {
    // Mock news
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _buildNewsItem(
          context,
          "Match Preview: ${match.team1Name} looks to dominate",
          "The upcoming clash promises to be an exciting one as both teams are in great form.",
          "2 hours ago"
        ),
        _buildNewsItem(
          context,
          "Pitch Report",
          "The pitch at ${match.ground} is expected to assist spinners in the later half.",
          "30 mins ago"
        ),
        _buildNewsItem(
          context,
           "Weather Update",
           "Clear skies expected throughout the match duration.",
           "10 mins ago"
        ),
      ],
    );
  }
  
  Widget _buildNewsItem(BuildContext context, String title, String summary, String time) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(Icons.article_outlined, size: 20.sp, color: AppTheme.primaryOrange),
                ),
                SizedBox(width: 12.w),
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, letterSpacing: 0.5))),
              ],
            ),
            SizedBox(height: 12.h),
            Text(summary, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, height: 1.5, fontSize: 13.sp)),
            SizedBox(height: 12.h),
             Text(time.toUpperCase(), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
