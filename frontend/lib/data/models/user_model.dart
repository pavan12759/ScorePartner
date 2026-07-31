import 'package:cloud_firestore/cloud_firestore.dart';
import 'achievement_model.dart';

/// Helper to convert Firestore Timestamp to DateTime
DateTime _toDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

class UserModel {
  final String uid;
  final String email;
  final String phoneNumber;
  final String name;
  final String spPId; // Player's unique ID (SPP12345678)
  final String gender;
  final DateTime? dob;
  
  final String role;
  final String battingStyle;
  final String bowlingStyle;
  final int age;
  final String location;
  final String profileImageUrl;
  final String instagramUrl;
  final String bio;
  final bool isVerified;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final PlayerStats tennisBallStats;
  final PlayerStats leatherBallStats;

  // Achievement tracking
  final List<PlayerAchievement> achievements;
  final List<String> tournamentIds; // Tournaments participated in

  // Warrior Progression System
  final int stars;
  final String rankTitle;
  final List<String> unlockedTitles;

  const UserModel({
    required this.uid,
    this.email = '',
    required this.phoneNumber,
    required this.name,
    this.spPId = '',
    required this.role,
    this.gender = 'Male',
    this.dob,

    required this.battingStyle,
    required this.bowlingStyle,
    required this.age,
    required this.location,
    required this.profileImageUrl,
    required this.instagramUrl,
    this.bio = '',
    required this.isVerified,
    this.isProfileComplete = false,
    required this.createdAt,
    required this.lastActiveAt,
    required this.tennisBallStats,
    required this.leatherBallStats,
    this.achievements = const [],
    this.tournamentIds = const [],
    this.stars = 0,
    this.rankTitle = 'Bal Yoddha',
    this.unlockedTitles = const ['Bal Yoddha'],
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'] ?? '',
      spPId: data['spPId'] ?? '',
      role: data['role'] ?? '',
      gender: data['gender'] ?? 'Male',
      dob: _toDateTime(data['dob']),

      battingStyle: data['battingStyle'] ?? '',
      bowlingStyle: data['bowlingStyle'] ?? '',
      age: data['age'] ?? 18,
      location: data['location'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      instagramUrl: data['instagramUrl'] ?? '',
      bio: data['bio'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isProfileComplete: data['isProfileComplete'] ?? false,
      createdAt: _toDateTime(data['createdAt']),
      lastActiveAt: _toDateTime(data['lastActiveAt']),
      tennisBallStats: PlayerStats.fromMap(data['tennisBallStats'] ?? {}),
      leatherBallStats: PlayerStats.fromMap(data['leatherBallStats'] ?? {}),
      achievements: (data['achievements'] as List<dynamic>?)
          ?.map((e) => PlayerAchievement.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      tournamentIds: List<String>.from(data['tournamentIds'] ?? []),
      stars: data['stars'] ?? 0,
      rankTitle: data['rankTitle'] ?? 'Bal Yoddha',
      unlockedTitles: List<String>.from(data['unlockedTitles'] ?? ['Bal Yoddha']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'name': name,
      'spPId': spPId,
      'role': role,
      'gender': gender,
      'dob': dob,

      'battingStyle': battingStyle,
      'bowlingStyle': bowlingStyle,
      'age': age,
      'location': location,
      'profileImageUrl': profileImageUrl,
      'instagramUrl': instagramUrl,
      'bio': bio,
      'isVerified': isVerified,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt,
      'tennisBallStats': tennisBallStats.toMap(),
      'leatherBallStats': leatherBallStats.toMap(),
      'achievements': achievements.map((a) => a.toMap()).toList(),
      'tournamentIds': tournamentIds,
      'stars': stars,
      'rankTitle': rankTitle,
      'unlockedTitles': unlockedTitles,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? name,
    String? spPId,
    String? role,
    String? gender,
    DateTime? dob,
    String? battingStyle,
    String? bowlingStyle,
    int? age,
    String? location,
    String? profileImageUrl,
    String? instagramUrl,
    String? bio,
    bool? isVerified,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    PlayerStats? tennisBallStats,
    PlayerStats? leatherBallStats,
    List<PlayerAchievement>? achievements,
    List<String>? tournamentIds,
    int? stars,
    String? rankTitle,
    List<String>? unlockedTitles,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      spPId: spPId ?? this.spPId,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      age: age ?? this.age,
      location: location ?? this.location,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      tennisBallStats: tennisBallStats ?? this.tennisBallStats,
      leatherBallStats: leatherBallStats ?? this.leatherBallStats,
      achievements: achievements ?? this.achievements,
      tournamentIds: tournamentIds ?? this.tournamentIds,
      stars: stars ?? this.stars,
      rankTitle: rankTitle ?? this.rankTitle,
      unlockedTitles: unlockedTitles ?? this.unlockedTitles,
    );
  }
}

class PlayerStats {
  final int matches;
  final int runs;
  final int wickets;
  final double strikeRate;
  final double economy;
  final int bestScore;
  final String bestBowling;
  final int manOfMatches;
  final int tournamentWins;
  // Additional detailed stats
  final int balls; // balls faced
  final int ballsBowled;
  final int runsConceded;
  final int fours;
  final int sixes;
  final int fifties;
  final int hundreds;
  final int ducks;
  final int fiveWickets;
  final int catches;
  final int runOuts;
  final int stumpings;
  final int directHits;

  PlayerStats({
    required this.matches,
    required this.runs,
    required this.wickets,
    required this.strikeRate,
    required this.economy,
    required this.bestScore,
    required this.bestBowling,
    required this.manOfMatches,
    required this.tournamentWins,
    this.balls = 0,
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.fours = 0,
    this.sixes = 0,
    this.fifties = 0,
    this.hundreds = 0,
    this.ducks = 0,
    this.fiveWickets = 0,
    this.catches = 0,
    this.runOuts = 0,
    this.stumpings = 0,
    this.directHits = 0,
  });

  factory PlayerStats.fromMap(Map<String, dynamic> data) {
    return PlayerStats(
      matches: data['matches'] ?? 0,
      runs: data['runs'] ?? 0,
      wickets: data['wickets'] ?? 0,
      strikeRate: (data['strikeRate'] ?? 0.0).toDouble(),
      economy: (data['economy'] ?? 0.0).toDouble(),
      bestScore: data['bestScore'] ?? 0,
      bestBowling: data['bestBowling'] ?? '0/0',
      manOfMatches: data['manOfMatches'] ?? 0,
      tournamentWins: data['tournamentWins'] ?? 0,
      balls: data['balls'] ?? 0,
      ballsBowled: data['ballsBowled'] ?? 0,
      runsConceded: data['runsConceded'] ?? 0,
      fours: data['fours'] ?? 0,
      sixes: data['sixes'] ?? 0,
      fifties: data['fifties'] ?? 0,
      hundreds: data['hundreds'] ?? 0,
      ducks: data['ducks'] ?? 0,
      fiveWickets: data['fiveWickets'] ?? 0,
      catches: data['catches'] ?? 0,
      runOuts: data['runOuts'] ?? 0,
      stumpings: data['stumpings'] ?? 0,
      directHits: data['directHits'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matches': matches,
      'runs': runs,
      'wickets': wickets,
      'strikeRate': strikeRate,
      'economy': economy,
      'bestScore': bestScore,
      'bestBowling': bestBowling,
      'manOfMatches': manOfMatches,
      'tournamentWins': tournamentWins,
      'balls': balls,
      'ballsBowled': ballsBowled,
      'runsConceded': runsConceded,
      'fours': fours,
      'sixes': sixes,
      'fifties': fifties,
      'hundreds': hundreds,
      'ducks': ducks,
      'fiveWickets': fiveWickets,
      'catches': catches,
      'runOuts': runOuts,
      'stumpings': stumpings,
      'directHits': directHits,
    };
  }

  PlayerStats copyWith({
    int? matches,
    int? runs,
    int? wickets,
    double? strikeRate,
    double? economy,
    int? bestScore,
    String? bestBowling,
    int? manOfMatches,
    int? tournamentWins,
    int? balls,
    int? ballsBowled,
    int? runsConceded,
    int? fours,
    int? sixes,
    int? fifties,
    int? hundreds,
    int? ducks,
    int? fiveWickets,
    int? catches,
    int? runOuts,
    int? stumpings,
    int? directHits,
  }) {
    return PlayerStats(
      matches: matches ?? this.matches,
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      strikeRate: strikeRate ?? this.strikeRate,
      economy: economy ?? this.economy,
      bestScore: bestScore ?? this.bestScore,
      bestBowling: bestBowling ?? this.bestBowling,
      manOfMatches: manOfMatches ?? this.manOfMatches,
      tournamentWins: tournamentWins ?? this.tournamentWins,
      balls: balls ?? this.balls,
      ballsBowled: ballsBowled ?? this.ballsBowled,
      runsConceded: runsConceded ?? this.runsConceded,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      fifties: fifties ?? this.fifties,
      hundreds: hundreds ?? this.hundreds,
      ducks: ducks ?? this.ducks,
      fiveWickets: fiveWickets ?? this.fiveWickets,
      catches: catches ?? this.catches,
      runOuts: runOuts ?? this.runOuts,
      stumpings: stumpings ?? this.stumpings,
      directHits: directHits ?? this.directHits,
    );
  }
}
