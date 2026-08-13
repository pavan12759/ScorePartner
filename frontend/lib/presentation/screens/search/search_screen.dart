import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../profile/player_profile_screen.dart';
import 'dart:math';
import '../tournament/tournament_details_screen.dart';
import '../matches/match_detail_screen.dart';
import '../matches/live_scoring_screen.dart';
import '../../widgets/state/scorepartner_skeleton.dart';
import '../../widgets/state/scorepartner_empty_state.dart';
import '../../widgets/state/scorepartner_error_state.dart';

/// Search screen to search for tournaments, players, and matches
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search tournaments, players, matches...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15.sp),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[600]),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                      tabs: const [
                        Tab(text: 'Tournaments'),
                        Tab(text: 'Players'),
                        Tab(text: 'Matches'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTournamentsTab(),
                  _buildPlayersTab(),
                  _buildMatchesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentsTab() {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState('Search tournaments by name or location', Icons.emoji_events_outlined);
    }

    return FutureBuilder<List<TournamentModel>>(
      future: FirebaseDataService.instance.searchTournaments(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: 4,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ScorePartnerSkeleton(
                width: double.infinity,
                height: 88.h,
                borderRadius: 16.r,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return ScorePartnerErrorState(message: snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No tournaments found', Icons.emoji_events_outlined);
        }

        final tournaments = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: tournaments.length,
          itemBuilder: (context, index) {
            return _buildTournamentCard(tournaments[index]);
          },
        );
      },
    );
  }

  Widget _buildTournamentCard(TournamentModel tournament) {
    Color statusColor;
    switch (tournament.status) {
      case 'live':
        statusColor = Colors.red;
        break;
      case 'upcoming':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
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
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.emoji_events, color: AppTheme.primaryOrange, size: 28.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tournament.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              tournament.status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              tournament.location,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Icon(Icons.groups_outlined, size: 14.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text(
                            '${tournament.registeredTeamIds.length} Teams',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersTab() {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState('Enter a name or SPP ID to search', Icons.person_search);
    }

    return FutureBuilder<List<UserModel>>(
      future: _searchPlayers(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: 4,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ScorePartnerSkeleton(
                width: double.infinity,
                height: 88.h,
                borderRadius: 16.r,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return ScorePartnerErrorState(message: snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No players found', Icons.person_outline);
        }

        final players = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: players.length,
          itemBuilder: (context, index) {
            return _buildPlayerCardReal(players[index]);
          },
        );
      },
    );
  }

  Future<List<UserModel>> _searchPlayers(String query) async {
    // If query looks like SPP ID, search by SPP ID first
    if (query.toUpperCase().startsWith('SPP')) {
      final user = await FirebaseDataService.instance.getUserBySppId(query.toUpperCase());
      if (user != null) {
        return [user];
      }
    }
    // Otherwise search by name
    return FirebaseDataService.instance.searchUsers(query);
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

  Widget _buildPlayerCardReal(UserModel player) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                builder: (_) => PlayerProfileScreen(player: player),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                  backgroundImage: _getProfileImageProvider(player.profileImageUrl),
                  child: player.profileImageUrl.isEmpty
                      ? Text(
                          player.name.isNotEmpty ? player.name.substring(0, 1).toUpperCase() : 'P',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                      SizedBox(height: 4.h),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (player.role.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                player.role,
                                style: TextStyle(color: Colors.blue, fontSize: 11.sp, fontWeight: FontWeight.w500),
                              ),
                            ),
                          if (player.spPId.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                player.spPId,
                                style: TextStyle(color: AppTheme.primaryOrange, fontSize: 11.sp, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${player.tennisBallStats.matches}',
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                    Text(
                      'Matches',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                    ),
                  ],
                ),
                SizedBox(width: 8.w),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState('Search matches by team names', Icons.sports_cricket);
    }

    return FutureBuilder<List<MatchModel>>(
      future: FirebaseDataService.instance.searchMatches(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: 4,
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
        
        if (snapshot.hasError) {
          return ScorePartnerErrorState(message: snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No matches found', Icons.sports_cricket);
        }

        final matches = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            return _buildMatchCard(matches[index]);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                builder: (_) => MatchDetailScreen(matchId: match.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                            child: Text(
                              match.team1Name.substring(0, min(3, match.team1Name.length)).toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            match.team1Name,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${match.team1Score.runs}/${match.team1Score.wickets}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            child: Text(
                              match.team2Name.substring(0, min(3, match.team2Name.length)).toUpperCase(),
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            match.team2Name,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${match.team2Score.runs}/${match.team2Score.wickets}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    match.status.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: ScorePartnerEmptyState(
        title: message,
        description: 'Try a different search term.',
        icon: icon,
      ),
    );
  }
}
