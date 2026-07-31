import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a team join request
enum JoinRequestStatus {
  pending,
  accepted,
  rejected,
}

/// Model representing a player's request to join a team via invite link
class JoinRequestModel {
  final String id;
  final String teamId;
  final String teamName;
  final String playerId;
  final String playerName;
  final String playerPhotoUrl;
  final String playerSpPId;
  final String playerRole; // Batsman, Bowler, All-rounder, Wicket Keeper
  final String battingStyle;
  final String bowlingStyle;
  final String playerCity;
  final JoinRequestStatus status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String reviewedBy; // UID of admin who reviewed

  const JoinRequestModel({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.playerId,
    required this.playerName,
    this.playerPhotoUrl = '',
    this.playerSpPId = '',
    this.playerRole = '',
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.playerCity = '',
    this.status = JoinRequestStatus.pending,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy = '',
  });

  factory JoinRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return JoinRequestModel(
      id: id,
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      playerPhotoUrl: data['playerPhotoUrl'] ?? '',
      playerSpPId: data['playerSpPId'] ?? '',
      playerRole: data['playerRole'] ?? '',
      battingStyle: data['battingStyle'] ?? '',
      bowlingStyle: data['bowlingStyle'] ?? '',
      playerCity: data['playerCity'] ?? '',
      status: _parseStatus(data['status']),
      requestedAt: _parseDate(data['requestedAt']),
      reviewedAt: data['reviewedAt'] != null ? _parseDate(data['reviewedAt']) : null,
      reviewedBy: data['reviewedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'playerId': playerId,
      'playerName': playerName,
      'playerPhotoUrl': playerPhotoUrl,
      'playerSpPId': playerSpPId,
      'playerRole': playerRole,
      'battingStyle': battingStyle,
      'bowlingStyle': bowlingStyle,
      'playerCity': playerCity,
      'status': status.name,
      'requestedAt': FieldValue.serverTimestamp(),
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
    };
  }

  JoinRequestModel copyWith({
    String? id,
    String? teamId,
    String? teamName,
    String? playerId,
    String? playerName,
    String? playerPhotoUrl,
    String? playerSpPId,
    String? playerRole,
    String? battingStyle,
    String? bowlingStyle,
    String? playerCity,
    JoinRequestStatus? status,
    DateTime? requestedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return JoinRequestModel(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      playerPhotoUrl: playerPhotoUrl ?? this.playerPhotoUrl,
      playerSpPId: playerSpPId ?? this.playerSpPId,
      playerRole: playerRole ?? this.playerRole,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      playerCity: playerCity ?? this.playerCity,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  static JoinRequestStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return JoinRequestStatus.pending;
    try {
      return JoinRequestStatus.values.firstWhere((e) => e.name == statusStr);
    } catch (_) {
      return JoinRequestStatus.pending;
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
