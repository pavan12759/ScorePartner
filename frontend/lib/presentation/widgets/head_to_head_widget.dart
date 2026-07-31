import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';

/// Head-to-Head stats widget showing historical record between two teams
class HeadToHeadCard extends StatefulWidget {
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;

  const HeadToHeadCard({
    super.key,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  State<HeadToHeadCard> createState() => _HeadToHeadCardState();
}

class _HeadToHeadCardState extends State<HeadToHeadCard> {
  List<MatchModel>? _h2hMatches;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadH2H();
  }

  Future<void> _loadH2H() async {
    try {
      // Get completed matches between these two teams  
      final h2h = await FirebaseDataService.instance.getMatchesBetweenTeams(
        widget.team1Id,
        widget.team2Id,
      );
      
      // Sort by date (most recent first)
      h2h.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      
      if (mounted) {
        setState(() {
          _h2hMatches = h2h;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(20.w),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange, strokeWidth: 2),
        ),
      );
    }

    if (_h2hMatches == null || _h2hMatches!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
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
        ),
        child: Column(
          children: [
            Icon(Icons.compare_arrows, size: 32.sp, color: Colors.grey),
            SizedBox(height: 8.h),
            Text(
              'No previous meetings',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // Calculate stats
    int team1Wins = 0;
    int team2Wins = 0;
    int ties = 0;
    int totalTeam1Runs = 0;
    int totalTeam2Runs = 0;
    int highestTotal = 0;
    String highestTotalTeam = '';

    for (var match in _h2hMatches!) {
      // Map actual team1/team2 in each match to our widget's team1/team2
      bool t1IsWidgetT1 = match.team1Id == widget.team1Id;
      
      int t1Runs = t1IsWidgetT1 ? match.team1Score.runs : match.team2Score.runs;
      int t2Runs = t1IsWidgetT1 ? match.team2Score.runs : match.team1Score.runs;
      
      totalTeam1Runs += t1Runs;
      totalTeam2Runs += t2Runs;
      
      if (t1Runs > highestTotal) {
        highestTotal = t1Runs;
        highestTotalTeam = widget.team1Name;
      }
      if (t2Runs > highestTotal) {
        highestTotal = t2Runs;
        highestTotalTeam = widget.team2Name;
      }
      
      // Determine winner - check winnerTeamId first, then fall back to winnerTeam name
      if (match.winnerTeamId != null && match.winnerTeamId!.isNotEmpty) {
        if (match.winnerTeamId == widget.team1Id) {
          team1Wins++;
        } else if (match.winnerTeamId == widget.team2Id) {
          team2Wins++;
        } else {
          ties++;
        }
      } else if (match.winnerTeam != null && match.winnerTeam!.isNotEmpty && match.winnerTeam != 'Match Tied') {
        // Fallback: match winner name against team names
        if (match.winnerTeam == widget.team1Name) {
          team1Wins++;
        } else if (match.winnerTeam == widget.team2Name) {
          team2Wins++;
        } else {
          // Check if winner name matches either team in the match data
          if (match.winnerTeam == match.team1Name) {
            // Winner is match's team1 — figure out which widget team that is
            if (match.team1Id == widget.team1Id) {
              team1Wins++;
            } else {
              team2Wins++;
            }
          } else if (match.winnerTeam == match.team2Name) {
            if (match.team2Id == widget.team1Id) {
              team1Wins++;
            } else {
              team2Wins++;
            }
          } else {
            ties++;
          }
        }
      } else {
        ties++;
      }
    }

    final total = _h2hMatches!.length;

    return Container(
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
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.indigo.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.compare_arrows, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'HEAD TO HEAD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.sp,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '$total MATCHES',
                    style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Win/Loss bar
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.team1Name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$team1Wins',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: team1Wins > team2Wins ? Colors.green : Colors.black54,
                        ),
                      ),
                      Text('WINS', style: TextStyle(fontSize: 9.sp, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Center divider with ties
                Column(
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!, width: 2.w),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$ties',
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.black54),
                          ),
                          Text('DRAW', style: TextStyle(fontSize: 7.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.team2Name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$team2Wins',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: team2Wins > team1Wins ? Colors.green : Colors.black54,
                        ),
                      ),
                      Text('WINS', style: TextStyle(fontSize: 9.sp, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Win bar visualization
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Row(
                children: [
                  if (team1Wins > 0)
                    Expanded(
                      flex: team1Wins,
                      child: Container(height: 8.h, color: Colors.green),
                    ),
                  if (ties > 0)
                    Expanded(
                      flex: ties,
                      child: Container(height: 8.h, color: Colors.grey[300]),
                    ),
                  if (team2Wins > 0)
                    Expanded(
                      flex: team2Wins,
                      child: Container(height: 8.h, color: Colors.blue),
                    ),
                ],
              ),
            ),
          ),
          // Quick stats
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildH2HStat('Avg Score', '${total > 0 ? (totalTeam1Runs / total).round() : 0}', widget.team1Name),
                Container(width: 1.w, height: 30.h, color: Colors.grey[200]),
                _buildH2HStat('Avg Score', '${total > 0 ? (totalTeam2Runs / total).round() : 0}', widget.team2Name),
                Container(width: 1.w, height: 30.h, color: Colors.grey[200]),
                _buildH2HStat('Highest', '$highestTotal', highestTotalTeam),
              ],
            ),
          ),
          // Recent results
          if (_h2hMatches!.length > 1) ...[
            Divider(height: 1.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECENT RESULTS',
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1),
                  ),
                  SizedBox(height: 8.h),
                  ..._h2hMatches!.take(3).map((m) => _buildRecentResult(m)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildH2HStat(String label, String value, String team) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
        Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey[500])),
        Text(team, style: TextStyle(fontSize: 8.sp, color: Colors.grey[400], fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildRecentResult(MatchModel match) {
    final winner = match.winnerTeam ?? 'Tie';
    final margin = match.winningMargin.isNotEmpty ? match.winningMargin : '';
    
    // Determine which widget team won
    Color dotColor = Colors.grey;
    if (match.winnerTeamId != null && match.winnerTeamId!.isNotEmpty) {
      dotColor = match.winnerTeamId == widget.team1Id
          ? Colors.green
          : match.winnerTeamId == widget.team2Id
              ? Colors.blue
              : Colors.grey;
    } else if (match.winnerTeam != null && match.winnerTeam!.isNotEmpty && match.winnerTeam != 'Match Tied') {
      if (match.winnerTeam == widget.team1Name || 
          (match.winnerTeam == match.team1Name && match.team1Id == widget.team1Id) ||
          (match.winnerTeam == match.team2Name && match.team2Id == widget.team1Id)) {
        dotColor = Colors.green;
      } else {
        dotColor = Colors.blue;
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Container(
            width: 6.w,
            height: 6.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              margin.isNotEmpty ? '$winner won by $margin' : winner,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${match.scheduledDate.day}/${match.scheduledDate.month}/${match.scheduledDate.year}',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

