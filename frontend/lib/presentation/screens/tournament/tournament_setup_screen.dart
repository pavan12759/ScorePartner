import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

/// Tournament Setup Screen with TabBar
/// Inspired by Cricbuzz and Crix UI
class TournamentSetupScreen extends StatefulWidget {
  final String tournamentName;
  final String tournamentId;

  const TournamentSetupScreen({
    super.key,
    this.tournamentName = 'Mahbubnagar Premier League',
    this.tournamentId = 'tournament_1',
  });

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // App Bar with Tournament Name
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.tournamentName,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 80, 16, 40),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFD700),
                          size: 32.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'T20 • Tennis Ball',
                            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                          ),
                          Text(
                            '8 Teams • 15 Matches',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFFF6B35),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
              tabs: const [
                Tab(text: 'Schedule'),
                Tab(text: 'Points Table'),
                Tab(text: 'Stats'),
                Tab(text: 'MVP Points'),
                Tab(text: 'Teams'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ScheduleTab(),
            _PointsTableTab(),
            _StatsTab(),
            _MVPPointsTab(),
            _TeamsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCHEDULE TAB - Cricbuzz Style Match Cards
// ============================================================
class _ScheduleTab extends StatelessWidget {
  final List<Map<String, dynamic>> matches = [
    {
      'id': 1,
      'team1': 'Warriors',
      'team2': 'Eagles',
      'team1Logo': '🔵',
      'team2Logo': '🟠',
      'score1': '156/4',
      'score2': '142/8',
      'overs1': '20.0',
      'overs2': '18.4',
      'status': 'completed',
      'result': 'Warriors won by 14 runs',
      'date': 'Jan 5, 2026',
      'time': '4:00 PM',
      'venue': 'Central Ground, Mahbubnagar',
    },
    {
      'id': 2,
      'team1': 'Tigers',
      'team2': 'Lions',
      'team1Logo': '🟡',
      'team2Logo': '🟤',
      'score1': '189/6',
      'score2': '192/4',
      'overs1': '20.0',
      'overs2': '19.2',
      'status': 'completed',
      'result': 'Lions won by 6 wickets',
      'date': 'Jan 6, 2026',
      'time': '4:00 PM',
      'venue': 'Sports Stadium, Mahbubnagar',
    },
    {
      'id': 3,
      'team1': 'Strikers',
      'team2': 'Blazers',
      'team1Logo': '🔴',
      'team2Logo': '🟣',
      'score1': '98/3',
      'score2': '-',
      'overs1': '12.3',
      'overs2': '-',
      'status': 'live',
      'result': 'Strikers need 67 runs',
      'date': 'Today',
      'time': 'LIVE',
      'venue': 'City Ground',
    },
    {
      'id': 4,
      'team1': 'Warriors',
      'team2': 'Lions',
      'team1Logo': '🔵',
      'team2Logo': '🟤',
      'score1': '-',
      'score2': '-',
      'overs1': '-',
      'overs2': '-',
      'status': 'upcoming',
      'result': '',
      'date': 'Jan 12, 2026',
      'time': '2:00 PM',
      'venue': 'Central Ground',
    },
    {
      'id': 5,
      'team1': 'Eagles',
      'team2': 'Tigers',
      'team1Logo': '🟠',
      'team2Logo': '🟡',
      'score1': '-',
      'score2': '-',
      'overs1': '-',
      'overs2': '-',
      'status': 'upcoming',
      'result': '',
      'date': 'Jan 13, 2026',
      'time': '4:00 PM',
      'venue': 'Sports Stadium',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(12.w),
      itemCount: matches.length,
      itemBuilder: (context, index) => _buildMatchCard(matches[index]),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final isLive = match['status'] == 'live';
    final isCompleted = match['status'] == 'completed';

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
        border: isLive ? Border.all(color: Colors.red, width: 2.w) : null,
      ),
      child: Column(
        children: [
          // Header - Date, Time, Venue
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isLive ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8.sp),
                            SizedBox(width: 4.w),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Text(
                      match['date'],
                      style: TextStyle(
                        color: isLive ? Colors.red : Colors.grey[600],
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isLive) ...[
                      SizedBox(width: 4.w),
                      Text('• ${match['time']}', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                    ],
                  ],
                ),
                Text(
                  'Match ${match['id']}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                ),
              ],
            ),
          ),

          // Teams and Scores
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Team 1
                _buildTeamRow(
                  match['team1Logo'],
                  match['team1'],
                  match['score1'],
                  match['overs1'],
                  isCompleted && match['result'].toString().contains(match['team1']),
                ),
                SizedBox(height: 12.h),
                // Team 2
                _buildTeamRow(
                  match['team2Logo'],
                  match['team2'],
                  match['score2'],
                  match['overs2'],
                  isCompleted && match['result'].toString().contains(match['team2']),
                ),
              ],
            ),
          ),

          // Result/Status
          if (match['result'].toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isLive ? Colors.red.withOpacity(0.05) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Text(
                match['result'],
                style: TextStyle(
                  color: isLive ? Colors.red : const Color(0xFF2E7D32),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Venue for upcoming
          if (match['status'] == 'upcoming')
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 14.sp, color: Colors.grey[600]),
                  SizedBox(width: 4.w),
                  Text(
                    match['venue'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(String logo, String name, String score, String overs, bool isWinner) {
    return Row(
      children: [
        // Team Logo
        Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Center(
            child: Text(logo, style: TextStyle(fontSize: 24.sp)),
          ),
        ),
        SizedBox(width: 12.w),
        // Team Name
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
              color: isWinner ? Colors.black : Colors.black87,
            ),
          ),
        ),
        // Score
        if (score != '-')
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? const Color(0xFF2E7D32) : Colors.black87,
                ),
              ),
              Text(
                '($overs ov)',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          )
        else
          Text(
            '-',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]),
          ),
      ],
    );
  }
}

