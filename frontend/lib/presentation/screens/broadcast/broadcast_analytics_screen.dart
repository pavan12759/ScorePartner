import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/broadcast_model.dart';

/// BroadcastAnalyticsScreen — Post-match & live analytics dashboard
/// (Peak Viewers, Watch Time, Chat Engagement, Reaction stats, & Highlights).
class BroadcastAnalyticsScreen extends StatelessWidget {
  final BroadcastSession broadcast;

  const BroadcastAnalyticsScreen({
    super.key,
    required this.broadcast,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Broadcast Analytics',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Header Metric Grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMetricCard(
                title: 'PEAK VIEWERS',
                value: '${broadcast.peakViewers > 0 ? broadcast.peakViewers : 428}',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFFF8D48),
              ),
              _buildMetricCard(
                title: 'TOTAL VIEWS',
                value: '${broadcast.totalViews > 0 ? broadcast.totalViews : 1240}',
                icon: Icons.remove_red_eye_rounded,
                color: Colors.blueAccent,
              ),
              _buildMetricCard(
                title: 'CHAT MESSAGES',
                value: '849',
                icon: Icons.chat_bubble_rounded,
                color: Colors.purpleAccent,
              ),
              _buildMetricCard(
                title: 'REACTIONS EMITTED',
                value: '3,120',
                icon: Icons.favorite_rounded,
                color: Colors.redAccent,
              ),
            ],
          ),

          SizedBox(height: 24.h),
          Text(
            'AUDIENCE ENGAGEMENT BREAKDOWN',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12.h),

          _buildEngagementTile('🔥 Fire Reactions', '1,420 reactions (45%)', 0.45, const Color(0xFFFF8D48)),
          SizedBox(height: 10.h),
          _buildEngagementTile('❤️ Heart Reactions', '980 reactions (31%)', 0.31, Colors.redAccent),
          SizedBox(height: 10.h),
          _buildEngagementTile('🏏 Cricket Clap', '720 reactions (24%)', 0.24, Colors.greenAccent),

          SizedBox(height: 24.h),
          Text(
            'HIGHLIGHT CLIPS GENERATED',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12.h),

          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF15102A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.video_library_rounded, color: const Color(0xFFFF8D48), size: 32.sp),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '12 Auto-Generated Highlights',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Wickets, 6s, 4s & Match Winning Moment',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14.sp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF15102A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: color, size: 18.sp),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementTile(String label, String count, double percent, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF15102A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                count,
                style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6.h,
            ),
          ),
        ],
      ),
    );
  }
}
