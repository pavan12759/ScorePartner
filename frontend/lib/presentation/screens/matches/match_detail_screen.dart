import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/data/services/tts_commentary_service.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/live_tab.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/scorecard_tab.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/info_tab.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/commentary_tab.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/overs_tab.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/news_tab.dart';
import 'package:scorepatner/presentation/screens/matches/tabs/squads_tab.dart';
import 'package:scorepatner/presentation/screens/matches/ball_history_edit_screen.dart';
import 'package:scorepatner/presentation/screens/matches/match_scorecard_screen.dart';
import 'package:scorepatner/presentation/widgets/mvp_calculator_widget.dart';
import 'package:scorepatner/presentation/widgets/key_moments_widget.dart';
import '../../widgets/dialogs/manage_access_dialog.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'package:scorepatner/presentation/screens/tournament/tournament_details_screen.dart';
import 'package:scorepatner/presentation/screens/matches/match_highlights_generator_screen.dart';
import 'package:scorepatner/presentation/widgets/match_highlights_badges_widget.dart';
import '../ground/ground_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/live_audience_island.dart';
import '../../../data/services/viewer_service.dart';
import '../../widgets/match/pin_live_score_button.dart';
import '../broadcast/broadcast_tab.dart';
import '../broadcast/go_live_screen.dart';
import '../matches/poster/match_summary_poster_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with TickerProviderStateMixin {
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  final TtsCommentaryService _ttsService = TtsCommentaryService.instance;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _ttsEnabled = false;
  int _lastAnnouncedBallCount = -1;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Tabs configuration
  List<String> get _tabs => [
    'Info',
    'Live',
    'Scorecard',
    'Commentary',
    'Squads',
    'Overs',
    'Stars',
    'Key Moments',
    'News',
    'Broadcast',
  ];

  @override
  void initState() {
    super.initState();
    // Join viewer tracking for live matches
    ViewerService.instance.joinMatch(widget.matchId);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: 1,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to update selected pill
      }
    });
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Leave viewer tracking
    ViewerService.instance.leaveMatch(widget.matchId);
    _tabController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<MatchModel?>(
        stream: _dataService.streamMatch(widget.matchId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final match = snapshot.data!;
          final currentUser = FirebaseAuth.instance.currentUser;
          final isAdmin =
              currentUser != null &&
              (match.createdBy == currentUser.uid ||
                  match.adminIds.contains(currentUser.uid));

          // Trigger TTS for new ball events
          _handleTtsForNewBalls(match);

          final bool isTournament =
              match.tournamentId != null &&
              match.tournamentName != null &&
              match.tournamentName!.isNotEmpty;
          final bool isLiveMatch = match.status == 'live';

          // Calculate precise header height using ScreenUtil's .h and .sp scaling 
          // to perfectly match the internal widgets and text scale.
          double headerHeight = kToolbarHeight + 6 + 95 + 5.0; // Fixed outer padding and dividers
          // Increased base height to properly account for padding and text line-heights
          headerHeight += 75.h + 130.sp; 
          
          if (isTournament) headerHeight += 10.h + 20.sp; // Tournament row
          // The equation row can wrap or take up more space due to text, so we allocate a generous height for it
          if (isLiveMatch && match.currentInnings == 2) headerHeight += 35.h + 30.sp; // Equation row
          if (match.tossWinnerId != null) headerHeight += 25.h + 20.sp; // Toss info
          
          // Negative buffer to pull the tabs flush against the card
          headerHeight -= 50.0;

          return Stack(
            children: [
              NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: headerHeight,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.white,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        // Watch Live Broadcast Button
                        if (isLiveMatch)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _tabController.animateTo(9); // Index for BroadcastTab
                              },
                              icon: const Icon(Icons.live_tv, size: 16, color: Colors.white),
                              label: const Text('Watch Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        // Pin Live Score Bubble (Android only, live matches)
                        if (isLiveMatch)
                          PinLiveScoreButton(
                            matchId: match.id,
                            team1Name: match.team1Name,
                            team2Name: match.team2Name,
                            isLive: isLiveMatch,
                          ),
                        // AI Voice Commentary Toggle
                        IconButton(
                          icon: Icon(
                            _ttsEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: _ttsEnabled ? AppTheme.primaryOrange : Colors.black87,
                            size: 22,
                          ),
                          tooltip: _ttsEnabled
                              ? 'Disable AI Commentary'
                              : 'Enable AI Commentary',
                          onPressed: () async {
                            final enabled = await _ttsService.toggle();
                            setState(() => _ttsEnabled = enabled);
                            if (enabled) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🔊 AI Voice Commentary ON'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                        // Share
                        IconButton(
                          icon: Icon(Icons.share, color: Colors.black87, size: 22),
                          onPressed: () {
                            final String shareText =
                                'Check out this match on ScorePartner: ${match.team1Name} vs ${match.team2Name}!\n\nLive Score: https://scorepartner.in/match/${match.id}';
                            Share.share(shareText);
                          },
                        ),
                        // Admin overflow menu
                        if (isAdmin)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.black87, size: 22),
                            onSelected: (value) {
                              switch (value) {
                                case 'manage_access':
                                  _showManageAccessDialog(context, match);
                                  break;
                                case 'go_live':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GoLiveScreen(preselectedMatchId: match.id),
                                    ),
                                  );
                                  break;
                                case 'edit_history':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BallHistoryEditScreen(matchId: match.id),
                                    ),
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'manage_access',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add_alt_1, size: 20),
                                    SizedBox(width: 8),
                                    Text('Manage Access'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'go_live',
                                child: Row(
                                  children: [
                                    Icon(Icons.videocam, size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('GO LIVE', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit_history',
                                child: Row(
                                  children: [
                                    Icon(Icons.history_edu_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit Ball History'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildDynamicMatchHeader(match),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(60),
                        child: _buildNavigationPills(),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    InfoTab(match: match),
                    LiveTab(
                      match: match,
                      onNavigate: (index) => _tabController.animateTo(index),
                    ),
                    ScorecardTab(match: match),
                    CommentaryTab(match: match),
                    SquadsTab(match: match),
                    OversTab(match: match),
                    SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isAdmin &&
                              (match.status == 'past' ||
                                  match.result != null)) ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MatchHighlightsGeneratorScreen(
                                          matchId: match.id,
                                        ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.add_photo_alternate),
                              label: const Text('Add Photos & Highlights'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                elevation: 2,
                              ),
                            ),
                            SizedBox(height: 16.h),
                          ],
                          if (match.highlights.isNotEmpty) ...[
                            MatchHighlightsBadgesWidget(match: match),
                            SizedBox(height: 16.h),
                          ],
                          MvpRatingCard(match: match),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: KeyMomentsCard(match: match),
                    ),
                    NewsTab(match: match),
                    BroadcastTab(match: match),
                  ],
                ),
              ),


            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _navItems => [
    {'icon': Icons.info_outline, 'label': 'Info', 'tabIndex': 0},
    {'icon': Icons.live_tv, 'label': 'Live', 'tabIndex': 1},
    {'icon': Icons.scoreboard_outlined, 'label': 'Score', 'tabIndex': 2},
    {'icon': Icons.sports_cricket, 'label': 'Overs', 'tabIndex': 5},
    {'icon': Icons.group_outlined, 'label': 'Squads', 'tabIndex': 4},
    {'icon': Icons.star_rounded, 'label': 'Stars', 'tabIndex': 6},
    {'icon': Icons.flash_on_rounded, 'label': 'Key Moments', 'tabIndex': 7},
  ];

  Widget _buildNavigationPills() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _navItems.length,
        itemBuilder: (context, index) {
          final item = _navItems[index];
          return _buildNavPill(item);
        },
      ),
    );
  }

  Widget _buildNavPill(Map<String, dynamic> item) {
    final isSelected = _tabController.index == item['tabIndex'];

    return Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25.r),
          onTap: () {
            _tabController.animateTo(item['tabIndex']);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [],
              border: isSelected
                  ? null
                  : Border.all(
                      color: Colors.grey.shade300,
                      width: 1.w,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        item['icon'],
                        color: isSelected ? Colors.white : Colors.black54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  item['label'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13.sp,
                    letterSpacing: isSelected ? 0.3 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dynamic match header – compact, clean card-based design
  Widget _buildDynamicMatchHeader(MatchModel match) {
    final bool isLive = match.status == 'live';

    // Determine batting/bowling teams
    final bool isTeam1Batting = match.currentBattingTeam == 'team1';
    final String battingTeamName = isTeam1Batting ? match.team1Name : match.team2Name;
    final String bowlingTeamName = isTeam1Batting ? match.team2Name : match.team1Name;
    final TeamScore battingScore = isTeam1Batting ? match.team1Score : match.team2Score;
    final TeamScore bowlingScore = isTeam1Batting ? match.team2Score : match.team1Score;

    final bool isSecondInnings = match.currentInnings == 2;
    final bool bowlingTeamYetToBat = isLive && !isSecondInnings &&
        bowlingScore.runs == 0 && bowlingScore.wickets == 0 && bowlingScore.overs == 0.0;

    final crr = _calculateRunRate(battingScore.runs, battingScore.overs);

    // Projected score calculation
    double projectedScore = 0;
    if (isLive && battingScore.overs > 0) {
      projectedScore = crr * match.oversPerSide;
    }

    // Additional match info (Toss or Match Result)
    String tossInfo = '';
    if (match.status == 'completed' || match.status == 'past') {
      if (match.winnerTeam != null) {
        if (match.winnerTeam == 'Match Tied') {
          tossInfo = 'Match Tied';
        } else {
          tossInfo = '${match.winnerTeam} won by ${match.winningMargin}';
        }
      }
    } else if (match.tossWinnerId != null && match.tossDecision != null) {
      final tossWinnerName = match.tossWinnerId == match.team1Id
          ? match.team1Name
          : match.team2Name;
      tossInfo = '$tossWinnerName won the toss and chose to ${match.tossDecision}';
    }

    return Container(
      color: Color(0xFFF4F6F9), // Light background to replace the orange gradient
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, kToolbarHeight + 6, 16, 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tournament name (if tournament match)
                  if (match.tournamentId != null &&
                      match.tournamentName != null &&
                      match.tournamentName!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: GestureDetector(
                        onTap: () => _navigateToTournament(match.tournamentId!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 14.sp, color: AppTheme.primaryOrange),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                match.tournamentName!,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Main score card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top bar: Team1 vs Team2 + LIVE badge
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${match.team1Name.toUpperCase()}  vs  ${match.team2Name.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    // Match type & location integrated here
                                    Row(
                                      children: [
                                        Icon(Icons.sports_cricket_rounded, size: 10.sp, color: Colors.grey.shade600),
                                        SizedBox(width: 4.w),
                                        Text(
                                          match.matchType,
                                          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                        ),
                                        SizedBox(width: 10.w),
                                        Icon(Icons.location_on_rounded, size: 10.sp, color: Colors.grey.shade600),
                                        SizedBox(width: 4.w),
                                        Expanded(
                                          child: Text(
                                            match.ground,
                                            style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isLive || match.status == 'past' || match.status == 'completed')
                                StreamBuilder<Map<String, int>>(
                                  stream: ViewerService.instance.streamViewerStats(match.id),
                                  builder: (context, viewerSnap) {
                                    final stats = viewerSnap.data ?? {'liveViewers': 0, 'totalViews': 0};
                                    final liveViewers = stats['liveViewers'] ?? 0;
                                    final totalViews = stats['totalViews'] ?? 0;
                                    
                                    String formatCount(int n) {
                                      final str = n.toString();
                                      if (str.length <= 3) return str;
                                      return str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
                                    }

                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isLive) ...[
                                          Icon(Icons.remove_red_eye_rounded, size: 12.sp, color: Colors.grey.shade600),
                                          SizedBox(width: 2.w),
                                          Text(
                                            formatCount(liveViewers),
                                            style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                                          ),
                                          SizedBox(width: 8.w),
                                        ],
                                        Icon(Icons.play_circle_outline_rounded, size: 12.sp, color: Colors.grey.shade600),
                                        SizedBox(width: 2.w),
                                        Text(
                                          formatCount(totalViews),
                                          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                                        ),
                                        SizedBox(width: 8.w),
                                        if (isLive)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFCC1C1C),
                                              borderRadius: BorderRadius.circular(12.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6.w,
                                                  height: 6.h,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'LIVE',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade600,
                                              borderRadius: BorderRadius.circular(10.r),
                                            ),
                                            child: Text(
                                              'COMPLETED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        
                        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

                        // Score section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Batting team (left)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            battingTeamName,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Icon(Icons.sports_cricket, size: 14.sp, color: AppTheme.primaryOrange),
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '${battingScore.runs}/${battingScore.wickets}',
                                          style: TextStyle(
                                            fontSize: 32.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                            height: 1.1,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          '(${battingScore.oversDisplay})',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    if (tossInfo.isNotEmpty) ...[
                                      SizedBox(height: 12.h),
                                      Text(
                                        tossInfo,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.primaryOrange,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Bowling team (right)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sports_baseball, size: 14.sp, color: AppTheme.primaryOrange),
                                      SizedBox(width: 6.w),
                                      Flexible(
                                        child: Text(
                                          bowlingTeamName,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  if (bowlingTeamYetToBat)
                                    Text(
                                      'Yet to bat',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    )
                                  else
                                    Text(
                                      '${bowlingScore.runs}/${bowlingScore.wickets} (${bowlingScore.oversDisplay})',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Bottom row (CRR, PROJ SCORE, Refresh)
                        if (match.status == 'completed' || match.status == 'past') ...[
                           Builder(builder: (context) {
                             var mvpList = calculateMvpRatings(match);
                             
                             // Only consider players from the winning team for MVP
                             if (match.winnerTeam != null && match.winnerTeam != 'Match Tied') {
                               mvpList = mvpList.where((p) => p.teamName == match.winnerTeam).toList();
                             }
                             
                             if (mvpList.isEmpty) return SizedBox.shrink();
                             final mvp = mvpList.first;
                             final parts = <String>[];
                             if (mvp.runs > 0 || mvp.balls > 0) parts.add('${mvp.runs}(${mvp.balls})');
                             if (mvp.wickets > 0) parts.add('${mvp.wickets}/${mvp.runsConceded}');
                             
                             return Column(
                               children: [
                                 Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                                 Padding(
                                   padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                   child: Row(
                                     children: [
                                       Container(
                                         padding: EdgeInsets.all(6.w),
                                         decoration: BoxDecoration(
                                           color: Colors.amber.shade50,
                                           shape: BoxShape.circle,
                                         ),
                                         child: Icon(Icons.workspace_premium_rounded, size: 16.sp, color: Colors.amber.shade700),
                                       ),
                                       SizedBox(width: 8.w),
                                       Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text('PLAYER OF THE MATCH', style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                           SizedBox(height: 2.h),
                                           Text(mvp.playerName, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
                                         ],
                                       ),
                                       Spacer(),
                                       Text(
                                         parts.join(' • '),
                                         style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.grey.shade700),
                                       ),
                                     ],
                                   ),
                                 ),
                               ],
                             );
                           }),
                        ] else if (isLive) ...[
                          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                            child: Row(
                              children: [
                                // CRR
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CRR', style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                    SizedBox(height: 2.h),
                                    Text(crr.toStringAsFixed(2), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
                                  ],
                                ),
                                SizedBox(width: 24.w),
                                // Target / RRR / Proj Score
                                if (isSecondInnings && match.target != null) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('RRR', style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 2.h),
                                      Text(match.requiredRunRate.toStringAsFixed(2), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    ],
                                  ),
                                  SizedBox(width: 24.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('TARGET', style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 2.h),
                                      Text('${match.target}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    ],
                                  ),
                                ] else if (isLive) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('PROJ. SCORE', style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 2.h),
                                      Text('${projectedScore.round()}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    ],
                                  ),
                                ],
                                
                                Spacer(),
                                
                                // Refresh Button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Refreshing...'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                  icon: Icon(Icons.refresh_rounded, size: 14.sp, color: AppTheme.primaryOrange),
                                  label: Text('Refresh', style: TextStyle(fontSize: 11.sp, color: AppTheme.primaryOrange, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    side: BorderSide(color: AppTheme.primaryOrange.withOpacity(0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Equation Row (Integrated into the card)
                        if (isLive && match.currentInnings == 2) ...[
                          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFF8F0), // Very light orange background
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20.r),
                                bottomRight: Radius.circular(20.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, color: AppTheme.primaryOrange, size: 16.sp),
                                SizedBox(width: 6.w),
                                Flexible(
                                  child: Text(
                                    _getStatusText(match).toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryOrange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small stat box for CRR / RRR
  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Animated background with stadium lighting and bokeh effects
  Widget _buildAnimatedBackground(bool isLive) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Stadium spotlight — top left
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 250.w,
              height: 250.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Stadium spotlight — top right
          Positioned(
            top: -40,
            right: -50,
            child: Container(
              width: 200.w,
              height: 200.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.withOpacity(0.12),
                    Colors.amber.withOpacity(0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Bokeh particle 1
          Positioned(
            top: 100.h,
            left: 30.w,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.08 + (0.06 * _pulseAnimation.value),
                  child: Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),

          // Bokeh particle 2
          Positioned(
            top: 180.h,
            right: 50.w,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.06 + (0.04 * (1.0 - _pulseAnimation.value)),
                  child: Container(
                    width: 120.w,
                    height: 120.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber,
                    ),
                  ),
                );
              },
            ),
          ),

          // Bokeh particle 3
          Positioned(
            bottom: 120.h,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.05 + (0.05 * _pulseAnimation.value),
                  child: Container(
                    width: 60.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),

          // Cricket bat watermark
          Positioned(
            top: -20,
            right: -20,
            child: Opacity(
              opacity: 0.06,
              child: Icon(
                Icons.sports_cricket,
                size: 160.sp,
                color: Colors.white,
              ),
            ),
          ),

          // Animated pulse rings for live matches
          if (isLive)
            Positioned(
              top: 80.h,
              left: MediaQuery.of(context).size.width / 2 - 60,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 120.w * _pulseAnimation.value,
                    height: 120.h * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(
                          0.08 / _pulseAnimation.value,
                        ),
                        width: 2.w,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Bottom gradient fade — smoother transition
          Positioned(
            bottom: 0.h,
            left: 0.w,
            right: 0.w,
            height: 120.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.35),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Frosted glass info badge helper
  Widget _buildFrostedBadge({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.w,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Match info bar – just match type and venue
  Widget _buildMatchInfoBar(MatchModel match, bool isLive) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        // Match type badge — frosted glass
        _buildFrostedBadge(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_cricket_rounded,
                size: 14.sp,
                color: Colors.white.withOpacity(0.9),
              ),
              SizedBox(width: 6.w),
              Text(
                match.matchType,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        // Venue badge — frosted glass, tappable
        InkWell(
          onTap: () {
            if (match.ground.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroundProfileScreen(
                    groundName: match.ground,
                    location: match.location,
                    latitude: match.latitude,
                    longitude: match.longitude,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16.r),
          child: _buildFrostedBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
                SizedBox(width: 5.w),
                Text(
                  match.ground,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Navigate to tournament details
  void _navigateToTournament(String tournamentId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      ),
    );

    try {
      final tournament = await _dataService.getTournamentById(tournamentId);
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      if (tournament != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentDetailsScreen(tournament: tournament),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Dynamic score section with glassmorphism and animated scores
  Widget _buildDynamicScoreSection(MatchModel match, bool isLive) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool team1YetToBat = isLive &&
        match.currentInnings == 1 &&
        match.currentBattingTeam != 'team1' &&
        match.team1Score.runs == 0 &&
        match.team1Score.wickets == 0 &&
        match.team1Score.overs == 0.0;

    final bool team2YetToBat = isLive &&
        match.currentInnings == 1 &&
        match.currentBattingTeam != 'team2' &&
        match.team2Score.runs == 0 &&
        match.team2Score.wickets == 0 &&
        match.team2Score.overs == 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withOpacity(
              isDark ? 0.35 : 0.92,
            ),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(
              color: (isDark ? Colors.white : AppTheme.primaryOrange)
                  .withOpacity(0.15),
              width: 1.5.w,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: AppTheme.primaryOrange.withOpacity(0.08),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Team 1
              Expanded(
                child: _buildTeamScoreWidget(
                  teamName: match.team1Name,
                  runs: match.team1Score.runs,
                  wickets: match.team1Score.wickets,
                  overs: match.team1Score.overs,
                  isBatting: match.currentBattingTeam == 'team1' && isLive,
                  isTeam1: true,
                  isDark: isDark,
                  yetToBat: team1YetToBat,
                ),
              ),

              // VS Divider with gradient lines
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top gradient line
                    Container(
                      width: 1.5.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.primaryOrange.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // VS badge — diamond-shaped
                    AnimatedBuilder(
                      animation: isLive
                          ? _pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      builder: (context, child) {
                        return Container(
                          width: 42.w,
                          height: 42.h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFB74D),
                                Color(0xFFFF8A50),
                                Color(0xFFFF6B35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryOrange.withOpacity(
                                  isLive
                                      ? 0.3 + (0.15 * _pulseAnimation.value)
                                      : 0.25,
                                ),
                                blurRadius: isLive
                                    ? 10 + (4 * _pulseAnimation.value)
                                    : 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: math.pi / 4,
                            child: Center(
                              child: Transform.rotate(
                                angle: -math.pi / 4,
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 8.h),
                    // Bottom gradient line
                    Container(
                      width: 1.5.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryOrange.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Team 2
              Expanded(
                child: _buildTeamScoreWidget(
                  teamName: match.team2Name,
                  runs: match.team2Score.runs,
                  wickets: match.team2Score.wickets,
                  overs: match.team2Score.overs,
                  isBatting: match.currentBattingTeam == 'team2' && isLive,
                  isTeam1: false,
                  isDark: isDark,
                  yetToBat: team2YetToBat,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to calculate run rate securely
  double _calculateRunRate(int runs, double overs) {
    if (overs <= 0) return 0.0;
    // Convert 4.3 overs to 4.5 overs mathematically
    int completedOvers = overs.floor();
    int balls = ((overs - completedOvers) * 10).round();
    double totalOversDec = completedOvers + (balls / 6.0);
    if (totalOversDec == 0) return 0.0;
    return runs / totalOversDec;
  }

  /// Individual team score widget with avatar, animated scores, and overs chip
  Widget _buildTeamScoreWidget({
    required String teamName,
    required int runs,
    required int wickets,
    required double overs,
    required bool isBatting,
    required bool isTeam1,
    required bool isDark,
    bool yetToBat = false,
  }) {
    return Column(
      crossAxisAlignment: isTeam1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        // Team initial avatar
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isTeam1
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (!isTeam1 && isBatting) _buildBattingIndicator(),
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isBatting
                      ? [const Color(0xFFFF9E80), AppTheme.primaryOrange]
                      : isDark
                      ? [Colors.grey.shade700, Colors.grey.shade800]
                      : [Colors.grey.shade200, Colors.grey.shade300],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBatting
                      ? Colors.white
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: 2.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isBatting
                        ? AppTheme.primaryOrange.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  teamName.isNotEmpty ? teamName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isBatting
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (isTeam1 && isBatting) _buildBattingIndicator(),
          ],
        ),
        SizedBox(height: 8.h),

        // Team name
        Text(
          teamName.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isTeam1 ? TextAlign.left : TextAlign.right,
        ),
        SizedBox(height: 6.h),

        // Score
        Text(
          yetToBat ? '-' : '$runs/$wickets',
          style: TextStyle(
            color: isBatting
                ? AppTheme.primaryOrange
                : (isDark ? Colors.white70 : Colors.black54),
            fontSize: isBatting ? 36 : 26,
            fontWeight: FontWeight.w900,
            height: 1.1,
            shadows: isBatting
                ? [
                    Shadow(
                      color: AppTheme.primaryOrange.withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(height: 6.h),

        // Overs chip
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: isBatting
                ? AppTheme.primaryOrange.withOpacity(0.12)
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isBatting
                  ? AppTheme.primaryOrange.withOpacity(0.25)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            yetToBat ? 'Yet to bat' : '${overs.toStringAsFixed(1)} ov',
            style: TextStyle(
              color: isBatting
                  ? AppTheme.primaryOrange
                  : (isDark ? Colors.grey : Colors.grey.shade600),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Batting indicator widget with glow
  Widget _buildBattingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryOrange.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withOpacity(
                    0.15 * _pulseAnimation.value,
                  ),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(
              Icons.sports_cricket_rounded,
              size: 14.sp,
              color: AppTheme.primaryOrange,
            ),
          );
        },
      ),
    );
  }

  /// Status badge with frosted glass and premium indicator dot/icon
  Widget _buildStatusBadge(MatchModel match) {
    final statusText = _getStatusText(match);
    final isChasing = match.currentInnings == 2 && match.status == 'live';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isChasing
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: Colors.white.withOpacity(isChasing ? 0.4 : 0.25),
              width: 1.w,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isChasing
                  ? Icon(
                      Icons.bolt_rounded,
                      color: Colors.yellowAccent,
                      size: 16.sp,
                    )
                  : (match.status == 'live'
                      ? AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 8.w,
                              height: 8.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.greenAccent,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(
                                      0.5 * _pulseAnimation.value,
                                    ),
                                    blurRadius: 6 * _pulseAnimation.value,
                                    spreadRadius: 1.w,
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.sports_cricket_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 14.sp,
                        )),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(MatchModel match) {
    if (match.winnerTeam != null) {
      if (match.winnerTeam == 'Match Tied') {
        return 'Match Tied';
      }
      return '${match.winnerTeam} won by ${match.winningMargin}';
    }
    if (match.status == 'live') {
      final target = match.team1Score.runs + 1;
      if (match.currentInnings == 2) {
        final bool isTeam1Batting = match.currentBattingTeam == 'team1';
        final chasingTeamName = isTeam1Batting ? match.team1Name : match.team2Name;
        final chasingScore = isTeam1Batting ? match.team1Score : match.team2Score;
        final defendingScore = isTeam1Batting ? match.team2Score : match.team1Score;
        
        final target = match.target ?? (defendingScore.runs + 1);
        final needed = target - chasingScore.runs;
        
        int completedOvers = chasingScore.overs.floor();
        int extraBalls = ((chasingScore.overs - completedOvers) * 10).round();
        int ballsBowled = completedOvers * 6 + extraBalls;
        int remainingBalls = (match.oversPerSide.toInt() * 6) - ballsBowled;
        remainingBalls = remainingBalls < 0 ? 0 : remainingBalls;
        
        return '$chasingTeamName need $needed runs in $remainingBalls balls';
      }
      return '${match.currentBattingTeam == "team1" ? match.team1Name : match.team2Name} batting';
    }
    return 'Match scheduled';
  }

  /// Handle TTS commentary for new ball events
  void _handleTtsForNewBalls(MatchModel match) {
    if (!_ttsEnabled || match.ballByBall.isEmpty) return;

    final currentBallCount = match.ballByBall.length;

    // Initialize on first run
    if (_lastAnnouncedBallCount == -1) {
      _lastAnnouncedBallCount = currentBallCount;
      return;
    }

    // Only speak if there are new balls
    if (currentBallCount > _lastAnnouncedBallCount) {
      final latestBall = match.ballByBall.last;

      // Get batsman and bowler names from current match state
      final isTeam1Batting = match.currentBattingTeam == 'team1';
      final battingTeam = isTeam1Batting ? match.team1Score : match.team2Score;
      final bowlingTeam = isTeam1Batting ? match.team2Score : match.team1Score;

      final striker = battingTeam.batters
          .where((b) => b.isOnStrike)
          .firstOrNull;
      final currentBowler = bowlingTeam.bowlers
          .where((b) => b.isBowling)
          .firstOrNull;

      _ttsService.commentOnBall(
        latestBall,
        batsmanName: striker?.playerName,
        bowlerName: currentBowler?.playerName,
      );

      _lastAnnouncedBallCount = currentBallCount;
    }
  }

  void _showManageAccessDialog(BuildContext context, MatchModel match) {
    showDialog(
      context: context,
      builder: (context) => ManageAccessDialog(match: match),
    );
  }
}
