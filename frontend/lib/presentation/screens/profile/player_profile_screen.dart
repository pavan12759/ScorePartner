import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/match_model.dart';
import 'dart:convert';
import '../../../data/services/firebase_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../widgets/highlight_badge_widgets.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../providers/auth_provider.dart';
import '../matches/match_detail_screen.dart';
import 'followers_list_screen.dart';
import '../../widgets/state/scorepartner_skeleton.dart';
import '../../widgets/state/scorepartner_empty_state.dart';
import '../../widgets/state/scorepartner_error_state.dart';

/// Screen to display another user's profile (view-only with follow functionality)
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/achievement_share_card.dart';
import '../../../data/models/achievement_model.dart';
import '../../widgets/genz_badge_widget.dart';
import '../../widgets/rank_badge.dart';

class PlayerProfileScreen extends StatefulWidget {
  final UserModel player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  int _followerCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFollowData();
  }

  Future<void> _loadFollowData() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      final isFollowing = await FirebaseDataService.instance.isFollowing(currentUserId, widget.player.uid);
      final followers = await FirebaseDataService.instance.getFollowerCount(widget.player.uid);
      final following = await FirebaseDataService.instance.getFollowingCount(widget.player.uid);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _followerCount = followers;
          _followingCount = following;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isLoadingFollow = true);

    try {
      if (_isFollowing) {
        await FirebaseDataService.instance.unfollowUser(currentUserId, widget.player.uid);
        setState(() {
          _isFollowing = false;
          _followerCount--;
        });
      } else {
        await FirebaseDataService.instance.followUser(currentUserId, widget.player.uid);
        setState(() {
          _isFollowing = true;
          _followerCount++;
        });
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }

    setState(() => _isLoadingFollow = false);
  }

  int _calculatePlayerRating(UserModel user) {
    final stats = user.tennisBallStats;
    int rating = 50;
    rating += (stats.matches * 2).clamp(0, 20);
    rating += (stats.runs ~/ 50).clamp(0, 15);
    rating += (stats.wickets * 2).clamp(0, 10);
    return rating.clamp(50, 99);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: FirebaseDataService.instance.streamUser(widget.player.uid),
      initialData: widget.player,
      builder: (context, snapshot) {
        final player = snapshot.data ?? widget.player;
        debugPrint('🔍 Player Instagram: "${player.instagramUrl}"');
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                title: Text(player.name, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              
              // Profile Header
              SliverToBoxAdapter(child: _buildProfileHeader(player)),
              
              // Quick Stats
              SliverToBoxAdapter(child: _buildQuickStats(player)),
              
              // Floating Tab Section (replaces old vertical sections)
              SliverToBoxAdapter(child: _buildFloatingTabSection(context, player)),
              
              // Bottom Padding
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
              
              // Bottom Padding
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _getProfileImageProvider(String url) {
    if (url.isEmpty) return null;
    if (url.trim().startsWith('data:')) {
      try {
        final base64Str = url.split(',').last.trim();
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  Widget _buildProfileHeader(UserModel player) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Profile Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey[100],
                backgroundImage: _getProfileImageProvider(player.profileImageUrl),
                child: player.profileImageUrl.isEmpty
                    ? Icon(Icons.person, size: 50.sp, color: Colors.grey.withOpacity(0.5))
                    : null,
              ),
              
              SizedBox(width: 16.w),
              
              // Player Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Verified
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.name.isNotEmpty ? player.name : 'Player',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (player.isVerified) ...[
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
                    
                    // Role & Style Tags
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.stadiumOrange, Color(0xFFB34200)],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            player.role.isNotEmpty ? player.role.toUpperCase() : 'BATSMAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
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
                                player.battingStyle.isNotEmpty ? player.battingStyle : 'RHB',
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
                    
                    // Rating
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14.sp, color: Color(0xFFFFD700)),
                              SizedBox(width: 4.w),
                              Text(
                                '${_calculatePlayerRating(player)}',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
                      stars: player.stars, 
                      unlockedTitles: player.unlockedTitles,
                      compact: true,
                    ),
                    
                    SizedBox(height: 12.h),
                    
                    // Follow & Message Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoadingFollow ? null : _toggleFollow,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                gradient: _isFollowing
                                    ? null
                                    : const LinearGradient(
                                        colors: [AppTheme.stadiumOrange, Color(0xFFB34200)],
                                      ),
                                color: _isFollowing ? Colors.grey[200] : null,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Center(
                                child: _isLoadingFollow
                                    ? SizedBox(
                                        width: 16.w,
                                        height: 16.h,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        _isFollowing ? 'FOLLOWING' : 'FOLLOW',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11.sp,
                                          color: _isFollowing ? Colors.black : Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: () async {
                            final currentUser = context.read<AuthProvider>().user;
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please login to message')),
                              );
                              return;
                            }
                            
                            try {
                              // Get or create chat room
                              final chatId = await FirebaseDataService.instance.getChatRoom(
                                currentUser.uid, 
                                widget.player.uid
                              );
                              
                              if (!mounted) return;
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chatId,
                                    otherUserId: widget.player.uid,
                                    otherUserName: widget.player.name,
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error opening chat: $e')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(Icons.message_outlined, size: 16.sp, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Followers Section
          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFollowerItem('$_followerCount', 'FOLLOWERS', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FollowersListScreen(
                        userId: widget.player.uid,
                        userName: widget.player.name,
                        isFollowing: false,
                      ),
                    ),
                  );
                }),
                Container(width: 1.w, height: 35.h, color: Colors.grey[300]),
                _buildFollowerItem('$_followingCount', 'FOLLOWING', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FollowersListScreen(
                        userId: widget.player.uid,
                        userName: widget.player.name,
                        isFollowing: true,
                      ),
                    ),
                  );
                }),
                Container(width: 1.w, height: 35.h, color: Colors.grey[300]),
                _buildFollowerItem('${player.tennisBallStats.matches}', 'MATCHES', onTap: null),
              ],
            ),
          ),
          
          SizedBox(height: 12.h),
          
          // Bio, Social Links & Highlights Section
          Container(
            width: double.infinity,
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
                Row(
                  children: [
                    Icon(Icons.sports_cricket, size: 14.sp, color: Colors.grey[600]),
                    SizedBox(width: 4.w),
                    Text(
                      'PASSIONATE ${player.role.isNotEmpty ? player.role.toUpperCase() : "CRICKETER"} | ',
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
                      '${player.location.isNotEmpty ? player.location.toUpperCase() : "INDIA"}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                
                if (player.bio.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  // User Bio Text (Instagram Style)
                  Text(
                    player.bio,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                ],
                
                SizedBox(height: 12.h),
                
                Divider(color: Colors.grey[200], height: 1.h),
                
                SizedBox(height: 12.h),
                
                Row(
                  children: [
                    // Instagram section
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 20.sp,
                            color: player.instagramUrl.isNotEmpty ? Colors.pink : Colors.grey,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'INSTAGRAM',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            player.instagramUrl.isNotEmpty 
                              ? (player.instagramUrl.startsWith('@') ? player.instagramUrl : player.instagramUrl)
                              : 'Not set',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: player.instagramUrl.isNotEmpty ? Colors.pink : Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    Container(width: 1.w, height: 30.h, color: Colors.grey[300]),
                    
                    // SPP ID section
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sports_cricket,
                            size: 20.sp,
                            color: AppTheme.stadiumOrange,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'SCOREPARTNER ID',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            player.spPId.isNotEmpty ? player.spPId : 'N/A',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.stadiumOrange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
              ],
            ),
          ),
        ],
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

  Widget _buildFollowerItem(String count, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: AppTheme.stadiumOrange),
        SizedBox(width: 6.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
            Text(value, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(UserModel player) {
    final stats = player.tennisBallStats;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CAREER STATS',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Matches', '${stats.matches}', Icons.sports_cricket),
              _buildStatItem('Runs', '${stats.runs}', Icons.trending_up),
              _buildStatItem('Wickets', '${stats.wickets}', Icons.gps_fixed),
              _buildStatItem('Best', '${stats.bestScore}', Icons.star),
              _buildStatItem('MOM', '${stats.manOfMatches}', Icons.emoji_events),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20.sp, color: AppTheme.stadiumOrange),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
        ),
      ],
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

  Widget _buildRealMatchCard(BuildContext context, MatchModel match) {
    bool isCompleted = match.status == 'completed';
    String resultText = match.result?.winner != null ? '${match.result!.winner} won' : match.status.toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailScreen(
              matchId: match.id,
            ),
          ),
        );
      },
      child: Container(
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
                _buildRecentMatchesContent(user),
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
              onPressed: () => _shareAchievement(context, user, ach),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareAchievement(BuildContext context, UserModel user, PlayerAchievement achievement) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.stadiumOrange)),
    );

    try {
      final controller = ScreenshotController();
      
      // Capture the card widget as an image
      // We render it slightly larger for better quality (pixelRatio 2.0)
      final Uint8List imageBytes = await controller.captureFromWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: Material(
            color: Colors.transparent,
            child: AchievementShareCard(
              achievement: achievement,
              user: user,
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
      );

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Share the file directly from memory (works on Web and Mobile)
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
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) Navigator.pop(context);
      
      debugPrint('Error sharing achievement: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share achievement. Please try again.')),
        );
      }
    }
  }

  Widget _buildRecentMatchesContent(UserModel user) {
    final userId = user.uid;
    if (userId.isEmpty) {
      return const Center(child: Text('No user ID available'));
    }

    return FutureBuilder<List<MatchModel>>(
      future: FirebaseDataService.instance.getUserPlayedMatches(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 3,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ScorePartnerSkeleton(
                width: double.infinity,
                height: 120.h,
                borderRadius: 16.r,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return ScorePartnerErrorState(message: snapshot.error.toString());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: ScorePartnerEmptyState(
              title: 'No matches played yet',
              description: 'This player has not played any matches yet.',
              icon: Icons.sports_cricket,
            ),
          );
        }
        final matches = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: matches.length,
          itemBuilder: (context, index) => _buildRealMatchCard(context, matches[index]),
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
                  child: _buildHighlightRewardCard(achievement, user),
                ),
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
