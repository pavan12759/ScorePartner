import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

class ScorePartnerOfflineBanner extends StatelessWidget {
  final bool isOffline;
  
  const ScorePartnerOfflineBanner({
    super.key,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isOffline ? 32.h : 0,
      width: double.infinity,
      color: AppTheme.primaryOrange,
      child: isOffline
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 14.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'You\'re offline. Some information may be outdated.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
