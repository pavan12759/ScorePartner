import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/presentation/widgets/mvp_calculator_widget.dart';

/// Types of key moments in a cricket match
enum MomentType {
  wicket,
  six,
  four,
  milestone50,
  milestone100,
  maidenOver,
  hatTrick,
  overRate, // High-scoring over
}

/// Represents a key moment in a match
class KeyMoment {
  final MomentType type;
  final String title;
  final String description;
  final String overInfo;
  final IconData icon;
  final Color color;
  final int importance; // 1-10 scale for sorting

  KeyMoment({
    required this.type,
    required this.title,
    required this.description,
    required this.overInfo,
    required this.icon,
    required this.color,
    required this.importance,
  });
}

String _getFielderName(MatchModel match, String fielderId) {
  if (fielderId.isEmpty) return 'fielder';
  for (var b in match.ballByBall) {
    if (b.batsmanId == fielderId) return b.batsmanName;
    if (b.bowlerId == fielderId) return b.bowlerName;
  }
  return 'fielder';
}

/// Extract key moments from ball-by-ball data
List<KeyMoment> extractKeyMoments(MatchModel match) {
  final moments = <KeyMoment>[];
  
  // Track running stats per batsman
  final Map<String, int> batsmanRuns = {};
  final Map<String, bool> hit50 = {};
  final Map<String, bool> hit100 = {};
  
  // Track consecutive wickets for hat-trick detection
  final List<String> recentWicketBowlers = [];
  
  // Track runs per over for high-scoring overs
  final Map<String, Map<int, int>> teamOverRuns = {};
  
  for (var ball in match.ballByBall) {
    final overStr = '${ball.overNumber}.${ball.ballNumber}';
    final teamKey = ball.battingTeam;
    
    // Track batsman runs
    batsmanRuns[ball.batsmanId] = (batsmanRuns[ball.batsmanId] ?? 0) + ball.runs;
    // Track runs per over per team
    teamOverRuns.putIfAbsent(teamKey, () => {});
    teamOverRuns[teamKey]![ball.overNumber] = 
        (teamOverRuns[teamKey]![ball.overNumber] ?? 0) + ball.totalRuns;
    
    // --- SIXES ---
    if (ball.runs == 6) {
      moments.add(KeyMoment(
        type: MomentType.six,
        title: 'SIX! 🔥',
        description: '${ball.batsmanName} smashes a massive six off ${ball.bowlerName}',
        overInfo: 'Over $overStr',
        icon: Icons.sports_cricket,
        color: Colors.purple,
        importance: 5,
      ));
    }
    
    // --- FOURS ---
    if (ball.runs == 4) {
      moments.add(KeyMoment(
        type: MomentType.four,
        title: 'FOUR! 🏏',
        description: '${ball.batsmanName} finds the boundary off ${ball.bowlerName}',
        overInfo: 'Over $overStr',
        icon: Icons.sports_cricket,
        color: Colors.blue,
        importance: 3,
      ));
    }
    
    // --- WICKETS ---
    if (ball.wicket != null) {
      String dismissalDesc;
      switch (ball.wicket!.type) {
        case 'bowled':
          dismissalDesc = '${ball.batsmanName} bowled by ${ball.bowlerName}! Timber! 🪵';
          break;
        case 'caught':
          final fielderId = ball.wicket!.fielderId ?? '';
          final fielder = fielderId.isNotEmpty ? _getFielderName(match, fielderId) : 'fielder';
          dismissalDesc = '${ball.batsmanName} caught by $fielder off ${ball.bowlerName}! 🤲';
          break;
        case 'lbw':
          dismissalDesc = '${ball.batsmanName} LBW to ${ball.bowlerName}! Plumb in front! ☝️';
          break;
        case 'run out':
          final fielderId = ball.wicket!.fielderId ?? '';
          final fielder = fielderId.isNotEmpty ? _getFielderName(match, fielderId) : 'fielder';
          dismissalDesc = '${ball.batsmanName} run out by $fielder! 🎯';
          break;
        case 'stumped':
          final fielderId = ball.wicket!.fielderId ?? '';
          final keeper = fielderId.isNotEmpty ? _getFielderName(match, fielderId) : 'keeper';
          dismissalDesc = '${ball.batsmanName} stumped by $keeper off ${ball.bowlerName}! ⚡';
          break;
        default:
          dismissalDesc = '${ball.batsmanName} dismissed by ${ball.bowlerName}!';
      }
      
      moments.add(KeyMoment(
        type: MomentType.wicket,
        title: 'WICKET! ❌',
        description: dismissalDesc,
        overInfo: 'Over $overStr',
        icon: Icons.close,
        color: Colors.red,
        importance: 7,
      ));
      
      // Hat-trick detection
      recentWicketBowlers.add(ball.bowlerId);
      if (recentWicketBowlers.length >= 3) {
        final last3 = recentWicketBowlers.sublist(recentWicketBowlers.length - 3);
        if (last3.every((id) => id == last3.first)) {
          moments.add(KeyMoment(
            type: MomentType.hatTrick,
            title: 'HAT-TRICK! 🎩🎩🎩',
            description: '${ball.bowlerName} takes a sensational hat-trick!',
            overInfo: 'Over $overStr',
            icon: Icons.celebration,
            color: Colors.amber,
            importance: 10,
          ));
        }
      }
    } else {
      // Reset hat-trick tracking on non-wicket legal balls
      if (ball.isLegalBall) {
        // Don't reset — hat-trick is consecutive deliveries including across overs
      }
    }
    
    // --- MILESTONES ---
    final currentRuns = batsmanRuns[ball.batsmanId] ?? 0;
    
    if (currentRuns >= 50 && hit50[ball.batsmanId] != true) {
      hit50[ball.batsmanId] = true;
      moments.add(KeyMoment(
        type: MomentType.milestone50,
        title: 'FIFTY! 5️⃣0️⃣',
        description: '${ball.batsmanName} reaches a brilliant half-century! ($currentRuns runs)',
        overInfo: 'Over $overStr',
        icon: Icons.star,
        color: Colors.teal,
        importance: 8,
      ));
    }
    
    // Century
    if (currentRuns >= 100 && hit100[ball.batsmanId] != true) {
      hit100[ball.batsmanId] = true;
      moments.add(KeyMoment(
        type: MomentType.milestone100,
        title: 'CENTURY! 💯',
        description: '${ball.batsmanName} smashes a magnificent century! ($currentRuns runs)',
        overInfo: 'Over $overStr',
        icon: Icons.emoji_events,
        color: Colors.amber,
        importance: 10,
      ));
    }
  }
  
  // --- MAIDEN OVERS (post-process) ---
  for (var teamEntry in teamOverRuns.entries) {
    for (var overEntry in teamEntry.value.entries) {
      if (overEntry.value == 0) {
        // Find bowler name for this over
        final bowlerBall = match.ballByBall.firstWhere(
          (b) => b.battingTeam == teamEntry.key && b.overNumber == overEntry.key,
          orElse: () => match.ballByBall.first,
        );
        moments.add(KeyMoment(
          type: MomentType.maidenOver,
          title: 'MAIDEN! ⭕',
          description: '${bowlerBall.bowlerName} bowls a maiden over!',
          overInfo: 'Over ${overEntry.key + 1}',
          icon: Icons.block,
          color: Colors.green,
          importance: 4,
        ));
      }
      // High-scoring over (15+)
      if (overEntry.value >= 15) {
        moments.add(KeyMoment(
          type: MomentType.overRate,
          title: '${overEntry.value} RUNS! 💥',
          description: '${overEntry.value} runs scored in over ${overEntry.key + 1}! Carnage!',
          overInfo: 'Over ${overEntry.key + 1}',
          icon: Icons.local_fire_department,
          color: Colors.deepOrange,
          importance: 6,
        ));
      }
    }
  }
  
  // Sort by importance (highest first), then limit to most exciting moments
  moments.sort((a, b) => b.importance.compareTo(a.importance));
  
  return moments;
}

