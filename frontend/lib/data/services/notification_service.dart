import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'firebase_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/screens/profile/player_profile_screen.dart';
import '../../presentation/screens/matches/match_detail_screen.dart';
import '../../presentation/screens/teams/join_requests_screen.dart';
import '../../presentation/screens/teams/team_details_screen.dart';
import '../models/team_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  String? _currentUserUid;

  /// Initialize Firebase Messaging
  Future<void> init(BuildContext context) async {
    if (_initialized) return;

    // Request permissions for iOS and Web
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted push permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('✅ User granted provisional push permission');
    } else {
      debugPrint('❌ User declined or has not accepted push permission');
    }

    // Configure foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        
        // Show local snackbar for foreground notification
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(message.notification!.title ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(message.notification!.body ?? ''),
                ],
              ),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                   _handleNotificationTap(context, message);
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    // Handle when app is opened via a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _handleNotificationTap(context, message);
    });
    
    // Check if app was opened from terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (context.mounted) {
            _handleNotificationTap(context, initialMessage);
         }
       });
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
       if (_currentUserUid != null) {
          _saveTokenToFirestore(_currentUserUid!, newToken);
       }
    });

    _initialized = true;
  }

  /// Called when user logs in to attach their FCM token to their account
  Future<void> setupForUser(String uid) async {
    _currentUserUid = uid;
    
    try {
      // Check permissions first to avoid the permission-blocked exception
      NotificationSettings settings = await _fcm.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized || 
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Only fetch token if permission is granted
        String? token = await _fcm.getToken();
        
        if (token != null) {
          debugPrint('FCM Token: $token');
          await _saveTokenToFirestore(uid, token);
        }
      } else {
        debugPrint('Push notifications are not authorized by the user. Skipping token sync.');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Clean up token when user logs out
  Future<void> clearUser() async {
    if (_currentUserUid != null) {
       try {
         String? token = await _fcm.getToken();
         if (token != null) {
            await FirebaseDataService.instance.removeFCMToken(_currentUserUid!, token);
         }
       } catch (e) {
         debugPrint('Error removing token on logout: $e');
       }
    }
    _currentUserUid = null;
  }

  Future<void> _saveTokenToFirestore(String uid, String token) async {
    await FirebaseDataService.instance.saveFCMToken(uid, token);
  }

  void _handleNotificationTap(BuildContext context, RemoteMessage message) async {
     final data = message.data;
     
     if (data['type'] == 'matchStart' || data['type'] == 'achievement') {
        final matchId = data['matchId'] ?? data['match_id'];
        if (matchId != null) {
           Navigator.push(
             context,
             MaterialPageRoute(
               builder: (context) => MatchDetailScreen(matchId: matchId),
             ),
           );
        }
     } else if (data['type'] == 'follow') {
        final followerId = data['followerId'];
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
              Navigator.pop(context); // Hide loading indicator
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
      } else if (data['type'] == 'teamJoinRequest') {
        // Admin taps on a join request notification → go to join requests screen
        final teamId = data['teamId'];
        if (teamId != null && context.mounted) {
          try {
            final team = await FirebaseDataService.instance.getTeamById(teamId);
            if (team != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JoinRequestsScreen(
                    teamId: team.id,
                    teamName: team.name,
                  ),
                ),
              );
            }
          } catch (_) {}
        }
      } else if (data['type'] == 'teamJoinAccepted' || data['type'] == 'teamJoinRejected') {
        // Player taps on accepted/rejected notification → go to team details
        final teamId = data['teamId'];
        if (teamId != null && context.mounted) {
          try {
            final team = await FirebaseDataService.instance.getTeamById(teamId);
            if (team != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamDetailsScreen(team: team),
                ),
              );
            }
          } catch (_) {}
        }
      }
   }
}
