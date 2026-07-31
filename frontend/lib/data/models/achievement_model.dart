/// Achievement types for players
enum AchievementType {
  tournamentWin,    // Won a tournament
  tournamentRunner, // Runner-up in tournament
  topScorer,        // Top scorer in a match/tournament
  topWicketTaker,   // Top wicket-taker in a match/tournament
  manOfMatch,       // Man of the match
  century,          // Scored 100+ runs
  halfCentury,      // Scored 50-99 runs
  fiveWickets,      // Took 5+ wickets
  hatTrick,         // 3 wickets in 3 balls
  matchWin,         // Won a match
}

/// Player achievement earned from tournaments/matches
class PlayerAchievement {
  final String id;
  final String type;           // AchievementType as string
  final String title;          // "🏆 Champion - IPL 2024"
  final String description;    // "Winner of IPL 2024 tournament"
  final String? tournamentId;  // Link to tournament
  final String? tournamentName;
  final String? matchId;       // For match-specific achievements
  final String? matchName;
  final DateTime earnedAt;

  final Map<String, dynamic> stats; // Runs, wickets, etc.
  final String badgeIcon;      // Badge emoji or icon name

  const PlayerAchievement({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.tournamentId,
    this.tournamentName,
    this.matchId,
    this.matchName,
    required this.earnedAt,
    this.stats = const {},
    this.badgeIcon = '🏅',
  });

