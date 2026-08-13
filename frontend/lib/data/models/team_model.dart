import 'package:flutter/material.dart';

/// Team Model for cricket teams
class TeamModel {
  final String id;
  final String spTId; // Unique formatted ID (SPT12345678)
  final String name;
  final String captainId;
  final String captainName;
  final String viceCaptainId;
  final String viceCaptainName;
  final String logoUrl;
  final List<TeamPlayer> players;
  final DateTime createdAt;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;

  // Invite link fields
  final String inviteToken;
  final bool inviteLinkEnabled;
  final DateTime? inviteExpiry;

  const TeamModel({
    required this.id,
    this.spTId = '',
    required this.name,
    required this.captainId,
    required this.captainName,
    this.viceCaptainId = '',
    this.viceCaptainName = '',

    this.logoUrl = '',
    required this.players,
    required this.createdAt,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.inviteToken = '',
    this.inviteLinkEnabled = false,
    this.inviteExpiry,
  });

  factory TeamModel.fromMap(Map<String, dynamic> data) {
    // Helper to convert Firestore Timestamp to DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      // Handle Firestore Timestamp
      final typeString = value.runtimeType.toString();
      if (typeString.contains('Timestamp')) {
        try {
          return (value as dynamic).toDate();
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return TeamModel(
      id: data['id'] ?? data['_id'] ?? '',
      spTId: data['spTId'] ?? '',
      name: data['name'] ?? '',
      captainId: data['captainId'] ?? '',
      captainName: data['captainName'] ?? '',
      viceCaptainId: data['viceCaptainId'] ?? '',
      viceCaptainName: data['viceCaptainName'] ?? '',

      logoUrl: data['logoUrl'] ?? '',
      players: (data['players'] as List<dynamic>?)
          ?.map((p) => TeamPlayer.fromMap(p))
          .toList() ?? [],
      createdAt: parseDateTime(data['createdAt']),
      matchesPlayed: data['matchesPlayed'] ?? 0,
      matchesWon: data['matchesWon'] ?? 0,
      matchesLost: data['matchesLost'] ?? 0,
      inviteToken: data['inviteToken'] ?? '',
      inviteLinkEnabled: data['inviteLinkEnabled'] ?? false,
      inviteExpiry: data['inviteExpiry'] != null ? parseDateTime(data['inviteExpiry']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spTId': spTId,
      'name': name,
      'captainId': captainId,
      'captainName': captainName,
      'viceCaptainId': viceCaptainId,
      'viceCaptainName': viceCaptainName,

      'logoUrl': logoUrl,
      'players': players.map((p) => p.toMap()).toList(),
      'createdAt': createdAt,
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'matchesLost': matchesLost,
      'inviteToken': inviteToken,
      'inviteLinkEnabled': inviteLinkEnabled,
      if (inviteExpiry != null) 'inviteExpiry': inviteExpiry!.toIso8601String(),
    };
  }

  TeamModel copyWith({
    String? id,
    String? spTId,
    String? name,
    String? captainId,
    String? captainName,
    String? viceCaptainId,
    String? viceCaptainName,
    String? logoUrl,
    List<TeamPlayer>? players,
    DateTime? createdAt,
    int? matchesPlayed,
    int? matchesWon,
    int? matchesLost,
    String? inviteToken,
    bool? inviteLinkEnabled,
    DateTime? inviteExpiry,
  }) {
    return TeamModel(
      id: id ?? this.id,
      spTId: spTId ?? this.spTId,
      name: name ?? this.name,
      captainId: captainId ?? this.captainId,
      captainName: captainName ?? this.captainName,
      viceCaptainId: viceCaptainId ?? this.viceCaptainId,
      viceCaptainName: viceCaptainName ?? this.viceCaptainName,

      logoUrl: logoUrl ?? this.logoUrl,
      players: players ?? this.players,
      createdAt: createdAt ?? this.createdAt,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      matchesLost: matchesLost ?? this.matchesLost,
      inviteToken: inviteToken ?? this.inviteToken,
      inviteLinkEnabled: inviteLinkEnabled ?? this.inviteLinkEnabled,
      inviteExpiry: inviteExpiry ?? this.inviteExpiry,
    );
  }

  int get totalPlayers => players.length;
  double get winPercentage => matchesPlayed > 0 ? (matchesWon / matchesPlayed) * 100 : 0;
}

/// Player in a team
class TeamPlayer {
  final String userId;
  final String spPId; // Player's unique ID if registered (SPP12345678)
  final String name;
  final String mobileNumber; // Contact info for non-registered players
  final String role; // Batsman, Bowler, All-rounder, Wicket Keeper
  final String battingStyle;
  final String bowlingStyle;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isRegistered;

  const TeamPlayer({
    required this.userId,
    this.spPId = '',
    required this.name,
    this.mobileNumber = '',
    required this.role,
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.isRegistered = false,
  });

  factory TeamPlayer.fromMap(Map<String, dynamic> data) {
    return TeamPlayer(
      userId: data['userId'] ?? data['uid'] ?? '',
      spPId: data['spPId'] ?? '',
      name: data['name'] ?? '',
      mobileNumber: data['mobileNumber'] ?? '',
      role: data['role'] ?? '',
      battingStyle: data['battingStyle'] ?? '',
      bowlingStyle: data['bowlingStyle'] ?? '',
      isCaptain: data['isCaptain'] ?? false,
      isViceCaptain: data['isViceCaptain'] ?? false,
      isRegistered: data['isRegistered'] ?? (data['spPId'] != null && data['spPId'] != ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'spPId': spPId,
      'name': name,
      'mobileNumber': mobileNumber,
      'role': role,
      'battingStyle': battingStyle,
      'bowlingStyle': bowlingStyle,
      'isCaptain': isCaptain,
      'isViceCaptain': isViceCaptain,
      'isRegistered': isRegistered,
    };
  }
}


/// Tournament Gallery Item representing a photo or cinematic poster
class TournamentGalleryItem {
  final String id;
  final String imageUrl;
  final String category; // 'celebration', 'trophy', 'match_winning', 'crowd', 'action', 'mvp', 'six', 'wicket', 'century', 'poster'
  final String title;
  final String description;
  final DateTime createdAt;
  final String? badgeType; // 'batsman', 'bowler', 'team'
  final String? badgeName;
  final String? overlayStyle;
  final String? shareFormat;
  final String? playerName;

  const TournamentGalleryItem({
    required this.id,
    required this.imageUrl,
    required this.category,
    required this.title,
    required this.description,
    required this.createdAt,
    this.badgeType,
    this.badgeName,
    this.overlayStyle,
    this.shareFormat,
    this.playerName,
  });

  factory TournamentGalleryItem.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {}
      }
      final typeStr = val.runtimeType.toString();
      if (typeStr.contains('Timestamp')) {
        try {
          return (val as dynamic).toDate();
        } catch (_) {}
      }
      return DateTime.now();
    }

    return TournamentGalleryItem(
      id: data['id'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'celebration',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: parseDate(data['createdAt']),
      badgeType: data['badgeType'],
      badgeName: data['badgeName'],
      overlayStyle: data['overlayStyle'],
      shareFormat: data['shareFormat'],
      playerName: data['playerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'category': category,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'badgeType': badgeType,
      'badgeName': badgeName,
      'overlayStyle': overlayStyle,
      'shareFormat': shareFormat,
      'playerName': playerName,
    };
  }
}


/// Tournament Model
class TournamentModel {
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    // Handle Firestore Timestamp
    final typeString = value.runtimeType.toString();
    if (typeString.contains('Timestamp')) {
      try {
        return (value as dynamic).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  final String id;
  final String name;
  final String description;
  final String organizerId;
  final String organizerName;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final int maxTeams;
  final List<String> registeredTeamIds;
  final String status; // upcoming, ongoing, completed
  final String format; // knockout, league, group
  final int overs;
  final String ballType; // tennis, leather
  final String matchFormat; // 'T20', 'ODI', 'Test'
  final double entryFee;
  final double prizePool;
  final String winnerId;
  final String runnerUpId;
  
  // New fields for match generation
  final List<String> matchIds;
  final Map<String, List<String>>? groups; // Group name -> team IDs
  final List<TournamentFixture> fixtures;
  
  // CricHeroes-like fields
  final String category; // 'open', 'corporate', 'box_cricket', 'series', 'community'
  final int powerPlayOvers; // Power play configuration
  final String? logoUrl; // Tournament branding
  final String? bannerUrl; // Tournament banner
  final List<TeamPoints> pointsTable; // ICC-style points with NRR
  
  // Tournament leaderboard
  final List<TournamentLeaderboardEntry> topRunScorers;
  final List<TournamentLeaderboardEntry> topWicketTakers;
  final List<TournamentLeaderboardEntry> topSixHitters;
  final List<TournamentLeaderboardEntry> topFourHitters;
  final List<TournamentLeaderboardEntry> bestEconomy;
  final List<TournamentLeaderboardEntry> bestBowlingFigures;
  
  // Multi-admin support
  final List<String> adminIds; // Co-admins who can manage matches
  final String fixtureGenerationMode; // 'auto' or 'manual'
  final List<TournamentGalleryItem> gallery;
  final int views; // Total views of the tournament

  // Geo-coordinates for location (from Google Places)
  final double? latitude;
  final double? longitude;

  // Invite link fields
  final String inviteToken;
  final bool inviteLinkEnabled;
  final DateTime? inviteExpiry;

  const TournamentModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.organizerId,
    required this.organizerName,
    required this.location,
    required this.startDate,
    required this.endDate,
    this.maxTeams = 8,
    required this.registeredTeamIds,
    this.status = 'upcoming',
    this.format = 'knockout',
    this.overs = 10,
    this.ballType = 'tennis',
    this.matchFormat = 'T20',
    this.entryFee = 0,
    this.prizePool = 0,
    this.winnerId = '',
    this.runnerUpId = '',
    this.matchIds = const [],
    this.groups,
    this.fixtures = const [],
    this.category = 'open',
    this.powerPlayOvers = 0,
    this.logoUrl,
    this.bannerUrl,
    this.pointsTable = const [],
    this.topRunScorers = const [],
    this.topWicketTakers = const [],
    this.topSixHitters = const [],
    this.topFourHitters = const [],
    this.bestEconomy = const [],
    this.bestBowlingFigures = const [],
    this.adminIds = const [],
    this.fixtureGenerationMode = 'auto',
    this.gallery = const [],
    this.views = 0,
    this.latitude,
    this.longitude,
    this.inviteToken = '',
    this.inviteLinkEnabled = false,
    this.inviteExpiry,
  });

  factory TournamentModel.fromMap(Map<String, dynamic> data) {
    return TournamentModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      location: data['location'] ?? '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      maxTeams: data['maxTeams'] ?? 8,
      registeredTeamIds: List<String>.from(data['registeredTeamIds'] ?? []),
      status: data['status'] ?? 'upcoming',
      format: data['format'] ?? 'knockout',
      overs: data['overs'] ?? 10,
      ballType: data['ballType'] ?? 'tennis',
      matchFormat: data['matchFormat'] ?? 'T20',
      entryFee: (data['entryFee'] ?? 0).toDouble(),
      prizePool: (data['prizePool'] ?? 0).toDouble(),
      winnerId: data['winnerId'] ?? '',
      runnerUpId: data['runnerUpId'] ?? '',
      matchIds: List<String>.from(data['matchIds'] ?? []),
      groups: data['groups'] != null 
          ? Map<String, List<String>>.from(
              (data['groups'] as Map).map((k, v) => MapEntry(k.toString(), List<String>.from(v)))
            )
          : null,
      fixtures: (data['fixtures'] as List<dynamic>?)
          ?.map((e) => TournamentFixture.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      category: data['category'] ?? 'open',
      powerPlayOvers: data['powerPlayOvers'] ?? 0,
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      pointsTable: (data['pointsTable'] as List<dynamic>?)
          ?.map((e) => TeamPoints.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      topRunScorers: (data['topRunScorers'] as List<dynamic>?)
          ?.map((e) => TournamentLeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      topWicketTakers: (data['topWicketTakers'] as List<dynamic>?)
          ?.map((e) => TournamentLeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      topSixHitters: (data['topSixHitters'] as List<dynamic>?)
          ?.map((e) => TournamentLeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      topFourHitters: (data['topFourHitters'] as List<dynamic>?)
          ?.map((e) => TournamentLeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      bestEconomy: (data['bestEconomy'] as List<dynamic>?)
          ?.map((e) => TournamentLeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      bestBowlingFigures: (data['bestBowlingFigures'] as List<dynamic>?)
          ?.map((e) => TournamentLeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      adminIds: List<String>.from(data['adminIds'] ?? []),
      fixtureGenerationMode: data['fixtureGenerationMode'] ?? 'auto',
      gallery: (data['gallery'] as List<dynamic>?)
          ?.map((e) => TournamentGalleryItem.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      views: data['views'] ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      inviteToken: data['inviteToken'] ?? '',
      inviteLinkEnabled: data['inviteLinkEnabled'] ?? false,
      inviteExpiry: data['inviteExpiry'] != null ? _parseDate(data['inviteExpiry']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'location': location,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'maxTeams': maxTeams,
      'registeredTeamIds': registeredTeamIds,
      'status': status,
      'format': format,
      'overs': overs,
      'ballType': ballType,
      'matchFormat': matchFormat,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'winnerId': winnerId,
      'runnerUpId': runnerUpId,
      'matchIds': matchIds,
      'groups': groups,
      'fixtures': fixtures.map((f) => f.toMap()).toList(),
      'category': category,
      'powerPlayOvers': powerPlayOvers,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'pointsTable': pointsTable.map((p) => p.toMap()).toList(),
      'topRunScorers': topRunScorers.map((e) => e.toMap()).toList(),
      'topWicketTakers': topWicketTakers.map((e) => e.toMap()).toList(),
      'topSixHitters': topSixHitters.map((e) => e.toMap()).toList(),
      'topFourHitters': topFourHitters.map((e) => e.toMap()).toList(),
      'bestEconomy': bestEconomy.map((e) => e.toMap()).toList(),
      'bestBowlingFigures': bestBowlingFigures.map((e) => e.toMap()).toList(),
      'adminIds': adminIds,
      'fixtureGenerationMode': fixtureGenerationMode,
      'gallery': gallery.map((e) => e.toMap()).toList(),
      'views': views,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'inviteToken': inviteToken,
      'inviteLinkEnabled': inviteLinkEnabled,
      if (inviteExpiry != null) 'inviteExpiry': inviteExpiry!.toIso8601String(),
    };
  }

  TournamentModel copyWith({
    String? id,
    String? name,
    String? description,
    String? organizerId,
    String? organizerName,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    int? maxTeams,
    List<String>? registeredTeamIds,
    String? status,
    String? format,
    int? overs,
    String? ballType,
    String? matchFormat,
    double? entryFee,
    double? prizePool,
    String? winnerId,
    String? runnerUpId,
    List<String>? matchIds,
    Map<String, List<String>>? groups,
    List<TournamentFixture>? fixtures,
    String? category,
    int? powerPlayOvers,
    String? logoUrl,
    String? bannerUrl,
    List<TeamPoints>? pointsTable,
    List<TournamentLeaderboardEntry>? topRunScorers,
    List<TournamentLeaderboardEntry>? topWicketTakers,
    List<TournamentLeaderboardEntry>? topSixHitters,
    List<TournamentLeaderboardEntry>? topFourHitters,
    List<TournamentLeaderboardEntry>? bestEconomy,
    List<TournamentLeaderboardEntry>? bestBowlingFigures,
    List<String>? adminIds,
    String? fixtureGenerationMode,
    List<TournamentGalleryItem>? gallery,
    int? views,
    double? latitude,
    double? longitude,
    String? inviteToken,
    bool? inviteLinkEnabled,
    DateTime? inviteExpiry,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxTeams: maxTeams ?? this.maxTeams,
      registeredTeamIds: registeredTeamIds ?? this.registeredTeamIds,
      status: status ?? this.status,
      format: format ?? this.format,
      overs: overs ?? this.overs,
      ballType: ballType ?? this.ballType,
      matchFormat: matchFormat ?? this.matchFormat,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      winnerId: winnerId ?? this.winnerId,
      runnerUpId: runnerUpId ?? this.runnerUpId,
      matchIds: matchIds ?? this.matchIds,
      groups: groups ?? this.groups,
      fixtures: fixtures ?? this.fixtures,
      category: category ?? this.category,
      powerPlayOvers: powerPlayOvers ?? this.powerPlayOvers,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      pointsTable: pointsTable ?? this.pointsTable,
      topRunScorers: topRunScorers ?? this.topRunScorers,
      topWicketTakers: topWicketTakers ?? this.topWicketTakers,
      topSixHitters: topSixHitters ?? this.topSixHitters,
      topFourHitters: topFourHitters ?? this.topFourHitters,
      bestEconomy: bestEconomy ?? this.bestEconomy,
      bestBowlingFigures: bestBowlingFigures ?? this.bestBowlingFigures,
      adminIds: adminIds ?? this.adminIds,
      fixtureGenerationMode: fixtureGenerationMode ?? this.fixtureGenerationMode,
      gallery: gallery ?? this.gallery,
      views: views ?? this.views,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      inviteToken: inviteToken ?? this.inviteToken,
      inviteLinkEnabled: inviteLinkEnabled ?? this.inviteLinkEnabled,
      inviteExpiry: inviteExpiry ?? this.inviteExpiry,
    );
  }

  int get registeredTeamsCount => registeredTeamIds.length;
  int get slotsAvailable => maxTeams - registeredTeamIds.length;
  bool get isFull => registeredTeamIds.length >= maxTeams;
  
  /// Automatically determine status based on dates
  /// If endDate has passed → 'completed'
  /// If startDate has passed but endDate hasn't → 'ongoing'
  /// Otherwise use stored status
  String get effectiveStatus {
    final now = DateTime.now();
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    if (now.isAfter(endOfDay)) return 'completed';
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    if (now.isAfter(startOfDay) || now.isAtSameMomentAs(startOfDay)) return 'ongoing';
    return status;
  }
}

/// Tournament Fixture - Represents a scheduled match in a tournament
class TournamentFixture {
  final String id;
  final String? matchId; // Actual match ID once created
  final String team1Id;
  final String team1Name;
  final String team2Id;
  final String team2Name;
  final String round; // 'Group A', 'Semi-Final 1', 'Final', etc.
  final int roundNumber; // 1, 2, 3... for ordering
  final String? groupName; // For group stage matches
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime; // Match time
  final String? venue; // Match venue/ground
  final String status; // 'pending', 'scheduled', 'live', 'completed'
  final String? winnerId;
  
  // Per-match configuration
  final int? overs; // Override tournament default overs for this match
  
  // Live score display
  final String? team1Score; // e.g., "145/6 (18.2)"
  final String? team2Score; // e.g., "120/10 (19.0)"

  const TournamentFixture({
    required this.id,
    this.matchId,
    required this.team1Id,
    required this.team1Name,
    required this.team2Id,
    required this.team2Name,
    required this.round,
    this.roundNumber = 1,
    this.groupName,
    this.scheduledDate,
    this.scheduledTime,
    this.venue,
    this.status = 'pending',
    this.winnerId,
    this.overs,
    this.team1Score,
    this.team2Score,
  });

  factory TournamentFixture.fromMap(Map<String, dynamic> data) {
    // Parse time from string format "HH:MM"
    TimeOfDay? parseTime(dynamic value) {
      if (value == null) return null;
      if (value is String && value.contains(':')) {
        final parts = value.split(':');
        return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      return null;
    }

    return TournamentFixture(
      id: data['id'] ?? '',
      matchId: data['matchId'],
      team1Id: data['team1Id'] ?? '',
      team1Name: data['team1Name'] ?? '',
      team2Id: data['team2Id'] ?? '',
      team2Name: data['team2Name'] ?? '',
      round: data['round'] ?? '',
      roundNumber: data['roundNumber'] ?? 1,
      groupName: data['groupName'],
      scheduledDate: data['scheduledDate'] != null 
          ? TournamentModel._parseDate(data['scheduledDate'])
          : null,
      scheduledTime: parseTime(data['scheduledTime']),
      venue: data['venue'],
      status: data['status'] ?? 'pending',
      winnerId: data['winnerId'],
      overs: data['overs'],
      team1Score: data['team1Score'],
      team2Score: data['team2Score'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'team1Id': team1Id,
      'team1Name': team1Name,
      'team2Id': team2Id,
      'team2Name': team2Name,
      'round': round,
      'roundNumber': roundNumber,
      'groupName': groupName,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'scheduledTime': scheduledTime != null 
          ? '${scheduledTime!.hour.toString().padLeft(2, '0')}:${scheduledTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'venue': venue,
      'status': status,
      'winnerId': winnerId,
      'overs': overs,
      'team1Score': team1Score,
      'team2Score': team2Score,
    };
  }

  TournamentFixture copyWith({
    String? id,
    String? matchId,
    String? team1Id,
    String? team1Name,
    String? team2Id,
    String? team2Name,
    String? round,
    int? roundNumber,
    String? groupName,
    DateTime? scheduledDate,
    TimeOfDay? scheduledTime,
    String? venue,
    String? status,
    String? winnerId,
    int? overs,
    String? team1Score,
    String? team2Score,
  }) {
    return TournamentFixture(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      team1Id: team1Id ?? this.team1Id,
      team1Name: team1Name ?? this.team1Name,
      team2Id: team2Id ?? this.team2Id,
      team2Name: team2Name ?? this.team2Name,
      round: round ?? this.round,
      roundNumber: roundNumber ?? this.roundNumber,
      groupName: groupName ?? this.groupName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      venue: venue ?? this.venue,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      overs: overs ?? this.overs,
      team1Score: team1Score ?? this.team1Score,
      team2Score: team2Score ?? this.team2Score,
    );
  }
}

/// Team standings with NRR for points table (ICC-style)
class TeamPoints {
  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final int runsFor;
  final int ballsFor;      // In balls for precision
  final int runsAgainst;
  final int ballsAgainst;  // In balls for precision
  final double nrr;        // Net Run Rate

  const TeamPoints({
    required this.teamId,
    required this.teamName,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.runsFor = 0,
    this.ballsFor = 0,
    this.runsAgainst = 0,
    this.ballsAgainst = 0,
    this.nrr = 0.0,
  });

  factory TeamPoints.fromMap(Map<String, dynamic> data) {
    return TeamPoints(
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      played: data['played'] ?? 0,
      won: data['won'] ?? 0,
      lost: data['lost'] ?? 0,
      tied: data['tied'] ?? 0,
      noResult: data['noResult'] ?? 0,
      points: data['points'] ?? 0,
      runsFor: data['runsFor'] ?? 0,
      ballsFor: data['ballsFor'] ?? 0,
      runsAgainst: data['runsAgainst'] ?? 0,
      ballsAgainst: data['ballsAgainst'] ?? 0,
      nrr: (data['nrr'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'played': played,
      'won': won,
      'lost': lost,
      'tied': tied,
      'noResult': noResult,
      'points': points,
      'runsFor': runsFor,
      'ballsFor': ballsFor,
      'runsAgainst': runsAgainst,
      'ballsAgainst': ballsAgainst,
      'nrr': nrr,
    };
  }

  /// Calculate NRR: (Runs Scored / Overs Faced) - (Runs Conceded / Overs Bowled)
  static double calculateNRR(int runsFor, int ballsFor, int runsAgainst, int ballsAgainst) {
    if (ballsFor == 0 || ballsAgainst == 0) return 0.0;
    final runRateFor = runsFor / (ballsFor / 6.0);
    final runRateAgainst = runsAgainst / (ballsAgainst / 6.0);
    return runRateFor - runRateAgainst;
  }

  TeamPoints copyWith({
    String? teamId,
    String? teamName,
    int? played,
    int? won,
    int? lost,
    int? tied,
    int? noResult,
    int? points,
    int? runsFor,
    int? ballsFor,
    int? runsAgainst,
    int? ballsAgainst,
    double? nrr,
  }) {
    return TeamPoints(
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      played: played ?? this.played,
      won: won ?? this.won,
      lost: lost ?? this.lost,
      tied: tied ?? this.tied,
      noResult: noResult ?? this.noResult,
      points: points ?? this.points,
      runsFor: runsFor ?? this.runsFor,
      ballsFor: ballsFor ?? this.ballsFor,
      runsAgainst: runsAgainst ?? this.runsAgainst,
      ballsAgainst: ballsAgainst ?? this.ballsAgainst,
      nrr: nrr ?? this.nrr,
    );
  }

  /// Display overs in X.Y format (e.g., 19.4 for 118 balls)
  String get oversForDisplay {
    final overs = ballsFor ~/ 6;
    final balls = ballsFor % 6;
    return '$overs.$balls';
  }

  String get oversAgainstDisplay {
    final overs = ballsAgainst ~/ 6;
    final balls = ballsAgainst % 6;
    return '$overs.$balls';
  }

  String get nrrDisplay {
    return nrr >= 0 ? '+${nrr.toStringAsFixed(3)}' : nrr.toStringAsFixed(3);
  }
}

/// Tournament Leaderboard Entry - For tracking top run scorers and wicket takers
class TournamentLeaderboardEntry {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int value; // Runs for batters, Wickets for bowlers
  final int matches;
  final double average; // Batting average or bowling average/economy
  final String? description; // Optional text like "5/12" for bowling stats

  const TournamentLeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.value = 0,
    this.matches = 0,
    this.average = 0.0,
    this.description,
  });

  factory TournamentLeaderboardEntry.fromMap(Map<String, dynamic> data) {
    return TournamentLeaderboardEntry(
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      value: data['value'] ?? 0,
      matches: data['matches'] ?? 0,
      average: (data['average'] ?? 0.0).toDouble(),
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'teamId': teamId,
      'teamName': teamName,
      'value': value,
      'matches': matches,
      'average': average,
      if (description != null) 'description': description,
    };
  }

  TournamentLeaderboardEntry copyWith({
    String? playerId,
    String? playerName,
    String? teamId,
    String? teamName,
    int? value,
    int? matches,
    double? average,
    String? description,
  }) {
    return TournamentLeaderboardEntry(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      value: value ?? this.value,
      matches: matches ?? this.matches,
      average: average ?? this.average,
      description: description ?? this.description,
    );
  }
}
