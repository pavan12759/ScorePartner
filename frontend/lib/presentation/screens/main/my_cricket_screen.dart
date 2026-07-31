import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../matches/match_detail_screen.dart';


class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<MatchModel> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final dataService = FirebaseDataService.instance;
    
    // Get played matches ONLY (where user is a player)
    final playedMatches = await dataService.getUserPlayedMatches(userId);
    
    // Get user's teams to fetch tournament matches
    final userTeams = await dataService.getUserTeams(userId);
    final teamIds = userTeams.map((t) => t.id).toList();
    
    // Get tournament matches where user's teams are playing
    List<MatchModel> tournamentMatches = [];
    if (teamIds.isNotEmpty) {
      tournamentMatches = await dataService.getPlayerTournamentMatches(userId, teamIds);
    }
    
    // Merge and deduplicate
    final matchIds = <String>{};
    final allMatches = <MatchModel>[];
    
    for (var m in [...playedMatches, ...tournamentMatches]) {
      if (!matchIds.contains(m.id)) {
        matchIds.add(m.id);
        allMatches.add(m);
      }
    }
    
    // Sort - prioritize live, then upcoming. 
    // We are only showing Live and Upcoming in this player view as per request.
    allMatches.sort((a, b) {
      final statusOrder = {'live': 0, 'ongoing': 0, 'scheduled': 1, 'upcoming': 1, 'completed': 2};
      final aOrder = statusOrder[a.status] ?? 3;
      final bOrder = statusOrder[b.status] ?? 3;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return b.createdAt.compareTo(a.createdAt);
    });
    
    if (mounted) {
      setState(() {
        _matches = allMatches;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MatchModel> get _filteredMatches {
    if (_searchQuery.isEmpty) return _matches;
    return _matches.where((m) =>
      m.matchName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      m.team1Name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      m.team2Name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Live, Past
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
        title: Text(
          'My Cricket',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () => _showNotifications(context),
          ),
        ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(110),
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search my matches...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20.sp),
                        suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[500], size: 18.sp),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                ),
                // Tabs
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryOrange,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                    tabs: const [
                      Tab(text: 'Live'),
                      Tab(text: 'Past'),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : TabBarView(
          children: [
            _buildMatchList('live'),
            _buildMatchList('completed'),
          ],
        ),
        // No FloatingActionButton
      ),
    );
  }

  Widget _buildMatchList(String status) {
    // Filter matches by status
    List<MatchModel> matches;
    
    if (status == 'live') {
      // Live tab: include 'live' and 'ongoing' statuses
      matches = _filteredMatches.where((m) => 
        m.status == 'live' || m.status == 'ongoing'
      ).toList();
    } else if (status == 'scheduled') {
      // Upcoming tab: include 'scheduled', 'upcoming', 'pending' statuses
      matches = _filteredMatches.where((m) => 
        m.status == 'scheduled' || 
        m.status == 'upcoming' || 
        m.status == 'pending' || 
        m.status == 'not_started'
      ).toList();
    } else {
      // Past/Completed tab
      matches = _filteredMatches.where((m) => m.status == 'completed').toList();
    }
    
    if (matches.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: matches.length,
      itemBuilder: (context, index) => _buildMatchCard(matches[index]),
    );
  }

  Widget _buildEmptyState(String status) {
    IconData icon;
    String title;
    String subtitle;

    switch (status) {
      case 'live':
      case 'ongoing':
        icon = Icons.sports_cricket_outlined;
        title = 'No live matches';
        subtitle = 'Matches you are playing in will appear here';
        break;
      case 'scheduled':
      case 'upcoming':
        icon = Icons.event_outlined;
        title = 'No upcoming matches';
        subtitle = 'Scheduled matches you play in will appear here';
        break;
      default:
        icon = Icons.history;
        title = 'No past matches';
        subtitle = 'Completed matches you played in will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48.sp, color: Colors.grey[400]),
          ),
          SizedBox(height: 20.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    Color statusColor;
    String statusText;

    switch (match.status) {
      case 'live':
      case 'ongoing':
        statusColor = AppTheme.primaryOrange;
        statusText = 'LIVE';
        break;
      case 'scheduled':
      case 'upcoming':
        statusColor = Colors.blue;
        statusText = 'UPCOMING';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'COMPLETED';
    }
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    bool isCreator = match.createdBy == userId;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: match.id)));
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Creator badge
                    if (isCreator)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.admin_panel_settings, size: 12.sp, color: AppTheme.primaryOrange),
                            SizedBox(width: 4.w),
                            Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  match.matchName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Expanded(child: Text(match.team1Name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp))),
                     Text('vs', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
                     Expanded(child: Text(match.team2Name, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp))),
                  ],
                ),
                 SizedBox(height: 8.h),
                 if (match.status != 'scheduled' && match.status != 'upcoming')
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text('${match.team1Score.runs}/${match.team1Score.wickets} (${match.team1Score.overs})', style: TextStyle(fontWeight: FontWeight.w600)),
                         Text('${match.team2Score.runs}/${match.team2Score.wickets} (${match.team2Score.overs})', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                   ),
                 
                 SizedBox(height: 12.h),
                 Row(
                   children: [
                     _buildInfoChip(Icons.location_on_outlined, match.location),
                     SizedBox(width: 16.w),
                     _buildInfoChip(Icons.calendar_today_outlined, '${match.scheduledDate.day}/${match.scheduledDate.month}'),
                   ],
                 ),
               ],
             ),
           ),
         ),
       ),
     );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: Colors.grey[600]),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                    'Notifications',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: Text('Mark all read', style: TextStyle(color: AppTheme.primaryOrange)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  _buildNotificationItem(
                    'Tournament Invite',
                    'You have been invited to join Street Cricket Championship',
                    '2 hours ago',
                    Icons.emoji_events,
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    'Match Starting Soon',
                    'Your match starts in 30 minutes',
                    '5 hours ago',
                    Icons.sports_cricket,
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    'New Team Request',
                    'Eagles FC wants to join your tournament',
                    '1 day ago',
                    Icons.group_add,
                    isUnread: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String message, String time, IconData icon, {bool isUnread = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isUnread ? AppTheme.primaryOrange.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: isUnread ? Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 20.sp),
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
                        title,
                        style: TextStyle(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
