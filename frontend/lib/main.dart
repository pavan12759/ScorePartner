import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/main/main_navigation.dart';
import 'data/services/notification_service.dart';
import 'data/services/firebase_data_service.dart';
import 'presentation/screens/tournament/tournament_details_screen.dart';
import 'presentation/screens/matches/match_detail_screen.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/floating_bubble_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/teams/team_invitation_screen.dart';
import 'presentation/screens/tournament/tournament_invitation_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
  }
  
  runApp(const ScorePartnerApp());
}

class ScorePartnerApp extends StatefulWidget {
  const ScorePartnerApp({super.key});

  @override
  State<ScorePartnerApp> createState() => _ScorePartnerAppState();
}

class _ScorePartnerAppState extends State<ScorePartnerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    await NotificationService().init(context);
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link if app was cold started from a link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial deep link: $e');
    }

    // Attach a listener to listen for foreground links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep link stream error: $err');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Received deep link: $uri');
    final pathSegments = uri.pathSegments;

    // Check if link matches: scorepartner.in/tournament/<tournamentId>
    if (pathSegments.length >= 2 && pathSegments[0] == 'tournament') {
      final tournamentId = pathSegments[1];
      debugPrint('Navigating to tournament ID: $tournamentId');
      
      // We need to wait for Auth initialization before redirecting
      // The push approach relies on the navigatorKey
      
      try {
        final tournament = await FirebaseDataService.instance.getTournamentById(tournamentId);
        if (tournament != null && mounted) {
          // Add a small delay for navigator to be ready if it's app launch
          await Future.delayed(const Duration(milliseconds: 500));
          
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => TournamentDetailsScreen(tournament: tournament),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error handling deep link tournament fetch: $e');
      }
    } else if (pathSegments.length >= 2 && pathSegments[0] == 'match') {
      final matchId = pathSegments[1];
      debugPrint('Navigating to match ID: $matchId');
      
      try {
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: matchId),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error handling deep link match route: $e');
      }
    } else if (pathSegments.length >= 3 && pathSegments[0] == 'join' && pathSegments[1] == 'team') {
      // Team invite link: scorepartner.in/join/team/{teamId}?invite={token}
      final teamId = pathSegments[2];
      final inviteToken = uri.queryParameters['invite'] ?? '';
      debugPrint('Navigating to team invitation: teamId=$teamId, token=$inviteToken');

      if (inviteToken.isNotEmpty) {
        try {
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 500));

            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => TeamInvitationScreen(
                  teamId: teamId,
                  inviteToken: inviteToken,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error handling team invite deep link: $e');
        }
      }
    } else if (pathSegments.length >= 3 && pathSegments[0] == 'join' && pathSegments[1] == 'tournament') {
      // Tournament invite link: scorepartner.in/join/tournament/{tournamentId}?invite={token}
      final tournamentId = pathSegments[2];
      final inviteToken = uri.queryParameters['invite'] ?? '';
      debugPrint('Navigating to tournament invitation: tournamentId=$tournamentId, token=$inviteToken');

      if (inviteToken.isNotEmpty) {
        try {
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 500));

            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => TournamentInvitationScreen(
                  tournamentId: tournamentId,
                  inviteToken: inviteToken,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error handling tournament invite deep link: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If it's a wide screen (like desktop web), we set designSize to the actual 
        // window size so that 1.w == 1 pixel, preventing everything from becoming massive.
        final isDesktopWide = constraints.maxWidth > 600;
        final designSize = isDesktopWide 
            ? Size(constraints.maxWidth, constraints.maxHeight) 
            : const Size(390, 844);

        return ScreenUtilInit(
          designSize: designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => FloatingBubbleProvider()),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                navigatorKey: _navigatorKey,
                title: 'ScorePartner',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                builder: (context, widget) {
                  ErrorWidget.builder = (FlutterErrorDetails details) {
                    // Log technical details for debugging
                    debugPrint('ErrorWidget: ${details.exception}');
                    debugPrint('Stack: ${details.stack}');

                    return Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 64,
                                  color: const Color(0xFFFF8D48),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Something went wrong',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please restart the app. If the problem persists, contact support.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  };

                  return MediaQuery.withClampedTextScaling(
                    minScaleFactor: 1.0,
                    maxScaleFactor: 2.0,
                    child: widget ?? const SizedBox.shrink(),
                  );
                },
                home: SplashScreen(
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      // Show loading while auth is initializing
                      if (!auth.isAuthInitialized) {
                        return const Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF8D48),
                            ),
                          ),
                        );
                      }

                      // Always show MainNavigation so Home, Search, and Matches
                      // are accessible without login. Profile tab will show
                      // LoginScreen for unauthenticated users.
                      return const MainNavigation();
                    },
                  ),
                ),
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        );
      },
    );
      },
    );
  }
}

