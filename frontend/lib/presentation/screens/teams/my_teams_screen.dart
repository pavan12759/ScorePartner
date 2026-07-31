import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/team_logo_widget.dart';
import 'create_team_screen.dart';
import 'team_details_screen.dart';


/// Screen to display user's teams
class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  List<TeamModel> _teams = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;
      final spPId = authProvider.user?.spPId;

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please login to view your teams';
        });
        return;
      }

      // Fetch teams where user is captain
      final captainTeams = await FirebaseDataService.instance.getUserTeams(userId);
      
      // Fetch teams where user is a player member
      final playerTeams = await FirebaseDataService.instance.getTeamsWhereUserIsPlayer(userId, spPId);

      // Merge and deduplicate
      final teamIds = <String>{};
      final allTeams = <TeamModel>[];
      
      for (var team in [...captainTeams, ...playerTeams]) {
        if (!teamIds.contains(team.id)) {
          teamIds.add(team.id);
          allTeams.add(team);
        }
      }
      
      // Sort by creation date
      allTeams.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _teams = allTeams;
        _isLoading = false;
      });

      // Recalculate stats for all teams in the background, then refresh
      _recalculateAllTeamStats(allTeams);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading teams: $e';
      });
    }
  }

  /// Recalculate stats for all teams from match history, then refresh the list
  Future<void> _recalculateAllTeamStats(List<TeamModel> teams) async {
    final ds = FirebaseDataService.instance;
    // Recalculate in parallel
    await Future.wait(teams.map((t) => ds.recalculateTeamStats(t.id)));

    // Re-fetch updated teams so UI refreshes
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final spPId = authProvider.user?.spPId;
    if (userId == null) return;

    final captainTeams = await ds.getUserTeams(userId);
    final playerTeams = await ds.getTeamsWhereUserIsPlayer(userId, spPId);

    final teamIds = <String>{};
    final allTeams = <TeamModel>[];
    for (var team in [...captainTeams, ...playerTeams]) {
      if (!teamIds.contains(team.id)) {
        teamIds.add(team.id);
        allTeams.add(team);
      }
    }
    allTeams.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() => _teams = allTeams);
    }
  }

  void _navigateToCreateTeam() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
    );

    if (result != null && result is TeamModel) {
      setState(() => _teams.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryOrange),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Teams',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryOrange),
            onPressed: _loadTeams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : _errorMessage != null
              ? _buildErrorState()
              : _teams.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadTeams,
                      color: AppTheme.primaryOrange,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _teams.length,
                        itemBuilder: (context, index) => _buildTeamCard(_teams[index]),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTeam,
        backgroundColor: AppTheme.primaryOrange,
        icon: Icon(Icons.add, color: Colors.white),
        label: const Text('Create Team', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text(_errorMessage!, textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadTeams,
            child: const Text('Retry'),
          ),
        ],
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
            child: Icon(
              Icons.groups,
              size: 64.sp,
              color: AppTheme.primaryOrange,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'NO TEAMS YET',
            style: TextStyle(
              fontSize: 24.sp, 
              fontWeight: FontWeight.w900, 
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Create your first team to join tournaments',
            style: TextStyle(fontSize: 14.sp, color: Colors.white60),
          ),
          SizedBox(height: 32.h),
          ElevatedButton.icon(
            onPressed: _navigateToCreateTeam,
            icon: Icon(Icons.add),
            label: const Text('CREATE TEAM'),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(TeamModel team) {
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
      child: Column(
        children: [
          // Card Header
          Container(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                TeamLogoWidget(
                  teamName: team.name,
                  logoUrl: team.logoUrl,
                  size: 56.sp,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Captain: ${team.captainName}',
                        style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                      ),
                      if (team.viceCaptainName.isNotEmpty)
                        Text(
                          'Vice-Captain: ${team.viceCaptainName}',
                          style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                        ),
                      if (team.matchesPlayed > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            'P: ${team.matchesPlayed}  W: ${team.matchesWon}  L: ${team.matchesLost}',
                            style: TextStyle(color: Colors.white60, fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100.r),
                    border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.5)),
                  ),
                  child: Text(
                    '${team.players.length} Players',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            height: 1.h,
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            color: Colors.white.withOpacity(0.05),
          ),
          
          // Stats Row
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Played', '${team.matchesPlayed}', Icons.sports_cricket),
                Container(width: 1.w, height: 40.h, color: Colors.white.withOpacity(0.1)),
                _buildStatItem('Won', '${team.matchesWon}', Icons.emoji_events),
                Container(width: 1.w, height: 40.h, color: Colors.white.withOpacity(0.1)),
                _buildStatItem('Lost', '${team.matchesLost}', Icons.trending_down),
              ],
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamDetailsScreen(team: team),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100.r)),
                    ),
                    child: Text('VIEW DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TournamentListScreen(team: team),
                        ),
                      );
                    },
                    child: Text('JOIN', style: TextStyle(fontSize: 12.sp)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTeamQR(TeamModel team) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Container(
          width: 320.w, // Explicit width for stability on Web
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                team.name,
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'ID: ${team.spTId}',
                style: TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: QrImageView(
                  data: team.spTId,
                  version: QrVersions.auto,
                  size: 200.0.sp,
                  foregroundColor: const Color(0xFFFF6B35),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Scan to Join Team',
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20.sp, color: AppTheme.primaryOrange),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: Colors.white54),
        ),
      ],
    );
  }
}

/// Screen to browse and join tournaments
class TournamentListScreen extends StatelessWidget {
  final TeamModel team;

  const TournamentListScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    // Mock tournaments
    final tournaments = [
      TournamentModel(
        id: '1',
        name: 'Gully Premier League 2024',
        description: 'Annual street cricket championship',
        organizerId: 'org1',
        organizerName: 'Local Cricket Club',
        location: 'Mumbai',
        startDate: DateTime.now().add(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 14)),
        maxTeams: 16,
        registeredTeamIds: ['team1', 'team2', 'team3'],
        overs: 10,
        prizePool: 50000,
      ),
      TournamentModel(
        id: '2',
        name: 'Night Cricket Challenge',
        description: 'Play under the lights',
        organizerId: 'org2',
        organizerName: 'City Sports',
        location: 'Delhi',
        startDate: DateTime.now().add(const Duration(days: 14)),
        endDate: DateTime.now().add(const Duration(days: 21)),
        maxTeams: 8,
        registeredTeamIds: ['team1'],
        overs: 6,
        prizePool: 25000,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Join Tournament'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: tournaments.length,
        itemBuilder: (context, index) {
          final tournament = tournaments[index];
          return _buildTournamentCard(context, tournament);
        },
      ),
    );
  }

  Widget _buildTournamentCard(BuildContext context, TournamentModel tournament) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.white, size: 32.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tournament.location,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${tournament.overs} Overs',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.description, style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(Icons.groups, '${tournament.registeredTeamsCount}/${tournament.maxTeams} Teams'),
                    _buildInfoChip(Icons.calendar_today, '${tournament.startDate.day}/${tournament.startDate.month}'),
                    _buildInfoChip(Icons.attach_money, '₹${tournament.prizePool.toInt()}'),
                  ],
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: tournament.isFull
                        ? null
                        : () {
                            // Register team
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${team.name} registered for ${tournament.name}! 🏏'),
                                backgroundColor: const Color(0xFFFF6B35),
                              ),
                            );
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text(
                      tournament.isFull ? 'Tournament Full' : 'Register ${team.name}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey[600]),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12.sp)),
        ],
      ),
    );
  }
}
