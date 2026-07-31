import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/screens/matches/match_detail_screen.dart';

/// Shows all matches played, live, and upcoming at a specific venue.
class GroundProfileScreen extends StatefulWidget {
  final String groundName;
  final String? location;
  final double? latitude;
  final double? longitude;

  const GroundProfileScreen({
    super.key,
    required this.groundName,
    this.location,
    this.latitude,
    this.longitude,
  });

  @override
  State<GroundProfileScreen> createState() => _GroundProfileScreenState();
}

class _GroundProfileScreenState extends State<GroundProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseDataService _dataService = FirebaseDataService.instance;

  List<MatchModel> _liveMatches = [];
  List<MatchModel> _completedMatches = [];
  List<MatchModel> _upcomingMatches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await _dataService.getMatchesByGround(widget.groundName);
      if (!mounted) return;

      setState(() {
        _liveMatches = matches
            .where((match) => match.status == 'live')
            .toList();
        _completedMatches = matches
            .where((match) => match.status == 'completed')
            .toList();
        _upcomingMatches = matches
            .where((match) => match.status == 'scheduled')
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepBlack : const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? AppTheme.deepBlack : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.deepBlack,
        title: const Text('Ground Profile'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 10.h),
            child: _buildHero(isDark),
          ),
          _buildTabBar(isDark),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMatchList(
                        _liveMatches,
                        title: 'No live matches',
                        message: 'Live action at this ground will appear here.',
                      ),
                      _buildMatchList(
                        _completedMatches,
                        title: 'No played matches',
                        message:
                            'Completed games for this ground will appear here.',
                      ),
                      _buildMatchList(
                        _upcomingMatches,
                        title: 'No upcoming matches',
                        message:
                            'Scheduled fixtures for this ground will appear here.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    final totalMatches =
        _liveMatches.length +
        _completedMatches.length +
        _upcomingMatches.length;

    return Container(
      height: 238.h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20263A) : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GroundProfilePainter(isDark: isDark)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: isDark ? 0.58 : 0.42),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18.w,
            right: 18.w,
            top: 16.h,
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.stadium_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                const Spacer(),
                _buildLivePill(),
              ],
            ),
          ),
          Positioned(
            left: 18.w,
            right: 18.w,
            bottom: 18.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groundName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.location != null && widget.location!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.white.withValues(alpha: 0.82),
                        size: 15.sp,
                      ),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: Text(
                          widget.location!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 16.h),
                Row(
                  children: [
                    _buildHeroStat('$totalMatches', 'Matches'),
                    SizedBox(width: 8.w),
                    _buildHeroStat('${_liveMatches.length}', 'Live'),
                    SizedBox(width: 8.w),
                    _buildHeroStat('${_completedMatches.length}', 'Played'),
                    SizedBox(width: 8.w),
                    _buildHeroStat('${_upcomingMatches.length}', 'Next'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePill() {
    if (_liveMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            '${_liveMatches.length} live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String value, String label) {
    return Expanded(
      child: Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            FittedBox(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 48.h,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20263A) : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(6.r),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? Colors.white.withValues(alpha: 0.62)
            : AppTheme.darkGrey,
        labelStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
        tabs: [
          Tab(text: 'Live ${_liveMatches.length}'),
          Tab(text: 'Played ${_completedMatches.length}'),
          Tab(text: 'Upcoming ${_upcomingMatches.length}'),
        ],
      ),
    );
  }

  Widget _buildMatchList(
    List<MatchModel> matches, {
    required String title,
    required String message,
  }) {
    if (matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMatches,
        color: AppTheme.primaryOrange,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24.w, 56.h, 24.w, 24.h),
          children: [_buildEmptyState(title, message)],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: AppTheme.primaryOrange,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
        itemCount: matches.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) => _buildGroundMatchCard(matches[index]),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20263A) : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.stadium_outlined,
              color: AppTheme.primaryOrange,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.deepBlack,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.66)
                  : AppTheme.darkGrey,
              fontSize: 12.sp,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroundMatchCard(MatchModel match) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = match.status == 'live';
    final isCompleted = match.status == 'completed';
    final statusColor = _statusColor(match.status);

    return Material(
      color: isDark ? const Color(0xFF20263A) : Colors.white,
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: match.id),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isLive
                  ? Colors.red.withValues(alpha: 0.35)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusBadge(match.status),
                  const Spacer(),
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13.sp,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.54)
                        : AppTheme.darkGrey,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    DateFormat('d MMM yyyy').format(match.scheduledDate),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.62)
                          : AppTheme.darkGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: _buildTeamBlock(
                      match.team1Name,
                      isLive || isCompleted
                          ? _formatScore(
                              match.team1Score.runs,
                              match.team1Score.wickets,
                              match.team1Score.overs,
                            )
                          : null,
                      alignEnd: false,
                      isDark: isDark,
                    ),
                  ),
                  Container(
                    width: 36.w,
                    height: 36.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildTeamBlock(
                      match.team2Name,
                      isLive || isCompleted
                          ? _formatScore(
                              match.team2Score.runs,
                              match.team2Score.wickets,
                              match.team2Score.overs,
                            )
                          : null,
                      alignEnd: true,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              if (isCompleted && match.result != null) ...[
                SizedBox(height: 12.h),
                _buildResultStrip(match.result!.winner, match.result!.margin),
              ],
              if (match.tournamentName != null &&
                  match.tournamentName!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 15.sp,
                      color: const Color(0xFFF6B73C),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        match.tournamentName!,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.62)
                              : AppTheme.darkGrey,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.42)
                          : Colors.black26,
                      size: 20.sp,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    final isLive = status == 'live';
    final label = switch (status) {
      'live' => 'Live',
      'completed' => 'Played',
      _ => 'Upcoming',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 5.w),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamBlock(
    String name,
    String? score, {
    required bool alignEnd,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white : AppTheme.deepBlack,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          ),
          if (score != null) ...[
            SizedBox(height: 5.h),
            Text(
              score,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultStrip(String winner, String margin) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        '$winner won by $margin',
        style: TextStyle(
          color: Colors.green.shade700,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatScore(int runs, int wickets, double overs) {
    return '$runs/$wickets (${overs.toStringAsFixed(1)})';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'live' => Colors.red,
      'completed' => Colors.green,
      _ => AppTheme.primaryOrange,
    };
  }
}

class _GroundProfilePainter extends CustomPainter {
  final bool isDark;

  const _GroundProfilePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF123326), Color(0xFF21553B), Color(0xFF4C6D32)]
            : const [Color(0xFF1F7A45), Color(0xFF37A063), Color(0xFFE09A45)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    final boundaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final center = Offset(size.width * 0.5, size.height * 0.52);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.96,
        height: size.height * 0.72,
      ),
      boundaryPaint,
    );
    canvas.drawCircle(center, size.width * 0.065, boundaryPaint);

    final pitchPaint = Paint()
      ..color = const Color(0xFFDDAF75).withValues(alpha: 0.86);
    final pitchRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.18,
        height: size.height * 0.48,
      ),
      Radius.circular(8.r),
    );
    canvas.drawRRect(pitchRect, pitchPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.2 + i * 0.18);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GroundProfilePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
