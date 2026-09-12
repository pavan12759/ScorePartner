import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_models.dart';

/// Chat message bubble for AI conversations
class AIMessageBubble extends StatelessWidget {
  final AIMessage message;

  const AIMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return _buildLoadingBubble(context);
    }
    if (message.error != null) {
      return _buildErrorBubble(context);
    }
    return message.isUser
        ? _buildUserBubble(context)
        : _buildAssistantBubble(context);
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.w),
        margin: EdgeInsets.only(bottom: 12.h, left: 48.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18.r),
            topRight: Radius.circular(18.r),
            bottomLeft: Radius.circular(18.r),
            bottomRight: Radius.circular(4.r),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        margin: EdgeInsets.only(bottom: 12.h, right: 32.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Avatar
            Container(
              width: 28.w,
              height: 28.w,
              margin: EdgeInsets.only(top: 4.h, right: 8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryOrange,
                    AppTheme.primaryOrange.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.sports_cricket,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
            // Message
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.r),
                    topRight: Radius.circular(18.r),
                    bottomLeft: Radius.circular(18.r),
                    bottomRight: Radius.circular(18.r),
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h, right: 32.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              margin: EdgeInsets.only(top: 4.h, right: 8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryOrange,
                    AppTheme.primaryOrange.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.sports_cricket,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E2E)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(0),
                  SizedBox(width: 4.w),
                  _buildDot(1),
                  SizedBox(width: 4.w),
                  _buildDot(2),
                  SizedBox(width: 10.w),
                  Text(
                    'Thinking...',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildErrorBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        margin: EdgeInsets.only(bottom: 12.h, right: 32.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 18.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                message.error ?? 'Something went wrong',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
