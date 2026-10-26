import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/achievement_model.dart';
import '../../data/models/match_model.dart';
import '../../data/services/firebase_data_service.dart';
import 'mvp_calculator_widget.dart';
import 'player_avatar_widget.dart';

/// Available Themes for Key Moment Posters
enum KeyMomentPosterTheme {
  gold(
    id: 'gold',
    name: 'Golden Glory',
    icon: Icons.emoji_events_rounded,
    primary: Color(0xFFFFB300),
    accent: Color(0xFFFFA000),
    gradientColors: [Color(0xFFFFB300), Color(0xFFF57C00), Color(0xFF181000)],
  ),
  fire(
    id: 'fire',
    name: 'Crimson Fire',
    icon: Icons.local_fire_department_rounded,
    primary: Color(0xFFFF3D00),
    accent: Color(0xFFFF6E40),
    gradientColors: [Color(0xFFFF3D00), Color(0xFFDD2C00), Color(0xFF200600)],
  ),
  cyber(
    id: 'cyber',
    name: 'Cyber Electric',
    icon: Icons.flash_on_rounded,
    primary: Color(0xFF00E5FF),
    accent: Color(0xFF18FFFF),
    gradientColors: [Color(0xFF00E5FF), Color(0xFF0091EA), Color(0xFF001A29)],
  ),
  violet(
    id: 'violet',
    name: 'Neon Violet',
    icon: Icons.bolt_rounded,
    primary: Color(0xFFD500F9),
    accent: Color(0xFFE040FB),
    gradientColors: [Color(0xFFD500F9), Color(0xFF651FFF), Color(0xFF140026)],
  ),
  emerald(
    id: 'emerald',
    name: 'Pitch Emerald',
    icon: Icons.sports_cricket_rounded,
    primary: Color(0xFF00E676),
    accent: Color(0xFF69F0AE),
    gradientColors: [Color(0xFF00E676), Color(0xFF00B0FF), Color(0xFF002214)],
  ),
  midnight(
    id: 'midnight',
    name: 'Dark Carbon',
    icon: Icons.shield_rounded,
    primary: Color(0xFFCFD8DC),
    accent: Color(0xFFECEFF1),
    gradientColors: [Color(0xFFECEFF1), Color(0xFF607D8B), Color(0xFF101214)],
  );

  final String id;
  final String name;
  final IconData icon;
  final Color primary;
  final Color accent;
  final List<Color> gradientColors;

  const KeyMomentPosterTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.primary,
    required this.accent,
    required this.gradientColors,
  });
}

/// Structured single metric (e.g. BALLS, 4s/6s, STRIKE RATE, OVERS, ECONOMY)
class PerformanceMetric {
  final String label;
  final String value;
  final IconData? icon;

  const PerformanceMetric({
    required this.label,
    required this.value,
    this.icon,
  });
}

/// Model representing a rich Key Moment Poster
class KeyMomentPosterModel {
  final String id;
  final String category; // 'motm', 'batter', 'bowler', 'sixes', 'fifty', 'century', 'wicket_haul', 'highlight'
  final String badgeTitle;
  final String badgeTagline;
  final IconData badgeIcon;
  final KeyMomentPosterTheme defaultTheme;
  final String playerId;
  final String playerName;
  final String teamName;
  final String? photoUrl;
  
  // Enhanced Performance Box fields
  final String primaryStat;
  final String primaryStatLabel;
  final String? performanceSubtitle;
  final String? impactRatingText;
  final double? impactProgress;
  final List<PerformanceMetric> metrics;
  final List<String> statPills;

  final String matchFixture;
  final String matchDate;
  final String venue;

  // Match Scores
  final String team1Name;
  final String team2Name;
  final String team1ScoreText;
  final String team2ScoreText;
  final String matchResultText;

  final String? matchId;

  const KeyMomentPosterModel({
    required this.id,
    this.matchId,
    required this.category,
    required this.badgeTitle,
    required this.badgeTagline,
    required this.badgeIcon,
    required this.defaultTheme,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    this.photoUrl,
    required this.primaryStat,
    required this.primaryStatLabel,
    this.performanceSubtitle,
    this.impactRatingText,
    this.impactProgress,
    required this.metrics,
    required this.statPills,
    required this.matchFixture,
    required this.matchDate,
    required this.venue,
    required this.team1Name,
    required this.team2Name,
    required this.team1ScoreText,
    required this.team2ScoreText,
    required this.matchResultText,
  });

