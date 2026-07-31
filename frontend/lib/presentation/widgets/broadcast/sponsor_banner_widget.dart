import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// SponsorBannerWidget — Configurable TV broadcast sponsor ticker / brand banner slot.
class SponsorBannerWidget extends StatelessWidget {
  final OverlayThemeData theme;
  final String sponsorName;
  final String? sponsorLogoUrl;
  final String? tagline;

  const SponsorBannerWidget({
    super.key,
    required this.theme,
    this.sponsorName = 'SCOREPARTNER LIVE+',
    this.sponsorLogoUrl,
    this.tagline = 'POWERED BY SCOREPARTNER',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cornerRadius > 0 ? 12 : 0),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: theme.glassBlur,
          sigmaY: theme.glassBlur,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withOpacity(theme.transparency),
            borderRadius: BorderRadius.circular(theme.cornerRadius > 0 ? 12 : 0),
            border: theme.borderWidth > 0
                ? Border.all(color: theme.borderColor, width: theme.borderWidth)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sponsorLogoUrl != null && sponsorLogoUrl!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: 6.w),
                  child: Image.network(
                    sponsorLogoUrl!,
                    width: 14.w,
                    height: 14.w,
                    errorBuilder: (_, __, ___) => Icon(Icons.star, color: theme.accentColor, size: 12.sp),
                  ),
                )
              else
                Icon(Icons.stars_rounded, color: theme.accentColor, size: 13.sp),
              SizedBox(width: 4.w),
              Text(
                tagline ?? 'POWERED BY $sponsorName',
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.8),
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
