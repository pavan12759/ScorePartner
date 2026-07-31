import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../widgets/navigation/floating_bottom_nav_bar.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import 'my_matches_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/login_screen.dart';


/// Main navigation wrapper that provides a floating bottom navigation bar
/// and handles screen switching between the main app sections.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    WidgetsBinding.instance.addObserver(this);
    _setUserPresence(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserPresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setUserPresence(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setUserPresence(false);
    }
  }

  void _setUserPresence(bool isOnline) {
    final user = _authProvider.user;
    if (user != null) {
      FirebaseDataService.instance.updateUserPresence(user.uid, isOnline);
    }
  }

  // Define the screens for each navigation item (4 tabs)
  // Profile tab shows LoginScreen if not authenticated
  List<Widget> _screens(bool isAuthenticated) => [
    HomeScreen(),
    SearchScreen(),
    MyMatchesScreen(),
    isAuthenticated ? ProfileScreen() : const LoginScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    final screens = _screens(isAuthenticated);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: IndexedStack(
          key: ValueKey('$_currentIndex-$isAuthenticated'),
          index: _currentIndex, 
          children: screens,
        ),
      ),

      // Floating bottom navigation bar - 4 items
      bottomNavigationBar: FloatingBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        horizontalMargin: 50,
        bottomMargin: 20,
        items: const [
          // Home
          FloatingNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
          ),
          // Search
          FloatingNavItem(
            icon: Icons.search_outlined,
            activeIcon: Icons.search,
            label: 'Search',
          ),
          // Matches
          FloatingNavItem(
            icon: Icons.emoji_events_outlined,
            activeIcon: Icons.emoji_events,
            label: 'My Cricket',
          ),
          // Profile
          FloatingNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
