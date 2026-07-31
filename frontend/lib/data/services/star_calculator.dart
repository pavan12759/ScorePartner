/// Cricket Progression System – Star Calculator
///
/// Calculates stars earned per match and determines cricket rank titles.
class StarCalculator {
  // ──────────────── RANK DEFINITIONS ────────────────
  static const List<Map<String, dynamic>> ranks = [
    {'minStars': 0,    'title': 'Gully Player',         'emoji': '🏏',  'color': 'green',       'message': '✨ Every legend started in the gully!'},
    {'minStars': 100,  'title': 'Net Warrior',           'emoji': '🥅',  'color': 'blue',        'message': '💪 Putting in the hard yards at the nets!'},
    {'minStars': 250,  'title': 'District Star',         'emoji': '⭐',  'color': 'purple',      'message': '🌟 Your talent shines at district level!'},
    {'minStars': 450,  'title': 'Captain\'s Pick',       'emoji': '🧢',  'color': 'orange',      'message': '🫡 Every captain wants you in their XI!'},
    {'minStars': 700,  'title': 'Match Winner',          'emoji': '🔥',  'color': 'crimson',     'message': '⚡ You turn matches on your own!'},
    {'minStars': 1000, 'title': 'All-Star Player',       'emoji': '💫',  'color': 'gold',        'message': '✨ You dominate every format you play!'},
    {'minStars': 1400, 'title': 'Tournament MVP',        'emoji': '🏆',  'color': 'bronzeGold',  'message': '🥇 The most valuable player on any stage!'},
    {'minStars': 1800, 'title': 'Cricket Icon',          'emoji': '🏟️',  'color': 'flame',       'message': '📢 Your name echoes through every ground!'},
    {'minStars': 2500, 'title': 'Cricket Legend',        'emoji': '👑',  'color': 'goldCrown',   'message': '🐐 You are the G.O.A.T. — a true legend!'},
  ];

  // ──────────────── EPIC TITLES (SKILL-BASED) ────────────────
  static const List<Map<String, dynamic>> epicTitleDefinitions = [
    {'id': 'sixer_king',       'title': 'Sixer King',         'emoji': '💥', 'type': 'batting',  'description': 'Clears the boundary at will (High SR + 10+ Sixes)'},
    {'id': 'boundary_machine', 'title': 'Boundary Machine',   'emoji': '🪵', 'type': 'batting',  'description': 'Finds the gaps everywhere (High SR + 50+ Fours)'},
    {'id': 'anchor_master',    'title': 'Anchor Master',      'emoji': '⚓', 'type': 'batting',  'description': 'The backbone of every innings (High runs + Low Dot %)'},
    {'id': 'yorker_king',      'title': 'Yorker King',        'emoji': '🎳', 'type': 'bowling',  'description': 'Deadly pace bowler with pinpoint yorkers'},
    {'id': 'spin_wizard',      'title': 'Spin Wizard',        'emoji': '🌀', 'type': 'bowling',  'description': 'Turns the ball like magic'},
    {'id': 'wicket_machine',   'title': 'Wicket Machine',     'emoji': '💀', 'type': 'bowling',  'description': 'Unstoppable wicket taker (50+ Wickets)'},
    {'id': 'safe_hands',       'title': 'Safe Hands',         'emoji': '🧤', 'type': 'fielding', 'description': 'Never drops a catch (30+ Catches)'},
    {'id': 'direct_hit_king',  'title': 'Direct Hit King',    'emoji': '🎯', 'type': 'fielding', 'description': 'Bullet throw run-out specialist (15+ Run-outs/Stumpings)'},
  ];

  // ──────────────── STAR CALCULATION ────────────────

  /// Calculate the number of stars earned from a single match performance.
  static int calculateMatchStars({
    required int runsScored,
    required int ballsFaced,
    required int wickets,
    required int catches,
    required int runOuts,
    required int stumpings,
    required int directHits,
    required bool isManOfMatch,
    bool isTournamentMvp = false,
    required bool isWinner,
  }) {
    int stars = 0;

    // ── Batting Stars ──
    // 1 star for every 10 runs scored
    stars += (runsScored ~/ 10);

    // ── Bowling Stars ──
    // 1 star for every 1 wicket taken
    stars += wickets;

    // ── Fielding Stars ──
    // 1 star per dismissal
    stars += catches;
    stars += runOuts;
    stars += stumpings;
    stars += directHits;

    // ── Awards ──
    if (isManOfMatch) stars += 5;
    if (isTournamentMvp) stars += 10;
    if (isWinner) stars += 2;

    return stars;
  }

  /// Evaluates which special epic titles a player has earned based on their career stats.
  static List<String> calculateEpicTitles(Map<String, dynamic> stats, String bowlingStyle) {
    List<String> titles = [];
    
    final int runs = (stats['runs'] ?? 0);
    final int wickets = (stats['wickets'] ?? 0);
    final int sixes = (stats['sixes'] ?? 0);
    final int fours = (stats['fours'] ?? 0);
    final double sr = (stats['strikeRate'] ?? 0.0);
    final int catches = (stats['catches'] ?? 0);
    final int runOuts = (stats['runOuts'] ?? 0);
    final int stumpings = (stats['stumpings'] ?? 0);
    final int directHits = (stats['directHits'] ?? 0);

    // Batting Titles
    if (sr > 180 && sixes >= 10) titles.add('Sixer King');
    if (sr > 140 && fours >= 50) titles.add('Boundary Machine');
    if (runs >= 500 && sr > 120) titles.add('Anchor Master');

    // Bowling Titles
    if (wickets >= 10) {
      if (bowlingStyle.toLowerCase().contains('fast') || bowlingStyle.toLowerCase().contains('pace')) {
        titles.add('Yorker King');
      } else if (bowlingStyle.toLowerCase().contains('spin')) {
        titles.add('Spin Wizard');
      }
    }
    if (wickets >= 50) titles.add('Wicket Machine');

    // Fielding Titles
    if (catches >= 30) titles.add('Safe Hands');
    if ((runOuts + stumpings + directHits) >= 15) titles.add('Direct Hit King');

    return titles;
  }

  // ──────────────── RANK LOOKUP ────────────────

  /// Returns the rank map for the given total stars.
  static Map<String, dynamic> getRankForStars(int totalStars) {
    Map<String, dynamic> currentRank = ranks.first;
    for (var rank in ranks) {
      if (totalStars >= (rank['minStars'] as int)) {
        currentRank = rank;
      } else {
        break;
      }
    }
    return currentRank;
  }

  /// Returns just the title string for total stars.
  static String getRankTitle(int totalStars) {
    return getRankForStars(totalStars)['title'] as String;
  }

  /// Check if stars crossed a rank boundary, returning the new rank or null.
  static Map<String, dynamic>? checkRankUp(int oldStars, int newStars) {
    final oldRank = getRankForStars(oldStars);
    final newRank = getRankForStars(newStars);
    if (oldRank['title'] != newRank['title']) {
      return newRank;
    }
    return null;
  }

  /// Returns progress within the current rank as a value from 0.0 to 1.0.
  static double getRankProgress(int totalStars) {
    final current = getRankForStars(totalStars);
    final currentMin = current['minStars'] as int;

    // Find the next rank
    int nextMin = -1;
    for (var rank in ranks) {
      if ((rank['minStars'] as int) > currentMin) {
        nextMin = rank['minStars'] as int;
        break;
      }
    }

    // Already at max rank
    if (nextMin == -1) return 1.0;

    final range = nextMin - currentMin;
    final progress = totalStars - currentMin;
    return (progress / range).clamp(0.0, 1.0);
  }
}
