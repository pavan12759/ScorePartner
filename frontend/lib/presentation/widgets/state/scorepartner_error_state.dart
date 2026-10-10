import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class ScorePartnerErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  const ScorePartnerErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryText = 'Try Again',
    this.icon = Icons.error_outline_rounded,
  });

  /// Sanitizes raw error messages to prevent exposing technical details to users.
  /// Logs the original error to debug console.
  static String sanitizeMessage(String rawError) {
    debugPrint('ScorePartnerError: $rawError');

    final raw = rawError.toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable') ||
        raw.contains('no internet') ||
        raw.contains('failed host lookup')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }
    if (raw.contains('firebaseexception') ||
        raw.contains('firebase') ||
        raw.contains('permission-denied') ||
        raw.contains('unavailable')) {
      return 'Our servers are temporarily unavailable. Please try again in a moment.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }
    if (raw.contains('http') && (raw.contains('500') || raw.contains('502') || raw.contains('503'))) {
      return 'Server error. Please try again later.';
    }
    if (raw.contains('formatexception') || raw.contains('type ')) {
      return 'Something went wrong while loading data. Please try again.';
    }
    // If the message looks clean enough (no exception class names), show it
    if (!raw.contains('exception') && !raw.contains('error:') && rawError.length < 120) {
      return rawError;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64.sp,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              sanitizeMessage(message),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            SizedBox(height: 32.h),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  minimumSize: Size(200.w, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  retryText,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
