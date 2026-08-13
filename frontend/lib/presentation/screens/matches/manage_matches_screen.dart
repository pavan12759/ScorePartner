import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/screens/matches/create_match_screen.dart';
import 'package:scorepatner/presentation/screens/matches/live_scoring_screen.dart';
import 'package:scorepatner/presentation/screens/matches/match_detail_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scorepatner/presentation/widgets/state/scorepartner_skeleton.dart';
import 'package:scorepatner/presentation/widgets/state/scorepartner_empty_state.dart';

class ManageMatchesScreen extends StatefulWidget {
  const ManageMatchesScreen({super.key});

  @override
  State<ManageMatchesScreen> createState() => _ManageMatchesScreenState();
}

class _ManageMatchesScreenState extends State<ManageMatchesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseDataService _dataService = FirebaseDataService.instance;
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
    
    // Get created matches ONLY
    final createdMatches = await dataService.getUserMatches(userId);
    
    // Sort created matches by date
    createdMatches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    if (mounted) {
      setState(() {
        _matches = createdMatches;
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
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
        title: Text(
          'Manage Matches',
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
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchMatches();
            },
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
                        hintText: 'Search your matches...',
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
                      Tab(text: 'Completed'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        body: _isLoading 
          ? ListView.builder(
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
            )
          : TabBarView(
          children: [
            _buildMatchList('live'),
            _buildMatchList('completed'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const CreateMatchScreen()),
            ).then((_) => _fetchMatches()); // Refresh list on return
          },
          backgroundColor: AppTheme.primaryOrange,
          child: Icon(Icons.add, color: Colors.white),
        ),
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
      // Completed tab
      matches = _filteredMatches.where((m) => m.status == status).toList();
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
        subtitle = 'Start a match to see it here.';
        break;
      case 'scheduled':
      case 'upcoming':
        icon = Icons.event_outlined;
        title = 'No upcoming matches';
        subtitle = 'Create a match to schedule it.';
        break;
      default:
        icon = Icons.history;
        title = 'No completed matches';
        subtitle = 'Completed matches will appear here.';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: ScorePartnerEmptyState(
        title: title,
        description: subtitle,
        icon: icon,
        primaryButtonText: 'Create Match',
        onPrimaryAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateMatchScreen()),
          ).then((_) => _fetchMatches());
        },
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
    
    // For admin view, we are the creator typically
    bool isCreator = true; 

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
            if (match.status == 'live' || match.status == 'ongoing') {
               Navigator.push(context, MaterialPageRoute(builder: (_) => LiveScoringScreen(matchId: match.id)));
            } else {
               Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: match.id)));
            }
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
                    // Creator badge usually implicit here, but let's keep it consistent
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
                    if (isCreator)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert, color: Colors.grey, size: 20.sp),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Match'),
                                content: const Text('Are you sure you want to delete this match? This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final success = await _dataService.deleteMatch(match.id);
                              if (success) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Match deleted')),
                                  );
                                  _fetchMatches(); // Refresh the list
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('❌ Failed to delete match')),
                                  );
                                }
                              }
                            }
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 18.sp),
                                SizedBox(width: 8.w),
                                Text('Delete Match', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
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
                 // Basic Score display if not upcoming
                 if (match.status != 'scheduled' && match.status != 'upcoming')
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text('${match.team1Score.runs}/${match.team1Score.wickets} (${match.team1Score.overs})', style: TextStyle(fontWeight: FontWeight.w600)),
                         Text('${match.team2Score.runs}/${match.team2Score.wickets} (${match.team2Score.overs})', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                   ),
                 
                 if (match.status == 'completed' && match.result != null)
                   Padding(
                     padding: EdgeInsets.only(top: 8.h),
                     child: Text(
                       '${match.result!.winner} won by ${match.result!.margin}',
                        style: TextStyle(color: AppTheme.primaryOrange, fontSize: 12.sp, fontWeight: FontWeight.bold),
                     ),
                   ),

                SizedBox(height: 12.h),
                Row(
                  children: [
                    _buildInfoChip(Icons.location_on_outlined, match.location),
                    SizedBox(width: 16.w),
                    _buildInfoChip(Icons.calendar_today_outlined, '${match.scheduledDate.day}/${match.scheduledDate.month}'),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.share, size: 20.sp, color: Colors.grey[600]),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        Share.share('Check out this match on ScorePartner: ${match.team1Name} vs ${match.team2Name}!\n\nMatch Link: https://scorepartner.in/match/${match.id}');
                      },
                    ),
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
}
