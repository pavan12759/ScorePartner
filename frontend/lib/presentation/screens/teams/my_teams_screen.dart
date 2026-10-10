import 'package:flutter/material.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<TeamModel> _teams = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  String? _currentUserSpPId;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _currentUserId = userId;
        _currentUserSpPId = spPId;
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
      setState(() {
        _teams = allTeams;
        _currentUserId = userId;
        _currentUserSpPId = spPId;
      });
    }
  }

  List<TeamModel> get _filteredTeams {
    if (_searchQuery.isEmpty) return _teams;
    final query = _searchQuery.toLowerCase();
    return _teams.where((t) =>
      t.name.toLowerCase().contains(query) ||
      t.captainName.toLowerCase().contains(query) ||
      t.viceCaptainName.toLowerCase().contains(query) ||
      t.spTId.toLowerCase().contains(query)
    ).toList();
  }

  void _navigateToCreateTeam() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
    );

    if (result != null) {
      _loadTeams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.of(context).scaffoldBg,
      appBar: AppBar(
        backgroundColor: ThemeHelper.of(context).scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryOrange),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Teams',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ThemeHelper.of(context).textPrimary,
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
              : Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: ThemeHelper.of(context).dividerColor!,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search my teams...',
                            hintStyle: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 14.sp),
                            prefixIcon: Icon(Icons.search, color: ThemeHelper.of(context).textSecondary, size: 20.sp),
                            suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: ThemeHelper.of(context).textSecondary, size: 18.sp),
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
                    Expanded(
                      child: _filteredTeams.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadTeams,
                              color: AppTheme.primaryOrange,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
                                itemCount: _filteredTeams.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 12.h, top: 4.h),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${_filteredTeams.length} ${_filteredTeams.length == 1 ? "Team" : "Teams"}',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: ThemeHelper.of(context).textSecondary,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: _navigateToCreateTeam,
                                            borderRadius: BorderRadius.circular(20.r),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryOrange.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(20.r),
                                                border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.add, size: 16.sp, color: AppTheme.primaryOrange),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    'Create Team',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryOrange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return _buildTeamCard(_filteredTeams[index - 1]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTeam,
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: ThemeHelper.of(context).textPrimary)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadTeams,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: ThemeHelper.of(context).dividerColor!,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 48.sp,
                color: ThemeHelper.of(context).textSecondary,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'No teams found',
              style: TextStyle(
                fontSize: 18.sp, 
                fontWeight: FontWeight.w600, 
                color: ThemeHelper.of(context).textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Teams you created or joined as a player will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: ThemeHelper.of(context).textSecondary),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: _navigateToCreateTeam,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Create Team',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(TeamModel team) {
    final userId = _currentUserId;
    final isCaptain = team.captainId == userId;
    TeamPlayer? playerMembership;
    for (final p in team.players) {
      if (p.userId == userId || (_currentUserSpPId != null && _currentUserSpPId!.isNotEmpty && p.spPId == _currentUserSpPId)) {
        playerMembership = p;
        break;
      }
    }
    final isPlayer = playerMembership != null;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: ThemeHelper.of(context).cardBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
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
                builder: (_) => TeamDetailsScreen(team: team),
              ),
            ).then((_) => _loadTeams());
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Logo + Name + SPT ID + Captain + Quick QR
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeamLogoWidget(
                      teamName: team.name,
                      logoUrl: team.logoUrl,
                      size: 48.sp,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  team.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: ThemeHelper.of(context).textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (team.spTId.isNotEmpty) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.25)),
                                  ),
                                  child: Text(
                                    team.spTId,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryOrange,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                              ],
                              InkWell(
                                onTap: () => _showTeamQR(team),
                                borderRadius: BorderRadius.circular(20.r),
                                child: Padding(
                                  padding: EdgeInsets.all(4.w),
                                  child: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 18.sp,
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14.sp, color: ThemeHelper.of(context).textSecondary),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  'Captain: ${team.captainName.isNotEmpty ? team.captainName : "Not assigned"}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: ThemeHelper.of(context).textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Line 2: Role badge (Captain / Player) + Squad count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (isCaptain)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12.sp, color: AppTheme.primaryOrange),
                                SizedBox(width: 4.w),
                                Text(
                                  'Captain',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isPlayer)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_cricket, size: 12.sp, color: Colors.blue),
                                SizedBox(width: 4.w),
                                Text(
                                  playerMembership.role.isNotEmpty
                                      ? 'Player • ${playerMembership.role}'
                                      : 'Player',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${team.players.length} Players',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // Line 3: Stats Pill (Played | Won | Lost | Win %)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: ThemeHelper.of(context).dividerColor!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTeamStatItem('Played', '${team.matchesPlayed}'),
                      Container(width: 1.w, height: 20.h, color: ThemeHelper.of(context).textSecondary.withOpacity(0.2)),
                      _buildTeamStatItem('Won', '${team.matchesWon}', color: Colors.green),
                      Container(width: 1.w, height: 20.h, color: ThemeHelper.of(context).textSecondary.withOpacity(0.2)),
                      _buildTeamStatItem('Lost', '${team.matchesLost}', color: Colors.redAccent),
                      if (team.matchesPlayed > 0) ...[
                        Container(width: 1.w, height: 20.h, color: ThemeHelper.of(context).textSecondary.withOpacity(0.2)),
                        _buildTeamStatItem('Win %', '${team.winPercentage.toStringAsFixed(0)}%'),
                      ],
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

  Widget _buildTeamStatItem(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color ?? ThemeHelper.of(context).textPrimary,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: ThemeHelper.of(context).textSecondary,
          ),
        ),
      ],
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
                style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: ThemeHelper.of(context).cardBg,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 10),
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
                style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 14.sp),
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
      backgroundColor: ThemeHelper.of(context).scaffoldBg,
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
                Icon(Icons.emoji_events, color: ThemeHelper.of(context).cardBg, size: 32.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: TextStyle(
                          color: ThemeHelper.of(context).cardBg,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tournament.location,
                        style: TextStyle(color: ThemeHelper.of(context).textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: ThemeHelper.of(context).cardBg.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${tournament.overs} Overs',
                    style: TextStyle(color: ThemeHelper.of(context).cardBg, fontWeight: FontWeight.bold),
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
                Text(tournament.description, style: TextStyle(color: ThemeHelper.of(context).textSecondary)),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey[600]),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
        ],
      ),
    );
  }
}
