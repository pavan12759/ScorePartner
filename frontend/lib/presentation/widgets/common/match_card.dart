import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

class MatchCard extends StatelessWidget {
  final MatchModel? match;
  final VoidCallback onTap;

  const MatchCard({super.key, required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      return _buildLoadingCard();
    }

    return Container(
      width: 280.w,
      margin: EdgeInsets.only(right: 12.w),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Match Status Badge
                _buildStatusBadge(),
                SizedBox(height: 12.h),

                // Match Name
                Text(
                  match!.matchName.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),

                // Teams
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            match!.team1Name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (match!.status == 'live') ...[
                            SizedBox(height: 6.h),
                            Text(
                              '${match!.team1Score.runs}/${match!.team1Score.wickets}',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '(${match!.team1Score.overs.toStringAsFixed(1)} ov)',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            match!.team2Name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (match!.status == 'live') ...[
                            SizedBox(height: 6.h),
                            Text(
                              '${match!.team2Score.runs}/${match!.team2Score.wickets}',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '(${match!.team2Score.overs.toStringAsFixed(1)} ov)',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),
                Divider(color: Colors.grey[300], height: 1.h),
                SizedBox(height: 12.h),

                // Match Info
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        match!.ground,
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _formatDate(match!.scheduledDate),
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    switch (match!.status) {
      case 'live':
        color = Colors.redAccent;
        text = 'LIVE';
        break;
      case 'completed':
        color = Colors.blueAccent;
        text = 'COMPLETED';
        break;
      case 'scheduled':
        color = AppTheme.primaryOrange;
        text = 'UPCOMING';
        break;
      default:
        color = Colors.grey;
        text = match!.status.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (match!.status == 'live')
            Container(
              margin: EdgeInsets.only(right: 6.w),
              width: 6.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: 280.w,
      margin: EdgeInsets.only(right: 12.w),
      child: Card(
        color: Colors.white,
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60.w, height: 20.h,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8.r)),
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity, height: 16.h,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4.r)),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(child: Container(height: 40.h, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8.r)))),
                  SizedBox(width: 8.w),
                  Container(width: 30.w, height: 20.h, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4.r))),
                  SizedBox(width: 8.w),
                  Expanded(child: Container(height: 40.h, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8.r)))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
