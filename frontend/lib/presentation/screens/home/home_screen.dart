import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/screens/matches/match_detail_screen.dart';
import 'package:scorepatner/presentation/widgets/match/match_card.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/utils/location_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../chat/chat_list_screen.dart';
import '../notifications/notifications_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = FirebaseDataService.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: AppTheme.primaryOrange),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.sports_cricket, color: AppTheme.primaryOrange, size: 22.sp),
              ),
              SizedBox(width: 10.w),
              Text(
                'ScorePartner',
                style: GoogleFonts.fredoka(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 20.sp,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // Notifications Bell Icon
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (!auth.isAuthenticated || auth.user == null) {
                return IconButton(
                   icon: Icon(Icons.notifications_outlined, color: AppTheme.primaryOrange),
                   onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                   },
                );
              }
              
              return StreamBuilder<int>(
                stream: dataService.getUnreadNotificationCount(auth.user!.uid),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  
                  return IconButton(
                    icon: Stack(
                      children: [
                        Icon(Icons.notifications_outlined, color: AppTheme.primaryOrange),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0.w,
                            top: 0.h,
                            child: Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                  );
                },
              );
            },
          ),
          
          // Custom Unique "Cricket Chat" Icon
          InkWell(
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              );
            },
            borderRadius: BorderRadius.circular(50.r),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8.w),
              padding: EdgeInsets.all(8.w),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                   Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryOrange, size: 25.sp),
                   Positioned(
                     top: -5,
                     right: -5,
                     child: Container(
                       padding: EdgeInsets.all(2.w),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         shape: BoxShape.circle,
                         border: Border.all(color: Colors.white, width: 1.w),
                         boxShadow: [
                           BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                           )
                         ]
                       ),
                       child: Transform.rotate(
                         angle: -0.2,
                         child: Icon(Icons.sports_cricket, color: AppTheme.primaryOrange, size: 14.sp),
                       ),
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],

      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 100.h),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section
            Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Stay updated with live matches & ScorePartner news',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // Matches Near You Section
            _MatchesNearYouSection(dataService: dataService),

            // Live Matches Section
            _buildSectionHeader(context, 'Live Matches', showViewAll: false),
              SizedBox(
                height: 230.h,
                child: FutureBuilder<List<MatchModel>>(
                  future: dataService.getLiveMatches(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingList();
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyMatchState('NO LIVE MATCHES RIGHT NOW');
                    }
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final match = snapshot.data![index];
                        return MatchCard(
                          match: match,
                          onTap: () => _navigateToMatch(context, match),
                        );
                      },
                    );
                  },
                ),
              ),

              // Past Matches Section  
              _buildSectionHeader(context, 'Past Matches', showViewAll: false),
              SizedBox(
                height: 230.h,
                child: FutureBuilder<List<MatchModel>>(
                  future: dataService.getPastMatches(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingList();
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyMatchState('NO PAST MATCHES');
                    }
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final match = snapshot.data![index];
                        return MatchCard(
                          match: match,
                          onTap: () => _navigateToMatch(context, match),
                        );
                      },
                    );
                  },
                ),
              ),
  
              // ScorePartner News Section
              _buildSectionHeader(context, 'ScorePartner News', showViewAll: false),
              _buildNewsCard(
                context,
                title: "India vs Australia: Day 2 Highlights",
                description: "Kohli scores brilliant century as India takes lead",
                time: "2 hours ago",
                imageIcon: Icons.sports_cricket,
              ),
              _buildNewsCard(
                context,
                title: "IPL 2026 Auction Date Announced",
                description: "Mega auction to be held in December with new rules",
                time: "5 hours ago",
                imageIcon: Icons.event,
              ),
              _buildNewsCard(
                context,
                title: "Rohit Sharma Press Conference",
                description: "Captain discusses team strategy for upcoming series",
                time: "8 hours ago",
                imageIcon: Icons.mic,
              ),
              _buildNewsCard(
                context,
                title: "Young Talent Spotlight: U19 World Cup",
                description: "Rising stars to watch in the upcoming tournament",
                time: "1 day ago",
                imageIcon: Icons.star,
              ),
            ],
          ),
        ),
    );
  }

  /// Build the navigation drawer with menu options
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryOrange.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.sports_cricket,
                    color: Colors.white,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'ScorePartner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'YOUR CRICKET COMPANION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: 8.h),

                Divider(height: 32.h),

                // Settings Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange.withOpacity(0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Theme
                _buildDrawerItem(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  subtitle: 'Light mode',
                  onTap: () {
                    Navigator.pop(context);
                    _showThemeSheet(context);
                  },
                ),

                // Language
                _buildDrawerItem(
                  context,
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {
                    Navigator.pop(context);
                    _showLanguageSheet(context);
                  },
                ),

                Divider(height: 32.h),

                // About & Help
                _buildDrawerItem(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    _showHelpSheet(context);
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'Version 1.0.0',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutSheet(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: AppTheme.primaryOrange, size: 22.sp),
      ),
      title: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 13.sp, 
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, 
          letterSpacing: 0.5
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle.toUpperCase(), style: TextStyle(color: Colors.white24, fontSize: 9.sp, fontWeight: FontWeight.bold))
          : null,
      onTap: onTap,
    );
  }

  void _showThemeSheet(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Theme',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            _buildThemeOption(context, 'Light', Icons.light_mode, themeProvider.themeMode == ThemeMode.light, ThemeMode.light),
            _buildThemeOption(context, 'Dark', Icons.dark_mode, themeProvider.themeMode == ThemeMode.dark, ThemeMode.dark),
            _buildThemeOption(context, 'System', Icons.settings_suggest, themeProvider.themeMode == ThemeMode.system, ThemeMode.system),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, IconData icon, bool isSelected, ThemeMode mode) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryOrange : Colors.grey),
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppTheme.primaryOrange)
          : null,
      onTap: () {
        Provider.of<ThemeProvider>(context, listen: false).setThemeMode(mode);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title theme selected'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final languages = [
      {'name': 'English', 'flag': '🇺🇸'},
      {'name': 'Hindi', 'flag': '🇮🇳'},
      {'name': 'Marathi', 'flag': '🇮🇳'},
      {'name': 'Gujarati', 'flag': '🇮🇳'},
      {'name': 'Bihari', 'flag': '🇮🇳'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            ...languages.map((lang) => ListTile(
              leading: Text(lang['flag']!, style: TextStyle(fontSize: 24.sp)),
              title: Text(lang['name']!),
              trailing: lang['name'] == 'English' ? Icon(Icons.check_circle, color: AppTheme.primaryOrange) : null,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${lang['name']} selected')),
                );
              },
            )),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            _buildHelpItem(Icons.question_answer_outlined, 'FAQs', 'Frequently asked questions'),
            _buildHelpItem(Icons.email_outlined, 'Contact Us', 'support@scorepartner.com'),
            _buildHelpItem(Icons.description_outlined, 'Terms of Service', 'Read our legal terms'),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryOrange),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {},
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sports_cricket, color: AppTheme.primaryOrange, size: 48.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'ScorePartner',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 24.h),
            Text(
              'ScorePartner is your ultimate cricket companion, designed to bring a premium, saga-like experience to every match you play and follow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, height: 1.5),
            ),
            SizedBox(height: 32.h),
            Text(
              '© 2026 ScorePartner. All rights reserved.',
              style: TextStyle(color: Colors.grey, fontSize: 11.sp),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _showCreateTournamentSheet(BuildContext context) {
    String selectedBallType = 'tennis';
    String selectedFormat = 'league';
    bool enableVoiceAnnouncements = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    Text(
                      'Create Tournament',
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField('Tournament Name', 'Enter tournament name', Icons.emoji_events_outlined),
                      SizedBox(height: 16.h),
                      
                      // Ball Type Selection
                      Text('Ball Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBallTypeOption(
                              'Tennis Ball', Icons.sports_tennis, Colors.green,
                              selectedBallType == 'tennis',
                              () => setSheetState(() => selectedBallType = 'tennis'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildBallTypeOption(
                              'Leather Ball', Icons.sports_cricket, Colors.brown,
                              selectedBallType == 'leather',
                              () => setSheetState(() => selectedBallType = 'leather'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      _buildTextField('Location', 'Enter location', Icons.location_on_outlined),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Start Date', 'Select date', Icons.calendar_today_outlined)),
                          SizedBox(width: 16.w),
                          Expanded(child: _buildTextField('Teams', 'No. of teams', Icons.groups_outlined)),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField('Prize Pool', 'Enter prize amount', Icons.monetization_on_outlined),
                      SizedBox(height: 24.h),

                      // Format Selection
                      Text('Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                      SizedBox(height: 12.h),
                      Wrap(
                        spacing: 12,
                        children: [
                          _buildFormatChip('League', selectedFormat == 'league', () {
                            setSheetState(() => selectedFormat = 'league');
                          }),
                          _buildFormatChip('Knockout', selectedFormat == 'knockout', () {
                            setSheetState(() => selectedFormat = 'knockout');
                          }),
                          _buildFormatChip('Group Stage', selectedFormat == 'group', () {
                            setSheetState(() => selectedFormat = 'group');
                          }),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // AI Voice Toggle
                      Container(
                        padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.record_voice_over, color: AppTheme.primaryOrange),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('AI Voice Announcements', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text('4s, 6s, wickets, 50s, 100s', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                                ],
                              ),
                            ),
                            Switch(
                              value: enableVoiceAnnouncements,
                              onChanged: (val) => setSheetState(() => enableVoiceAnnouncements = val),
                              activeColor: AppTheme.primaryOrange,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),

                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tournament created! Ball: ${selectedBallType == 'tennis' ? 'Tennis' : 'Leather'}'),
                                backgroundColor: AppTheme.primaryOrange,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          ),
                          child: Text('Create Tournament', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBallTypeOption(String label, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 32.sp),
            SizedBox(height: 8.h),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? color : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange : Colors.grey[100],
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12.r)),
          child: TextField(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(icon, color: Colors.grey[600], size: 20.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {bool showViewAll = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, letterSpacing: 1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showViewAll) ...[
            SizedBox(width: 10.w),
            TextButton(
              onPressed: () {},
              child: Text('VIEW ALL', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 11.sp, letterSpacing: 0.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMatchState(String message) {
    return Center(
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        child: Container(
          width: 280.w,
          padding: EdgeInsets.symmetric(vertical: 32.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_cricket, size: 48.sp, color: Colors.grey),
            SizedBox(height: 12.h),
              Text(
                message, 
                style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5), 
                textAlign: TextAlign.center
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      itemBuilder: (_, __) => const MatchCard(match: null, onTap: _emptyTap),
    );
  }

  static void _emptyTap() {}

  Widget _buildNewsCard(BuildContext context, {required String title, required String description, required String time, required IconData imageIcon}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 70.w, height: 70.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryOrange.withOpacity(0.2), AppTheme.primaryOrange.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  child: Icon(imageIcon, color: AppTheme.primaryOrange, size: 32.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp), maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 6.h),
                      Text(description, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54, fontSize: 13.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 8.h),
                      Row(children: [
                        Icon(Icons.access_time, size: 14.sp, color: AppTheme.primaryOrange),
                        SizedBox(width: 4.w),
                        Text(time, style: TextStyle(color: AppTheme.primaryOrange, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  /// Get tournament matches for the current player
  Future<List<MatchModel>> _getPlayerTournamentMatches(String userId, String spPId) async {
    final dataService = FirebaseDataService.instance;
    
    // Get user's teams (owned and as player)
    final userTeams = await dataService.getUserTeams(userId);
    final playerTeams = await dataService.getTeamsWhereUserIsPlayer(userId, spPId);
    
    // Combine team IDs
    final allTeamIds = <String>{
      ...userTeams.map((t) => t.id),
      ...playerTeams.map((t) => t.id),
    }.toList();
    
    // Get tournament matches
    return dataService.getPlayerTournamentMatches(userId, allTeamIds);
  }

  /// Navigate to match detail screen
  void _navigateToMatch(BuildContext context, MatchModel match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(matchId: match.id),
      ),
    );
  }



  /// Show Create Match sheet with Cricbuzz-like features
  void _showCreateMatchSheet(BuildContext context) {
    String selectedBallType = 'tennis';
    String selectedOvers = '20';
    String tossWinner = '';
    String tossDecision = 'bat';
    bool enablePowerplay = true;
    bool enableDRS = false;
    bool enableVoice = true;
    bool wideReball = true;
    bool noBallReball = true;

    final oversOptions = ['5', '10', '15', '20', '50', 'Test'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              
              // Header
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.sports_cricket, color: AppTheme.primaryOrange),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Match', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                          Text('Start scoring live', style: TextStyle(color: Colors.grey, fontSize: 13.sp)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teams Section with SPT ID Lookup
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Team A with SPT ID
                            Text('Team A', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Enter SPT ID (e.g., SPT12345678)',
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
                                        prefixIcon: Container(
                                          margin: EdgeInsets.all(8.w),
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(Icons.shield_outlined, color: Colors.blue, size: 18.sp),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      // TODO: Lookup team by SPT ID
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Looking up team...')),
                                      );
                                    },
                                    icon: Icon(Icons.search, color: Colors.white),
                                    tooltip: 'Lookup Team',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text('Or enter team name manually:', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                            SizedBox(height: 8.h),
                            _buildMatchTeamInput('Team A Name', Icons.groups, Colors.blue),
                            
                            SizedBox(height: 20.h),
                            
                            // VS Badge
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            
                            SizedBox(height: 20.h),
                            
                            // Team B with SPT ID
                            Text('Team B', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Enter SPT ID (e.g., SPT12345678)',
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
                                        prefixIcon: Container(
                                          margin: EdgeInsets.all(8.w),
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(Icons.shield_outlined, color: Colors.red, size: 18.sp),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      // TODO: Lookup team by SPT ID
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Looking up team...')),
                                      );
                                    },
                                    icon: Icon(Icons.search, color: Colors.white),
                                    tooltip: 'Lookup Team',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text('Or enter team name manually:', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                            SizedBox(height: 8.h),
                            _buildMatchTeamInput('Team B Name', Icons.groups, Colors.red),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Ball Type
                      Text('Ball Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBallTypeOption(
                              'Tennis Ball', Icons.sports_tennis, Colors.green,
                              selectedBallType == 'tennis',
                              () => setSheetState(() => selectedBallType = 'tennis'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildBallTypeOption(
                              'Leather Ball', Icons.sports_cricket, Colors.brown,
                              selectedBallType == 'leather',
                              () => setSheetState(() => selectedBallType = 'leather'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      // Overs Selection
                      Text('Overs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                      SizedBox(height: 12.h),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: oversOptions.map((overs) {
                          bool isSelected = selectedOvers == overs;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedOvers = overs),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryOrange : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryOrange : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                overs == 'Test' ? 'Test' : '$overs Overs',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 20.h),

                      // Ground & Location
                      _buildTextField('Ground / Venue', 'Enter ground name', Icons.stadium_outlined),
                      SizedBox(height: 16.h),
                      _buildTextField('City / Location', 'Enter city', Icons.location_on_outlined),
                      SizedBox(height: 20.h),

                      // Toss Section
                      Text('Toss Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTossOption('Team A', tossWinner == 'Team A', () {
                                    setSheetState(() => tossWinner = 'Team A');
                                  }),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _buildTossOption('Team B', tossWinner == 'Team B', () {
                                    setSheetState(() => tossWinner = 'Team B');
                                  }),
                                ),
                              ],
                            ),
                            if (tossWinner.isNotEmpty) ...[
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTossDecision('Bat First', Icons.sports_cricket, tossDecision == 'bat', () {
                                      setSheetState(() => tossDecision = 'bat');
                                    }),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: _buildTossDecision('Bowl First', Icons.sports_baseball, tossDecision == 'bowl', () {
                                      setSheetState(() => tossDecision = 'bowl');
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Match Features
                      Text('Match Features', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp)),
                      SizedBox(height: 12.h),
                      _buildMatchFeatureToggle('Powerplay Overs', 'First 6 overs restriction', Icons.flash_on, enablePowerplay, (val) {
                        setSheetState(() => enablePowerplay = val);
                      }),
                      _buildMatchFeatureToggle('DRS (Review)', 'Decision Review System', Icons.slow_motion_video, enableDRS, (val) {
                        setSheetState(() => enableDRS = val);
                      }),
                      _buildMatchFeatureToggle('Wide = Re-ball', 'Wide counted as extra + re-ball', Icons.compare_arrows, wideReball, (val) {
                        setSheetState(() => wideReball = val);
                      }),
                      _buildMatchFeatureToggle('No Ball = Re-ball', 'No ball gives free hit', Icons.sports_handball, noBallReball, (val) {
                        setSheetState(() => noBallReball = val);
                      }),
                      _buildMatchFeatureToggle('AI Voice Commentary', 'Announcements for 4s, 6s, wickets', Icons.record_voice_over, enableVoice, (val) {
                        setSheetState(() => enableVoice = val);
                      }),
                      SizedBox(height: 24.h),

                      // Start Match Button
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Match created! ${selectedOvers == 'Test' ? 'Test Match' : '$selectedOvers Overs'} - ${selectedBallType == 'tennis' ? 'Tennis Ball' : 'Leather Ball'}'),
                                backgroundColor: AppTheme.primaryOrange,
                              ),
                            );
                          },
                          icon: Icon(Icons.play_arrow, color: Colors.white),
                          label: Text('Start Match', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchTeamInput(String label, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Container(
            margin: EdgeInsets.all(8.w),
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
      ),
    );
  }

  Widget _buildTossOption(String team, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: isSelected ? AppTheme.primaryOrange : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            team,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTossDecision(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: isSelected ? AppTheme.primaryOrange : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: isSelected ? AppTheme.primaryOrange : Colors.grey[600]),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryOrange : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchFeatureToggle(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: value ? AppTheme.primaryOrange.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: value ? Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: value ? AppTheme.primaryOrange.withOpacity(0.1) : Colors.grey[200],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 18.sp, color: value ? AppTheme.primaryOrange : Colors.grey[600]),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, color: value ? Colors.black87 : Colors.grey[700])),
                Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryOrange,
          ),
        ],
      ),
    );
  }
}

class _MatchesNearYouSection extends StatelessWidget {
  final FirebaseDataService dataService;

  const _MatchesNearYouSection({required this.dataService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position?>(
      future: LocationUtils.getCurrentLocation(),
      builder: (context, locationSnapshot) {
        if (locationSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Hide while loading location initially
        }
        
        final position = locationSnapshot.data;
        if (position == null) {
          return const SizedBox.shrink(); // Hide if location is not available
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Matches Near You',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 230.h,
              child: FutureBuilder<List<MatchModel>>(
                future: dataService.getMatchesNearMe(position.latitude, position.longitude),
                builder: (context, matchSnapshot) {
                  if (matchSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryOrange),
                    );
                  }
                  if (!matchSnapshot.hasData || matchSnapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'NO MATCHES NEAR YOU',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    scrollDirection: Axis.horizontal,
                    itemCount: matchSnapshot.data!.length,
                    itemBuilder: (context, index) {
                      final match = matchSnapshot.data![index];
                      return MatchCard(
                        match: match,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MatchDetailScreen(matchId: match.id),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
