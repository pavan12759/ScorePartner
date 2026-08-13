import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a team's request to join a tournament
enum TournamentJoinRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  expired,
  withdrawn,
}

/// Model representing a team's request to join a tournament via invite link
class TournamentJoinRequestModel {
  final String id;
  final String tournamentId;
  final String tournamentName;
  final String teamId;
  final String teamName;
  final String teamLogoUrl;
  final String requestedByUserId;
  final String requestedByUserName;
  final String requestedByUserRole; // owner, admin, captain, player
  final TournamentJoinRequestStatus status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String reviewedBy; // UID of tournament admin who reviewed
  final String rejectionReason;

  const TournamentJoinRequestModel({
    required this.id,
    required this.tournamentId,
    required this.tournamentName,
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl = '',
    required this.requestedByUserId,
    required this.requestedByUserName,
    required this.requestedByUserRole,
    this.status = TournamentJoinRequestStatus.pending,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy = '',
    this.rejectionReason = '',
  });

  factory TournamentJoinRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return TournamentJoinRequestModel(
      id: id,
      tournamentId: data['tournamentId'] ?? '',
      tournamentName: data['tournamentName'] ?? '',
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      teamLogoUrl: data['teamLogoUrl'] ?? '',
      requestedByUserId: data['requestedByUserId'] ?? '',
      requestedByUserName: data['requestedByUserName'] ?? '',
      requestedByUserRole: data['requestedByUserRole'] ?? '',
      status: _parseStatus(data['status']),
      requestedAt: _parseDate(data['requestedAt']),
      reviewedAt: data['reviewedAt'] != null ? _parseDate(data['reviewedAt']) : null,
      reviewedBy: data['reviewedBy'] ?? '',
      rejectionReason: data['rejectionReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'teamId': teamId,
      'teamName': teamName,
      'teamLogoUrl': teamLogoUrl,
      'requestedByUserId': requestedByUserId,
      'requestedByUserName': requestedByUserName,
      'requestedByUserRole': requestedByUserRole,
      'status': status.name,
      'requestedAt': FieldValue.serverTimestamp(),
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
    };
  }

  TournamentJoinRequestModel copyWith({
    String? id,
    String? tournamentId,
    String? tournamentName,
    String? teamId,
    String? teamName,
    String? teamLogoUrl,
    String? requestedByUserId,
    String? requestedByUserName,
    String? requestedByUserRole,
    TournamentJoinRequestStatus? status,
    DateTime? requestedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
  }) {
    return TournamentJoinRequestModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      teamLogoUrl: teamLogoUrl ?? this.teamLogoUrl,
      requestedByUserId: requestedByUserId ?? this.requestedByUserId,
      requestedByUserName: requestedByUserName ?? this.requestedByUserName,
      requestedByUserRole: requestedByUserRole ?? this.requestedByUserRole,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  static TournamentJoinRequestStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return TournamentJoinRequestStatus.pending;
    try {
      return TournamentJoinRequestStatus.values.firstWhere((e) => e.name == statusStr);
    } catch (_) {
      return TournamentJoinRequestStatus.pending;
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
