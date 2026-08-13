import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class ScorePartnerSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ScorePartnerSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.margin,
  });

  /// Skeleton for a match card
  static Widget matchCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScorePartnerSkeleton(width: 100.w, height: 14.h, borderRadius: 4.r),
              ScorePartnerSkeleton(width: 60.w, height: 24.h, borderRadius: 12.r),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              ScorePartnerSkeleton(width: 40.r, height: 40.r, borderRadius: 20.r),
              SizedBox(width: 12.w),
              ScorePartnerSkeleton(width: 80.w, height: 16.h, borderRadius: 4.r),
              const Spacer(),
              ScorePartnerSkeleton(width: 40.w, height: 16.h, borderRadius: 4.r),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              ScorePartnerSkeleton(width: 40.r, height: 40.r, borderRadius: 20.r),
              SizedBox(width: 12.w),
              ScorePartnerSkeleton(width: 80.w, height: 16.h, borderRadius: 4.r),
              const Spacer(),
              ScorePartnerSkeleton(width: 40.w, height: 16.h, borderRadius: 4.r),
            ],
          ),
          SizedBox(height: 16.h),
          ScorePartnerSkeleton(width: double.infinity, height: 14.h, borderRadius: 4.r),
        ],
      ),
    );
  }

  /// Skeleton for a list item (like team or tournament)
  static Widget listItem() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ScorePartnerSkeleton(width: 50.r, height: 50.r, borderRadius: 8.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScorePartnerSkeleton(width: 150.w, height: 16.h, borderRadius: 4.r),
                SizedBox(height: 8.h),
                ScorePartnerSkeleton(width: 100.w, height: 12.h, borderRadius: 4.r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton for a player profile
  static Widget profile() {
    return Column(
      children: [
        SizedBox(height: 24.h),
        ScorePartnerSkeleton(width: 100.r, height: 100.r, borderRadius: 50.r),
        SizedBox(height: 16.h),
        ScorePartnerSkeleton(width: 150.w, height: 24.h, borderRadius: 4.r),
        SizedBox(height: 8.h),
        ScorePartnerSkeleton(width: 100.w, height: 14.h, borderRadius: 4.r),
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ScorePartnerSkeleton(width: 60.w, height: 60.w, borderRadius: 8.r),
            ScorePartnerSkeleton(width: 60.w, height: 60.w, borderRadius: 8.r),
            ScorePartnerSkeleton(width: 60.w, height: 60.w, borderRadius: 8.r),
          ],
        ),
        SizedBox(height: 24.h),
        Expanded(
          child: ListView.builder(
            itemCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) => listItem(),
          ),
        )
      ],
    );
  }
  
  /// Skeleton for a search list result
  static Widget searchList() {
    return ListView.builder(
      itemCount: 10,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) => listItem(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
