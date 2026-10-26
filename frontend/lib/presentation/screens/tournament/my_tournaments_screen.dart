import 'package:flutter/material.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import 'create_tournament_screen.dart';
import 'tournament_details_screen.dart';
import '../../widgets/state/scorepartner_skeleton.dart';
import '../../widgets/state/scorepartner_empty_state.dart';

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
        backgroundColor: ThemeHelper.of(context).scaffoldBg,
        appBar: AppBar(
          backgroundColor: ThemeHelper.of(context).scaffoldBg,
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
            ? ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: ScorePartnerSkeleton(
                    width: double.infinity,
                    height: 140.h,
                    borderRadius: 24.r,
                  ),
                ),
              )
            : TabBarView(
                children: [
                  _buildTournamentList(_liveTournaments, false),
                  _buildTournamentList(_pastTournaments, true),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToCreateTournament,
          backgroundColor: AppTheme.primaryOrange,
          icon: Icon(Icons.add, color: ThemeHelper.of(context).cardBg,),
          label: Text('Create', style: TextStyle(color: ThemeHelper.of(context).cardBg,)),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: ScorePartnerEmptyState(
        title: _searchQuery.isNotEmpty ? 'No Results' : 'No Tournaments',
        description: _searchQuery.isNotEmpty 
            ? 'Try a different search term.'
            : 'Create your first tournament.',
        icon: Icons.emoji_events_outlined,
        primaryButtonText: _searchQuery.isEmpty ? 'Create Tournament' : null,
        onPrimaryAction: _searchQuery.isEmpty ? _navigateToCreateTournament : null,
      ),
    );
  }

  Widget _buildTournamentCard(TournamentModel tournament) {
    final th = ThemeHelper.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;
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
          onTap: () => _navigateToTournamentDetails(tournament),
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
}
