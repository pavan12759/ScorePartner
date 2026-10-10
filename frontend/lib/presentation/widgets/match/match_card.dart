import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/widgets/match/pin_live_score_button.dart';
import '../../../../core/utils/app_responsive.dart';

class MatchCard extends StatelessWidget {
  final MatchModel? match; // Nullable for skeleton/loading state
  final VoidCallback onTap;

  const MatchCard({
    super.key,
    this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      final responsive = AppResponsive.of(context);
      final th = ThemeHelper.of(context);
      return Container(
        width: responsive.matchCardWidth,
        height: 180.h,
        margin: EdgeInsets.only(right: 16.w),
        decoration: BoxDecoration(
          color: th.cardBg,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }

    final isLive = match!.status == 'live';

    final responsive = AppResponsive.of(context);
    final th = ThemeHelper.of(context);

    return Container(
      width: responsive.matchCardWidth,
      margin: EdgeInsets.only(right: 16.w, bottom: 8.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: th.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: th.isDark ? AppTheme.darkContainer : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(100.r),
                              ),
                              child: Text(
                                (match!.matchName.isNotEmpty ? match!.matchName : 'Match').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: th.isDark ? AppTheme.darkSubtitle : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (match!.tournamentName != null && match!.tournamentName!.isNotEmpty) ...[
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                match!.tournamentName!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: th.isDark ? AppTheme.darkSubtitle : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    if (isLive)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: th.isDark ? AppTheme.darkContainer : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        child: Text(
                          match!.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: th.isDark ? AppTheme.darkSubtitle : Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8.h),
                
                // Teams
                _buildTeamRow(
                  context,
                  match!.team1Id,
                  match!.team1Name, 
                  match!.team1Score.runs, 
                  match!.team1Score.wickets, 
                  match!.team1Score.overs,
                  isBatting: match!.currentBattingTeam == 'team1' && isLive,
                ),
                SizedBox(height: 6.h),
                _buildTeamRow(
                  context,
                  match!.team2Id,
                  match!.team2Name, 
                  match!.team2Score.runs, 
                  match!.team2Score.wickets, 
                  match!.team2Score.overs,
                  isBatting: match!.currentBattingTeam == 'team2' && isLive,
                ),
                
                SizedBox(height: 8.h),
                Divider(height: 1.h, color: th.dividerColor),
                SizedBox(height: 4.h),
                
                // Footer
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getStatusText(match!).toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primaryOrange,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLive)
                      PinLiveScoreButton(
                        matchId: match!.id,
                        team1Name: match!.team1Name,
                        team2Name: match!.team2Name,
                        isLive: true,
                        iconOnly: true,
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

  Widget _buildTeamRow(BuildContext context, String teamId, String name, int runs, int wickets, double overs, {bool isBatting = false}) {
    final th = ThemeHelper.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              // Team Icon / Placeholder
              FutureBuilder<TeamModel?>(
                future: FirebaseDataService.instance.getTeamById(teamId),
                builder: (context, snapshot) {
                  final team = snapshot.data;
                  final hasLogo = team != null && team.logoUrl.isNotEmpty;
                  ImageProvider? logoProvider;
                  
                  if (hasLogo) {
                    if (team.logoUrl.startsWith('data:image')) {
                      try {
                        final base64String = team.logoUrl.split(',').last;
                        logoProvider = MemoryImage(base64Decode(base64String));
                      } catch (e) {
                        // fallback if base64 fails
                      }
                    } else {
                      logoProvider = NetworkImage(team.logoUrl);
                    }
                  }

                  return Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                      image: hasLogo && logoProvider != null ? DecorationImage(
                        image: logoProvider,
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: hasLogo && logoProvider != null ? null : Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange, fontSize: 13.sp),
                      ),
                    ),
                  );
                }
              ),
              SizedBox(width: 12.w),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: isBatting ? FontWeight.bold : FontWeight.w500,
                    color: isBatting ? th.textPrimary : th.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBatting) 
                Padding(
                  padding: EdgeInsets.only(left: 8.0.w),
                  child: Icon(Icons.sports_cricket, size: 14.sp, color: AppTheme.primaryOrange),
                ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$runs/$wickets',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: isBatting ? FontWeight.bold : FontWeight.w500,
                color: th.textPrimary,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              '($overs)',
              style: TextStyle(
                fontSize: 11.sp,
                color: th.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getStatusText(MatchModel match) {
    if (match.status == 'live') {
      if (match.tossWinnerId != null && match.tossDecision != null) {
        String tossWinnerName = match.tossWinnerId == match.team1Id 
            ? match.team1Name 
            : (match.tossWinnerId == match.team2Id ? match.team2Name : '');
        if (tossWinnerName.isNotEmpty) {
          return '$tossWinnerName won toss • chose to ${match.tossDecision}';
        }
      }
      return 'Ongoing • ${match.oversPerSide} Overs';
    } else if (match.status == 'completed') {
      final winner = match.winnerTeam;
      final margin = match.winningMargin;
      
      if (winner == 'Match Tied') {
        return 'Match Tied';
      } else if (winner != null && winner.isNotEmpty) {
        if (margin.isNotEmpty) {
          return '$winner won by $margin';
        } else {
          return '$winner won';
        }
      }
      return 'Match Completed';
    } else {
      return 'Scheduled at 10:00 AM'; // Need formatting logic
    }
  }
}
