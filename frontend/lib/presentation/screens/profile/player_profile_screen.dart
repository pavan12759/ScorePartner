import 'package:flutter/material.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/match_model.dart';
import '../../../core/utils/image_utils.dart';
import 'dart:convert';
import '../../../data/services/firebase_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../providers/auth_provider.dart';
import '../matches/match_detail_screen.dart';
import '../tournament/tournament_details_screen.dart';
import '../../../data/models/team_model.dart';
import '../../widgets/match/profile_match_card.dart';
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
import '../../widgets/key_moment_poster_card.dart';

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

  Stream<UserModel?>? _playerStream;
  Future<List<MatchModel>>? _recentMatchesFuture;
  Future<List<TournamentModel>>? _tournamentsFuture;

  @override
  void initState() {
    super.initState();
    _playerStream = FirebaseDataService.instance.streamUser(widget.player.uid);
    _recentMatchesFuture = FirebaseDataService.instance.getUserPlayedMatches(widget.player.uid);
    _tournamentsFuture = _loadUserTournaments(widget.player.uid, widget.player);
    _loadFollowData();
  }

  Future<List<TournamentModel>> _loadUserTournaments(String uid, UserModel user) async {
    try {
      final dataService = FirebaseDataService.instance;
      final created = await dataService.getUserTournaments(uid);

      final userTeams = await dataService.getUserTeams(uid);
      final spPId = user.spPId;
      final playerTeams = spPId.isNotEmpty
          ? await dataService.getTeamsWhereUserIsPlayer(uid, spPId)
          : <TeamModel>[];

      final teamIds = <String>{
        ...userTeams.map((t) => t.id),
        ...playerTeams.map((t) => t.id),
      }.toList();

      List<TournamentModel> playerTournaments = [];
      if (teamIds.isNotEmpty) {
        playerTournaments = await dataService.getPlayerTournaments(uid, teamIds);
      }

      final Map<String, TournamentModel> map = {};
      for (final t in created) {
        map[t.id] = t;
      }
      for (final t in playerTournaments) {
        map[t.id] = t;
      }

      if (user.tournamentIds.isNotEmpty) {
        for (final tId in user.tournamentIds) {
          if (!map.containsKey(tId)) {
            final t = await dataService.getTournament(tId);
            if (t != null) {
              map[t.id] = t;
            }
          }
        }
      }

      final list = map.values.toList();
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      return list;
    } catch (e) {
      debugPrint('Error loading user tournaments: $e');
      return [];
    }
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
      stream: _playerStream,
      initialData: widget.player,
      builder: (context, snapshot) {
        final player = snapshot.data ?? widget.player;
        debugPrint('🔍 Player Instagram: "${player.instagramUrl}"');
        
        return Scaffold(
          backgroundColor: ThemeHelper.of(context).scaffoldBg,
          body: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: ThemeHelper.of(context).scaffoldBg,
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
    return ImageUtils.getProfileImageProvider(url, fallbackAsset: 'assets/images/default_avatar.png');
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
                backgroundColor: ThemeHelper.of(context).dividerColor!,
                backgroundImage: _getProfileImageProvider(player.profileImageUrl),
                child: player.profileImageUrl.isEmpty
                    ? Icon(Icons.person, size: 50.sp, color: Colors.grey.withValues(alpha: 0.5))
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
                              color: ThemeHelper.of(context).textPrimary,
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
                            color: ThemeHelper.of(context).dividerColor!,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_cricket, size: 12.sp, color: ThemeHelper.of(context).textSecondary),
                              SizedBox(width: 4.w),
                              Text(
                                player.battingStyle.isNotEmpty ? player.battingStyle : 'RHB',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  color: ThemeHelper.of(context).textSecondary,
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
                                color: _isFollowing ? ThemeHelper.of(context).dividerColor! : null,
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
                                          color: _isFollowing ? ThemeHelper.of(context).textPrimary : Colors.white,
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
                              color: ThemeHelper.of(context).dividerColor!,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(Icons.message_outlined, size: 16.sp, color: ThemeHelper.of(context).textPrimary),
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
              color: ThemeHelper.of(context).containerColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: ThemeHelper.of(context).dividerColor!),
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
                Container(width: 1.w, height: 35.h, color: ThemeHelper.of(context).dividerColor!),
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
                Container(width: 1.w, height: 35.h, color: ThemeHelper.of(context).dividerColor!),
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
              color: ThemeHelper.of(context).cardBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: ThemeHelper.of(context).dividerColor!),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: Offset(0, 2))
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_cricket, size: 14.sp, color: ThemeHelper.of(context).textSecondary),
                    SizedBox(width: 4.w),
                    Text(
                      'PASSIONATE ${player.role.isNotEmpty ? player.role.toUpperCase() : "CRICKETER"} | ',
                      style: TextStyle(
                        color: ThemeHelper.of(context).textSecondary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(Icons.location_on, size: 14.sp, color: ThemeHelper.of(context).textSecondary),
                    SizedBox(width: 2.w),
                    Text(
                      '${player.location.isNotEmpty ? player.location.toUpperCase() : "INDIA"}',
                      style: TextStyle(
                        color: ThemeHelper.of(context).textSecondary,
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
                      color: ThemeHelper.of(context).textPrimary,
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                ],
                
                SizedBox(height: 12.h),
                
                Divider(color: ThemeHelper.of(context).dividerColor!, height: 1.h),
                
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
                              color: ThemeHelper.of(context).textSecondary,
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
                              color: player.instagramUrl.isNotEmpty ? Colors.pink : ThemeHelper.of(context).textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    Container(width: 1.w, height: 30.h, color: ThemeHelper.of(context).dividerColor!),
                    
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
                              color: ThemeHelper.of(context).textSecondary,
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
              color: ThemeHelper.of(context).cardBg,
              border: Border.all(color: ThemeHelper.of(context).dividerColor!, width: 1.5.w),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg.withValues(alpha: 0.15),
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
              color: ThemeHelper.of(context).textPrimary,
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
                color: ThemeHelper.of(context).textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: ThemeHelper.of(context).textSecondary,
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
            Text(label, style: TextStyle(fontSize: 9.sp, color: ThemeHelper.of(context).textSecondary)),
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
        color: ThemeHelper.of(context).cardBg,
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
              color: ThemeHelper.of(context).textPrimary,
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
            color: ThemeHelper.of(context).textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: ThemeHelper.of(context).textSecondary),
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
                color: ThemeHelper.of(context).textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: ThemeHelper.of(context).containerColor,
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
          bottom: BorderSide(color: ThemeHelper.of(context).dividerColor!, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ThemeHelper.of(context).textSecondary,
              fontSize: 14.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              color: highlight ? AppTheme.primaryOrange : ThemeHelper.of(context).textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealMatchCard(BuildContext context, MatchModel match) {
    return ProfileMatchCard(
      match: match,
      targetUserId: widget.player.uid,
      targetUserName: widget.player.name,
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
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    bool isWin = match['isWin'] == true;
    final th = ThemeHelper.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isWin ? Colors.green.withValues(alpha: 0.35) : Colors.red.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
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
              Text(
                match['date'] ?? '',
                style: TextStyle(color: th.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isWin ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(
                    color: isWin ? Colors.green.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isWin ? 'WON' : 'LOST',
                  style: TextStyle(
                    color: isWin ? Colors.green : Colors.red,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: th.dividerColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match['team1'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, color: th.textPrimary)),
                      SizedBox(height: 2.h),
                      Text(match['score1'] ?? '', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: th.textPrimary)),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text('VS', style: TextStyle(color: th.textSecondary, fontWeight: FontWeight.bold, fontSize: 10.sp)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(match['team2'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, color: th.textPrimary)),
                      SizedBox(height: 2.h),
                      Text(match['score2'] ?? '', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: th.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  match['result'] ?? '',
                  style: TextStyle(color: th.textSecondary, fontSize: 10.5.sp, fontWeight: FontWeight.w600),
                ),
                if (match['playerScore'] != null && match['playerScore'].toString().isNotEmpty)
                  Row(
                    children: [
                      Text('Player Score: ', style: TextStyle(fontSize: 10.5.sp, color: th.textSecondary)),
                      Text(
                        match['playerScore'],
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: AppTheme.primaryOrange),
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
        color: ThemeHelper.of(context).cardBg,
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(tournament['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp), maxLines: 1),
                    ),
                    SizedBox(height: 2.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${tournament['status']} • ${tournament['date']}', style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp), maxLines: 1),
                    ),
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
        Text(label, style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 11.sp)),
      ],
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
      length: 4,
      child: Column(
        children: [
          // Floating Tab Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: ThemeHelper.of(context).cardBg,
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
              unselectedLabelColor: ThemeHelper.of(context).textSecondary,
              tabs: [
                const Tab(icon: Icon(Icons.query_stats), text: 'Stats'),
                const Tab(icon: Icon(Icons.emoji_events), text: 'Achieve'),
                const Tab(icon: Icon(Icons.sports_cricket), text: 'Matches'),
                Tab(
                  icon: const Icon(Icons.workspace_premium),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tournaments',
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
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
            unselectedLabelColor: ThemeHelper.of(context).textSecondary,
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


  void _openKeyMomentPosterForAchievement(BuildContext context, PlayerAchievement ach, UserModel user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.stadiumOrange)),
    );

    try {
      final poster = await KeyMomentPosterModel.fromAchievement(
        ach,
        playerName: user.name,
        photoUrl: user.profileImageUrl.isNotEmpty ? user.profileImageUrl : null,
        playerId: user.uid,
      );
      if (context.mounted) {
        Navigator.pop(context); // close loading indicator
        KeyMomentPosterDialog.show(context, poster, poster.defaultTheme);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open poster: $e')),
        );
      }
    }
  }

  Widget _buildAchievementsContent(UserModel user) {
    final uniqueAchievements = _getUniqueAchievements(user.achievements);
    if (uniqueAchievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48.sp, color: ThemeHelper.of(context).dividerColor!),
            SizedBox(height: 16.h),
            Text('No achievements yet', style: TextStyle(color: ThemeHelper.of(context).textSecondary)),
            SizedBox(height: 4.h),
            Text('Play matches to earn badges and key moment posters!', style: TextStyle(fontSize: 12.sp, color: ThemeHelper.of(context).textSecondary)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openKeyMomentPosterForAchievement(context, ach, user),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.12),
                    child: Text(ach.badgeIcon, style: TextStyle(fontSize: 20.sp)),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ach.title,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.4), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 10.sp, color: AppTheme.primaryOrange),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'POSTER',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryOrange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          ach.description,
                          style: TextStyle(fontSize: 11.5.sp, color: ThemeHelper.of(context).textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${ach.earnedAt.day}/${ach.earnedAt.month}/${ach.earnedAt.year}${ach.matchName != null ? ' • ${ach.matchName}' : ''}',
                          style: TextStyle(fontSize: 10.sp, color: ThemeHelper.of(context).textSecondary.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: ThemeHelper.of(context).textSecondary, size: 19.sp),
                    onPressed: () => _shareAchievement(context, user, ach),
                  ),
                ],
              ),
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
      future: _recentMatchesFuture,
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
    final tourneyWins = user.achievements
        .where((a) => a.type == 'tournament_win' || a.type == 'win')
        .toList();
    final tourneyRunners = user.achievements
        .where((a) => a.type == 'tournamentRunner')
        .toList();

    return FutureBuilder<List<TournamentModel>>(
      future: _tournamentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: 3,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ScorePartnerSkeleton(
                width: double.infinity,
                height: 140.h,
                borderRadius: 16.r,
              ),
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty && tourneyWins.isEmpty && tourneyRunners.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: ThemeHelper.of(context).dividerColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.workspace_premium, size: 42.sp, color: ThemeHelper.of(context).textSecondary),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'No tournament history',
                    style: TextStyle(
                      color: ThemeHelper.of(context).textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'This player has not participated in or organized any tournaments yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Trophy showcase if user has wins or runner up trophies
            if (tourneyWins.isNotEmpty || tourneyRunners.isNotEmpty) ...[
              Container(
                margin: EdgeInsets.only(bottom: 14.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ThemeHelper.of(context).isDark
                        ? [const Color(0xFF3E2723), const Color(0xFF261D19)]
                        : [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, size: 26.sp, color: Colors.amber[700]),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tournament Trophies',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: ThemeHelper.of(context).isDark ? Colors.amber[200] : const Color(0xFFB45309),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${tourneyWins.length} Winner • ${tourneyRunners.length} Runner-up',
                            style: TextStyle(fontSize: 11.sp, color: ThemeHelper.of(context).textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Real tournament cards
            ...tournaments.map((t) => _buildRealTournamentCard(t, user)),

            // Legacy tournament achievement fallback cards
            ...tourneyWins.where((a) => !tournaments.any((t) => t.id == a.tournamentId || t.name == a.tournamentName)).map((a) {
              return _buildTournamentCard({
                'name': a.tournamentName ?? 'Tournament',
                'status': 'Winner',
                'icon': '🏆',
                'date': '${a.earnedAt.month}/${a.earnedAt.year}',
                'matches': a.stats['matches'] ?? 0,
                'runs': a.stats['runs'] ?? 0,
                'wickets': a.stats['wickets'] ?? 0,
              });
            }),
            ...tourneyRunners.where((a) => !tournaments.any((t) => t.id == a.tournamentId || t.name == a.tournamentName)).map((a) {
              return _buildTournamentCard({
                'name': a.tournamentName ?? 'Tournament',
                'status': 'Runner-up',
                'icon': '🥈',
                'date': '${a.earnedAt.month}/${a.earnedAt.year}',
                'matches': a.stats['matches'] ?? 0,
                'runs': a.stats['runs'] ?? 0,
                'wickets': a.stats['wickets'] ?? 0,
              });
            }),
          ],
        );
      },
    );
  }

  Widget _buildRealTournamentCard(TournamentModel tournament, UserModel user) {
    final th = ThemeHelper.of(context);
    final isOrganizer = tournament.organizerId == user.uid || tournament.adminIds.contains(user.uid);
    final isChampion = tournament.winnerId.isNotEmpty &&
        (tournament.winnerId == user.uid ||
            user.achievements.any((a) =>
                (a.type == 'tournament_win' || a.type == 'win') &&
                (a.tournamentId == tournament.id || a.tournamentName == tournament.name)));
    final isRunnerUp = tournament.runnerUpId.isNotEmpty &&
        (tournament.runnerUpId == user.uid ||
            user.achievements.any((a) =>
                (a.type == 'tournamentRunner') &&
                (a.tournamentId == tournament.id || a.tournamentName == tournament.name)));

    final status = tournament.effectiveStatus.toLowerCase();
    final isOngoing = status == 'ongoing';
    final isUpcoming = status == 'upcoming';

    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    if (isOngoing) {
      statusColor = const Color(0xFF2E7D32);
      statusBgColor = const Color(0xFF2E7D32).withValues(alpha: 0.12);
      statusText = 'ONGOING';
      statusIcon = Icons.fiber_manual_record;
    } else if (isUpcoming) {
      statusColor = const Color(0xFF0288D1);
      statusBgColor = const Color(0xFF0288D1).withValues(alpha: 0.12);
      statusText = 'UPCOMING';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = Colors.grey[700]!;
      statusBgColor = Colors.grey.withValues(alpha: 0.12);
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isOngoing
              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
              : (th.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
          width: isOngoing ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TournamentDetailsScreen(tournament: tournament),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Status pill + Role badge + Ball type/Format pill)
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOngoing) ...[
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ] else ...[
                            Icon(statusIcon, size: 10.sp, color: statusColor),
                            SizedBox(width: 3.w),
                          ],
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 6.w),

                    // Role pill
                    if (isChampion) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100.r),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events, size: 10.sp, color: Colors.amber[800]),
                            SizedBox(width: 2.w),
                            Text(
                              'CHAMPION',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ] else if (isRunnerUp) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100.r),
                          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          'RUNNER-UP',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey[700],
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ] else if (isOrganizer) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100.r),
                          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.35), width: 0.8),
                        ),
                        child: Text(
                          'ORGANIZER',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ],

                    const Spacer(),

                    // Format badge (e.g. Tennis • T20)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: th.dividerColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Text(
                        '${tournament.ballType.toUpperCase()} • ${tournament.overs} Ov',
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w600,
                          color: th.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10.h),

                // 2. Tournament Name & Location
                Text(
                  tournament.name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: th.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 4.h),

                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12.sp, color: th.textSecondary),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        tournament.location.isNotEmpty ? tournament.location : 'Cricket Stadium',
                        style: TextStyle(fontSize: 11.sp, color: th.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(Icons.calendar_month_outlined, size: 11.sp, color: th.textSecondary),
                    SizedBox(width: 3.w),
                    Text(
                      DateFormat('d MMM yyyy').format(tournament.startDate),
                      style: TextStyle(fontSize: 11.sp, color: th.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                SizedBox(height: 10.h),

                // 3. Stats Strip (Teams, Prize Pool, Format)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups_outlined, size: 14.sp, color: AppTheme.primaryOrange),
                      SizedBox(width: 4.w),
                      Text(
                        '${tournament.registeredTeamIds.length}/${tournament.maxTeams} Teams',
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: th.textPrimary),
                      ),
                      if (tournament.prizePool > 0) ...[
                        const Spacer(),
                        Icon(Icons.emoji_events_outlined, size: 13.sp, color: Colors.amber[700]),
                        SizedBox(width: 3.w),
                        Text(
                          '₹${tournament.prizePool.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: th.isDark ? Colors.amber[300] : const Color(0xFFD97706),
                          ),
                        ),
                      ] else ...[
                        const Spacer(),
                        Text(
                          tournament.format.toUpperCase(),
                          style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: th.textSecondary),
                        ),
                      ],
                      SizedBox(width: 6.w),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9.sp, color: th.textSecondary.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
