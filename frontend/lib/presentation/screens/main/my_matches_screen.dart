import 'package:flutter/material.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../matches/match_detail_screen.dart';
import '../tournament/tournament_details_screen.dart';
import '../teams/team_details_screen.dart';
import '../teams/create_team_screen.dart';
import '../../widgets/team_logo_widget.dart';

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
  List<TournamentModel> _tournaments = [];
  List<TeamModel> _teams = [];
  String? _currentUserId;
  String? _currentUserSpPId;
  final Map<String, TeamModel?> _teamCache = {};

  Future<TeamModel?> _getTeam(String teamId) async {
    if (teamId.isEmpty) return null;
    if (_teamCache.containsKey(teamId)) return _teamCache[teamId];
    for (final t in _teams) {
      if (t.id == teamId) {
        _teamCache[teamId] = t;
        return t;
      }
    }
    try {
      final team = await FirebaseDataService.instance.getTeamById(teamId);
      _teamCache[teamId] = team;
      return team;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final dataService = FirebaseDataService.instance;
    final userModel = await dataService.getUserById(userId);
    final spPId = userModel?.spPId ?? '';
    
    // Get played matches ONLY (where user is a player)
    final playedMatches = await dataService.getUserPlayedMatches(userId);
    
    // Fetch tournaments created by user
    final createdTournaments = await dataService.getUserTournaments(userId);
    
    // Get user's teams to fetch tournament matches & tournaments
    final userTeams = await dataService.getUserTeams(userId);
    final playerTeams = spPId.isNotEmpty ? await dataService.getTeamsWhereUserIsPlayer(userId, spPId) : [];
    
    // Merge and deduplicate player's teams (captain teams + member player teams)
    final teamIdsSet = <String>{};
    final allTeams = <TeamModel>[];
    for (var t in [...userTeams, ...playerTeams]) {
      if (!teamIdsSet.contains(t.id)) {
        teamIdsSet.add(t.id);
        allTeams.add(t);
      }
    }
    allTeams.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Combine team IDs
    final allTeamIds = allTeams.map((t) => t.id).toList();
    
    // Get tournament matches where user's teams are playing
    List<MatchModel> tournamentMatches = [];
    List<TournamentModel> playerTournaments = [];
    
    if (allTeamIds.isNotEmpty) {
      tournamentMatches = await dataService.getPlayerTournamentMatches(userId, allTeamIds);
      playerTournaments = await dataService.getPlayerTournaments(userId, allTeamIds);
    }
    
    // Merge created tournaments and player tournaments
    final allTournamentsMap = <String, TournamentModel>{};
    for (var t in createdTournaments) {
      allTournamentsMap[t.id] = t;
    }
    for (var t in playerTournaments) {
      allTournamentsMap[t.id] = t;
    }
    
    final allTournaments = allTournamentsMap.values.toList();
    
    // Merge and deduplicate matches
    final matchIds = <String>{};
    final allMatches = <MatchModel>[];
    
    for (var m in [...playedMatches, ...tournamentMatches]) {
      if (!matchIds.contains(m.id)) {
        matchIds.add(m.id);
        allMatches.add(m);
      }
    }
    
    // Sort - prioritize live, then upcoming, then completed. 
    allMatches.sort((a, b) {
      final statusOrder = {'live': 0, 'ongoing': 0, 'scheduled': 1, 'upcoming': 1, 'completed': 2};
      final aOrder = statusOrder[a.status] ?? 3;
      final bOrder = statusOrder[b.status] ?? 3;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return b.createdAt.compareTo(a.createdAt);
    });

    allTournaments.sort((a, b) => b.startDate.compareTo(a.startDate));
    
    if (mounted) {
      setState(() {
        _matches = allMatches;
        _tournaments = allTournaments;
        _teams = allTeams;
        _currentUserId = userId;
        _currentUserSpPId = spPId;
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

  List<TournamentModel> get _filteredTournaments {
    if (_searchQuery.isEmpty) return _tournaments;
    final query = _searchQuery.toLowerCase();
    return _tournaments.where((t) => 
      t.name.toLowerCase().contains(query) ||
      t.location.toLowerCase().contains(query)
    ).toList();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Matches, Teams, Tournaments
      child: Scaffold(
        backgroundColor: ThemeHelper.of(context).scaffoldBg,
        appBar: AppBar(
        title: Text(
          'My Cricket',
          style: TextStyle(
            color: ThemeHelper.of(context).textPrimary,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: ThemeHelper.of(context).scaffoldBg,
        centerTitle: false,
        elevation: 0,
        iconTheme: IconThemeData(color: ThemeHelper.of(context).textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: ThemeHelper.of(context).textPrimary),
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
                      color: ThemeHelper.of(context).dividerColor!,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search...',
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
                // Tabs
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeHelper.of(context).dividerColor!,
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
                    unselectedLabelColor: ThemeHelper.of(context).textSecondary,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
                    labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
                    tabs: const [
                      Tab(text: 'Matches'),
                      Tab(text: 'Teams'),
                      Tab(text: 'Tournaments'),
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
            _buildMatchList(),
            _buildTeamList(),
            _buildTournamentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchList() {
    final matches = _filteredMatches;
    
    if (matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppTheme.primaryOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            alignment: Alignment.center,
            child: _buildEmptyState('matches'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppTheme.primaryOrange,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: matches.length,
        itemBuilder: (context, index) => _buildMatchCard(matches[index]),
      ),
    );
  }

  Widget _buildTournamentList() {
    final tournaments = _filteredTournaments;
    
    if (tournaments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppTheme.primaryOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            alignment: Alignment.center,
            child: _buildEmptyState('tournaments'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppTheme.primaryOrange,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tournaments.length,
        itemBuilder: (context, index) => _buildTournamentCard(tournaments[index]),
      ),
    );
  }

  Widget _buildTeamList() {
    final teams = _filteredTeams;

    if (teams.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppTheme.primaryOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            alignment: Alignment.center,
            child: _buildEmptyState('teams'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppTheme.primaryOrange,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: teams.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h, top: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${teams.length} ${teams.length == 1 ? "Team" : "Teams"}',
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
          return _buildTeamCard(teams[index - 1]);
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    IconData icon;
    String title;
    String subtitle;

    if (type == 'matches') {
      icon = Icons.sports_cricket_outlined;
      title = 'No matches found';
      subtitle = 'Matches you are playing in will appear here';
    } else if (type == 'teams') {
      icon = Icons.groups_outlined;
      title = 'No teams found';
      subtitle = 'Teams you created or joined as a player will appear here';
    } else {
      icon = Icons.emoji_events_outlined;
      title = 'No tournaments found';
      subtitle = 'Tournaments you participate in will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: ThemeHelper.of(context).dividerColor!,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48.sp, color: ThemeHelper.of(context).textSecondary),
          ),
          SizedBox(height: 20.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.of(context).textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 14.sp),
            ),
          ),
          if (type == 'teams') ...[
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: _navigateToCreateTeam,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              icon: Icon(Icons.add, size: 18.sp),
              label: Text(
                'Create Team',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
            ),
          ],
        ],
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
            ).then((_) => _fetchData());
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              if (team.spTId.isNotEmpty)
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

  void _navigateToCreateTeam() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
    );
    if (result != null) {
      _fetchData();
    }
  }

  Widget _buildMatchCard(MatchModel match) {
    final th = ThemeHelper.of(context);
    final userId = _currentUserId;
    final bool isCreator = match.createdBy == userId || match.adminIds.contains(userId);
    
    final statusLower = match.status.toLowerCase();
    final bool isLive = statusLower == 'live' || statusLower == 'ongoing';
    final bool isUpcoming = statusLower == 'scheduled' || statusLower == 'upcoming';
    final bool isCompleted = !isLive && !isUpcoming;

    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    if (isLive) {
      statusColor = const Color(0xFFE53935);
      statusBgColor = const Color(0xFFE53935).withOpacity(0.12);
      statusText = 'LIVE';
      statusIcon = Icons.fiber_manual_record;
    } else if (isUpcoming) {
      statusColor = const Color(0xFF1E88E5);
      statusBgColor = const Color(0xFF1E88E5).withOpacity(0.12);
      statusText = 'UPCOMING';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = const Color(0xFF2E7D32);
      statusBgColor = const Color(0xFF2E7D32).withOpacity(0.12);
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    final isTeam1Batting = isLive && (match.currentBattingTeam == 'team1' || match.currentBattingTeam == match.team1Id || match.currentBattingTeam == match.team1Name);
    final isTeam2Batting = isLive && (match.currentBattingTeam == 'team2' || match.currentBattingTeam == match.team2Id || match.currentBattingTeam == match.team2Name);

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
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
              MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: match.id)),
            ).then((_) => _fetchData());
          },
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Status badge, Format, Admin badge
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLive) ...[
                            Container(
                              width: 7.w,
                              height: 7.h,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 5.w),
                          ] else ...[
                            Icon(statusIcon, size: 12.sp, color: statusColor),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Format badge (T20 / 20 Ov)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: th.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Text(
                        match.oversPerSide > 0 
                            ? '${match.matchFormat.isNotEmpty ? match.matchFormat : "Match"} • ${match.oversPerSide} Ov'
                            : (match.matchFormat.isNotEmpty ? match.matchFormat : 'Match'),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: th.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Admin badge
                    if (isCreator)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.admin_panel_settings, size: 12.sp, color: AppTheme.primaryOrange),
                            SizedBox(width: 3.w),
                            Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),

                // 2. Teams & Scores Card Container
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Column(
                    children: [
                      // Team 1 Row
                      _buildMatchTeamScoreRow(
                        teamId: match.team1Id,
                        teamName: match.team1Name,
                        score: match.team1Score,
                        isBatting: isTeam1Batting,
                        isUpcoming: isUpcoming,
                        isWinner: isCompleted && (match.winnerTeam == match.team1Name || match.winnerTeamId == match.team1Id),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: th.dividerColor.withOpacity(0.6),
                        ),
                      ),
                      // Team 2 Row
                      _buildMatchTeamScoreRow(
                        teamId: match.team2Id,
                        teamName: match.team2Name,
                        score: match.team2Score,
                        isBatting: isTeam2Batting,
                        isUpcoming: isUpcoming,
                        isWinner: isCompleted && (match.winnerTeam == match.team2Name || match.winnerTeamId == match.team2Id),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // 3. Equation / Result Banner Strip
                _buildMatchEquationStrip(match, isLive, isUpcoming, isCompleted),
                SizedBox(height: 8.h),

                // 4. Downside: Tournament Name (prominent and fully visible)
                if (match.tournamentName != null && match.tournamentName!.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.emoji_events, size: 13.sp, color: Colors.amber[700]),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          (match.matchName.isNotEmpty && match.matchName != '${match.team1Name} vs ${match.team2Name}')
                              ? '${match.tournamentName!.trim()} • ${match.matchName}'
                              : match.tournamentName!.trim(),
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            color: th.isDark ? Colors.amber[300] : const Color(0xFFD97706),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                ] else if (match.matchName.isNotEmpty && match.matchName != '${match.team1Name} vs ${match.team2Name}') ...[
                  Row(
                    children: [
                      Icon(Icons.sports_cricket, size: 12.sp, color: th.textSecondary),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          match.matchName,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: th.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                ],

                // 5. Footer: Venue & Date & Arrow
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14.sp, color: th.textSecondary),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                match.ground.isNotEmpty 
                                    ? (match.location.isNotEmpty ? '${match.ground}, ${match.location}' : match.ground)
                                    : (match.location.isNotEmpty ? match.location : 'Cricket Ground'),
                                style: TextStyle(fontSize: 12.sp, color: th.textSecondary),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13.sp, color: th.textSecondary),
                        SizedBox(width: 4.w),
                        Text(
                          DateFormat('d MMM').format(match.scheduledDate),
                          style: TextStyle(fontSize: 12.sp, color: th.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12.sp, color: th.textSecondary.withOpacity(0.7)),
                      ],
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

  Widget _buildMatchTeamScoreRow({
    required String teamId,
    required String teamName,
    required TeamScore score,
    required bool isBatting,
    required bool isUpcoming,
    required bool isWinner,
  }) {
    final th = ThemeHelper.of(context);
    return FutureBuilder<TeamModel?>(
      future: _getTeam(teamId),
      builder: (context, snapshot) {
        final team = snapshot.data;
        final hasProfile = team != null;
        final logoUrl = team?.logoUrl;

        void navigateToTeamProfile() {
          if (team != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TeamDetailsScreen(team: team)),
            ).then((_) => _fetchData());
          }
        }

        return Row(
          children: [
            // Team Logo / Profile Picture
            GestureDetector(
              onTap: hasProfile ? navigateToTeamProfile : null,
              child: TeamLogoWidget(
                teamName: teamName,
                logoUrl: logoUrl,
                size: 34.sp,
              ),
            ),
            SizedBox(width: 10.w),
            // Team Name & Badges
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasProfile ? navigateToTeamProfile : null,
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          teamName,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: isWinner || isBatting ? FontWeight.w800 : FontWeight.w600,
                            color: isWinner ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange) : th.textPrimary,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (isWinner) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.emoji_events, size: 14.sp, color: Colors.amber),
                    ],
                    if (isBatting) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_cricket, size: 11.sp, color: AppTheme.primaryOrange),
                            SizedBox(width: 3.w),
                            Text(
                              'Batting',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // Score Display
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: isUpcoming
                  ? Text(
                      '-',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: th.textSecondary,
                      ),
                    )
                  : (!isBatting && score.runs == 0 && score.wickets == 0 && score.overs == 0.0)
                      ? Text(
                          'Yet to bat',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: th.textSecondary.withOpacity(0.85),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${score.runs}/${score.wickets}',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: isWinner ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange) : th.textPrimary,
                              ),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              '(${score.overs} ov)',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: th.textSecondary,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMatchEquationStrip(MatchModel match, bool isLive, bool isUpcoming, bool isCompleted) {
    String message;
    IconData icon;
    Color color;

    if (isLive) {
      color = AppTheme.primaryOrange;
      if (match.currentInnings == 2 && match.target != null && match.target! > 0) {
        final runsReq = match.runsRequired;
        final ballsRem = match.ballsRemaining;
        if (runsReq <= 0) {
          message = 'Scores level! Need 1 run to win';
        } else if (ballsRem > 0) {
          message = 'Need $runsReq off $ballsRem balls (Target: ${match.target})';
        } else {
          message = 'Target: ${match.target} • Match in balance';
        }
      } else if (match.currentRunRate > 0) {
        message = 'CRR: ${match.currentRunRate.toStringAsFixed(2)} • 1st Innings ongoing';
      } else {
        message = 'Match in progress';
      }
      icon = Icons.sports_cricket_outlined;
    } else if (isCompleted) {
      color = const Color(0xFF2E7D32);
      final winner = match.winnerTeam;
      final margin = match.winningMargin;
      if (winner == 'Match Tied') {
        message = 'Match Tied';
      } else if (winner != null && winner.isNotEmpty) {
        message = margin.isNotEmpty ? '$winner won by $margin' : '$winner won';
      } else if (match.result != null && match.result!.winner.isNotEmpty) {
        message = match.result!.margin.isNotEmpty 
            ? '${match.result!.winner} won by ${match.result!.margin}' 
            : '${match.result!.winner} won';
      } else {
        message = 'Match Completed';
      }
      icon = Icons.emoji_events_rounded;
    } else {
      color = const Color(0xFF1976D2);
      message = 'Scheduled • ${DateFormat('EEE, d MMM, h:mm a').format(match.scheduledDate)}';
      icon = Icons.event_available_outlined;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (isCompleted && match.result?.manOfMatch != null && match.result!.manOfMatch.isNotEmpty) ...[
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                'POTM: ${match.result!.manOfMatch}',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentCard(TournamentModel tournament) {
    final th = ThemeHelper.of(context);
    final userId = _currentUserId;
    final bool isOrganizer = tournament.organizerId == userId || tournament.adminIds.contains(userId);

    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    switch (tournament.effectiveStatus.toLowerCase()) {
      case 'ongoing':
        statusColor = const Color(0xFF2E7D32);
        statusBgColor = const Color(0xFF2E7D32).withOpacity(0.12);
        statusText = 'ONGOING';
        statusIcon = Icons.fiber_manual_record;
        break;
      case 'upcoming':
        statusColor = const Color(0xFF0288D1);
        statusBgColor = const Color(0xFF0288D1).withOpacity(0.12);
        statusText = 'UPCOMING';
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = Colors.grey[700]!;
        statusBgColor = Colors.grey.withOpacity(0.12);
        statusText = 'COMPLETED';
        statusIcon = Icons.check_circle_outline_rounded;
    }

    final double fillPercent = tournament.maxTeams > 0
        ? (tournament.registeredTeamsCount / tournament.maxTeams).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
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
              MaterialPageRoute(builder: (_) => TournamentDetailsScreen(tournament: tournament)),
            ).then((_) => _fetchData());
          },
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tournament.effectiveStatus.toLowerCase() == 'ongoing') ...[
                            Container(
                              width: 7.w,
                              height: 7.h,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 5.w),
                          ] else ...[
                            Icon(statusIcon, size: 12.sp, color: statusColor),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Ball type badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: th.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Text(
                        tournament.ballType.toLowerCase() == 'leather' ? '🏏 Leather' : '🎾 Tennis',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: th.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    // Format badge
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: th.dividerColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${tournament.overs} Ov • ${tournament.format.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: th.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Organizer badge
                    if (isOrganizer)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 12.sp, color: AppTheme.primaryOrange),
                            SizedBox(width: 3.w),
                            Text(
                              'Organizer',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 14.h),

                // 2. Identity Row: Trophy Logo + Name + Organizer + Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trophy / Logo Emblem
                    Container(
                      width: 52.w,
                      height: 52.h,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              tournament.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16.sp,
                                color: th.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 13.sp, color: th.textSecondary),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'By ${tournament.organizerName.isNotEmpty ? tournament.organizerName : "ScorePartner"}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: th.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 13.sp, color: th.textSecondary),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    tournament.location.isNotEmpty ? tournament.location : 'Cricket Venue',
                                    style: TextStyle(fontSize: 12.sp, color: th.textSecondary),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

                // 3. Stats & Fill Progress Strip
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Dates
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_outlined, size: 14.sp, color: th.textSecondary),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${DateFormat('d MMM').format(tournament.startDate)} - ${DateFormat('d MMM').format(tournament.endDate)}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: th.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          // Teams Slot Count
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.groups_outlined, size: 15.sp, color: AppTheme.primaryOrange),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${tournament.registeredTeamsCount}/${tournament.maxTeams} Teams',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: th.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      // Mini Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: fillPercent,
                          minHeight: 5.h,
                          backgroundColor: th.dividerColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            fillPercent >= 1.0 ? Colors.green : AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                      if (tournament.prizePool > 0 || tournament.entryFee > 0) ...[
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (tournament.prizePool > 0)
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Icon(Icons.military_tech_outlined, size: 14.sp, color: Colors.amber[700]),
                                      SizedBox(width: 3.w),
                                      Text(
                                        'Prize Pool: ₹${tournament.prizePool.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tournament.entryFee > 0 
                                      ? 'Entry: ₹${tournament.entryFee.toStringAsFixed(0)}' 
                                      : 'Free Entry',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: tournament.entryFee > 0 ? th.textSecondary : Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 10.h),

                // 4. Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_outlined, size: 14.sp, color: th.textSecondary),
                            SizedBox(width: 4.w),
                            Text(
                              '${tournament.views} views',
                              style: TextStyle(fontSize: 11.sp, color: th.textSecondary),
                            ),
                            if (tournament.matchIds.isNotEmpty) ...[
                              SizedBox(width: 8.w),
                              Text('•', style: TextStyle(color: th.textSecondary, fontSize: 11.sp)),
                              SizedBox(width: 8.w),
                              Text(
                                '${tournament.matchIds.length} matches',
                                style: TextStyle(fontSize: 11.sp, color: th.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Tournament',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.arrow_forward_rounded, size: 14.sp, color: AppTheme.primaryOrange),
                      ],
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: ThemeHelper.of(context).cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ThemeHelper.of(context).dividerColor,
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
                  style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  time,
                  style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