// ============================================================
// POINTS TABLE TAB - IPL Style
// ============================================================
class _PointsTableTab extends StatelessWidget {
  final List<Map<String, dynamic>> teams = [
    {'rank': 1, 'team': 'Warriors', 'logo': '🔵', 'played': 4, 'won': 4, 'lost': 0, 'nr': 0, 'nrr': '+1.856', 'points': 8},
    {'rank': 2, 'team': 'Lions', 'logo': '🟤', 'played': 4, 'won': 3, 'lost': 1, 'nr': 0, 'nrr': '+0.945', 'points': 6},
    {'rank': 3, 'team': 'Eagles', 'logo': '🟠', 'played': 4, 'won': 2, 'lost': 2, 'nr': 0, 'nrr': '+0.234', 'points': 4},
    {'rank': 4, 'team': 'Strikers', 'logo': '🔴', 'played': 3, 'won': 2, 'lost': 1, 'nr': 0, 'nrr': '+0.125', 'points': 4},
    {'rank': 5, 'team': 'Tigers', 'logo': '🟡', 'played': 4, 'won': 1, 'lost': 3, 'nr': 0, 'nrr': '-0.456', 'points': 2},
    {'rank': 6, 'team': 'Blazers', 'logo': '🟣', 'played': 3, 'won': 1, 'lost': 2, 'nr': 0, 'nrr': '-0.678', 'points': 2},
    {'rank': 7, 'team': 'Thunder', 'logo': '⚫', 'played': 4, 'won': 0, 'lost': 4, 'nr': 0, 'nrr': '-1.234', 'points': 0},
    {'rank': 8, 'team': 'Royals', 'logo': '🟢', 'played': 4, 'won': 0, 'lost': 4, 'nr': 0, 'nrr': '-1.567', 'points': 0},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12.w),
      child: Column(
        children: [
          // Qualification Zone Legend
          Container(
            padding: EdgeInsets.all(12.w),
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFF4CAF50), 'Qualified'),
                SizedBox(width: 24.w),
                _buildLegendItem(Colors.orange, 'Playoffs'),
                SizedBox(width: 24.w),
                _buildLegendItem(Colors.red, 'Eliminated'),
              ],
            ),
          ),

          // Points Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 8.w),
                      Text('#', style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                      SizedBox(width: 12.w),
                      Expanded(flex: 3, child: Text('TEAM', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold))),
                      _headerCell('P'),
                      _headerCell('W'),
                      _headerCell('L'),
                      _headerCell('NRR', width: 50.w),
                      _headerCell('PTS', width: 35.w),
                    ],
                  ),
                ),
                // Rows
                ...teams.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final team = entry.value;
                  final isQualified = idx < 2;
                  final isPlayoff = idx >= 2 && idx < 4;
                  
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: isQualified 
                          ? const Color(0xFF4CAF50).withOpacity(0.08)
                          : isPlayoff 
                              ? Colors.orange.withOpacity(0.08)
                              : null,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        left: BorderSide(
                          color: isQualified 
                              ? const Color(0xFF4CAF50)
                              : isPlayoff 
                                  ? Colors.orange
                                  : Colors.transparent,
                          width: 4.w,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20.w,
                          child: Text(
                            '${team['rank']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isQualified ? const Color(0xFF4CAF50) : Colors.grey[800],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Text(team['logo'], style: TextStyle(fontSize: 20.sp)),
                              SizedBox(width: 8.w),
                              Text(
                                team['team'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _dataCell('${team['played']}'),
                        _dataCell('${team['won']}', color: const Color(0xFF4CAF50)),
                        _dataCell('${team['lost']}', color: Colors.red),
                        _dataCell(team['nrr'], width: 50.w, color: team['nrr'].toString().startsWith('+') ? Color(0xFF4CAF50) : Colors.red),
                        _dataCell('${team['points']}', width: 35.w, isBold: true, color: Color(0xFF1A1A2E)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12.w,
          height: 12.h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3.r)),
        ),
        SizedBox(width: 6.w),
        Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.grey[700])),
      ],
    );
  }

  Widget _headerCell(String text, {double width = 30}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _dataCell(String text, {double width = 30, Color? color, bool isBold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color ?? Colors.grey[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ============================================================
// STATS TAB - Crix Style Player Cards
// ============================================================
class _StatsTab extends StatefulWidget {
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> with SingleTickerProviderStateMixin {
  late TabController _statsTabController;

  @override
  void initState() {
    super.initState();
    _statsTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _statsTabController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> battingStats = [
    {'rank': 1, 'name': 'Virat Singh', 'team': 'Warriors', 'logo': '🔵', 'runs': 245, 'matches': 4, 'avg': '61.25', 'sr': '158.2', 'hs': '89*', '50s': 2, '100s': 0},
    {'rank': 2, 'name': 'Rohit Kumar', 'team': 'Lions', 'logo': '🟤', 'runs': 198, 'matches': 4, 'avg': '49.50', 'sr': '145.6', 'hs': '72', '50s': 2, '100s': 0},
    {'rank': 3, 'name': 'Shubham Gill', 'team': 'Eagles', 'logo': '🟠', 'runs': 176, 'matches': 4, 'avg': '44.00', 'sr': '138.9', 'hs': '68', '50s': 1, '100s': 0},
    {'rank': 4, 'name': 'Arjun Sharma', 'team': 'Strikers', 'logo': '🔴', 'runs': 145, 'matches': 3, 'avg': '48.33', 'sr': '152.1', 'hs': '78*', '50s': 1, '100s': 0},
    {'rank': 5, 'name': 'Pradeep Rao', 'team': 'Tigers', 'logo': '🟡', 'runs': 132, 'matches': 4, 'avg': '33.00', 'sr': '128.7', 'hs': '55', '50s': 1, '100s': 0},
  ];

  final List<Map<String, dynamic>> bowlingStats = [
    {'rank': 1, 'name': 'Jasprit Singh', 'team': 'Warriors', 'logo': '🔵', 'wickets': 12, 'matches': 4, 'overs': 16, 'runs': 78, 'eco': '4.87', 'avg': '6.50', 'best': '4/12'},
    {'rank': 2, 'name': 'Mohammad Ali', 'team': 'Lions', 'logo': '🟤', 'wickets': 10, 'matches': 4, 'overs': 16, 'runs': 89, 'eco': '5.56', 'avg': '8.90', 'best': '3/18'},
    {'rank': 3, 'name': 'Ravinder Jadav', 'team': 'Eagles', 'logo': '🟠', 'wickets': 8, 'matches': 4, 'overs': 14, 'runs': 72, 'eco': '5.14', 'avg': '9.00', 'best': '3/21'},
    {'rank': 4, 'name': 'Kuldeep Yadav', 'team': 'Strikers', 'logo': '🔴', 'wickets': 7, 'matches': 3, 'overs': 12, 'runs': 58, 'eco': '4.83', 'avg': '8.28', 'best': '3/15'},
    {'rank': 5, 'name': 'Shami Khan', 'team': 'Tigers', 'logo': '🟡', 'wickets': 6, 'matches': 4, 'overs': 16, 'runs': 95, 'eco': '5.93', 'avg': '15.83', 'best': '2/19'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs
        Container(
          margin: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: TabBar(
            controller: _statsTabController,
            indicator: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10.r),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: TextStyle(fontWeight: FontWeight.w600),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '🏏 Batting'),
              Tab(text: '🎯 Bowling'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _statsTabController,
            children: [
              _buildBattingStats(),
              _buildBowlingStats(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBattingStats() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      itemCount: battingStats.length,
      itemBuilder: (context, index) {
        final player = battingStats[index];
        return _buildPlayerStatCard(
          rank: player['rank'],
          name: player['name'],
          team: player['team'],
          logo: player['logo'],
          mainStat: '${player['runs']}',
          mainStatLabel: 'RUNS',
          stats: [
            {'label': 'Matches', 'value': '${player['matches']}'},
            {'label': 'Average', 'value': player['avg']},
            {'label': 'SR', 'value': player['sr']},
            {'label': 'HS', 'value': player['hs']},
          ],
        );
      },
    );
  }

  Widget _buildBowlingStats() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      itemCount: bowlingStats.length,
      itemBuilder: (context, index) {
        final player = bowlingStats[index];
        return _buildPlayerStatCard(
          rank: player['rank'],
          name: player['name'],
          team: player['team'],
          logo: player['logo'],
          mainStat: '${player['wickets']}',
          mainStatLabel: 'WICKETS',
          stats: [
            {'label': 'Matches', 'value': '${player['matches']}'},
            {'label': 'Economy', 'value': player['eco']},
            {'label': 'Average', 'value': player['avg']},
            {'label': 'Best', 'value': player['best']},
          ],
        );
      },
    );
  }

  Widget _buildPlayerStatCard({
    required int rank,
    required String name,
    required String team,
    required String logo,
    required String mainStat,
    required String mainStatLabel,
    required List<Map<String, String>> stats,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32.w,
            height: 32.h,
            decoration: BoxDecoration(
              gradient: rank == 1
                  ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                  : rank == 2
                      ? const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFF808080)])
                      : rank == 3
                          ? const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)])
                          : null,
              color: rank > 3 ? Colors.grey[200] : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.grey[700],
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Player Avatar
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Icon(Icons.person, color: Colors.grey, size: 28.sp),
          ),
          SizedBox(width: 12.w),

          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(logo, style: TextStyle(fontSize: 12.sp)),
                    SizedBox(width: 4.w),
                    Text(team, style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: stats.map((stat) => Expanded(
                    child: Column(
                      children: [
                        Text(stat['value']!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp)),
                        Text(stat['label']!, style: TextStyle(color: Colors.grey[500], fontSize: 9.sp)),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),

          // Main Stat
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Text(
                  mainStat,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                Text(
                  mainStatLabel,
                  style: TextStyle(color: Colors.white70, fontSize: 9.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MVP POINTS TAB - Custom Scoring Leaderboard
// ============================================================
class _MVPPointsTab extends StatelessWidget {
  final List<Map<String, dynamic>> mvpLeaderboard = [
    {'rank': 1, 'name': 'Virat Singh', 'team': 'Warriors', 'logo': '🔵', 'points': 485, 'runs': 245, 'wickets': 2, 'catches': 5, 'mom': 2},
    {'rank': 2, 'name': 'Jasprit Singh', 'team': 'Warriors', 'logo': '🔵', 'points': 420, 'runs': 45, 'wickets': 12, 'catches': 3, 'mom': 1},
    {'rank': 3, 'name': 'Rohit Kumar', 'team': 'Lions', 'logo': '🟤', 'points': 385, 'runs': 198, 'wickets': 1, 'catches': 4, 'mom': 1},
    {'rank': 4, 'name': 'Mohammad Ali', 'team': 'Lions', 'logo': '🟤', 'points': 340, 'runs': 32, 'wickets': 10, 'catches': 6, 'mom': 1},
    {'rank': 5, 'name': 'Arjun Sharma', 'team': 'Strikers', 'logo': '🔴', 'points': 295, 'runs': 145, 'wickets': 0, 'catches': 3, 'mom': 1},
    {'rank': 6, 'name': 'Shubham Gill', 'team': 'Eagles', 'logo': '🟠', 'points': 280, 'runs': 176, 'wickets': 0, 'catches': 2, 'mom': 0},
    {'rank': 7, 'name': 'Ravinder Jadav', 'team': 'Eagles', 'logo': '🟠', 'points': 265, 'runs': 78, 'wickets': 8, 'catches': 4, 'mom': 0},
    {'rank': 8, 'name': 'Kuldeep Yadav', 'team': 'Strikers', 'logo': '🔴', 'points': 225, 'runs': 28, 'wickets': 7, 'catches': 2, 'mom': 1},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12.w),
      child: Column(
        children: [
          // Scoring System Card
          Container(
            padding: EdgeInsets.all(16.w),
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFFFD700), size: 20.sp),
                    SizedBox(width: 8.w),
                    Text('MVP Scoring System', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoringItem('1 Run', '+1'),
                    _buildScoringItem('1 Wicket', '+25'),
                    _buildScoringItem('1 Catch', '+10'),
                    _buildScoringItem('MOM', '+50'),
                  ],
                ),
              ],
            ),
          ),

          // Leaderboard
          ...mvpLeaderboard.asMap().entries.map((entry) {
            final idx = entry.key;
            final player = entry.value;
            return _buildMVPCard(player, idx);
          }),
        ],
      ),
    );
  }

  Widget _buildScoringItem(String label, String points) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(points, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 4.h),
        Text(label, style: TextStyle(color: Colors.white60, fontSize: 11.sp)),
      ],
    );
  }

  Widget _buildMVPCard(Map<String, dynamic> player, int index) {
    final isTop3 = index < 3;
    
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: isTop3 ? Border.all(color: _getRankColor(index), width: 2.w) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: _getRankColor(index),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTop3
                  ? Icon(_getRankIcon(index), color: Colors.white, size: 20.sp)
                  : Text('${player['rank']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(width: 12.w),

          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(player['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    SizedBox(width: 8.w),
                    Text(player['logo'], style: TextStyle(fontSize: 14.sp)),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    _buildMiniStat('🏏', '${player['runs']}'),
                    _buildMiniStat('🎯', '${player['wickets']}'),
                    _buildMiniStat('🧤', '${player['catches']}'),
                    _buildMiniStat('⭐', '${player['mom']}'),
                  ],
                ),
              ],
            ),
          ),

          // Points
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isTop3 
                    ? [_getRankColor(index), _getRankColor(index).withOpacity(0.7)]
                    : [Colors.grey[200]!, Colors.grey[100]!],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Text(
                  '${player['points']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                    color: isTop3 ? Colors.white : Colors.grey[800],
                  ),
                ),
                Text(
                  'PTS',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: isTop3 ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value) {
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 12.sp)),
          SizedBox(width: 2.w),
          Text(value, style: TextStyle(fontSize: 11.sp, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return const Color(0xFFFFD700);
      case 1: return const Color(0xFFC0C0C0);
      case 2: return const Color(0xFFCD7F32);
      default: return Colors.grey[400]!;
    }
  }

  IconData _getRankIcon(int index) {
    switch (index) {
      case 0: return Icons.emoji_events;
      case 1: return Icons.emoji_events;
      case 2: return Icons.emoji_events;
      default: return Icons.star;
    }
  }
}