/// Widget that displays key moments / highlights timeline
class KeyMomentsCard extends StatelessWidget {
  final MatchModel match;
  final int maxMoments;
  final bool showAll;

  const KeyMomentsCard({
    super.key,
    required this.match,
    this.maxMoments = 10,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final allMoments = extractKeyMoments(match);
    
    // Extract top performance stats for summary widgets
    final allBatters = [...match.team1Score.batters, ...match.team2Score.batters];
    final allBowlers = [...match.team1Score.bowlers, ...match.team2Score.bowlers];
    
    // 1. Find Best Batter
    allBatters.sort((a, b) => b.runs.compareTo(a.runs));
    final bestBatter = allBatters.isNotEmpty && allBatters.first.runs > 0 ? allBatters.first : null;

    // 2. Find Best Bowler
    allBowlers.sort((a, b) {
      final comp = b.wickets.compareTo(a.wickets);
      if (comp != 0) return comp;
      return a.runs.compareTo(b.runs);
    });
    final bestBowler = allBowlers.isNotEmpty && allBowlers.first.wickets > 0 ? allBowlers.first : null;

    // 3. Find Most Sixes
    final sixesList = List<dynamic>.from(allBatters)..sort((a, b) => b.sixes.compareTo(a.sixes));
    final mostSixes = sixesList.isNotEmpty && sixesList.first.sixes > 0 ? sixesList.first : null;

    // 4. Man of the Match (MVP)
    final mvpList = calculateMvpRatings(match);
    final mvp = mvpList.isNotEmpty ? mvpList.firstWhere((p) => p.isManOfMatch, orElse: () => mvpList.first) : null;

    final displayMoments = showAll ? allMoments : allMoments.take(maxMoments).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🏆 A. TOP SUMMARY HERO CARDS (IPL / GAMING ACHIEVEMENT STYLE)
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.orange.withOpacity(0.12), width: 1.5.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stars_rounded, color: Colors.orange, size: 20.sp),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'MATCH CHAMPION BOARDS 🏆',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              
              // Scrollable Row of high-fidelity overlay highlight blocks
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // MOTM Card
                    if (mvp != null)
                      _buildHeroStatsCard(
                        title: 'Man Of The Match',
                        name: mvp.playerName,
                        subtitle: '${mvp.mvpPoints.toStringAsFixed(0)} MVP Rating 👑',
                        badgeType: 'team',
                        themeColor: Colors.amberAccent,
                        icon: Icons.emoji_events,
                      ),
                    
                    // Batter Card
                    if (bestBatter != null)
                      _buildHeroStatsCard(
                        title: 'Best Batter',
                        name: bestBatter.playerName,
                        subtitle: '${bestBatter.runs} Runs in ${bestBatter.balls}b 🏏',
                        badgeType: 'batsman',
                        themeColor: Colors.orangeAccent,
                        icon: Icons.flash_on,
                      ),
                    
                    // Bowler Card
                    if (bestBowler != null)
                      _buildHeroStatsCard(
                        title: 'Best Bowler',
                        name: bestBowler.playerName,
                        subtitle: '${bestBowler.wickets} Wkts for ${bestBowler.runs}r 🎯',
                        badgeType: 'bowler',
                        themeColor: Colors.cyanAccent,
                        icon: Icons.local_fire_department,
                      ),

                    // Most Sixes Card
                    if (mostSixes != null)
                      _buildHeroStatsCard(
                        title: 'Six Storm',
                        name: mostSixes.playerName,
                        subtitle: '${mostSixes.sixes} Over-the-boundary ⚡',
                        badgeType: 'batsman',
                        themeColor: Colors.purpleAccent,
                        icon: Icons.bolt,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // 📅 B. CHRONOLOGICAL KEY MOMENTS TIMELINE
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline_rounded, color: AppTheme.primaryOrange, size: 22.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'CHRONOLOGICAL MATCH TIMELINE ⏱️',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              allMoments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0.w),
                        child: Text(
                          'Waiting for live events to build timeline...',
                          style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                        ),
                      ),
                    )
                  : Column(
                      children: displayMoments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final moment = entry.value;
                        final isLast = index == displayMoments.length - 1;

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Timeline vertical line with glowing icon dot
                              SizedBox(
                                width: 44.w,
                                child: Column(
                                  children: [
                                    SizedBox(height: 6.h),
                                    Container(
                                      width: 24.w,
                                      height: 24.h,
                                      decoration: BoxDecoration(
                                        color: moment.color.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: moment.color, width: 2.w),
                                      ),
                                      child: Icon(
                                        moment.icon,
                                        size: 11.sp,
                                        color: moment.color,
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2.w,
                                          margin: EdgeInsets.symmetric(vertical: 4.h),
                                          color: Colors.grey[200],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 4.w),
                              
                              // Moment detail glass card
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
                                  child: Container(
                                    padding: EdgeInsets.all(12.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16.r),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.08),
                                        width: 1.2.w,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: moment.color.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8.r),
                                              ),
                                              child: Text(
                                                moment.title.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: moment.color,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              moment.overInfo,
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: Colors.grey[500],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          moment.description,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatsCard({
    required String title,
    required String name,
    required String subtitle,
    required String badgeType,
    required Color themeColor,
    required IconData icon,
  }) {
    return Container(
      width: 165.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: themeColor.withOpacity(0.35), width: 1.2.w),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 8.sp,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: themeColor, size: 14.sp),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.sp,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 9.sp,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