  KeyMomentPosterModel copyWith({
    String? id,
    String? matchId,
    String? category,
    String? badgeTitle,
    String? badgeTagline,
    IconData? badgeIcon,
    KeyMomentPosterTheme? defaultTheme,
    String? playerId,
    String? playerName,
    String? teamName,
    String? photoUrl,
    String? primaryStat,
    String? primaryStatLabel,
    String? performanceSubtitle,
    String? impactRatingText,
    double? impactProgress,
    List<PerformanceMetric>? metrics,
    List<String>? statPills,
    String? matchFixture,
    String? matchDate,
    String? venue,
    String? team1Name,
    String? team2Name,
    String? team1ScoreText,
    String? team2ScoreText,
    String? matchResultText,
  }) {
    return KeyMomentPosterModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      category: category ?? this.category,
      badgeTitle: badgeTitle ?? this.badgeTitle,
      badgeTagline: badgeTagline ?? this.badgeTagline,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      defaultTheme: defaultTheme ?? this.defaultTheme,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      teamName: teamName ?? this.teamName,
      photoUrl: photoUrl ?? this.photoUrl,
      primaryStat: primaryStat ?? this.primaryStat,
      primaryStatLabel: primaryStatLabel ?? this.primaryStatLabel,
      performanceSubtitle: performanceSubtitle ?? this.performanceSubtitle,
      impactRatingText: impactRatingText ?? this.impactRatingText,
      impactProgress: impactProgress ?? this.impactProgress,
      metrics: metrics ?? this.metrics,
      statPills: statPills ?? this.statPills,
      matchFixture: matchFixture ?? this.matchFixture,
      matchDate: matchDate ?? this.matchDate,
      venue: venue ?? this.venue,
      team1Name: team1Name ?? this.team1Name,
      team2Name: team2Name ?? this.team2Name,
      team1ScoreText: team1ScoreText ?? this.team1ScoreText,
      team2ScoreText: team2ScoreText ?? this.team2ScoreText,
      matchResultText: matchResultText ?? this.matchResultText,
    );
  }

  /// Factory to extract all key moment posters from a MatchModel
  static List<KeyMomentPosterModel> extractPosters(MatchModel match) {
    final posters = <KeyMomentPosterModel>[];
    final matchDateStr = DateFormat('dd MMM yyyy').format(match.scheduledDate);
    final fixture = '${match.team1Name} vs ${match.team2Name}';
    final ground = match.ground.isNotEmpty ? match.ground : 'Match Arena';

    // Match score texts
    final t1Score = '${match.team1Score.runs}/${match.team1Score.wickets} (${match.team1Score.oversDisplay} ov)';
    final t2Score = '${match.team2Score.runs}/${match.team2Score.wickets} (${match.team2Score.oversDisplay} ov)';
    String resultText = '';
    if (match.result != null && match.result!.winner.isNotEmpty) {
      if (match.result!.margin.isNotEmpty) {
        resultText = '${match.result!.winner} won ${match.result!.margin}';
      } else {
        resultText = '${match.result!.winner} won';
      }
    } else if (match.status == 'past') {
      resultText = 'MATCH FINISHED';
    } else if (match.status == 'live') {
      resultText = 'LIVE MATCH';
    }

    // Helper to find player's team name
    String getTeamName(String playerId, String defaultTeam) {
      if (match.team1Score.batters.any((b) => b.playerId == playerId || b.playerName == playerId) ||
          match.team1Score.bowlers.any((b) => b.playerId == playerId || b.playerName == playerId)) {
        return match.team1Name;
      }
      if (match.team2Score.batters.any((b) => b.playerId == playerId || b.playerName == playerId) ||
          match.team2Score.bowlers.any((b) => b.playerId == playerId || b.playerName == playerId)) {
        return match.team2Name;
      }
      return defaultTeam;
    }

    // Helper to find player's photo from cache or match highlights
    String? getPhoto(String playerId, String playerName) {
      final cached = PlayerAvatarWidget.getCachedPhoto(playerId) ?? PlayerAvatarWidget.getCachedPhoto(playerName);
      if (cached != null && cached.isNotEmpty) return cached;
      for (final h in match.highlights) {
        if ((h.playerId == playerId || h.playerName == playerName) && h.imageUrl.isNotEmpty) {
          return h.imageUrl;
        }
      }
      return null;
    }

    // 1. MAN OF THE MATCH (MVP)
    final mvpList = calculateMvpRatings(match);
    if (mvpList.isNotEmpty) {
      final mvp = mvpList.firstWhere(
        (p) => p.isManOfMatch,
        orElse: () => mvpList.reduce((a, b) => a.mvpPoints > b.mvpPoints ? a : b),
      );

      final mvpPills = <String>[];
      if (mvp.runs > 0) mvpPills.add('${mvp.runs} (${mvp.balls}b)');
      if (mvp.wickets > 0) mvpPills.add('${mvp.wickets}/${mvp.runsConceded}');
      if (mvp.catches > 0) mvpPills.add('${mvp.catches} Catches');
      if (mvpPills.isEmpty) mvpPills.add('Match MVP');

      posters.add(KeyMomentPosterModel(
        id: 'motm_${mvp.playerId}',
        matchId: match.id,
        category: 'motm',
        badgeTitle: 'MAN OF THE MATCH',
        badgeTagline: 'MATCH CHAMPION 👑',
        badgeIcon: Icons.emoji_events_rounded,
        defaultTheme: KeyMomentPosterTheme.gold,
        playerId: mvp.playerId,
        playerName: mvp.playerName,
        photoUrl: getPhoto(mvp.playerId, mvp.playerName),
        teamName: mvp.teamName.isNotEmpty ? mvp.teamName : getTeamName(mvp.playerId, match.team1Name),
        primaryStat: mvp.mvpPoints.toStringAsFixed(0),
        primaryStatLabel: 'MVP POINTS',
        performanceSubtitle: 'ALL-ROUND MATCH HERO',
        impactRatingText: '${mvp.runs} Runs • ${mvp.wickets} Wickets • ${mvp.catches} Catches',
        impactProgress: 0.95,
        metrics: [
          PerformanceMetric(
            label: 'BATTING',
            value: mvp.runs > 0 ? '${mvp.runs} (${mvp.balls}b)' : '-',
            icon: Icons.sports_cricket_rounded,
          ),
          PerformanceMetric(
            label: 'BOWLING',
            value: mvp.wickets > 0 || mvp.runsConceded > 0 ? '${mvp.wickets}/${mvp.runsConceded}' : '-',
            icon: Icons.sports_baseball_rounded,
          ),
          PerformanceMetric(
            label: 'CATCHES',
            value: '${mvp.catches}',
            icon: Icons.pan_tool_outlined,
          ),
        ],
        statPills: mvpPills,
        matchFixture: fixture,
        matchDate: matchDateStr,
        venue: ground,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        team1ScoreText: t1Score,
        team2ScoreText: t2Score,
        matchResultText: resultText,
      ));
    }

    // 2. BEST BATTER
    final allBatters = [...match.team1Score.batters, ...match.team2Score.batters];
    allBatters.sort((a, b) => b.runs.compareTo(a.runs));
    if (allBatters.isNotEmpty && allBatters.first.runs > 0) {
      final batter = allBatters.first;
      final boundaryRuns = (batter.fours * 4) + (batter.sixes * 6);
      final boundaryPct = batter.runs > 0 ? ((boundaryRuns / batter.runs) * 100).round() : 0;
      final pills = [
        '${batter.balls} Balls',
        '${batter.fours}x4 • ${batter.sixes}x6',
        'SR ${batter.strikeRate.toStringAsFixed(1)}',
      ];
      if (!batter.isOut) pills.add('Not Out 🌟');

      posters.add(KeyMomentPosterModel(
        id: 'batter_${batter.playerId}',
        matchId: match.id,
        category: 'batter',
        badgeTitle: 'BEST BATTER',
        badgeTagline: 'POWER STRIKER 🏏',
        badgeIcon: Icons.flash_on_rounded,
        defaultTheme: KeyMomentPosterTheme.fire,
        playerId: batter.playerId,
        playerName: batter.playerName,
        photoUrl: getPhoto(batter.playerId, batter.playerName),
        teamName: getTeamName(batter.playerId, match.team1Name),
        primaryStat: '${batter.runs}${!batter.isOut ? '*' : ''}',
        primaryStatLabel: 'RUNS',
        performanceSubtitle: 'OFF ${batter.balls} DELIVERIES',
        impactRatingText: '$boundaryRuns boundary runs ($boundaryPct% in boundaries)',
        impactProgress: (boundaryPct / 100).clamp(0.1, 1.0),
        metrics: [
          PerformanceMetric(
            label: 'BALLS',
            value: '${batter.balls}',
            icon: Icons.timer_outlined,
          ),
          PerformanceMetric(
            label: '4s / 6s',
            value: '${batter.fours} / ${batter.sixes}',
            icon: Icons.flash_on_rounded,
          ),
          PerformanceMetric(
            label: 'STRIKE RATE',
            value: batter.strikeRate.toStringAsFixed(1),
            icon: Icons.speed_rounded,
          ),
        ],
        statPills: pills,
        matchFixture: fixture,
        matchDate: matchDateStr,
        venue: ground,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        team1ScoreText: t1Score,
        team2ScoreText: t2Score,
        matchResultText: resultText,
      ));
    }

    // 3. BEST BOWLER
    final allBowlers = [...match.team1Score.bowlers, ...match.team2Score.bowlers];
    allBowlers.sort((a, b) {
      final comp = b.wickets.compareTo(a.wickets);
      if (comp != 0) return comp;
      return a.runs.compareTo(b.runs);
    });
    if (allBowlers.isNotEmpty && allBowlers.first.wickets > 0) {
      final bowler = allBowlers.first;
      final pills = [
        '${bowler.oversDisplay} Overs',
        'Econ ${bowler.economy.toStringAsFixed(2)}',
      ];
      if (bowler.maidens > 0) pills.add('${bowler.maidens} Maiden');
      pills.add('Spell Hero');

      posters.add(KeyMomentPosterModel(
        id: 'bowler_${bowler.playerId}',
        matchId: match.id,
        category: 'bowler',
        badgeTitle: 'BEST BOWLER',
        badgeTagline: 'WICKET WIZARD 🎯',
        badgeIcon: Icons.sports_baseball_rounded,
        defaultTheme: KeyMomentPosterTheme.cyber,
        playerId: bowler.playerId,
        playerName: bowler.playerName,
        photoUrl: getPhoto(bowler.playerId, bowler.playerName),
        teamName: getTeamName(bowler.playerId, match.team2Name),
        primaryStat: '${bowler.wickets}/${bowler.runs}',
        primaryStatLabel: 'FIGURES',
        performanceSubtitle: 'IN ${bowler.oversDisplay} OVERS',
        impactRatingText: 'Economy ${bowler.economy.toStringAsFixed(2)} • ${bowler.maidens} Maidens',
        impactProgress: (10.0 - bowler.economy).clamp(2.0, 10.0) / 10.0,
        metrics: [
          PerformanceMetric(
            label: 'OVERS',
            value: bowler.oversDisplay,
            icon: Icons.rotate_right_rounded,
          ),
          PerformanceMetric(
            label: 'ECONOMY',
            value: bowler.economy.toStringAsFixed(2),
            icon: Icons.analytics_outlined,
          ),
          PerformanceMetric(
            label: 'MAIDENS',
            value: '${bowler.maidens}',
            icon: Icons.shield_outlined,
          ),
        ],
        statPills: pills,
        matchFixture: fixture,
        matchDate: matchDateStr,
        venue: ground,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        team1ScoreText: t1Score,
        team2ScoreText: t2Score,
        matchResultText: resultText,
      ));
    }

    // 4. SIX MACHINE
    final sixesList = List<BatterStats>.from(allBatters)..sort((a, b) => b.sixes.compareTo(a.sixes));
    if (sixesList.isNotEmpty && sixesList.first.sixes >= 2) {
      final sixHitter = sixesList.first;
      final sixRuns = sixHitter.sixes * 6;
      final pills = [
        '$sixRuns Runs in 6s',
        '${sixHitter.runs} (${sixHitter.balls}b)',
        'SR ${sixHitter.strikeRate.toStringAsFixed(0)}',
      ];

      posters.add(KeyMomentPosterModel(
        id: 'sixes_${sixHitter.playerId}',
        matchId: match.id,
        category: 'sixes',
        badgeTitle: 'SIX MACHINE',
        badgeTagline: 'MAXIMUM OVER-BOUNDARY ⚡',
        badgeIcon: Icons.bolt_rounded,
        defaultTheme: KeyMomentPosterTheme.violet,
        playerId: sixHitter.playerId,
        playerName: sixHitter.playerName,
        photoUrl: getPhoto(sixHitter.playerId, sixHitter.playerName),
        teamName: getTeamName(sixHitter.playerId, match.team1Name),
        primaryStat: '${sixHitter.sixes}',
        primaryStatLabel: 'MAXIMUMS',
        performanceSubtitle: '$sixRuns RUNS FROM SIXES',
        impactRatingText: '${sixHitter.runs} runs scored at ${sixHitter.strikeRate.toStringAsFixed(0)} Strike Rate',
        impactProgress: 0.9,
        metrics: [
          PerformanceMetric(
            label: 'TOTAL RUNS',
            value: '${sixHitter.runs}',
            icon: Icons.scoreboard_outlined,
          ),
          PerformanceMetric(
            label: 'BALLS',
            value: '${sixHitter.balls}',
            icon: Icons.timer_outlined,
          ),
          PerformanceMetric(
            label: 'STRIKE RATE',
            value: sixHitter.strikeRate.toStringAsFixed(0),
            icon: Icons.speed_rounded,
          ),
        ],
        statPills: pills,
        matchFixture: fixture,
        matchDate: matchDateStr,
        venue: ground,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        team1ScoreText: t1Score,
        team2ScoreText: t2Score,
        matchResultText: resultText,
      ));
    }

    // 5. CENTURY & HALF CENTURY HEROES
    for (final b in allBatters) {
      if (b.runs >= 50 && (posters.every((p) => p.playerId != b.playerId || p.category == 'motm'))) {
        final is100 = b.runs >= 100;
        final boundaryRuns = (b.fours * 4) + (b.sixes * 6);
        final boundaryPct = b.runs > 0 ? ((boundaryRuns / b.runs) * 100).round() : 0;
        final pills = [
          '${b.balls} Balls',
          '${b.fours}x4 • ${b.sixes}x6',
          'SR ${b.strikeRate.toStringAsFixed(1)}',
        ];

        posters.add(KeyMomentPosterModel(
          id: 'milestone_${b.playerId}',
          matchId: match.id,
          category: is100 ? 'century' : 'fifty',
          badgeTitle: is100 ? 'CENTURY HERO' : 'HALF CENTURY',
          badgeTagline: is100 ? '100 RUNS MASTERCLASS 💯' : '50 RUNS MASTERCLASS 5️⃣0️⃣',
          badgeIcon: is100 ? Icons.workspace_premium_rounded : Icons.star_rounded,
          defaultTheme: is100 ? KeyMomentPosterTheme.gold : KeyMomentPosterTheme.emerald,
          playerId: b.playerId,
          playerName: b.playerName,
          teamName: getTeamName(b.playerId, match.team1Name),
          photoUrl: getPhoto(b.playerId, b.playerName),
          primaryStat: '${b.runs}${!b.isOut ? '*' : ''}',
          primaryStatLabel: is100 ? 'CENTURY' : 'FIFTY',
          performanceSubtitle: 'OFF ${b.balls} DELIVERIES',
          impactRatingText: '$boundaryRuns boundary runs ($boundaryPct% in boundaries)',
          impactProgress: (boundaryPct / 100).clamp(0.1, 1.0),
          metrics: [
            PerformanceMetric(
              label: 'BALLS',
              value: '${b.balls}',
              icon: Icons.timer_outlined,
            ),
            PerformanceMetric(
              label: '4s / 6s',
              value: '${b.fours} / ${b.sixes}',
              icon: Icons.flash_on_rounded,
            ),
            PerformanceMetric(
              label: 'STRIKE RATE',
              value: b.strikeRate.toStringAsFixed(1),
              icon: Icons.speed_rounded,
            ),
          ],
          statPills: pills,
          matchFixture: fixture,
          matchDate: matchDateStr,
          venue: ground,
          team1Name: match.team1Name,
          team2Name: match.team2Name,
          team1ScoreText: t1Score,
          team2ScoreText: t2Score,
          matchResultText: resultText,
        ));
      }
    }

    // 6. 3+ WICKET HAULS
    for (final b in allBowlers) {
      if (b.wickets >= 3 && posters.every((p) => p.playerId != b.playerId)) {
        posters.add(KeyMomentPosterModel(
          id: 'wicket_haul_${b.playerId}',
          matchId: match.id,
          category: 'wicket_haul',
          badgeTitle: 'STRIKE BOWLER',
          badgeTagline: 'DEADLY BOWLING SPELL 🔥',
          badgeIcon: Icons.local_fire_department_rounded,
          defaultTheme: KeyMomentPosterTheme.fire,
          playerId: b.playerId,
          playerName: b.playerName,
          photoUrl: getPhoto(b.playerId, b.playerName),
          teamName: getTeamName(b.playerId, match.team2Name),
          primaryStat: '${b.wickets}/${b.runs}',
          primaryStatLabel: 'FIGURES',
          performanceSubtitle: 'IN ${b.oversDisplay} OVERS',
          impactRatingText: 'Economy ${b.economy.toStringAsFixed(2)} • Match impact spell',
          impactProgress: (10.0 - b.economy).clamp(2.0, 10.0) / 10.0,
          metrics: [
            PerformanceMetric(
              label: 'OVERS',
              value: b.oversDisplay,
              icon: Icons.rotate_right_rounded,
            ),
            PerformanceMetric(
              label: 'ECONOMY',
              value: b.economy.toStringAsFixed(2),
              icon: Icons.analytics_outlined,
            ),
            PerformanceMetric(
              label: 'MAIDENS',
              value: '${b.maidens}',
              icon: Icons.shield_outlined,
            ),
          ],
          statPills: ['${b.oversDisplay} Overs', 'Econ ${b.economy.toStringAsFixed(2)}', 'Match Changer'],
          matchFixture: fixture,
          matchDate: matchDateStr,
          venue: ground,
          team1Name: match.team1Name,
          team2Name: match.team2Name,
          team1ScoreText: t1Score,
          team2ScoreText: t2Score,
          matchResultText: resultText,
        ));
      }
    }

    // 7. MATCH HIGHLIGHTS FROM MATCH RECORD
    for (final h in match.highlights) {
      if (h.playerName != null && h.playerName!.isNotEmpty &&
          posters.every((p) => p.id != 'highlight_${h.id}')) {
        posters.add(KeyMomentPosterModel(
          id: 'highlight_${h.id}',
          matchId: match.id,
          category: 'highlight',
          badgeTitle: h.title.toUpperCase(),
          badgeTagline: 'MOMENT OF THE MATCH 🌟',
          badgeIcon: Icons.military_tech_rounded,
          defaultTheme: KeyMomentPosterTheme.midnight,
          playerId: h.playerId ?? '',
          playerName: h.playerName ?? 'PLAYER',
          teamName: h.playerId != null ? getTeamName(h.playerId!, match.team1Name) : match.team1Name,
          photoUrl: h.imageUrl.isNotEmpty ? h.imageUrl : getPhoto(h.playerId ?? '', h.playerName ?? ''),
          primaryStat: h.type.toUpperCase(),
          primaryStatLabel: 'ACHIEVEMENT',
          performanceSubtitle: 'MATCH MILESTONE',
          impactRatingText: h.description,
          impactProgress: 0.8,
          metrics: [
            PerformanceMetric(label: 'TYPE', value: h.type.toUpperCase(), icon: Icons.military_tech_rounded),
            const PerformanceMetric(label: 'MOMENT', value: 'STAR PLAY', icon: Icons.star_rounded),
          ],
          statPills: [h.description],
          matchFixture: fixture,
          matchDate: matchDateStr,
          venue: ground,
          team1Name: match.team1Name,
          team2Name: match.team2Name,
          team1ScoreText: t1Score,
          team2ScoreText: t2Score,
          matchResultText: resultText,
        ));
      }
    }

    return posters;
  }

  /// Factory to resolve or create a KeyMomentPosterModel from a PlayerAchievement
  static Future<KeyMomentPosterModel> fromAchievement(
    PlayerAchievement ach, {
    String? playerName,
    String? photoUrl,
    String? playerId,
  }) async {
    final effectivePlayerId = (playerId != null && playerId.isNotEmpty) ? playerId : (ach.stats['playerId']?.toString() ?? '');
    final effectivePlayerName = (playerName != null && playerName.isNotEmpty) ? playerName : (ach.stats['playerName']?.toString() ?? 'Player');
    final effectivePhotoUrl = (photoUrl != null && photoUrl.isNotEmpty)
        ? photoUrl
        : (ach.stats['photoUrl']?.toString() ??
            PlayerAvatarWidget.getCachedPhoto(effectivePlayerId) ??
            PlayerAvatarWidget.getCachedPhoto(effectivePlayerName));

    // 1. If matchId exists, try to load match and find matching poster
    if (ach.matchId != null && ach.matchId!.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('matches').doc(ach.matchId).get();
        if (doc.exists && doc.data() != null) {
          final mData = Map<String, dynamic>.from(doc.data()!);
          mData['id'] = doc.id;
          final match = MatchModel.fromMap(mData);
          final extracted = extractPosters(match);
          if (extracted.isNotEmpty) {
            final matching = extracted.firstWhere(
              (p) => (effectivePlayerId.isNotEmpty && (p.playerId == effectivePlayerId || p.playerId == ach.id)) ||
                     p.playerName.trim().toLowerCase() == effectivePlayerName.trim().toLowerCase() ||
                     p.category == ach.type,
              orElse: () => extracted.first,
            );
            return matching.copyWith(
              photoUrl: matching.photoUrl ?? effectivePhotoUrl,
            );
          }
        }
      } catch (e) {
        debugPrint('Error extracting poster from match for achievement: $e');
      }
    }

    // 2. Fallback: generate high-impact poster model from achievement
    KeyMomentPosterTheme theme = KeyMomentPosterTheme.gold;
    IconData icon = Icons.emoji_events_rounded;
    if (ach.type == 'wicket' || ach.type == 'five_wickets' || ach.type == 'wicket_haul') {
      theme = KeyMomentPosterTheme.fire;
      icon = Icons.local_fire_department_rounded;
    } else if (ach.type == 'sixes' || ach.type == 'strike_rate') {
      theme = KeyMomentPosterTheme.cyber;
      icon = Icons.flash_on_rounded;
    } else if (ach.type == 'tournament_win' || ach.type == 'win') {
      theme = KeyMomentPosterTheme.violet;
      icon = Icons.workspace_premium_rounded;
    } else if (ach.type == 'mvp' || ach.type == 'man_of_match') {
      theme = KeyMomentPosterTheme.gold;
      icon = Icons.military_tech_rounded;
    } else if (ach.type == 'fifty') {
      theme = KeyMomentPosterTheme.emerald;
      icon = Icons.sports_cricket_rounded;
    }

    final dateStr = DateFormat('dd MMM yyyy').format(ach.earnedAt);
    final statVal = ach.stats['runs']?.toString() ??
        ach.stats['wickets']?.toString() ??
        ach.stats['primaryStat']?.toString() ??
        'HERO';
    final statLbl = ach.stats['primaryStatLabel']?.toString() ?? 'MILESTONE';

    return KeyMomentPosterModel(
      id: ach.id.isNotEmpty ? ach.id : 'ach_${DateTime.now().millisecondsSinceEpoch}',
      category: ach.type,
      badgeTitle: ach.title.toUpperCase(),
      badgeTagline: ach.description.isNotEmpty ? ach.description : 'CRICKET MILESTONE 🏆',
      badgeIcon: icon,
      defaultTheme: theme,
      playerId: effectivePlayerId,
      playerName: effectivePlayerName,
      teamName: ach.stats['teamName']?.toString() ?? 'ScorePartner',
      photoUrl: effectivePhotoUrl,
      primaryStat: statVal,
      primaryStatLabel: statLbl,
      performanceSubtitle: ach.matchName ?? 'MATCH HIGHLIGHT',
      impactRatingText: ach.description,
      impactProgress: 0.9,
      metrics: [
        PerformanceMetric(
          label: 'TYPE',
          value: ach.type.toUpperCase(),
          icon: icon,
        ),
        PerformanceMetric(
          label: 'DATE',
          value: dateStr,
          icon: Icons.calendar_today_rounded,
        ),
      ],
      statPills: [ach.description.isNotEmpty ? ach.description : ach.title],
      matchFixture: ach.matchName ?? 'ScorePartner Cricket',
      matchDate: dateStr,
      venue: ach.stats['venue']?.toString() ?? 'Arena',
      team1Name: 'Team 1',
      team2Name: 'Team 2',
      team1ScoreText: '',
      team2ScoreText: '',
      matchResultText: 'ACHIEVEMENT UNLOCKED 🌟',
    );
  }
}