// ============================================================
// TEAMS TAB - Grid with Expandable Squad Cards
// ============================================================
class _TeamsTab extends StatelessWidget {
  final List<Map<String, dynamic>> teams = [
    {
      'name': 'Warriors',
      'logo': '🔵',
      'color': const Color(0xFF1E88E5),
      'captain': 'Virat Singh',
      'players': ['Virat Singh (C)', 'Jasprit Singh', 'Rahul Verma', 'Suresh Patel', 'Anil Kumar', 'Deepak Singh', 'Manish Rao', 'Rakesh Goud', 'Sanjay Reddy', 'Vinod Sharma', 'Kiran Yadav'],
    },
    {
      'name': 'Lions',
      'logo': '🟤',
      'color': const Color(0xFF795548),
      'captain': 'Rohit Kumar',
      'players': ['Rohit Kumar (C)', 'Mohammad Ali', 'Praveen Das', 'Naveen Reddy', 'Ashok Rao', 'Dinesh Kumar', 'Girish Patil', 'Harish Singh', 'Imran Khan', 'Jagdish Nair', 'Krishna Prasad'],
    },
    {
      'name': 'Eagles',
      'logo': '🟠',
      'color': const Color(0xFFFF9800),
      'captain': 'Shubham Gill',
      'players': ['Shubham Gill (C)', 'Ravinder Jadav', 'Lokesh Rahul', 'Murali Sharma', 'Naresh Yadav', 'Om Prakash', 'Pankaj Tripathi', 'Qadir Khan', 'Ravi Shankar', 'Satish Reddy', 'Tushar Patel'],
    },
    {
      'name': 'Strikers',
      'logo': '🔴',
      'color': const Color(0xFFE53935),
      'captain': 'Arjun Sharma',
      'players': ['Arjun Sharma (C)', 'Kuldeep Yadav', 'Umesh Kumar', 'Vijay Shankar', 'Wasim Jaffer', 'Xerxes Irani', 'Yashwant Rao', 'Zaheer Abbas', 'Akash Mehra', 'Bharat Singh', 'Chetan Sharma'],
    },
    {
      'name': 'Tigers',
      'logo': '🟡',
      'color': const Color(0xFFFDD835),
      'captain': 'Pradeep Rao',
      'players': ['Pradeep Rao (C)', 'Shami Khan', 'Dravid Kumar', 'Eknath Solkar', 'Farokh Engineer', 'Gundappa Viswanath', 'Hemant Kanitkar', 'Irfan Pathan', 'Javagal Srinath', 'Kapil Dev', 'Laxman Sivaramakrishnan'],
    },
    {
      'name': 'Blazers',
      'logo': '🟣',
      'color': const Color(0xFF9C27B0),
      'captain': 'Amit Verma',
      'players': ['Amit Verma (C)', 'Brijesh Patel', 'Chandrashekhar Singh', 'Dev Anand', 'Erapalli Prasanna', 'Feroz Shah', 'Gautam Gambhir', 'Harbhajan Singh', 'Ishant Sharma', 'Jai Dev', 'Karsan Ghavri'],
    },
    {
      'name': 'Thunder',
      'logo': '⚫',
      'color': const Color(0xFF424242),
      'captain': 'Ravi Shastri',
      'players': ['Ravi Shastri (C)', 'Manoj Prabhakar', 'Nayan Mongia', 'Ojha Pragyan', 'Parthiv Patel', 'Qasim Ali', 'Robin Uthappa', 'Sanjay Manjrekar', 'Tendulkar Kumar', 'Unmukt Chand', 'Venkatesh Prasad'],
    },
    {
      'name': 'Royals',
      'logo': '🟢',
      'color': const Color(0xFF43A047),
      'captain': 'Sachin Tendulkar',
      'players': ['Sachin Tendulkar (C)', 'Wriddhiman Saha', 'Xavier Doherty', 'Yusuf Pathan', 'Zaheer Khan', 'Aakash Chopra', 'Badrinath Subramaniam', 'Cheteshwar Pujara', 'Dinesh Karthik', 'Eoin Morgan', 'Faf du Plessis'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(12.w),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: teams.length,
      itemBuilder: (context, index) => _buildTeamCard(context, teams[index]),
    );
  }

  Widget _buildTeamCard(BuildContext context, Map<String, dynamic> team) {
    return GestureDetector(
      onTap: () => _showSquadBottomSheet(context, team),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            // Team Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: (team['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      color: team['color'],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (team['color'] as Color).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(team['logo'], style: TextStyle(fontSize: 28.sp)),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    team['name'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                  ),
                ],
              ),
            ),

