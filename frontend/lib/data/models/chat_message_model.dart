/// Chat and reaction models for ScorePartner Live+ broadcasts

class LiveChatMessage {
  final String id;
  final String broadcastId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String message;
  final String type; // 'text', 'emoji', 'gif', 'image', 'pinned', 'system'
  final DateTime timestamp;
  final bool isDeleted;
  final bool isMuted;
  final bool isPinned;
  final String? imageUrl;
  final String? gifUrl;
  final bool isModerator;

  const LiveChatMessage({
    required this.id,
    required this.broadcastId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.message,
    this.type = 'text',
    required this.timestamp,
    this.isDeleted = false,
    this.isMuted = false,
    this.isPinned = false,
    this.imageUrl,
    this.gifUrl,
    this.isModerator = false,
  });

  factory LiveChatMessage.fromMap(Map<String, dynamic> data, {String? docId}) {
    return LiveChatMessage(
      id: docId ?? data['id'] ?? '',
      broadcastId: data['broadcastId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      message: data['message'] ?? '',
      type: data['type'] ?? 'text',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is DateTime
              ? data['timestamp']
              : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
      isMuted: data['isMuted'] ?? false,
      isPinned: data['isPinned'] ?? false,
      imageUrl: data['imageUrl'],
      gifUrl: data['gifUrl'],
      isModerator: data['isModerator'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'broadcastId': broadcastId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isDeleted': isDeleted,
      'isMuted': isMuted,
      'isPinned': isPinned,
      'imageUrl': imageUrl,
      'gifUrl': gifUrl,
      'isModerator': isModerator,
    };
  }

  LiveChatMessage copyWith({
    String? id,
    String? broadcastId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? isDeleted,
    bool? isMuted,
    bool? isPinned,
    String? imageUrl,
    String? gifUrl,
    bool? isModerator,
  }) {
    return LiveChatMessage(
      id: id ?? this.id,
      broadcastId: broadcastId ?? this.broadcastId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      imageUrl: imageUrl ?? this.imageUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      isModerator: isModerator ?? this.isModerator,
    );
  }
}

/// Emoji reaction for live broadcast
class EmojiReaction {
  final String id;
  final String broadcastId;
  final String type; // '❤️', '🔥', '👏', '😮', '🏏', '🎉'
  final String userId;
  final DateTime timestamp;

  const EmojiReaction({
    required this.id,
    required this.broadcastId,
    required this.type,
    required this.userId,
    required this.timestamp,
  });

  factory EmojiReaction.fromMap(Map<String, dynamic> data, {String? docId}) {
    return EmojiReaction(
      id: docId ?? data['id'] ?? '',
      broadcastId: data['broadcastId'] ?? '',
      type: data['type'] ?? '❤️',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is DateTime
              ? data['timestamp']
              : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'broadcastId': broadcastId,
      'type': type,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Aggregated reaction counts for display
class ReactionCounts {
  final int hearts;
  final int fires;
  final int claps;
  final int wows;
  final int cricket;
  final int celebrations;

  const ReactionCounts({
    this.hearts = 0,
    this.fires = 0,
    this.claps = 0,
    this.wows = 0,
    this.cricket = 0,
    this.celebrations = 0,
  });

  int get total => hearts + fires + claps + wows + cricket + celebrations;

  factory ReactionCounts.fromMap(Map<String, dynamic> data) {
    return ReactionCounts(
      hearts: (data['hearts'] as num?)?.toInt() ?? 0,
      fires: (data['fires'] as num?)?.toInt() ?? 0,
      claps: (data['claps'] as num?)?.toInt() ?? 0,
      wows: (data['wows'] as num?)?.toInt() ?? 0,
      cricket: (data['cricket'] as num?)?.toInt() ?? 0,
      celebrations: (data['celebrations'] as num?)?.toInt() ?? 0,
    );
  }
}
