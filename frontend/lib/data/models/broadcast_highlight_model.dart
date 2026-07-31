/// Broadcast highlight model for auto-marking key moments
/// Auto-detected from ball-by-ball data: fours, sixes, wickets, milestones

class BroadcastHighlight {
  final String id;
  final String matchId;
  final String broadcastId;
  final String type; // 'four', 'six', 'wicket', 'runOut', 'hatTrick', 'century', 'fifty', 'winningShot'
  final String? ballEventId;
  final DateTime timestamp;
  final String title;
  final String description;
  final int? overNumber;
  final int? ballNumber;
  final String? batsmanName;
  final String? bowlerName;
  final int? runs;

  const BroadcastHighlight({
    required this.id,
    required this.matchId,
    required this.broadcastId,
    required this.type,
    this.ballEventId,
    required this.timestamp,
    required this.title,
    this.description = '',
    this.overNumber,
    this.ballNumber,
    this.batsmanName,
    this.bowlerName,
    this.runs,
  });

  String get emoji {
    switch (type) {
      case 'four': return '4️⃣';
      case 'six': return '6️⃣';
      case 'wicket': return '🔴';
      case 'runOut': return '🏃';
      case 'hatTrick': return '🎩';
      case 'century': return '💯';
      case 'fifty': return '5️⃣0️⃣';
      case 'winningShot': return '🏆';
      default: return '🏏';
    }
  }

  String get animationType {
    switch (type) {
      case 'four': return 'boundary';
      case 'six': return 'maximum';
      case 'wicket': return 'wicket';
      case 'runOut': return 'wicket';
      case 'hatTrick': return 'hat_trick';
      case 'century': return 'century';
      case 'fifty': return 'fifty';
      case 'winningShot': return 'winner';
      default: return 'generic';
    }
  }

  factory BroadcastHighlight.fromMap(Map<String, dynamic> data, {String? docId}) {
    return BroadcastHighlight(
      id: docId ?? data['id'] ?? '',
      matchId: data['matchId'] ?? '',
      broadcastId: data['broadcastId'] ?? '',
      type: data['type'] ?? '',
      ballEventId: data['ballEventId'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is DateTime
              ? data['timestamp']
              : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      overNumber: (data['overNumber'] as num?)?.toInt(),
      ballNumber: (data['ballNumber'] as num?)?.toInt(),
      batsmanName: data['batsmanName'],
      bowlerName: data['bowlerName'],
      runs: (data['runs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'broadcastId': broadcastId,
      'type': type,
      'ballEventId': ballEventId,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'description': description,
      'overNumber': overNumber,
      'ballNumber': ballNumber,
      'batsmanName': batsmanName,
      'bowlerName': bowlerName,
      'runs': runs,
    };
  }
}
