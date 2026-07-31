class LeaderboardEntry {
  final String id;
  final String name;
  final String city;
  final String? profileImage;
  final LeaderboardStats stats;

  LeaderboardEntry({
    required this.id,
    required this.name,
    required this.city,
    this.profileImage,
    required this.stats,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      city: json['city'] ?? 'Unknown',
      profileImage: json['profileImage'],
      stats: LeaderboardStats.fromJson(json['stats'] ?? {}),
    );
  }
}

class LeaderboardStats {
  final int matches;
  final int runs;
  final int wickets;
  final double average;
  final double strikeRate;
  final double economy;
  final int highestScore;
  final String bestBowling;

  LeaderboardStats({
    required this.matches,
    required this.runs,
    required this.wickets,
    required this.average,
    required this.strikeRate,
    required this.economy,
    required this.highestScore,
    required this.bestBowling,
  });

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) {
    return LeaderboardStats(
      matches: json['matches'] ?? 0,
      runs: json['runs'] ?? 0,
      wickets: json['wickets'] ?? 0,
      average: (json['average'] ?? 0).toDouble(),
      strikeRate: (json['strikeRate'] ?? 0).toDouble(),
      economy: (json['economy'] ?? 0).toDouble(),
      highestScore: json['highestScore'] ?? 0,
      bestBowling: json['bestBowling'] ?? '0/0',
    );
  }
}