/// Poster Card widget with player profile photo, enhanced performance box, match score, and sporty theme
class KeyMomentPosterCard extends StatelessWidget {
  final KeyMomentPosterModel poster;
  final KeyMomentPosterTheme? overrideTheme;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool isInteractive;

  const KeyMomentPosterCard({
    super.key,
    required this.poster,
    this.overrideTheme,
    this.onTap,
    this.width,
    this.height,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = overrideTheme ?? poster.defaultTheme;
    final cardW = width ?? 235.w;
    final cardH = height ?? 385.h;

    return GestureDetector(
      onTap: isInteractive
          ? (onTap ?? () => KeyMomentPosterDialog.show(context, poster, activeTheme))
          : null,
      child: Container(
        width: cardW,
        height: cardH,
        margin: EdgeInsets.only(right: 14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: LinearGradient(
            colors: [
              activeTheme.gradientColors[0].withValues(alpha: 0.28),
              activeTheme.gradientColors[1].withValues(alpha: 0.12),
              const Color(0xFF111114),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: activeTheme.primary.withValues(alpha: 0.55),
            width: 1.6.w,
          ),
          boxShadow: [
            BoxShadow(
              color: activeTheme.primary.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Stack(
            children: [
              // Subtle background decorative radial glow
              Positioned(
                top: -30.h,
                left: -20.w,
                right: -20.w,
                height: 160.h,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeTheme.primary.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Diagonal sports badge textures
              Positioned(
                top: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(70.w, 70.h),
                  painter: _DiagonalAccentPainter(color: activeTheme.primary),
                ),
              ),

              // Main poster layout
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Badge Title Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.5.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeTheme.primary,
                            activeTheme.accent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: activeTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(poster.badgeIcon, size: 11.sp, color: Colors.black),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              poster.badgeTitle,
                              style: TextStyle(
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 7.h),

                    // Player Profile Photo Spotlight
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 66.w,
                          height: 66.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: activeTheme.primary.withValues(alpha: 0.8),
                              width: 2.5.w,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeTheme.primary.withValues(alpha: 0.45),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        PlayerAvatarWidget(
                          playerId: poster.playerId.isNotEmpty ? poster.playerId : null,
                          playerName: poster.playerName,
                          profileImageUrl: (poster.photoUrl != null && poster.photoUrl!.isNotEmpty)
                              ? poster.photoUrl
                              : (PlayerAvatarWidget.getCachedPhoto(poster.playerId) ??
                                  PlayerAvatarWidget.getCachedPhoto(poster.playerName)),
                          size: 60.w,
                          enableProfileView: false,
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),

                    // Player Name
                    Text(
                      poster.playerName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    // Team Name Pill
                    Container(
                      margin: EdgeInsets.only(top: 2.h),
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        poster.teamName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 6.h),

                    // 🔥 ENHANCED DETAILED MATCH PERFORMANCE BOX
                    _buildPerformanceBox(poster, activeTheme),
                    SizedBox(height: 6.h),

                    // 🏏 MATCH SCORE SECTION
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.5.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: activeTheme.primary.withValues(alpha: 0.25),
                          width: 0.8.w,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  poster.team1Name,
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                poster.team1ScoreText,
                                style: TextStyle(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w800,
                                  color: activeTheme.accent,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.5.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  poster.team2Name,
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                poster.team2ScoreText,
                                style: TextStyle(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w800,
                                  color: activeTheme.accent,
                                ),
                              ),
                            ],
                          ),
                          if (poster.matchResultText.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              poster.matchResultText.toUpperCase(),
                              style: TextStyle(
                                fontSize: 7.sp,
                                fontWeight: FontWeight.w800,
                                color: activeTheme.primary,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Tap to Share Hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.palette_rounded, size: 9.sp, color: activeTheme.primary.withValues(alpha: 0.85)),
                        SizedBox(width: 3.w),
                        Text(
                          'THEMES & SHARE ↗',
                          style: TextStyle(
                            fontSize: 7.sp,
                            fontWeight: FontWeight.w800,
                            color: activeTheme.primary.withValues(alpha: 0.95),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// High-impact Enhanced Match Performance Box for the Card
  Widget _buildPerformanceBox(KeyMomentPosterModel poster, KeyMomentPosterTheme theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B1B22),
            const Color(0xFF121216),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11.r),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.38),
          width: 1.1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar of Performance Box
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(poster.badgeIcon, size: 9.sp, color: theme.primary),
                  SizedBox(width: 3.w),
                  Text(
                    'PERFORMANCE',
                    style: TextStyle(
                      fontSize: 7.5.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (poster.performanceSubtitle != null)
                Text(
                  poster.performanceSubtitle!,
                  style: TextStyle(
                    fontSize: 7.sp,
                    fontWeight: FontWeight.w800,
                    color: theme.accent,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),

          // Big Hero Figure Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                poster.primaryStat,
                style: TextStyle(
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w900,
                  color: theme.primary,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: theme.primary.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                poster.primaryStatLabel,
                style: TextStyle(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),

          // 3 Structured Stat Cells
          if (poster.metrics.isNotEmpty)
            Row(
              children: poster.metrics.take(3).map((metric) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8.w,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          metric.label,
                          style: TextStyle(
                            fontSize: 6.5.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          metric.value,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Diagonal corner ribbon accent painter
class _DiagonalAccentPainter extends CustomPainter {
  final Color color;

  _DiagonalAccentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Interactive Fullscreen Dialog to Preview, Customize Themes, Share, and Download the Key Moment Poster
class KeyMomentPosterDialog extends StatefulWidget {
  final KeyMomentPosterModel poster;
  final KeyMomentPosterTheme initialTheme;

  const KeyMomentPosterDialog({
    super.key,
    required this.poster,
    required this.initialTheme,
  });

  static void show(BuildContext context, KeyMomentPosterModel poster, [KeyMomentPosterTheme? initialTheme]) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => KeyMomentPosterDialog(
        poster: poster,
        initialTheme: initialTheme ?? poster.defaultTheme,
      ),
    );
  }

  @override
  State<KeyMomentPosterDialog> createState() => _KeyMomentPosterDialogState();
}

class _KeyMomentPosterDialogState extends State<KeyMomentPosterDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  late KeyMomentPosterTheme _selectedTheme;
  bool _isExporting = false;
  String? _resolvedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.initialTheme;
    _resolvedPhotoUrl = widget.poster.photoUrl;
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    final pid = widget.poster.playerId.trim();
    final name = widget.poster.playerName.trim();

    String? cached = PlayerAvatarWidget.getCachedPhoto(pid) ??
        PlayerAvatarWidget.getCachedPhoto(name) ??
        _resolvedPhotoUrl;

    if (cached != null && cached.isNotEmpty) {
      if (mounted) setState(() => _resolvedPhotoUrl = cached);
      _precache(cached);
      return;
    }

    try {
      final lookupKey = pid.isNotEmpty ? pid : name;
      if (lookupKey.isNotEmpty) {
        final user = await FirebaseDataService.instance.findUserByAnyId(lookupKey);
        if (user != null && user.profileImageUrl.isNotEmpty) {
          PlayerAvatarWidget.seedCache(lookupKey, user.profileImageUrl, user);
          if (pid.isNotEmpty) PlayerAvatarWidget.seedCache(pid, user.profileImageUrl, user);
          if (name.isNotEmpty) PlayerAvatarWidget.seedCache(name, user.profileImageUrl, user);
          if (mounted) {
            setState(() => _resolvedPhotoUrl = user.profileImageUrl);
          }
          _precache(user.profileImageUrl);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile photo in dialog: $e');
    }
  }

  void _precache(String url) {
    try {
      if (url.startsWith('data:')) {
        final bytes = base64Decode(url.split(',').last.trim());
        precacheImage(MemoryImage(bytes), context);
      } else if (url.startsWith('http')) {
        precacheImage(NetworkImage(url), context);
      }
    } catch (_) {}
  }

  Future<void> _sharePoster() async {
    setState(() => _isExporting = true);
    try {
      if (_resolvedPhotoUrl == null && (widget.poster.playerId.isNotEmpty || widget.poster.playerName.isNotEmpty)) {
        await _loadProfilePhoto().timeout(const Duration(milliseconds: 700), onTimeout: () {});
      }

      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 350),
        pixelRatio: 3.0,
      );

      if (imageBytes != null) {
        final fileName = 'moment_${widget.poster.playerName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
        await Share.shareXFiles(
          [
            XFile.fromData(
              imageBytes,
              mimeType: 'image/png',
              name: fileName,
            ),
          ],
          text: '🔥 Check out ${widget.poster.playerName}\'s ${widget.poster.badgeTitle} in ${widget.poster.matchFixture} on ScorePartner! 🏏🏆\n#ScorePartner #Cricket',
          subject: '${widget.poster.badgeTitle} - ${widget.poster.playerName}',
        );

        // Also save to Profile section achieve tab
        await _addToProfile(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share poster: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadPoster() async {
    setState(() => _isExporting = true);
    try {
      // Ensure photo is loaded & precached before capturing
      if (_resolvedPhotoUrl == null && (widget.poster.playerId.isNotEmpty || widget.poster.playerName.isNotEmpty)) {
        await _loadProfilePhoto().timeout(const Duration(milliseconds: 700), onTimeout: () {});
      }

      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 350),
        pixelRatio: 3.0,
      );

      if (imageBytes != null) {
        final safeName = widget.poster.playerName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
        final fileName = 'poster_${safeName}_${DateTime.now().millisecondsSinceEpoch}.png';

        if (kIsWeb) {
          final xFile = XFile.fromData(imageBytes, name: fileName, mimeType: 'image/png');
          await xFile.saveTo(fileName);
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(imageBytes);

          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }
          await Gal.putImage(filePath, album: 'ScorePartner');
        }

        // Automatically save to Profile section achieve tab!
        await _addToProfile(silent: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF2E7D32),
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Poster saved to Gallery & Profile Achievements! 📸🏆', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save poster: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _addToProfile({bool silent = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to add to profile')),
        );
      }
      return;
    }
    if (!silent) setState(() => _isExporting = true);
    try {
      final targetUid = currentUser.uid;
      final ach = PlayerAchievement(
        id: widget.poster.id.isNotEmpty ? widget.poster.id : 'poster_${DateTime.now().millisecondsSinceEpoch}',
        type: widget.poster.category,
        title: widget.poster.badgeTitle,
        description: '${widget.poster.primaryStatLabel}: ${widget.poster.primaryStat} • ${widget.poster.badgeTagline}',
        matchId: widget.poster.matchId,
        matchName: widget.poster.matchFixture,
        earnedAt: DateTime.now(),
        badgeIcon: '🏏',
        stats: {
          'playerId': widget.poster.playerId,
          'playerName': widget.poster.playerName,
          'teamName': widget.poster.teamName,
          'photoUrl': _resolvedPhotoUrl ?? widget.poster.photoUrl,
          'primaryStat': widget.poster.primaryStat,
          'primaryStatLabel': widget.poster.primaryStatLabel,
          'matchId': widget.poster.matchId,
          'matchFixture': widget.poster.matchFixture,
        },
      );

      final docRef = FirebaseFirestore.instance.collection('users').doc(targetUid);
      await docRef.set({
        'achievements': FieldValue.arrayUnion([ach.toMap()]),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Added to Profile Achieve tab! 🏆', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding achievement to profile: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to profile: $e')),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.poster;
    final theme = _selectedTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(theme.icon, color: theme.primary, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'KEY MOMENT POSTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.white, size: 24.sp),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 6.h),

            // High-Res Poster Container (Captured by ScreenshotController)
            Screenshot(
              controller: _screenshotController,
              child: Container(
                width: 320.w,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26.r),
                  gradient: LinearGradient(
                    colors: [
                      theme.gradientColors[0].withValues(alpha: 0.35),
                      theme.gradientColors[1].withValues(alpha: 0.18),
                      const Color(0xFF0F0F12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: theme.primary.withValues(alpha: 0.65),
                    width: 2.2.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.3),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App branding Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sports_cricket, color: theme.primary, size: 16.sp),
                            SizedBox(width: 4.w),
                            Text(
                              'SCOREPARTNER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          poster.matchDate,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Badge Banner
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.primary, theme.accent],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(poster.badgeIcon, size: 15.sp, color: Colors.black),
                          SizedBox(width: 6.w),
                          Text(
                            poster.badgeTitle,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Profile Photo Spotlight
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96.w,
                          height: 96.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primary,
                              width: 3.w,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primary.withValues(alpha: 0.55),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        PlayerAvatarWidget(
                          playerId: poster.playerId.isNotEmpty ? poster.playerId : null,
                          playerName: poster.playerName,
                          profileImageUrl: _resolvedPhotoUrl ?? poster.photoUrl,
                          size: 88.w,
                          enableProfileView: false,
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // Player Name & Team
                    Text(
                      poster.playerName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 3.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 2.5.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        poster.teamName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // 🔥 ENHANCED DETAILED MATCH PERFORMANCE BOX IN DIALOG
                    _buildDialogPerformanceBox(poster, theme),
                    SizedBox(height: 10.h),

                    // 🏏 MATCH SCOREBOARD BOARD
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: theme.primary.withValues(alpha: 0.3),
                          width: 1.w,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  poster.team1Name,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                poster.team1ScoreText,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  color: theme.accent,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  poster.team2Name,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                poster.team2ScoreText,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  color: theme.accent,
                                ),
                              ),
                            ],
                          ),
                          if (poster.matchResultText.isNotEmpty) ...[
                            Divider(color: Colors.white.withValues(alpha: 0.15), height: 10.h),
                            Text(
                              poster.matchResultText.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w900,
                                color: theme.primary,
                                letterSpacing: 0.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Venue & Ground Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            poster.matchFixture,
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white60,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          poster.venue,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // 🎨 THEME CUSTOMIZER ROW
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_rounded, size: 14.sp, color: Colors.orangeAccent),
                      SizedBox(width: 6.w),
                      Text(
                        'CHOOSE POSTER THEME',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: KeyMomentPosterTheme.values.map((t) {
                        final isSelected = t == _selectedTheme;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTheme = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: 8.w),
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: isSelected ? t.primary : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: isSelected ? Colors.white : t.primary.withValues(alpha: 0.4),
                                width: isSelected ? 1.8.w : 1.w,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: t.primary.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.black : t.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  t.name,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.black : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Action buttons: Share, Save Image, Add to Profile
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _sharePoster,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('SHARE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 3,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _downloadPoster,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('SAVE IMAGE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.3.w),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _addToProfile,
                  icon: const Icon(Icons.star_border_rounded, size: 16),
                  label: const Text('ADD TO PROFILE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.amberAccent,
                    side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.7), width: 1.3.w),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Detailed High-Res Performance Matrix Box for Dialog
  Widget _buildDialogPerformanceBox(KeyMomentPosterModel poster, KeyMomentPosterTheme theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.4),
          width: 1.4.w,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(poster.badgeIcon, size: 12.sp, color: theme.primary),
                  SizedBox(width: 5.w),
                  Text(
                    'MATCH PERFORMANCE MATRIX',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (poster.performanceSubtitle != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    poster.performanceSubtitle!,
                    style: TextStyle(
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w900,
                      color: theme.accent,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),

          // Big Headline Metric Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                poster.primaryStat,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w900,
                  color: theme.primary,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: theme.primary.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                poster.primaryStatLabel,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white70,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Structured Metrics Cells
          if (poster.metrics.isNotEmpty)
            Row(
              children: poster.metrics.take(3).map((metric) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.8.w,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (metric.icon != null) ...[
                          Icon(metric.icon, size: 12.sp, color: theme.accent),
                          SizedBox(height: 2.h),
                        ],
                        Text(
                          metric.label,
                          style: TextStyle(
                            fontSize: 7.5.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          metric.value,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          // Impact Rating Bar & Text
          if (poster.impactRatingText != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IMPACT ANALYSIS',
                        style: TextStyle(
                          fontSize: 7.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        poster.impactRatingText!,
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          color: theme.accent,
                        ),
                      ),
                    ],
                  ),
                  if (poster.impactProgress != null) ...[
                    SizedBox(height: 4.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: poster.impactProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                        minHeight: 4.h,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
