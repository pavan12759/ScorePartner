import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'create_tournament_screen.dart';
import 'tournament_details_screen.dart';

/// Screen to view and manage user's tournaments
class MyTournamentsScreen extends StatefulWidget {
  const MyTournamentsScreen({super.key});

  @override
  State<MyTournamentsScreen> createState() => _MyTournamentsScreenState();
}

class _MyTournamentsScreenState extends State<MyTournamentsScreen> {
  List<TournamentModel> _tournaments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      // Fetch ONLY tournaments created by the user
      final createdTournaments = await FirebaseDataService.instance.getUserTournaments(user.uid);
      
      if (mounted) {
        setState(() {
          _tournaments = createdTournaments
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TournamentModel> get _filteredTournaments {
    if (_searchQuery.isEmpty) return _tournaments;
    final query = _searchQuery.toLowerCase();
    return _tournaments.where((t) => 
      t.name.toLowerCase().contains(query) ||
      t.location.toLowerCase().contains(query)
    ).toList();
  }

  List<TournamentModel> get _liveTournaments => 
      _filteredTournaments.where((t) => t.effectiveStatus == 'ongoing' || t.effectiveStatus == 'upcoming').toList();
  
  List<TournamentModel> get _pastTournaments => 
      _filteredTournaments.where((t) => t.effectiveStatus == 'completed').toList();

  void _navigateToCreateTournament() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
    );
    if (result == true) _loadTournaments();
  }

  void _navigateToTournamentDetails(TournamentModel tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDetailsScreen(tournament: tournament),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.primaryOrange),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'My Tournaments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
              fontSize: 20.sp,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: AppTheme.primaryOrange),
              onPressed: _navigateToCreateTournament,
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.primaryOrange,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Live & Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
            : TabBarView(
                children: [
                  _buildTournamentList(_liveTournaments, false),
                  _buildTournamentList(_pastTournaments, true),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToCreateTournament,
          backgroundColor: AppTheme.primaryOrange,
          icon: Icon(Icons.add, color: Colors.white),
          label: const Text('Create', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildTournamentList(List<TournamentModel> tournaments, bool isPast) {
    if (tournaments.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: _loadTournaments,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: tournaments.length,
        itemBuilder: (context, index) {
          final tournament = tournaments[index];
          return _buildTournamentCard(tournament);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.emoji_events_outlined, size: 64.sp, color: AppTheme.primaryOrange),
          ),
          SizedBox(height: 24.h),
          Text(
            _searchQuery.isNotEmpty ? 'NO RESULTS' : 'NO TOURNAMENTS',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try a different search term'
                : 'Create your first tournament',
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
          if (_searchQuery.isEmpty) ...[
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: _navigateToCreateTournament,
              icon: Icon(Icons.add),
              label: const Text('CREATE TOURNAMENT'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentCard(TournamentModel tournament) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToTournamentDetails(tournament),
          borderRadius: BorderRadius.circular(24.r),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon/Logo
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.emoji_events, color: Colors.white, size: 28.sp),
                    ),
                    SizedBox(width: 16.w),
                    
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        tournament.name.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 14.sp,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Icon(Icons.remove_red_eye, color: Colors.white54, size: 12.sp),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${tournament.views}',
                                      style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(tournament.effectiveStatus).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(100.r),
                                  border: Border.all(color: _getStatusColor(tournament.effectiveStatus).withOpacity(0.5)),
                                ),
                                child: Text(
                                  tournament.effectiveStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    color: _getStatusColor(tournament.effectiveStatus),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14.sp, color: Colors.white38),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  tournament.location,
                                  style: TextStyle(fontSize: 12.sp, color: Colors.white54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'By ${tournament.organizerName}',
                            style: TextStyle(fontSize: 11.sp, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                Container(
                  margin: EdgeInsets.symmetric(vertical: 16.h),
                  height: 1.h,
                  color: Colors.white.withOpacity(0.05),
                ),
                
                // Footer Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFooterStat(Icons.calendar_today_outlined, 
                      '${tournament.startDate.day}/${tournament.startDate.month}', 'Start'),
                    _buildFooterStat(Icons.groups_outlined, 
                      '${tournament.registeredTeamsCount}/${tournament.maxTeams}', 'Teams'),
                    _buildFooterStat(Icons.sports_cricket_outlined, 
                      '${tournament.overs}', 'Overs'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppTheme.primaryOrange),
        SizedBox(width: 6.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: Colors.white)),
            Text(label, style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return const Color(0xFF4CAF50); // Green for live
      case 'upcoming':
        return const Color(0xFF00BFFF); // Bright cyan
      case 'completed':
        return Colors.white54;
      default:
        return AppTheme.primaryOrange;
    }
  }
}
