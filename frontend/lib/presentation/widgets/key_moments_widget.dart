import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/presentation/widgets/player_avatar_widget.dart';
import 'package:scorepatner/presentation/widgets/key_moment_poster_card.dart';

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
  final String? playerId;
  final String? playerName;

  KeyMoment({
    required this.type,
    required this.title,
    required this.description,
    required this.overInfo,
    required this.icon,
    required this.color,
    required this.importance,
    this.playerId,
    this.playerName,
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
        playerId: ball.batsmanId,
        playerName: ball.batsmanName,
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
        playerId: ball.batsmanId,
        playerName: ball.batsmanName,
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
        playerId: ball.bowlerId,
        playerName: ball.bowlerName,
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
            playerId: ball.bowlerId,
            playerName: ball.bowlerName,
          ));
        }
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
        playerId: ball.batsmanId,
        playerName: ball.batsmanName,
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
        playerId: ball.batsmanId,
        playerName: ball.batsmanName,
      ));
    }
  }
  
  // --- MAIDEN OVERS (post-process) ---
  for (var teamEntry in teamOverRuns.entries) {
    for (var overEntry in teamEntry.value.entries) {
      if (overEntry.value == 0) {
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
          playerId: bowlerBall.bowlerId,
          playerName: bowlerBall.bowlerName,
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
  
  // Sort by importance (highest first)
  moments.sort((a, b) => b.importance.compareTo(a.importance));
  
  return moments;
}

/// Widget that displays key moments / highlights timeline and performance posters
class KeyMomentsCard extends StatefulWidget {
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
  State<KeyMomentsCard> createState() => _KeyMomentsCardState();
}

class _KeyMomentsCardState extends State<KeyMomentsCard> {
  KeyMomentPosterTheme? _selectedTheme;

  @override
  void initState() {
    super.initState();
    _preloadPlayerPhotos();
  }

  void _preloadPlayerPhotos() {
    final posters = KeyMomentPosterModel.extractPosters(widget.match);
    final playerIds = posters
        .map((p) => p.playerId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (playerIds.isNotEmpty) {
      PlayerAvatarWidget.prefetch(playerIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMoments = extractKeyMoments(widget.match);
    final posters = KeyMomentPosterModel.extractPosters(widget.match);
    final displayMoments = widget.showAll ? allMoments : allMoments.take(widget.maxMoments).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🏆 A. KEY MOMENTS PERFORMANCE POSTERS CAROUSEL
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.orange.withOpacity(0.15), width: 1.5.w),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(7.w),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.stars_rounded, color: Colors.orange, size: 20.sp),
                      ),
                      SizedBox(width: 8.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KEY MOMENTS & POSTERS 🏆',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'Player profile photos, scores & performances',
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '${posters.length} Posters',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Theme Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedTheme = null),
                      child: Container(
                        margin: EdgeInsets.only(right: 6.w),
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: _selectedTheme == null
                              ? AppTheme.primaryOrange
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '✨ Auto Badges',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: _selectedTheme == null ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    ...KeyMomentPosterTheme.values.map((theme) {
                      final isSelected = _selectedTheme == theme;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTheme = theme),
                        child: Container(
                          margin: EdgeInsets.only(right: 6.w),
                          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.primary : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : theme.primary.withOpacity(0.35),
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7.w,
                                height: 7.w,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black : theme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                theme.name,
                                style: TextStyle(
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.black : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Poster Cards Horizontal Carousel
              if (posters.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  alignment: Alignment.center,
                  child: Text(
                    'Match performance posters will appear as match progresses...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 395.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: posters.length,
                    itemBuilder: (context, index) {
                      return KeyMomentPosterCard(
                        poster: posters[index],
                        overrideTheme: _selectedTheme,
                      );
                    },
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
                offset: const Offset(0, 4),
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
                              
                              // Moment detail glass card with Player Avatar
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
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Optional mini avatar if player exists
                                        if (moment.playerName != null && moment.playerName!.isNotEmpty) ...[
                                          PlayerAvatarWidget(
                                            playerId: moment.playerId,
                                            playerName: moment.playerName!,
                                            size: 36.w,
                                            enableProfileView: true,
                                          ),
                                          SizedBox(width: 10.w),
                                        ],

                                        // Text Details
                                        Expanded(
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
}
