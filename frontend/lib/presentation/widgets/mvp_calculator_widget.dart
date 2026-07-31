import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';

/// MVP (Most Valuable Player) data for a single player
class MvpEntry {
  final String playerId;
  final String playerName;
  final String teamName;
  final double mvpPoints;
  final int runs;
  final int balls;
  final int wickets;
  final int runsConceded;
  final int catches;
  final int runOuts;
  final bool isManOfMatch;

  MvpEntry({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.mvpPoints,
    this.runs = 0,
    this.balls = 0,
    this.wickets = 0,
    this.runsConceded = 0,
    this.catches = 0,
    this.runOuts = 0,
    this.isManOfMatch = false,
  });
}
List<MvpEntry> calculateMvpRatings(MatchModel match) {
  final Map<String, _MvpAccumulator> playerData = {};

  void _ensurePlayer(String id, String name, String team) {
    playerData.putIfAbsent(id, () => _MvpAccumulator(name: name, team: team));
  }

  final team1ScoreToUse = match.isSuperOver && match.mainMatchScores != null
      ? match.mainMatchScores!['team1']!
      : match.team1Score;
  final team2ScoreToUse = match.isSuperOver && match.mainMatchScores != null
      ? match.mainMatchScores!['team2']!
      : match.team2Score;

  // --- Process batting stats ---
  for (var batter in team1ScoreToUse.batters) {
    if (batter.playerId.isEmpty) continue;
    _ensurePlayer(batter.playerId, batter.playerName, match.team1Name);
    final p = playerData[batter.playerId]!;
    p.runs = batter.runs;
    p.balls = batter.balls;
    p.fours = batter.fours;
    p.sixes = batter.sixes;
    p.isOut = batter.isOut;
  }
  for (var batter in team2ScoreToUse.batters) {
    if (batter.playerId.isEmpty) continue;
    _ensurePlayer(batter.playerId, batter.playerName, match.team2Name);
    final p = playerData[batter.playerId]!;
    p.runs = batter.runs;
    p.balls = batter.balls;
    p.fours = batter.fours;
    p.sixes = batter.sixes;
    p.isOut = batter.isOut;
  }

  // --- Process bowling stats ---
  for (var bowler in team1ScoreToUse.bowlers) {
    if (bowler.playerId.isEmpty) continue;
    // Bowlers from team1Score bowled against team1 — they belong to team2
    _ensurePlayer(bowler.playerId, bowler.playerName, match.team2Name);
    final p = playerData[bowler.playerId]!;
    p.wickets = bowler.wickets;
    p.runsConceded = bowler.runs;
    p.maidens = bowler.maidens;
    p.oversBowled = bowler.overs + (bowler.balls / 6);
    p.dotBalls = _countDotBalls(match, bowler.playerId);
  }
  for (var bowler in team2ScoreToUse.bowlers) {
    if (bowler.playerId.isEmpty) continue;
    _ensurePlayer(bowler.playerId, bowler.playerName, match.team1Name);
    final p = playerData[bowler.playerId]!;
    p.wickets = bowler.wickets;
    p.runsConceded = bowler.runs;
    p.maidens = bowler.maidens;
    p.oversBowled = bowler.overs + (bowler.balls / 6);
    p.dotBalls = _countDotBalls(match, bowler.playerId);
  }

  // --- Process fielding from ball events ---
  for (var ball in match.ballByBall) {
    if (ball.wicket != null) {
      final w = ball.wicket!;
      final fId = w.fielderId ?? '';
      final fName = playerData.containsKey(fId) ? playerData[fId]!.name : 'Fielder';
      // Catches
      if (w.type == 'caught' && fId.isNotEmpty) {
        _ensurePlayer(fId, fName, '');
        playerData[fId]!.catches++;
      }
      // Run outs
      if (w.type == 'run out' && fId.isNotEmpty) {
        _ensurePlayer(fId, fName, '');
        playerData[fId]!.runOuts++;
      }
      // Stumpings
      if (w.type == 'stumped' && fId.isNotEmpty) {
        _ensurePlayer(fId, fName, '');
        playerData[fId]!.stumpings++;
      }
    }
  }

  // --- Calculate MVP score ---
  final String momName = match.result?.manOfMatch ?? '';
  
  final entries = playerData.entries.map((e) {
    final p = e.value;
    double score = 0;

    // Batting points: 1 run = 1 point
    score += p.runs * 1.0;

    // Bowling points: 1 wicket = 20 points
    score += p.wickets * 20.0;

    // Fielding points: caught = 2 points, run out = 5 points
    score += p.catches * 2.0;
    score += p.runOuts * 5.0;

    return MvpEntry(
      playerId: e.key,
      playerName: p.name,
      teamName: p.team,
      mvpPoints: score,
      runs: p.runs,
      balls: p.balls,
      wickets: p.wickets,
      runsConceded: p.runsConceded,
      catches: p.catches,
      runOuts: p.runOuts,
      isManOfMatch: momName.isNotEmpty && p.name.toLowerCase() == momName.toLowerCase(),
    );
  }).toList();

  // Sort descending by MVP points
  entries.sort((a, b) => b.mvpPoints.compareTo(a.mvpPoints));
  return entries;
}

