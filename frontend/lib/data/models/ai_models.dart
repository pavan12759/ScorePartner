/// ScorePartner AI Models
/// Data models for AI chat messages, responses, entities, actions, and news.

class AIMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<AIEntity> entities;
  final List<AIAction> actions;
  final bool isLoading;
  final String? error;

  const AIMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.entities = const [],
    this.actions = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasEntities => entities.isNotEmpty;
  bool get hasActions => actions.isNotEmpty;

  AIMessage copyWith({
    String? content,
    List<AIEntity>? entities,
    List<AIAction>? actions,
    bool? isLoading,
    String? error,
  }) {
    return AIMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      entities: entities ?? this.entities,
      actions: actions ?? this.actions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AIEntity {
  final String type; // 'match', 'player', 'team', 'tournament', 'news'
  final String id;
  final String title;
  final Map<String, dynamic>? data;

  const AIEntity({
    required this.type,
    required this.id,
    required this.title,
    this.data,
  });

  factory AIEntity.fromJson(Map<String, dynamic> json) {
    return AIEntity(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      data: json['data'],
    );
  }

  bool get isMatch => type == 'match';
  bool get isPlayer => type == 'player';
  bool get isTeam => type == 'team';
  bool get isTournament => type == 'tournament';
  bool get isNews => type == 'news';
}

class AIAction {
  final String type; // 'open_match', 'open_player', 'open_team', 'open_tournament', 'open_news'
  final String entityId;
  final String label;

  const AIAction({
    required this.type,
    required this.entityId,
    required this.label,
  });

  factory AIAction.fromJson(Map<String, dynamic> json) {
    return AIAction(
      type: json['type'] ?? '',
      entityId: json['entityId'] ?? '',
      label: json['label'] ?? 'Open →',
    );
  }
}

class AIResponse {
  final String message;
  final List<AIEntity> entities;
  final List<AIAction> actions;
  final String? raw;

  const AIResponse({
    required this.message,
    this.entities = const [],
    this.actions = const [],
    this.raw,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      message: json['message'] ?? '',
      entities: (json['entities'] as List<dynamic>?)
              ?.map((e) => AIEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) => AIAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      raw: json['raw'],
    );
  }
}

class NewsArticle {
  final String title;
  final String summary;
  final String source;
  final String url;
  final String publishedAt;
  final String? imageUrl;

  const NewsArticle({
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.publishedAt,
    this.imageUrl,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      summary: json['summary'] ?? json['description'] ?? '',
      source: json['source'] ?? 'Unknown',
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }
}
