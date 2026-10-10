import 'package:flutter/material.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        color: ThemeHelper.of(context).cardBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
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
                          color: ThemeHelper.of(context).cardBg,
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
                    color: ThemeHelper.of(context).textSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Expanded(child: Text(match.team1Name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp))),
                     Text('vs', style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontWeight: FontWeight.bold)),
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

  Widget _buildTournamentCard(TournamentModel tournament) {
    Color statusColor;
    String statusText;

    switch (tournament.effectiveStatus) {
      case 'ongoing':
        statusColor = const Color(0xFF4CAF50);
        statusText = 'ONGOING';
        break;
      case 'upcoming':
        statusColor = const Color(0xFF00BFFF);
        statusText = 'UPCOMING';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'COMPLETED';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: ThemeHelper.of(context).cardBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailsScreen(tournament: tournament)));
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
                    Container(
                      width: 50.w,
                      height: 50.h,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.emoji_events, color: ThemeHelper.of(context).cardBg, size: 24.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tournament.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: ThemeHelper.of(context).cardBg,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14.sp, color: ThemeHelper.of(context).textSecondary),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  tournament.location,
                                  style: TextStyle(fontSize: 12.sp, color: ThemeHelper.of(context).textSecondary),
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
                    _buildInfoChip(Icons.calendar_today_outlined, '${tournament.startDate.day}/${tournament.startDate.month}'),
                    _buildInfoChip(Icons.groups_outlined, '${tournament.registeredTeamsCount}/${tournament.maxTeams} Teams'),
                    _buildInfoChip(Icons.sports_cricket_outlined, '${tournament.overs} Overs'),
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
        Icon(icon, size: 14.sp, color: ThemeHelper.of(context).textSecondary),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp),
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
                color: ThemeHelper.of(context).dividerColor!,
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
