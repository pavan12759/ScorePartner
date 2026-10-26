import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../screens/matches/match_detail_screen.dart';
import '../../screens/teams/team_details_screen.dart';
import '../team_logo_widget.dart';

class ProfileMatchCard extends StatelessWidget {
  final MatchModel match;
  final String? targetUserId;
  final String? targetUserName;
  final VoidCallback? onTap;

  // In-memory cache to prevent redundant Firestore calls across cards and re-renders
  static final Map<String, TeamModel?> _teamCache = {};

  const ProfileMatchCard({
    super.key,
    required this.match,
    this.targetUserId,
    this.targetUserName,
    this.onTap,
  });

  static Future<TeamModel?> _getTeam(String teamId) async {
    if (teamId.isEmpty) return null;
    if (_teamCache.containsKey(teamId)) return _teamCache[teamId];
    try {
      final team = await FirebaseDataService.instance.getTeamById(teamId);
      _teamCache[teamId] = team;
      return team;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = ThemeHelper.of(context);
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
      statusBgColor = const Color(0xFFE53935).withValues(alpha: 0.12);
      statusText = 'LIVE';
      statusIcon = Icons.fiber_manual_record;
    } else if (isUpcoming) {
      statusColor = const Color(0xFF1E88E5);
      statusBgColor = const Color(0xFF1E88E5).withValues(alpha: 0.12);
      statusText = 'UPCOMING';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = const Color(0xFF2E7D32);
      statusBgColor = const Color(0xFF2E7D32).withValues(alpha: 0.12);
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    final currentBatting = match.currentBattingTeam.toLowerCase().trim();
    final isTeam1Batting = isLive &&
        (currentBatting == 'team1' ||
            match.currentBattingTeam == match.team1Id ||
            currentBatting == match.team1Name.toLowerCase().trim());
    final isTeam2Batting = isLive &&
        (currentBatting == 'team2' ||
            match.currentBattingTeam == match.team2Id ||
            currentBatting == match.team2Name.toLowerCase().trim());

    final isTeam1Winner = isCompleted &&
        (match.winnerTeamId == match.team1Id || match.winnerTeam == match.team1Name);
    final isTeam2Winner = isCompleted &&
        (match.winnerTeamId == match.team2Id || match.winnerTeam == match.team2Name);

    final bool hasTournament =
        match.tournamentName != null && match.tournamentName!.trim().isNotEmpty;
    final bool hasCustomName = match.matchName.isNotEmpty &&
        match.matchName.toLowerCase() !=
            '${match.team1Name} vs ${match.team2Name}'.toLowerCase() &&
        match.matchName.toLowerCase() != 'match';

    // Player contribution lookup
    final playerContribution = _getPlayerContribution(match, targetUserId, targetUserName);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isLive
              ? const Color(0xFFE53935).withValues(alpha: 0.4)
              : (th.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
          width: isLive ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchDetailScreen(matchId: match.id),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header (Status pill + Format + Tournament badge)
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLive) ...[
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ] else ...[
                            Icon(statusIcon, size: 10.sp, color: statusColor),
                            SizedBox(width: 3.w),
                          ],
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // Tournament Badge if present
                    if (hasTournament)
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100.r),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events, size: 11.sp, color: Colors.amber[800]),
                              SizedBox(width: 3.w),
                              Flexible(
                                child: Text(
                                  match.tournamentName!.trim(),
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: th.isDark ? Colors.amber[300] : const Color(0xFFD97706),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (hasCustomName)
                      Expanded(
                        child: Text(
                          match.matchName,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            color: th.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),

                    // Format Badge (e.g. T20 • 20 Ov)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: th.dividerColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Text(
                        match.oversPerSide > 0
                            ? '${match.matchFormat.isNotEmpty ? match.matchFormat : "Match"} • ${match.oversPerSide} Ov'
                            : (match.matchFormat.isNotEmpty ? match.matchFormat : 'Match'),
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w600,
                          color: th.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // 2. Teams Container
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      // Team 1 Row
                      _buildTeamRow(
                        context,
                        th,
                        teamId: match.team1Id,
                        teamName: match.team1Name,
                        score: match.team1Score,
                        isBatting: isTeam1Batting,
                        isWinner: isTeam1Winner,
                        isUpcoming: isUpcoming,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Divider(
                          height: 1,
                          thickness: 0.8,
                          color: th.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      // Team 2 Row
                      _buildTeamRow(
                        context,
                        th,
                        teamId: match.team2Id,
                        teamName: match.team2Name,
                        score: match.team2Score,
                        isBatting: isTeam2Batting,
                        isWinner: isTeam2Winner,
                        isUpcoming: isUpcoming,
                      ),
                    ],
                  ),
                ),

                // 3. Player Personal Contribution Strip (if player played in this match)
                if (playerContribution != null) ...[
                  SizedBox(height: 6.h),
                  _buildPlayerContributionStrip(th, playerContribution),
                ],

                SizedBox(height: 6.h),

                // 4. Equation / Result Banner Strip
                _buildEquationStrip(match, isLive, isUpcoming, isCompleted),

                SizedBox(height: 6.h),

                // 5. Footer (Venue, Date, Arrow)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12.sp, color: th.textSecondary),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                match.ground.isNotEmpty
                                    ? (match.location.isNotEmpty
                                        ? '${match.ground}, ${match.location}'
                                        : match.ground)
                                    : (match.location.isNotEmpty
                                        ? match.location
                                        : 'Cricket Ground'),
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: th.textSecondary,
                                ),
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
                        Icon(Icons.calendar_today_outlined, size: 10.sp, color: th.textSecondary),
                        SizedBox(width: 3.w),
                        Text(
                          DateFormat('d MMM yyyy').format(match.scheduledDate),
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: th.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9.sp,
                          color: th.textSecondary.withValues(alpha: 0.6),
                        ),
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

  Widget _buildTeamRow(
    BuildContext context,
    ThemeHelper th, {
    required String teamId,
    required String teamName,
    required TeamScore score,
    required bool isBatting,
    required bool isWinner,
    required bool isUpcoming,
  }) {
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
            );
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
                size: 26.sp,
              ),
            ),
            SizedBox(width: 8.w),

            // Team Name & Status Badges
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
                            fontSize: 13.sp,
                            fontWeight: isWinner || isBatting ? FontWeight.w800 : FontWeight.w600,
                            color: isWinner
                                ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange)
                                : th.textPrimary,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (isWinner) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.emoji_events, size: 12.sp, color: Colors.amber),
                    ],
                    if (isBatting) ...[
                      SizedBox(width: 5.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_cricket, size: 9.sp, color: AppTheme.primaryOrange),
                            SizedBox(width: 2.w),
                            Text(
                              'Batting',
                              style: TextStyle(
                                fontSize: 8.sp,
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
            SizedBox(width: 6.w),

            // Score Display
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: isUpcoming
                  ? Text(
                      '-',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: th.textSecondary,
                      ),
                    )
                  : (!isBatting && score.runs == 0 && score.wickets == 0 && score.overs == 0.0)
                      ? Text(
                          'Yet to bat',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: th.textSecondary.withValues(alpha: 0.85),
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
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                color: isWinner
                                    ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange)
                                    : th.textPrimary,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              '(${score.overs})',
                              style: TextStyle(
                                fontSize: 10.sp,
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

  Widget _buildPlayerContributionStrip(ThemeHelper th, _PlayerContribution contribution) {
    Color badgeColor = AppTheme.primaryOrange;
    String? statusBadge;
    if (contribution.playerWon == true) {
      badgeColor = const Color(0xFF2E7D32);
      statusBadge = 'WON';
    } else if (contribution.playerLost == true) {
      badgeColor = const Color(0xFFD32F2F);
      statusBadge = 'LOST';
    }

    final List<Widget> statsWidgets = [];

    // Batting stats
    if (contribution.batter != null &&
        (contribution.batter!.runs > 0 ||
            contribution.batter!.balls > 0 ||
            contribution.batter!.isOut)) {
      final b = contribution.batter!;
      final notOut = !b.isOut && b.balls > 0 ? '*' : '';
      statsWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏏 ', style: TextStyle(fontSize: 10.sp)),
            Text(
              '${b.runs}$notOut (${b.balls})',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: th.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    // Bowling stats
    if (contribution.bowler != null &&
        (contribution.bowler!.overs > 0 || contribution.bowler!.balls > 0)) {
      final b = contribution.bowler!;
      if (statsWidgets.isNotEmpty) {
        statsWidgets.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Text('•', style: TextStyle(color: th.textSecondary.withValues(alpha: 0.5))),
          ),
        );
      }
      statsWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎯 ', style: TextStyle(fontSize: 10.sp)),
            Text(
              '${b.wickets}/${b.runs} (${b.oversDisplay})',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: th.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (statsWidgets.isEmpty && statusBadge == null && !contribution.isPotm) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 0.6),
      ),
      child: Row(
        children: [
          if (statusBadge != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                statusBadge,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(width: 6.w),
          ],

          if (statsWidgets.isNotEmpty) ...[
            Text(
              'Contribution: ',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: th.textSecondary,
              ),
            ),
            ...statsWidgets,
          ] else ...[
            Text(
              'Match Participant',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: th.textSecondary,
              ),
            ),
          ],

          const Spacer(),

          if (contribution.isPotm) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, size: 10.sp, color: Colors.amber[800]),
                  SizedBox(width: 2.w),
                  Text(
                    'POTM',
                    style: TextStyle(
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquationStrip(
    MatchModel m,
    bool isLive,
    bool isUpcoming,
    bool isCompleted,
  ) {
    String message;
    IconData icon;
    Color color;

    if (isLive) {
      color = AppTheme.primaryOrange;
      if (m.currentInnings == 2 && m.target != null && m.target! > 0) {
        final runsReq = m.runsRequired;
        final ballsRem = m.ballsRemaining;
        if (runsReq <= 0) {
          message = 'Scores level! Need 1 run to win';
        } else if (ballsRem > 0) {
          message = 'Need $runsReq off $ballsRem balls (Target: ${m.target})';
        } else {
          message = 'Target: ${m.target} • Match in balance';
        }
      } else if (m.currentRunRate > 0) {
        message = 'CRR: ${m.currentRunRate.toStringAsFixed(2)} • 1st Innings ongoing';
      } else {
        message = 'Match in progress';
      }
      icon = Icons.sports_cricket_outlined;
    } else if (isCompleted) {
      color = const Color(0xFF2E7D32);
      final winner = m.winnerTeam;
      final margin = m.winningMargin;
      if (winner == 'Match Tied') {
        message = 'Match Tied';
      } else if (winner != null && winner.isNotEmpty) {
        message = margin.isNotEmpty ? '$winner won by $margin' : '$winner won';
      } else if (m.result != null && m.result!.winner.isNotEmpty) {
        message = m.result!.margin.isNotEmpty
            ? '${m.result!.winner} won by ${m.result!.margin}'
            : '${m.result!.winner} won';
      } else {
        message = 'Match Completed';
      }
      icon = Icons.emoji_events_rounded;
    } else {
      color = const Color(0xFF1976D2);
      message = 'Scheduled • ${DateFormat('EEE, d MMM, h:mm a').format(m.scheduledDate)}';
      icon = Icons.event_available_outlined;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 5.w),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (isCompleted &&
              m.result?.manOfMatch != null &&
              m.result!.manOfMatch.isNotEmpty) ...[
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                'POTM: ${m.result!.manOfMatch}',
                style: TextStyle(
                  fontSize: 8.5.sp,
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

  static _PlayerContribution? _getPlayerContribution(
    MatchModel match,
    String? targetUserId,
    String? targetUserName,
  ) {
    if ((targetUserId == null || targetUserId.isEmpty) &&
        (targetUserName == null || targetUserName.isEmpty)) {
      return null;
    }

    final id = targetUserId?.trim() ?? '';
    final name = targetUserName?.trim().toLowerCase() ?? '';

    bool isMatchPlayer(String pId, String pName) {
      if (id.isNotEmpty && pId == id) return true;
      if (name.isNotEmpty && pName.trim().toLowerCase() == name) return true;
      return false;
    }

    BatterStats? playerBatting;
    BowlerStats? playerBowling;
    bool playedForTeam1 = false;
    bool playedForTeam2 = false;

    // Search Team 1
    for (final b in match.team1Score.batters) {
      if (isMatchPlayer(b.playerId, b.playerName)) {
        playerBatting = b;
        playedForTeam1 = true;
        break;
      }
    }
    for (final b in match.team1Score.bowlers) {
      if (isMatchPlayer(b.playerId, b.playerName)) {
        playerBowling = b;
        playedForTeam1 = true;
        break;
      }
    }

    // Search Team 2
    for (final b in match.team2Score.batters) {
      if (isMatchPlayer(b.playerId, b.playerName)) {
        playerBatting = b;
        playedForTeam2 = true;
        break;
      }
    }
    for (final b in match.team2Score.bowlers) {
      if (isMatchPlayer(b.playerId, b.playerName)) {
        playerBowling = b;
        playedForTeam2 = true;
        break;
      }
    }

    if (!playedForTeam1 && !playedForTeam2 && playerBatting == null && playerBowling == null) {
      // Check if player ID is in match playerIds list
      if (id.isNotEmpty && match.playerIds.contains(id)) {
        // Player was in the match squad but has no batting/bowling entry yet
        return _PlayerContribution(
          batter: null,
          bowler: null,
          playerWon: null,
          playerLost: null,
          isPotm: false,
        );
      }
      return null;
    }

    bool? playerWon;
    bool? playerLost;
    final isCompleted = match.status.toLowerCase() == 'completed';
    if (isCompleted) {
      final isTeam1Winner = match.winnerTeamId == match.team1Id || match.winnerTeam == match.team1Name;
      final isTeam2Winner = match.winnerTeamId == match.team2Id || match.winnerTeam == match.team2Name;

      if (playedForTeam1) {
        playerWon = isTeam1Winner;
        playerLost = isTeam2Winner;
      } else if (playedForTeam2) {
        playerWon = isTeam2Winner;
        playerLost = isTeam1Winner;
      }
    }

    final isPotm = match.result?.manOfMatch != null &&
        match.result!.manOfMatch.isNotEmpty &&
        name.isNotEmpty &&
        match.result!.manOfMatch.trim().toLowerCase() == name;

    return _PlayerContribution(
      batter: playerBatting,
      bowler: playerBowling,
      playerWon: playerWon,
      playerLost: playerLost,
      isPotm: isPotm,
    );
  }
}

class _PlayerContribution {
  final BatterStats? batter;
  final BowlerStats? bowler;
  final bool? playerWon;
  final bool? playerLost;
  final bool isPotm;

  _PlayerContribution({
    required this.batter,
    required this.bowler,
    required this.playerWon,
    required this.playerLost,
    required this.isPotm,
  });
}
