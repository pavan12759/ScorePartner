import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/notification_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../profile/player_profile_screen.dart';
import '../matches/match_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: FirebaseDataService.instance.getNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80.sp, color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'When you get updates, they\'ll appear here.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(height: 1.h, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                userId: user.uid,
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String userId;

  const _NotificationTile({required this.notification, required this.userId});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (notification.type) {
      case NotificationType.follow:
        iconData = Icons.person_add;
        iconColor = Colors.blue;
        bgColor = Colors.blue.withOpacity(0.1);
        break;
      case NotificationType.matchStart:
        iconData = Icons.sports_cricket;
        iconColor = AppTheme.primaryOrange;
        bgColor = AppTheme.primaryOrange.withOpacity(0.1);
        break;
      case NotificationType.achievement:
        iconData = Icons.emoji_events;
        iconColor = Colors.amber;
        bgColor = Colors.amber.withOpacity(0.1);
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
        bgColor = Colors.grey.withOpacity(0.1);
    }

    return InkWell(
      onTap: () async {
        // Mark as read
        if (!notification.isRead) {
          FirebaseDataService.instance.markNotificationRead(userId, notification.id);
        }

        // Navigate based on type
        if (notification.type == NotificationType.follow) {
          final followerId = notification.data['followerId'];
          if (followerId != null) {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryOrange),
              ),
            );
            
            try {
              final userModel = await FirebaseDataService.instance.getUserById(followerId);
              
              if (context.mounted) {
                // Hide loading indicator
                Navigator.pop(context);
              }
              
              if (userModel != null && context.mounted) {
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => PlayerProfileScreen(player: userModel),
                   ),
                 );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Player profile no longer available')),
                );
              }
            } catch (e) {
              if (context.mounted) Navigator.pop(context);
            }
          }
        } else if (notification.type == NotificationType.matchStart || notification.type == NotificationType.achievement) {
           final matchId = notification.data['matchId'] ?? notification.data['match_id'];
           if (matchId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MatchDetailScreen(matchId: matchId),
                ),
              );
           }
        }
      },
      child: Container(
        color: notification.isRead ? Colors.transparent : AppTheme.primaryOrange.withOpacity(0.05),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
              child: Icon(iconData, color: iconColor, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(notification.createdAt),
                        style: TextStyle(
                          color: notification.isRead ? Colors.grey[500] : AppTheme.primaryOrange,
                          fontSize: 12.sp,
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: notification.isRead ? Colors.grey[700] : Colors.black87,
                      fontSize: 14.sp,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Unread Indicator
            if (!notification.isRead)
              Container(
                margin: EdgeInsets.only(left: 8.w, top: 4.h),
                width: 8.w,
                height: 8.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryOrange,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