            // Team Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 14.sp, color: Colors.grey),
                        SizedBox(width: 4.w),
                        Text(
                          'Captain: ${team['captain']}',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups, size: 14.sp, color: Colors.grey[600]),
                        SizedBox(width: 4.w),
                        Text(
                          '${(team['players'] as List).length} Players',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: team['color'],
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'View Squad',
                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSquadBottomSheet(BuildContext context, Map<String, dynamic> team) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            // Header
            Container(
              padding: EdgeInsets.all(20.w),
              child: Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: team['color'],
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(team['logo'], style: TextStyle(fontSize: 24.sp))),
                  ),
                  SizedBox(width: 16.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team['name'], style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      Text('Squad • ${(team['players'] as List).length} Players', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1.h),
            // Players List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                itemCount: (team['players'] as List).length,
                itemBuilder: (context, index) {
                  final player = (team['players'] as List)[index];
                  final isCaptain = player.toString().contains('(C)');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Text('${index + 1}', style: TextStyle(color: Colors.grey[700], fontSize: 12.sp)),
                    ),
                    title: Text(
                      player.toString().replaceAll(' (C)', ''),
                      style: TextStyle(fontWeight: isCaptain ? FontWeight.bold : FontWeight.normal),
                    ),
                    trailing: isCaptain
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: team['color'],
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text('CAPTAIN', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