int _countDotBalls(MatchModel match, String bowlerId) {
  return match.ballByBall.where((b) =>
    b.bowlerId == bowlerId && b.totalRuns == 0 && b.wicket == null && b.isLegalBall
  ).length;
}

class _MvpAccumulator {
  String name;
  String team;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  bool isOut = false;
  int wickets = 0;
  int runsConceded = 0;
  int maidens = 0;
  double oversBowled = 0;
  int dotBalls = 0;
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;

  _MvpAccumulator({required this.name, required this.team});
}

/// Widget that displays MVP ratings in a beautiful card
class MvpRatingCard extends StatelessWidget {
  final MatchModel match;
  final int maxPlayers;

  const MvpRatingCard({
    super.key,
    required this.match,
    this.maxPlayers = 5,
  });

  @override
  Widget build(BuildContext context) {
    final mvpList = calculateMvpRatings(match);
    if (mvpList.isEmpty) return SizedBox.shrink();

    final displayList = mvpList.take(maxPlayers).toList();
    final topScore = displayList.isNotEmpty ? displayList.first.mvpPoints : 1;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade700, Colors.amber.shade900],
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
                Icon(Icons.star, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'MVP RATINGS',
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
                    'TOP ${displayList.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Player list
          ...displayList.asMap().entries.map((entry) {
            final index = entry.key;
            final mvp = entry.value;
            final barWidth = topScore > 0 ? (mvp.mvpPoints / topScore) : 0.0;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: index < displayList.length - 1
                    ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
                    : null,
                color: index == 0 ? Colors.amber.withOpacity(0.05) : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 28.w,
                        height: 28.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == 0
                              ? Colors.amber
                              : index == 1
                                  ? Colors.grey.shade400
                                  : index == 2
                                      ? Colors.brown.shade300
                                      : Colors.grey.shade200,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index < 3 ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Player info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mvp.playerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                      color: index == 0 ? Colors.amber.shade800 : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (mvp.isManOfMatch) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      'MOM',
                                      style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _buildPerformanceSummary(mvp),
                              style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Score
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.withOpacity(0.15)
                              : AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          mvp.mvpPoints.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.sp,
                            color: index == 0 ? Colors.amber.shade800 : AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Progress bar
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: LinearProgressIndicator(
                      value: barWidth.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(
                        index == 0
                            ? Colors.amber
                            : index == 1
                                ? AppTheme.primaryOrange
                                : AppTheme.primaryOrange.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  String _buildPerformanceSummary(MvpEntry mvp) {
    final parts = <String>[];
    if (mvp.runs > 0 || mvp.balls > 0) parts.add('${mvp.runs}(${mvp.balls})');
    if (mvp.wickets > 0) parts.add('${mvp.wickets}/${mvp.runsConceded}');
    if (mvp.catches > 0) parts.add('${mvp.catches} ct');
    if (mvp.runOuts > 0) parts.add('${mvp.runOuts} ro');
    return parts.join(' • ');
  }
}