  factory PlayerAchievement.fromMap(Map<String, dynamic> data) {
    return PlayerAchievement(
      id: data['id'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      tournamentId: data['tournamentId'],
      tournamentName: data['tournamentName'],
      matchId: data['matchId'],
      matchName: data['matchName'],
      earnedAt: data['earnedAt'] != null 
          ? DateTime.tryParse(data['earnedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      stats: Map<String, dynamic>.from(data['stats'] ?? {}),
      badgeIcon: data['badgeIcon'] ?? '🏅',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'matchId': matchId,
      'matchName': matchName,
      'earnedAt': earnedAt.toIso8601String(),
      'stats': stats,
      'badgeIcon': badgeIcon,
    };
  }

  PlayerAchievement copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    String? tournamentId,
    String? tournamentName,
    String? matchId,
    String? matchName,
    DateTime? earnedAt,
    Map<String, dynamic>? stats,
    String? badgeIcon,
  }) {
    return PlayerAchievement(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      matchId: matchId ?? this.matchId,
      matchName: matchName ?? this.matchName,
      earnedAt: earnedAt ?? this.earnedAt,
      stats: stats ?? this.stats,
      badgeIcon: badgeIcon ?? this.badgeIcon,
    );
  }

  /// Factory constructors for common achievement types
  factory PlayerAchievement.tournamentWin({
    required String id,
    required String tournamentId,
    required String tournamentName,
  }) {
    return PlayerAchievement(
      id: id,
      type: 'tournament_win',
      title: '🏆 Champion - $tournamentName',
      description: 'Winner of $tournamentName',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      earnedAt: DateTime.now(),
      badgeIcon: '🏆',
    );
  }

  factory PlayerAchievement.century({
    required String id,
    required int runs,
    required String matchId,
    required String matchName,
    String? tournamentId,
    String? tournamentName,
  }) {
    return PlayerAchievement(
      id: id,
      type: 'century',
      title: '💯 Century - $runs runs',
      description: 'Scored $runs runs in $matchName',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      matchId: matchId,
      matchName: matchName,
      earnedAt: DateTime.now(),
      stats: {'runs': runs},
      badgeIcon: '💯',
    );
  }

  factory PlayerAchievement.halfCentury({
    required String id,
    required int runs,
    required String matchId,
    required String matchName,
    String? tournamentId,
    String? tournamentName,
  }) {
    return PlayerAchievement(
      id: id,
      type: 'half_century',
      title: '5️⃣0️⃣ Half Century - $runs runs',
      description: 'Scored $runs runs in $matchName',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      matchId: matchId,
      matchName: matchName,
      earnedAt: DateTime.now(),
      stats: {'runs': runs},
      badgeIcon: '5️⃣0️⃣',
    );
  }

  factory PlayerAchievement.fiveWickets({
    required String id,
    required int wickets,
    required String matchId,
    required String matchName,
    String? tournamentId,
    String? tournamentName,
  }) {
    return PlayerAchievement(
      id: id,
      type: 'five_wickets',
      title: '🔥 $wickets Wickets',
      description: 'Took $wickets wickets in $matchName',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      matchId: matchId,
      matchName: matchName,
      earnedAt: DateTime.now(),
      stats: {'wickets': wickets},
      badgeIcon: '🔥',
    );
  }

  factory PlayerAchievement.manOfMatch({
    required String id,
    required String matchId,
    required String matchName,
    String? tournamentId,
    String? tournamentName,
    Map<String, dynamic> stats = const {},
  }) {
    return PlayerAchievement(
      id: id,
      type: 'man_of_match',
      title: '⭐ Man of the Match',
      description: 'Player of the match in $matchName',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      matchId: matchId,
      matchName: matchName,
      earnedAt: DateTime.now(),
      stats: stats,
      badgeIcon: '⭐',
    );
  }

  factory PlayerAchievement.topScorer({
    required String id,
    required int runs,
    required String matchId,
    required String matchName,
    String? tournamentId,
    String? tournamentName,
  }) {
    return PlayerAchievement(
      id: id,
      type: 'top_scorer',
      title: '🏏 Top Scorer - $runs runs',
      description: 'Highest scorer in $matchName with $runs runs',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      matchId: matchId,
      matchName: matchName,
      earnedAt: DateTime.now(),
      stats: {'runs': runs},
      badgeIcon: '🏏',
    );
  }

  // ==========================================
  // 🎮 GEN-Z GAMIFIED CAREER BADGES
  // ==========================================

  /// Generate a custom Gen-Z Career Badge
  factory PlayerAchievement.genZCareerBadge({
    required String id,
    required String type,
    required String title,
    required String description,
    required String badgeIcon,
    required Map<String, dynamic> stats,
  }) {
    return PlayerAchievement(
      id: id,
      type: type,
      title: title,
      description: description,
      earnedAt: DateTime.now(),
      stats: stats,
      badgeIcon: badgeIcon,
    );
  }

  // --- BATSMAN BADGES ---

  static PlayerAchievement firstBlood(String userId, int runs) => PlayerAchievement.genZCareerBadge(
    id: 'badge_first_blood_$userId',
    type: 'badge_first_blood',
    title: '🧢 First Blood',
    description: 'Rookie achievement: Reached 100 career runs.',
    badgeIcon: '🧢',
    stats: {'runs': runs},
  );

  static PlayerAchievement runMachine(String userId, int runs) => PlayerAchievement.genZCareerBadge(
    id: 'badge_run_machine_$userId',
    type: 'badge_run_machine',
    title: '🔥 Run Machine',
    description: 'Respect level unlocked: Reached 500 career runs.',
    badgeIcon: '🔥',
    stats: {'runs': runs},
  );

  static PlayerAchievement certifiedBatsman(String userId, int runs) => PlayerAchievement.genZCareerBadge(
    id: 'badge_certified_batsman_$userId',
    type: 'badge_certified_batsman',
    title: '💎 Certified Batsman',
    description: 'Serious player status: Reached 1000 career runs.',
    badgeIcon: '💎',
    stats: {'runs': runs},
  );

  static PlayerAchievement localLegend(String userId, int runs) => PlayerAchievement.genZCareerBadge(
    id: 'badge_local_legend_$userId',
    type: 'badge_local_legend',
    title: '👑 Local Legend',
    description: 'Gully hero: Reached 2500 career runs.',
    badgeIcon: '👑',
    stats: {'runs': runs},
  );

  static PlayerAchievement goatBatter(String userId, int runs) => PlayerAchievement.genZCareerBadge(
    id: 'badge_goat_batter_$userId',
    type: 'badge_goat_batter',
    title: '🐐 GOAT Batter',
    description: 'Elite, untouchable: Reached 5000 career runs.',
    badgeIcon: '🐐',
    stats: {'runs': runs},
  );

  static PlayerAchievement sixHunter(String userId, int sixes) => PlayerAchievement.genZCareerBadge(
    id: 'badge_six_hunter_$userId',
    type: 'badge_six_hunter',
    title: '🧨 Six Hunter',
    description: 'Power hitting: Smashed 50+ career sixes.',
    badgeIcon: '🧨',
    stats: {'sixes': sixes},
  );

  static PlayerAchievement boundaryBoss(String userId, int fours) => PlayerAchievement.genZCareerBadge(
    id: 'badge_boundary_boss_$userId',
    type: 'badge_boundary_boss',
    title: '🎯 Boundary Boss',
    description: 'Finding the gaps: Hit 200+ career fours.',
    badgeIcon: '🎯',
    stats: {'fours': fours},
  );

  static PlayerAchievement quickFire(String userId, double strikeRate) => PlayerAchievement.genZCareerBadge(
    id: 'badge_quick_fire_$userId',
    type: 'badge_quick_fire',
    title: '🔥 Quick Fire',
    description: 'Devastating intent: Career strike rate above 150.',
    badgeIcon: '🔥',
    stats: {'strikeRate': strikeRate},
  );

  static PlayerAchievement iceCold(String userId, int notOuts) => PlayerAchievement.genZCareerBadge(
    id: 'badge_ice_cold_$userId',
    type: 'badge_ice_cold',
    title: '🧊 Ice Cold',
    description: 'Finisher: 10+ career Not-Outs.',
    badgeIcon: '🧊',
    stats: {'notOuts': notOuts},
  );

  // --- BOWLER BADGES ---

  static PlayerAchievement breakthrough(String userId, int wickets) => PlayerAchievement.genZCareerBadge(
    id: 'badge_breakthrough_$userId',
    type: 'badge_breakthrough',
    title: '🎯 Breakthrough',
    description: 'First blood with the ball: 10 career wickets.',
    badgeIcon: '🎯',
    stats: {'wickets': wickets},
  );

  static PlayerAchievement wicketDealer(String userId, int wickets) => PlayerAchievement.genZCareerBadge(
    id: 'badge_wicket_dealer_$userId',
    type: 'badge_wicket_dealer',
    title: '⚡ Wicket Dealer',
    description: 'Consistent threat: 50 career wickets.',
    badgeIcon: '⚡',
    stats: {'wickets': wickets},
  );

  static PlayerAchievement bowlingBrain(String userId, int wickets) => PlayerAchievement.genZCareerBadge(
    id: 'badge_bowling_brain_$userId',
    type: 'badge_bowling_brain',
    title: '🧠 Bowling Brain',
    description: 'Outsmarting batters: 100 career wickets.',
    badgeIcon: '🧠',
    stats: {'wickets': wickets},
  );

  static PlayerAchievement nightmare(String userId, int wickets) => PlayerAchievement.genZCareerBadge(
    id: 'badge_nightmare_$userId',
    type: 'badge_nightmare',
    title: '🐍 Nightmare',
    description: 'Feared by everyone: 250 career wickets.',
    badgeIcon: '🐍',
    stats: {'wickets': wickets},
  );

  static PlayerAchievement deathBringer(String userId, int wickets) => PlayerAchievement.genZCareerBadge(
    id: 'badge_death_bringer_$userId',
    type: 'badge_death_bringer',
    title: '💀 Death Bringer',
    description: 'Absolute destruction: 500 career wickets.',
    badgeIcon: '💀',
    stats: {'wickets': wickets},
  );

  static PlayerAchievement economyFreak(String userId, double economy) => PlayerAchievement.genZCareerBadge(
    id: 'badge_economy_freak_$userId',
    type: 'badge_economy_freak',
    title: '❄ Economy Freak',
    description: 'Nothing gets past: Total economy under 6.0.',
    badgeIcon: '❄',
    stats: {'economy': economy},
  );

  // --- ALL-ROUND / PROFILE FLEX BADGES ---

  static PlayerAchievement manOfMoments(String userId, int momAwards) => PlayerAchievement.genZCareerBadge(
    id: 'badge_man_of_moments_$userId',
    type: 'badge_man_of_moments',
    title: '🏆 Man of Moments',
    description: 'Game changer: 5+ Man of the Match awards.',
    badgeIcon: '🏆',
    stats: {'momAwards': momAwards},
  );

  static PlayerAchievement veteran(String userId, int matches) => PlayerAchievement.genZCareerBadge(
    id: 'badge_veteran_$userId',
    type: 'badge_veteran',
    title: '🧢 Veteran',
    description: 'True dedication: 100+ matches played.',
    badgeIcon: '🧢',
    stats: {'matches': matches},
  );
}
