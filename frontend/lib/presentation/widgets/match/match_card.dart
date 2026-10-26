import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/screens/teams/team_details_screen.dart';
import 'package:scorepatner/presentation/widgets/match/pin_live_score_button.dart';
import 'package:scorepatner/presentation/widgets/team_logo_widget.dart';
import '../../../../core/utils/app_responsive.dart';

class MatchCard extends StatelessWidget {
  final MatchModel? match; // Nullable for skeleton/loading state
  final VoidCallback onTap;

  // In-memory cache to prevent redundant Firestore calls across cards and re-renders
  static final Map<String, TeamModel?> _teamCache = {};

  const MatchCard({
    super.key,
    this.match,
    required this.onTap,
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
    final responsive = AppResponsive.of(context);
    final th = ThemeHelper.of(context);

    if (match == null) {
      return Container(
        width: responsive.matchCardWidth,
        margin: EdgeInsets.only(right: 14.w, bottom: 6.h),
        decoration: BoxDecoration(
          color: th.cardBg,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: th.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryOrange),
          ),
        ),
      );
    }

    final m = match!;
    final statusLower = m.status.toLowerCase();
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

    final isTeam1Batting = isLive && (m.currentBattingTeam == 'team1' || m.currentBattingTeam == m.team1Id || m.currentBattingTeam == m.team1Name);
    final isTeam2Batting = isLive && (m.currentBattingTeam == 'team2' || m.currentBattingTeam == m.team2Id || m.currentBattingTeam == m.team2Name);

    final isTeam1Winner = isCompleted && (m.winnerTeam == m.team1Name || m.winnerTeamId == m.team1Id);
    final isTeam2Winner = isCompleted && (m.winnerTeam == m.team2Name || m.winnerTeamId == m.team2Id);

    final bool hasCustomName = m.matchName.isNotEmpty &&
        m.matchName.toLowerCase() != '${m.team1Name} vs ${m.team2Name}'.toLowerCase() &&
        m.matchName.toLowerCase() != 'match';

    return Container(
      width: responsive.matchCardWidth,
      margin: EdgeInsets.only(right: 14.w, bottom: 4.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row (Status Pill on left, Format & Pin Button on right)
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
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
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Format Badge (e.g., T20 • 20 Ov)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: th.dividerColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Text(
                        m.oversPerSide > 0
                            ? '${m.matchFormat.isNotEmpty ? m.matchFormat : "Match"} • ${m.oversPerSide} Ov'
                            : (m.matchFormat.isNotEmpty ? m.matchFormat : 'Match'),
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: th.textSecondary,
                        ),
                      ),
                    ),

                    // Pin Live Score button for live match
                    if (isLive) ...[
                      SizedBox(width: 4.w),
                      PinLiveScoreButton(
                        matchId: m.id,
                        team1Name: m.team1Name,
                        team2Name: m.team2Name,
                        isLive: true,
                        iconOnly: true,
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 5.h),

                // 2. Teams Container (Teams, Logos, Batting indicator, Scores)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      // Team 1 Row
                      _buildTeamRow(
                        context,
                        th,
                        teamId: m.team1Id,
                        teamName: m.team1Name,
                        score: m.team1Score,
                        isBatting: isTeam1Batting,
                        isWinner: isTeam1Winner,
                        isUpcoming: isUpcoming,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3.h),
                        child: Divider(
                          height: 1,
                          thickness: 0.8,
                          color: th.dividerColor.withOpacity(0.5),
                        ),
                      ),
                      // Team 2 Row
                      _buildTeamRow(
                        context,
                        th,
                        teamId: m.team2Id,
                        teamName: m.team2Name,
                        score: m.team2Score,
                        isBatting: isTeam2Batting,
                        isWinner: isTeam2Winner,
                        isUpcoming: isUpcoming,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 4.h),

                // 3. Equation / Result Banner Strip
                _buildEquationStrip(m, isLive, isUpcoming, isCompleted),

                SizedBox(height: 4.h),

                // 4. Downside: Tournament Name (prominent and fully visible)
                if (m.tournamentName != null && m.tournamentName!.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.emoji_events, size: 12.sp, color: Colors.amber[700]),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          hasCustomName
                              ? '${m.tournamentName!.trim()} • ${m.matchName}'
                              : m.tournamentName!.trim(),
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: th.isDark ? Colors.amber[300] : const Color(0xFFD97706),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                ] else if (hasCustomName) ...[
                  Row(
                    children: [
                      Icon(Icons.sports_cricket, size: 11.sp, color: th.textSecondary),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          m.matchName,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            color: th.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                ],

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
                                m.ground.isNotEmpty
                                    ? (m.location.isNotEmpty ? '${m.ground}, ${m.location}' : m.ground)
                                    : (m.location.isNotEmpty ? m.location : 'Cricket Ground'),
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
                    SizedBox(width: 6.w),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 10.sp, color: th.textSecondary),
                        SizedBox(width: 3.w),
                        Text(
                          DateFormat('d MMM').format(m.scheduledDate),
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: th.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.arrow_forward_ios_rounded, size: 9.sp, color: th.textSecondary.withOpacity(0.6)),
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
            // Team Logo / Profile Picture (Clickable to profile)
            GestureDetector(
              onTap: hasProfile ? navigateToTeamProfile : null,
              child: TeamLogoWidget(
                teamName: teamName,
                logoUrl: logoUrl,
                size: 26.sp,
              ),
            ),
            SizedBox(width: 8.w),

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
                            fontSize: 13.sp,
                            fontWeight: isWinner || isBatting ? FontWeight.w800 : FontWeight.w600,
                            color: isWinner ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange) : th.textPrimary,
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
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.12),
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
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                color: isWinner ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange) : th.textPrimary,
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

  Widget _buildEquationStrip(MatchModel m, bool isLive, bool isUpcoming, bool isCompleted) {
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
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
          if (isCompleted && m.result?.manOfMatch != null && m.result!.manOfMatch.isNotEmpty) ...[
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
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
}
