import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../recalculate_user_stats_script.dart';
import 'followers_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import '../../../data/models/user_model.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../widgets/genz_badge_widget.dart';
import '../../widgets/highlight_badge_widgets.dart';
import '../../widgets/rank_badge.dart';
import '../../providers/auth_provider.dart';
import '../settings/help_support_screen.dart';
import '../settings/about_screen.dart';
import '../../../recalculate_user_stats_script.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';
import '../auth/user_onboarding_screen.dart';
import '../teams/my_teams_screen.dart';
import '../main/my_matches_screen.dart';
import '../matches/manage_matches_screen.dart';
import '../tournament/my_tournaments_screen.dart';
import '../matches/create_match_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../widgets/achievement_share_card.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../data/services/storage_service.dart';



/// Profile screen that shows LoginScreen when not authenticated,
/// UserOnboardingScreen for first-time users, and full profile with stats.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Edit Profile Controllers
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _instagramController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;

  // Edit Profile State
  String _selectedRole = 'Batsman';
  String _selectedBattingStyle = 'Right-hand';
  String _selectedBowlingStyle = 'Medium';
  bool _isUpdating = false;

  int _followerCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _instagramController = TextEditingController();
    _ageController = TextEditingController();
    _bioController = TextEditingController();
    
    // Load initial follow counts if user is already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowData();
    });
  }

  Future<void> _loadFollowData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      final followers = await FirebaseDataService.instance.getFollowerCount(user.uid);
      final following = await FirebaseDataService.instance.getFollowingCount(user.uid);
      if (mounted) {
        setState(() {
          _followerCount = followers;
          _followingCount = following;
        });
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      return _buildGuestView(context);
    }

    if (authProvider.isFirstTimeUser) {
      return const UserOnboardingScreen();
    }

    final initialUser = authProvider.user;

    if (initialUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<UserModel?>(
      stream: FirebaseDataService.instance.streamUser(initialUser.uid),
      initialData: initialUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? initialUser;
        
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          endDrawer: _buildProfileDrawer(context),
          body: CustomScrollView(
            slivers: [
              // Profile Header
              SliverToBoxAdapter(child: _buildProfileHeader(context, user)),
              
              // Quick Stats Row
              SliverToBoxAdapter(child: _buildQuickStats(user)),
              
              // Floating Tabbed Section
              SliverToBoxAdapter(child: _buildFloatingTabSection(context, user)),
              
              // Bottom padding
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar with Settings
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: Colors.black),
                    onPressed: () => _showSettingsSheet(context),
                  ),
                  Text(
                    user.name.isNotEmpty ? user.name : 'Player',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.menu, color: Colors.black),
                        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                    ],
                  ),
                ],

              ),
            ),

            // Profile Row - Instagram Style
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side - Profile Picture
                  GestureDetector(
                    onTap: () => _showPhotoOptions(context, user),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.grey[100],
                          child: user.profileImageUrl.isNotEmpty
                              ? ClipOval(
                                  child: _buildProfileImage(user.profileImageUrl, 96),
                                )
                              : Icon(Icons.person, size: 50.sp, color: Colors.grey.withOpacity(0.5)),
                        ),
                        // Add photo button
                        Positioned(
                          bottom: 0.h,
                          right: 0.w,
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: AppTheme.stadiumOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2.w),
                            ),
                            child: Icon(Icons.add, size: 14.sp, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: 16.w),
                  
                  // Right Side - Player Card Info (Unique Design)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Player Name & Verified
                        Row(
                          children: [
                            Flexible(
                                child: Text(
                                user.name.isNotEmpty ? user.name : 'Player',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isVerified) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: AppTheme.stadiumOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check, size: 10.sp, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                        
                        SizedBox(height: 4.h),
                        
                        // Player Role & Style Tag
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.stadiumOrange, Color(0xFFB34200)],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                user.role.isNotEmpty ? user.role.toUpperCase() : 'BATSMAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sports_cricket, size: 12.sp, color: Colors.grey[700]),
                                  SizedBox(width: 4.w),
                                    Text(
                                      user.battingStyle.isNotEmpty ? user.battingStyle : 'RHB',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 10.h),
                        
                        // Player Rating & Form (Like FIFA Card)
                        Row(
                          children: [
                            // Player Rating
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1A1A2E),
                                    const Color(0xFF16213E),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 14.sp, color: Color(0xFFFFD700)),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${_calculatePlayerRating(user)}',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(width: 8.w),
                            
                            // Form Indicator
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: _getFormColor(user).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: _getFormColor(user).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getFormIcon(user), size: 14.sp, color: _getFormColor(user)),
                                  SizedBox(width: 4.w),
                                  Text(
                                    _getFormText(user),
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _getFormColor(user),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 8.h),
                        
                        // Warrior Rank Badge
                        RankBadge(
                          stars: user.stars, 
                          unlockedTitles: user.unlockedTitles,
                          compact: true,
                        ),
                        
                        SizedBox(height: 12.h),
                        
                        // Edit Profile & Share
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showEditProfileSheet(context, user),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 8.h),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppTheme.stadiumOrange, Color(0xFFB34200)],
                                    ),
                                    borderRadius: BorderRadius.circular(8.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.stadiumOrange.withOpacity(0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'EDIT PROFILE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11.sp,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Icon(Icons.share, size: 16.sp, color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Followers Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _buildFollowerItem(_followerCount.toString(), 'FOLLOWERS', onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => FollowersListScreen(
                           userId: user.uid ?? '',
                           userName: user.name ?? 'Player',
                           isFollowing: false,
                         ),
                       ),
                     );
                   }),
                   Container(width: 1.w, height: 35.h, color: Colors.grey[300]),
                   _buildFollowerItem(_followingCount.toString(), 'FOLLOWING', onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => FollowersListScreen(
                           userId: user.uid ?? '',
                           userName: user.name ?? 'Player',
                           isFollowing: true,
                         ),
                       ),
                     );
                   }),
                   Container(width: 1.w, height: 35.h, color: Colors.grey[300]),
                   _buildFollowerItem(((user.tennisBallStats.matches * 0.3).round()).toString(), 'TEAMS'),
                 ],
              ),
            ),

            // Bio, Social Links & Highlights Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: Offset(0, 2))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Passion/Location tags
                  Row(
                    children: [
                      Icon(Icons.sports_cricket, size: 14.sp, color: Colors.grey[600]),
                      SizedBox(width: 4.w),
                      Text(
                        'PASSIONATE ${user.role.isNotEmpty ? user.role.toUpperCase() : "CRICKETER"} | ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Icon(Icons.location_on, size: 14.sp, color: Colors.grey[600]),
                      SizedBox(width: 2.w),
                      Text(
                        '${user.location.isNotEmpty ? user.location.toUpperCase() : "INDIA"}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  
                  if (user.bio.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    // User Bio Text (Instagram Style)
                    Text(
                      user.bio,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13.sp,
                        height: 1.4,
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 12.h),
                  
                  // Divider
                  Divider(color: Colors.grey[200], height: 1.h),
                  
                  SizedBox(height: 12.h),
                  
                  // Social Links Row
                  Row(
                    children: [
                      // Instagram
                      Expanded(
                        child: _buildSocialLinkItem(
                          icon: Icons.camera_alt,
                          color: Colors.pink,
                          label: 'INSTAGRAM',
                          value: (user.instagramUrl.isNotEmpty) ? user.instagramUrl : '@${user.name.isNotEmpty ? user.name.toLowerCase().replaceAll(' ', '_') : "player"}',
                          onTap: () => _openInstagram(user.instagramUrl.isNotEmpty ? user.instagramUrl : user.name.toLowerCase().replaceAll(' ', '_')),
                        ),
                      ),
                      Container(width: 1.w, height: 30.h, color: Colors.grey[300]),
                      // Cricket ID
                      Expanded(
                        child: _buildSocialLinkItem(
                          icon: Icons.sports_cricket,
                          color: AppTheme.stadiumOrange,
                          label: 'SCOREPARTNER ID',
                          value: (user.spPId.isNotEmpty) ? user.spPId : 'SPP${user.uid.length >= 8 ? user.uid.substring(0, 8).toUpperCase() : user.uid.toUpperCase()}',
                        ),
                      ),
                    ],
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRewardItem(String title, IconData icon, Color bg) {
    return Padding(
      padding: EdgeInsets.only(right: 16.w),
      child: Column(
        children: [
          Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!, width: 1.5.w),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg.withOpacity(0.15),
                  ),
                  child: Icon(icon, size: 28.sp, color: bg),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Icon(icon, size: 18.sp, color: color),
    );
  }

  Widget _buildFollowerItem(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinkItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: onTap != null ? color : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Open Instagram profile
  Future<void> _openInstagram(String username) async {
    // Remove @ symbol if present
    final cleanUsername = username.replaceAll('@', '');
    
    // Try to open Instagram app first, fallback to web
    final Uri instagramAppUri = Uri.parse('instagram://user?username=$cleanUsername');
    final Uri instagramWebUri = Uri.parse('https://www.instagram.com/$cleanUsername');
    
    try {
      // Try Instagram app first
      if (await canLaunchUrl(instagramAppUri)) {
        await launchUrl(instagramAppUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web browser
        await launchUrl(instagramWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // If all fails, open in browser
      await launchUrl(instagramWebUri, mode: LaunchMode.externalApplication);
    }
  }

  // Calculate player rating like FIFA (0-99 scale)
  int _calculatePlayerRating(UserModel user) {
    final stats = user.tennisBallStats;
    int rating = 50; // Base rating
    
    // Add points based on matches played
    rating += (stats.matches * 0.5).clamp(0, 15).toInt();
    
    // Add points based on runs
    rating += (stats.runs * 0.02).clamp(0, 15).toInt();
    
    // Add points based on wickets
    rating += (stats.wickets * 0.3).clamp(0, 10).toInt();
    
    // Add points for strike rate
    if (stats.strikeRate > 100) rating += 5;
    if (stats.strikeRate > 150) rating += 5;
    
    // Cap at 99
    return rating.clamp(50, 99);
  }

  // Get form color based on recent performance
  Color _getFormColor(UserModel user) {
    final stats = user.tennisBallStats;
    if (stats.strikeRate > 120 || stats.manOfMatches > 2) {
      return const Color(0xFF2ECC71); // Hot form - Green
    } else if (stats.strikeRate > 80) {
      return const Color(0xFFFF6B35); // Good form - Orange
    } else {
      return const Color(0xFF95A5A6); // Average - Grey
    }
  }

  // Get form icon
  IconData _getFormIcon(UserModel user) {
    final stats = user.tennisBallStats;
    if (stats.strikeRate > 120 || stats.manOfMatches > 2) {
      return Icons.local_fire_department;
    } else if (stats.strikeRate > 80) {
      return Icons.trending_up;
    } else {
      return Icons.remove;
    }
  }

  // Get form text
  String _getFormText(UserModel user) {
    final stats = user.tennisBallStats;
    if (stats.strikeRate > 120 || stats.manOfMatches > 2) {
      return 'HOT';
    } else if (stats.strikeRate > 80) {
      return 'GOOD';
    } else {
      return 'AVG';
    }
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14.sp),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 12.sp),
        ),
      ],
    );
  }

  void _showPhotoOptions(BuildContext context, UserModel user) {
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
            Text('Profile Photo', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(Icons.camera_alt, 'Camera', Colors.blue, () => _pickAndUploadImage(context, user, ImageSource.camera)),
                _buildPhotoOption(Icons.photo_library, 'Gallery', Colors.green, () => _pickAndUploadImage(context, user, ImageSource.gallery)),
                _buildPhotoOption(Icons.delete, 'Remove', Colors.red, () {
                  Navigator.pop(context);
                  _deleteProfilePhoto(user);
                }),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28.sp),
          ),
          SizedBox(height: 8.h),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Build profile drawer with Tournaments, Matches, Teams
  Widget _buildProfileDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryOrange,
                    AppTheme.primaryOrange.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sports_cricket, color: Colors.white, size: 40.sp),
                  SizedBox(height: 12.h),
                  Text(
                    'ScorePartner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage your content',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8.h),
            
            // Drawer Items
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.emoji_events, color: Color(0xFFFF6B35)),
              ),
              title: const Text('Tournaments', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('View & create tournaments'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTournamentsScreen()));
              },
            ),
            
            const Divider(indent: 72, endIndent: 16),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.sports_cricket, color: AppTheme.primaryOrange),
              ),
              title: const Text('Matches', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('View & enter scores'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageMatchesScreen()));
              },
            ),
            


            const Divider(indent: 72, endIndent: 16),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.groups, color: Color(0xFF3B82F6)),
              ),
              title: const Text('Teams', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Manage your teams'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamsScreen()));
              },
            ),
            
            const Spacer(),
            
            // Footer
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'ScorePartner v1.0',
                style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              
              _buildSettingsItem(Icons.help_outline, 'Help & Support', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
              }),
              _buildSettingsItem(Icons.info_outline, 'About', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
              }),
              _buildSettingsItem(Icons.sync, 'Recalculate All Stars (Fix)', () {
                Navigator.pop(context);
                final u = Provider.of<AuthProvider>(context, listen: false).user;
                if (u != null) {
                   runUserStatsRecalculationScript(context, u.uid);
                }
              }),
              
              Divider(height: 24.h),
              
              _buildSettingsItem(Icons.logout, 'Logout', () {
                Navigator.pop(context);
                _showLogoutDialog(context);
              }, isDestructive: true),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey[700]),
        title: Text(label, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, UserModel user) {
    // Initialize controllers with current user data
    _nameController.text = user.name;
    _locationController.text = user.location;
    _instagramController.text = user.instagramUrl;
    _bioController.text = user.bio;
    _ageController.text = user.age.toString();
    _selectedRole = user.role.isNotEmpty ? user.role : 'Batsman';
    _selectedBattingStyle = user.battingStyle.isNotEmpty ? user.battingStyle : 'Right-hand';
    _selectedBowlingStyle = user.bowlingStyle.isNotEmpty ? user.bowlingStyle : 'Medium';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Edit Profile', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        // Profile photo
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              child: Icon(Icons.person, size: 50.sp, color: Colors.grey[400]),
                            ),
                            Positioned(
                              bottom: 0.h,
                              right: 0.w,
                              child: GestureDetector(
                                onTap: () => _showPhotoOptions(context, user),
                                child: Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFF6B35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.camera_alt, size: 16.sp, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                        _buildEditField('Full Name', _nameController, Icons.person_outline),
                        _buildEditField('Location', _locationController, Icons.location_on_outlined),
                        _buildEditField('Age', _ageController, Icons.calendar_today, isNumeric: true),
                        _buildEditField('Instagram ID', _instagramController, Icons.camera_alt),
                        _buildEditField('Bio (150 chars max)', _bioController, Icons.description, maxLines: 3, maxLength: 150),
                        
                        _buildEditDropdown('Playing Role', _selectedRole, ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'], (val) {
                          setModalState(() => _selectedRole = val!);
                        }),
                        
                        _buildEditDropdown('Batting Style', _selectedBattingStyle, ['Right-hand', 'Left-hand'], (val) {
                          setModalState(() => _selectedBattingStyle = val!);
                        }),
                        
                        _buildEditDropdown('Bowling Style', _selectedBowlingStyle, ['Fast', 'Medium', 'Spin', 'None'], (val) {
                          setModalState(() => _selectedBowlingStyle = val!);
                        }),

                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: ElevatedButton(
                            onPressed: () => _saveProfile(context, user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            ),
                            child: _isUpdating 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text('Save Changes', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false, int maxLines = 1, int? maxLength}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2.w)),
        ),
      ),
    );
  }

  Widget _buildEditDropdown(String label, String value, List<String> options, Function(String?) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : options.first,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context, UserModel user) async {
    setState(() => _isUpdating = true);
    
    try {
      final updatedUser = user.copyWith(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        instagramUrl: _instagramController.text.trim(),
        bio: _bioController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        role: _selectedRole,
        battingStyle: _selectedBattingStyle,
        bowlingStyle: _selectedBowlingStyle,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateUserProfile(updatedUser);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }


  Future<void> _deleteProfilePhoto(UserModel user) async {
    try {
      final updatedUser = user.copyWith(profileImageUrl: '');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateUserProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildProfileImage(String url, double size) {
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
      } catch (_) {
        return Icon(Icons.person, size: size * 0.5, color: Colors.grey);
      }
    }
    return Image.network(
      '$url?t=${DateTime.now().millisecondsSinceEpoch}',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(Icons.person, size: size * 0.5, color: Colors.grey),
    );
  }

  Future<void> _pickAndUploadImage(BuildContext sheetContext, UserModel user, ImageSource source) async {
    // Close bottom sheet if open using the sheet's context
    Navigator.pop(sheetContext);
    
    final storageService = StorageService.instance;
    
    try {
      debugPrint('📸 Picking image from source: $source');
      final file = await storageService.pickImage(source);
      
      if (file != null) {
        // Crop the image before uploading
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Profile Photo',
              toolbarColor: AppTheme.primaryOrange,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Adjust Profile Photo',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              aspectRatioPickerButtonHidden: true,
            ),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
            ),
          ],
        );

        if (croppedFile == null) {
          debugPrint('⚠️ Image cropping cancelled');
          return;
        }

        final fileToUpload = XFile(croppedFile.path);

        debugPrint('📸 Image picked and cropped: ${fileToUpload.name} (${await fileToUpload.length()} bytes)');
        // Show loading using the Screen's context (this.context)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...'), duration: Duration(seconds: 2)),
        );
        
        debugPrint('🚀 Starting upload for user: ${user.uid}');
        final imageUrl = await storageService.uploadProfileImage(user.uid, fileToUpload);
        debugPrint('✅ Upload complete. URL: $imageUrl');
        
        if (imageUrl != null) {
          final updatedUser = user.copyWith(profileImageUrl: imageUrl);
          // Use this.context or simply context (which refers to state's context when not shadowed)
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          debugPrint('💾 Updating user profile in provider...');
          await authProvider.updateUserProfile(updatedUser);
          debugPrint('✨ ID token sync and profile update finished.');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.green),
            );
          }
        } else {
          debugPrint('❌ Upload returned null URL');
        }
      } else {
        debugPrint('⚠️ No image selected');
      }
    } catch (e, stack) {
      debugPrint('❌ Error in _pickAndUploadImage: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildQuickStats(UserModel user) {
    final stats = user.tennisBallStats;
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem('${stats.matches}', 'Matches', Icons.sports_cricket),
          _buildDivider(),
          _buildQuickStatItem('${stats.runs}', 'Runs', Icons.trending_up),
          _buildDivider(),
          _buildQuickStatItem('${stats.wickets}', 'Wickets', Icons.sports_baseball),
          _buildDivider(),
          _buildQuickStatItem('${stats.manOfMatches}', 'MOM', Icons.emoji_events),
        ],
      ),
    );
  }

  /// Build action cards for Tournaments, Matches, Teams
  Widget _buildActionCards(BuildContext context, UserModel user) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.emoji_events,
                  title: 'Tournaments',
                  subtitle: 'View & Create',
                  color: const Color(0xFFFF6B35),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTournamentsScreen()),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.sports_cricket,
                  title: 'Matches',
                  subtitle: 'View & Score',
                  color: AppTheme.primaryOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyMatchesScreen()),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.groups,
                  title: 'Teams',
                  subtitle: 'Manage',
                  color: const Color(0xFF3B82F6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTeamsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryOrange, size: 20.sp),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40.h,
      width: 1.w,
      color: Colors.grey[200],
    );
  }

  Widget _buildDetailedStats(BuildContext context, UserModel user) {
    return DefaultTabController(
      length: 2,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: TabBar(
                labelColor: AppTheme.primaryOrange,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryOrange,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.sports_baseball), text: 'Tennis Ball'),
                  Tab(icon: Icon(Icons.sports_cricket), text: 'Leather Ball'),
                ],
              ),
            ),

            // Tab Content
            SizedBox(
              height: 700.h,
              child: TabBarView(
                children: [
                  _buildFullStats(user.tennisBallStats),
                  _buildFullStats(user.leatherBallStats),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullStats(PlayerStats stats) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batting Stats
          _buildStatsCategory('Batting Stats', Icons.sports_cricket, [
            _buildStatRow('Matches', '${stats.matches}'),
            _buildStatRow('Innings', '${stats.matches}'),
            _buildStatRow('Runs', '${stats.runs}'),
            _buildStatRow('Balls Faced', '${stats.balls}'),
            _buildStatRow('Highest Score', '${stats.bestScore}*'),
            _buildStatRow('Average', stats.matches > 0 ? '${(stats.runs / stats.matches).toStringAsFixed(1)}' : '-'),
            _buildStatRow('Strike Rate', '${stats.strikeRate.toStringAsFixed(1)}'),
            _buildStatRow('50s', '${stats.fifties}'),
            _buildStatRow('100s', '${stats.hundreds}'),
            _buildStatRow('4s', '${stats.fours}', highlight: true),
            _buildStatRow('6s', '${stats.sixes}', highlight: true),
            _buildStatRow('Ducks', '${stats.ducks}'),
          ]),

          SizedBox(height: 24.h),

          // Bowling Stats
          _buildStatsCategory('Bowling Stats', Icons.sports_baseball, [
            _buildStatRow('Matches', '${stats.matches}'),
            _buildStatRow('Innings', '${stats.matches}'),
            _buildStatRow('Overs', '${stats.ballsBowled ~/ 6}.${stats.ballsBowled % 6}'),
            _buildStatRow('Wickets', '${stats.wickets}'),
            _buildStatRow('Best Bowling', stats.bestBowling),
            _buildStatRow('Economy', '${stats.economy.toStringAsFixed(2)}'),
            _buildStatRow('Runs Conceded', '${stats.runsConceded}'),
            _buildStatRow('Avg', stats.wickets > 0 ? '${(stats.runsConceded / stats.wickets).toStringAsFixed(1)}' : '-'),
            _buildStatRow('5-wicket Hauls', '${stats.fiveWickets}'),
          ]),

          SizedBox(height: 24.h),

          // Fielding Stats
          _buildStatsCategory('Fielding Stats', Icons.catching_pokemon, [
            _buildStatRow('Catches', '${(stats.matches * 0.8).round()}'),
            _buildStatRow('Stumpings', '${(stats.matches * 0.1).round()}'),
            _buildStatRow('Run Outs', '${(stats.matches * 0.2).round()}'),
          ]),

          SizedBox(height: 24.h),

          // Achievements
          _buildStatsCategory('Achievements', Icons.emoji_events, [
            _buildStatRow('Man of Match', '${stats.manOfMatches}', highlight: true),
            _buildStatRow('Tournament Wins', '${stats.tournamentWins}', highlight: true),
            _buildStatRow('Best Performance', '${stats.bestScore} runs & ${stats.wickets > 0 ? '${(stats.wickets / stats.matches).toStringAsFixed(1)} wkt/match' : 'batting'}'),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatsCategory(String title, IconData icon, List<Widget> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, size: 18.sp, color: AppTheme.primaryOrange),
            ),
            SizedBox(width: 10.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(children: stats),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {bool highlight = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              color: highlight ? AppTheme.primaryOrange : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32.0.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon with gradient
                Container(
                  width: 120.w,
                  height: 120.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF6B35),
                        Color(0xFFFF8C42),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.sports_cricket, size: 60.sp, color: Colors.white),
                ),
                SizedBox(height: 32.h),
                Text(
                  'Welcome to\nScorePartner!',
                  style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Track your cricket stats, join matches,\nand connect with players.',
                  style: TextStyle(fontSize: 15.sp, color: Colors.grey[600], height: 1.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48.h),
                
                // Sign Up Button (Primary)
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: () => _navigateToLogin(context, isSignUp: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: 0,
                    ),
                    child: Text('Sign Up', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
                
                SizedBox(height: 16.h),
                
                // Sign In Button (Secondary)
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: OutlinedButton(
                    onPressed: () => _navigateToLogin(context, isSignUp: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B35),
                      side: BorderSide(color: Color(0xFFFF6B35), width: 2.w),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                    child: Text('Sign In', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
                
                SizedBox(height: 32.h),
                
                // Terms text
                Text(
                  'By signing up, you agree to our\nTerms of Service and Privacy Policy',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500], height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context, {bool isSignUp = false}) {
    // Navigate to login screen - isSignUp can be used to show different UI
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).signOut();
              Navigator.pop(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Recent Matches Section (Fetches real data)
  Widget _buildRecentMatches(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.sports_cricket, size: 20.sp, color: AppTheme.primaryOrange),
                  ),
                  SizedBox(width: 10.w),
                  Text('Recent Matches', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyMatchesScreen())),
                child: Text('View All', style: TextStyle(color: AppTheme.primaryOrange)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          FutureBuilder<List<MatchModel>>(
            future: FirebaseDataService.instance.getUserPlayedMatches(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: Padding(padding: EdgeInsets.all(16.w), child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: const Center(child: Text('No matches played yet', style: TextStyle(color: Colors.grey))),
                );
              }
              final matches = snapshot.data!.take(4).toList();
              return Column(children: matches.map((m) => _buildRealMatchCard(m)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRealMatchCard(MatchModel match) {
    bool isCompleted = match.status == 'completed';
    String resultText = match.result?.winner != null ? '${match.result!.winner} won' : match.status.toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${match.scheduledDate.day}/${match.scheduledDate.month}/${match.scheduledDate.year}', style: TextStyle(color: Colors.grey[500], fontSize: 12.sp)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.withValues(alpha: 0.1) : AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  match.status.toUpperCase(),
                  style: TextStyle(color: isCompleted ? Colors.green : AppTheme.primaryOrange, fontSize: 10.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.team1Name, style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${match.team1Score.runs}/${match.team1Score.wickets}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Text('vs', style: TextStyle(color: Colors.grey)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(match.team2Name, style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${match.team2Score.runs}/${match.team2Score.wickets}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (isCompleted) ...[
            Divider(height: 20.h),
            Text(resultText, style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    bool isWin = match['isWin'] == true;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: isWin ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match['date'], style: TextStyle(color: Colors.grey[500], fontSize: 12.sp)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isWin ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  isWin ? 'WON' : 'LOST',
                  style: TextStyle(color: isWin ? Colors.green : Colors.red, fontSize: 10.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match['team1'], style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(match['score1'], style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Text('vs', style: TextStyle(color: Colors.grey)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(match['team2'], style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(match['score2'], style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match['result'], style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
              Row(
                children: [
                  Text('Your Score: ', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                  Text(match['playerScore'], style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tournaments Section
  Widget _buildTournamentsSection(BuildContext context) {
    final tournaments = [
      {'name': 'Mahbubnagar Premier League', 'status': 'Winner', 'icon': '🏆', 'date': 'Dec 2025', 'matches': 6, 'runs': 234, 'wickets': 5},
      {'name': 'Street Cricket Cup', 'status': 'Runner-up', 'icon': '🥈', 'date': 'Nov 2025', 'matches': 5, 'runs': 156, 'wickets': 3},
      {'name': 'Weekend Warriors League', 'status': 'Semi-finalist', 'icon': '🏅', 'date': 'Oct 2025', 'matches': 4, 'runs': 98, 'wickets': 2},
      {'name': 'Corporate Cricket Championship', 'status': 'Winner', 'icon': '🏆', 'date': 'Sep 2025', 'matches': 8, 'runs': 312, 'wickets': 7},
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.emoji_events, size: 20.sp, color: Colors.amber),
              ),
              SizedBox(width: 10.w),
              Text('Tournaments', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12.h),
          ...tournaments.map((t) => _buildTournamentCard(t)),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tournament['icon'], style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tournament['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp)),
                    SizedBox(height: 2.h),
                    Text('${tournament['status']} • ${tournament['date']}', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTournamentStat('Matches', '${tournament['matches']}'),
              _buildTournamentStat('Runs', '${tournament['runs']}'),
              _buildTournamentStat('Wickets', '${tournament['wickets']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11.sp)),
      ],
    );
  }

  /// Rewards & Awards Section
  Widget _buildRewardsSection(BuildContext context) {
    final rewards = [
      {'title': 'Player of the Tournament', 'tournament': 'Mahbubnagar Premier League', 'icon': Icons.star, 'color': Colors.amber, 'date': 'Dec 2025'},
      {'title': 'Best Batsman', 'tournament': 'Street Cricket Cup', 'icon': Icons.sports_cricket, 'color': Colors.blue, 'date': 'Nov 2025'},
      {'title': 'Man of the Match', 'tournament': 'Final - MPL 2025', 'icon': Icons.emoji_events, 'color': Colors.orange, 'date': 'Dec 2025'},
      {'title': 'Highest Scorer', 'tournament': 'Weekend Warriors League', 'icon': Icons.trending_up, 'color': Colors.green, 'date': 'Oct 2025'},
      {'title': 'Best All-rounder', 'tournament': 'Corporate Championship', 'icon': Icons.military_tech, 'color': Colors.purple, 'date': 'Sep 2025'},
      {'title': 'Hat-trick Hero', 'tournament': 'Street Cricket Cup', 'icon': Icons.local_fire_department, 'color': Colors.red, 'date': 'Nov 2025'},
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.military_tech, size: 20.sp, color: Colors.purple),
              ),
              SizedBox(width: 10.w),
              Text('Rewards & Awards', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: rewards.length,
            itemBuilder: (context, index) => _buildRewardCard(rewards[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: (reward['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(reward['icon'] as IconData, size: 20.sp, color: reward['color'] as Color),
          ),
          const Spacer(),
          Text(
            reward['title'],
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            reward['tournament'],
            style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            reward['date'],
            style: TextStyle(color: Colors.grey[400], fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  List<PlayerAchievement> _getUniqueAchievements(List<PlayerAchievement> achievements) {
    if (achievements.isEmpty) return [];
    
    final Map<String, PlayerAchievement> uniqueAchMap = {};
    for (var ach in achievements) {
      final dateStr = '${ach.earnedAt.year}-${ach.earnedAt.month}-${ach.earnedAt.day}';
      final contextKey = ach.matchId ?? ach.tournamentId ?? dateStr;
      final key = '${ach.type}_${ach.title}_$contextKey';
      
      if (!uniqueAchMap.containsKey(key)) {
        uniqueAchMap[key] = ach;
      }
    }
    return uniqueAchMap.values.toList();
  }

  Widget _buildFloatingTabSection(BuildContext context, UserModel user) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          // Floating Tab Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25.r),
                color: AppTheme.primaryOrange,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(icon: Icon(Icons.query_stats), text: 'Stats'),
                Tab(icon: Icon(Icons.emoji_events), text: 'Achieve'),
                Tab(icon: Icon(Icons.sports_cricket), text: 'Matches'),
                Tab(icon: Icon(Icons.workspace_premium), text: 'Tourney'),
                Tab(icon: Icon(Icons.card_giftcard), text: 'Rewards'),
              ],
              labelStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
              labelPadding: EdgeInsets.zero,
            ),
          ),

          // Tab Content
          SizedBox(
            height: 600.h, // Fixed height for tab content
            child: TabBarView(
              children: [
                _buildDetailedStatsContent(user),
                _buildAchievementsContent(user),
                _buildRecentMatchesContent(),
                _buildTournamentsContent(user),
                _buildRewardsContent(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatsContent(UserModel user) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryOrange,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TennisBallWidget(size: 18),
                    SizedBox(width: 8.w),
                    const Text('Tennis Ball', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LeatherBallWidget(size: 18),
                    SizedBox(width: 8.w),
                    const Text('Leather Ball', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFullStats(user.tennisBallStats),
                _buildFullStats(user.leatherBallStats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsContent(UserModel user) {
    final uniqueAchievements = _getUniqueAchievements(user.achievements);
    if (uniqueAchievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48.sp, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text('No achievements yet', style: TextStyle(color: Colors.grey[500])),
            SizedBox(height: 4.h),
            Text('Play matches to earn badges!', style: TextStyle(fontSize: 12.sp, color: Colors.grey[400])),
          ],
        ),
      );
    }

    // Sort by date new to old
    final achievements = List<PlayerAchievement>.from(uniqueAchievements)
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final ach = achievements[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
              child: Text(ach.badgeIcon, style: TextStyle(fontSize: 20.sp)),
            ),
            title: Text(ach.title, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ach.description),
                SizedBox(height: 2.h),
                Text(
                  '${ach.earnedAt.day}/${ach.earnedAt.month}/${ach.earnedAt.year}',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.share, color: Colors.grey, size: 20.sp),
              onPressed: () => _showFullRewardDialog(context, ach, user),
            ),
          ),
        );
      },
    );
  }


  Widget _buildRecentMatchesContent() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please sign in to view matches'));
    }

    return FutureBuilder<List<MatchModel>>(
      future: FirebaseDataService.instance.getUserPlayedMatches(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_cricket, size: 48.sp, color: Colors.grey[300]),
                SizedBox(height: 16.h),
                Text('No matches played yet', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        final matches = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: matches.length,
          itemBuilder: (context, index) => _buildRealMatchCard(matches[index]),
        );
      },
    );
  }

  Widget _buildTournamentsContent(UserModel user) {
    final tourneyAchievements = user.achievements
        .where((a) => a.type == 'tournament_win' || a.type == 'tournamentRunner')
        .toList();

    if (tourneyAchievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium, size: 48.sp, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text('No tournament history', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    final tournaments = tourneyAchievements.map((a) {
      return {
        'name': a.tournamentName ?? 'Unknown Tournament',
        'status': a.type == 'tournament_win' ? 'Winner' : 'Runner-up',
        'icon': '🏆',
        'date': '${a.earnedAt.month}/${a.earnedAt.year}',
        'matches': a.stats['matches'] ?? 0,
        'runs': a.stats['runs'] ?? 0,
        'wickets': a.stats['wickets'] ?? 0,
      };
    }).toList();

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: tournaments.length,
      itemBuilder: (context, index) => _buildTournamentCard(tournaments[index]),
    );
  }

  BadgeType _achievementTypeToBadgeType(String type) {
    switch (type) {
      case 'tournament_win':
      case 'win':
        return BadgeType.win;
      case 'century':
        return BadgeType.century;
      case 'half_century':
      case 'fifty':
        return BadgeType.fifty;
      case 'five_wickets':
      case 'wicket':
        return BadgeType.wicket;
      case 'man_of_match':
      case 'mvp':
        return BadgeType.mvp;
      default:
        return BadgeType.fifty;
    }
  }

  Widget _buildRewardsContent(UserModel user) {
    final uniqueAchievements = _getUniqueAchievements(user.achievements)
        .where((a) => !a.type.startsWith('badge_'))
        .toList();
    if (uniqueAchievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 48.sp, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text('No rewards yet', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: uniqueAchievements.length,
      itemBuilder: (context, index) {
        final achievement = uniqueAchievements[index];
        return GestureDetector(
          onTap: () => _showFullRewardDialog(context, achievement, user),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 400.w,
                  height: 500.h,
                  child: IgnorePointer(
                    child: _buildHighlightRewardCard(achievement, user),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullRewardDialog(BuildContext context, PlayerAchievement achievement, UserModel user) {
    final screenshotController = ScreenshotController();
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28.sp),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 400.w,
                  height: 500.h,
                  child: Screenshot(
                    controller: screenshotController,
                    child: _buildHighlightRewardCard(achievement, user),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final imageBytes = await screenshotController.capture(
                    delay: const Duration(milliseconds: 10),
                    pixelRatio: 3.0,
                  );

                  if (imageBytes != null) {
                    await Share.shareXFiles(
                      [
                        XFile.fromData(
                          imageBytes,
                          mimeType: 'image/png',
                          name: 'achievement_${achievement.id}.png',
                        )
                      ],
                      text: 'Check out my achievement on ScorePartner! 🏏🏆\n#Cricket #ScorePartner #Achievement',
                      subject: 'My Cricket Achievement',
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to share achievement: $e')),
                  );
                }
              },
              icon: Icon(Icons.share),
              label: const Text('SHARE MOMENT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.stadiumOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRewardCard(PlayerAchievement achievement, UserModel user) {
    final matchId = achievement.matchId;
    if (matchId == null || matchId.isEmpty) {
      // No match linked — show a simple gradient card
      final badgeType = _achievementTypeToBadgeType(achievement.type);
      final dateStr = '${achievement.earnedAt.day} ${_monthName(achievement.earnedAt.month)} ${achievement.earnedAt.year}';
      return Center(
        child: HighlightBadgeCard(
          type: badgeType,
          title: achievement.title,
          description: achievement.description,
          matchName: achievement.matchName ?? 'Match',
          ground: '',
          date: dateStr,
          playerName: user.name,
          playerPhoto: user.profileImageUrl.isNotEmpty ? user.profileImageUrl : null,
        ),
      );
    }

    // Fetch match data for team names and scores
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('matches').doc(matchId).get(),
      builder: (context, snapshot) {
        final badgeType = _achievementTypeToBadgeType(achievement.type);
        final dateStr = '${achievement.earnedAt.day} ${_monthName(achievement.earnedAt.month)} ${achievement.earnedAt.year}';

        String matchName = achievement.matchName ?? 'Match';
        String ground = '';
        String? team1Name;
        String? team2Name;
        String? team1Score;
        String? team2Score;

        String? generatedImageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final matchData = snapshot.data!.data() as Map<String, dynamic>;
          team1Name = matchData['team1Name'] as String? ?? 'Team 1';
          team2Name = matchData['team2Name'] as String? ?? 'Team 2';
          matchName = '$team1Name vs $team2Name';
          ground = matchData['ground'] as String? ?? matchData['location'] as String? ?? '';

          // Extract scores
          final t1Score = matchData['team1Score'] as Map<String, dynamic>?;
          final t2Score = matchData['team2Score'] as Map<String, dynamic>?;
          if (t1Score != null) {
            final runs = t1Score['runs'] ?? 0;
            final wickets = t1Score['wickets'] ?? 0;
            final overs = t1Score['overs'] ?? 0;
            team1Score = '$runs/$wickets ($overs ov)';
          }
          if (t2Score != null) {
            final runs = t2Score['runs'] ?? 0;
            final wickets = t2Score['wickets'] ?? 0;
            final overs = t2Score['overs'] ?? 0;
            team2Score = '$runs/$wickets ($overs ov)';
          }

          // Check if a highlight image was already generated for this achievement
          final highlightsList = matchData['highlights'] as List<dynamic>? ?? [];
          for (final h in highlightsList) {
            final hType = h['type'] as String?;
            final hPlayerId = h['playerId'] as String?;
            final hImg = h['imageUrl'] as String?;
            if (hType != null && hPlayerId == user.uid && hType == achievement.type && hImg != null && hImg.isNotEmpty) {
              generatedImageUrl = hImg;
              break;
            }
          }
        }

        return Center(
          child: HighlightBadgeCard(
            type: badgeType,
            title: achievement.title,
            description: achievement.description,
            matchName: matchName,
            ground: ground,
            date: dateStr,
            playerName: user.name,
            playerPhoto: (generatedImageUrl != null && generatedImageUrl.isNotEmpty) ? generatedImageUrl : (user.profileImageUrl.isNotEmpty ? user.profileImageUrl : null),
            team1Name: team1Name,
            team2Name: team2Name,
            team1Score: team1Score,
            team2Score: team2Score,
          ),
        );
      },
    );
  }

  ImageProvider _getHighlightImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image') || imageUrl.startsWith('data:')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error parsing highlight base64 image: $e');
      }
    }
    return NetworkImage(imageUrl);
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class TennisBallWidget extends StatelessWidget {
  final double size;
  const TennisBallWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFCCFF00), // Vibrant Tennis Neon Yellow/Green
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: CustomPaint(painter: _TennisBallPainter()),
    );
  }
}

class _TennisBallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12;

    final path1 = Path();
    path1.moveTo(size.width * 0.15, 0);
    path1.quadraticBezierTo(size.width * 0.5, size.height * 0.45, size.width * 0.85, 0);

    final path2 = Path();
    path2.moveTo(size.width * 0.15, size.height);
    path2.quadraticBezierTo(size.width * 0.5, size.height * 0.55, size.width * 0.85, size.height);

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LeatherBallWidget extends StatelessWidget {
  final double size;
  const LeatherBallWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFB71C1C), // Deep Crimson Leather Red
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: CustomPaint(painter: _LeatherBallPainter()),
    );
  }
}

class _LeatherBallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final seamPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14;

    // Main white seam line across the ball
    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.85);
    path.lineTo(size.width * 0.85, size.height * 0.15);
    canvas.drawPath(path, seamPaint);

    final stitchPaint = Paint()
      ..color = const Color(0xFF800000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;

    // Center seam stitching detail
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      stitchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

