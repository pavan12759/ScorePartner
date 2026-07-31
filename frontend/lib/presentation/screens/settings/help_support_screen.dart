import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          _buildFAQItem('How do I score a match?', 'You can start scoring a match by navigating to "My Matches", creating a new match, and selecting "Start Scoring".'),
          _buildFAQItem('How do I add players to my team?', 'Go to "My Teams", select your team, and click the "+" icon or "Add Player" button to search and add players.'),
          _buildFAQItem('Can I edit a match after it is finished?', 'Currently, once a match is completed, the scorecard is final. If there is a major issue, please contact support.'),
          SizedBox(height: 30.h),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Future: launch email or support chat
              },
              icon: const Icon(Icons.email_outlined),
              label: const Text('Contact Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: Colors.black87),
          ),
          SizedBox(height: 6.h),
          Text(
            answer,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[700], height: 1.4),
          ),
          SizedBox(height: 8.h),
          Divider(color: Colors.grey.shade200),
        ],
      ),
    );
  }
}
