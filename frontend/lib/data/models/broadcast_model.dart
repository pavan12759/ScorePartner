/// Broadcast data models for ScorePartner Live+
/// Manages live broadcast sessions, overlay configuration, crew, and themes.

class BroadcastSession {
  final String id;
  final String matchId;
  final String broadcasterId;
  final String status; // 'pre-live', 'live', 'ended'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String overlayThemeId;
  final BroadcastOverlayConfig overlayConfig;
  final int viewerCount;
  final int peakViewers;
  final int totalViews;
  final bool chatEnabled;
  final int slowModeSeconds;
  final String crewCode;
  final Map<String, String> crew; // userId -> role
  final String? title;
  final String? description;

  const BroadcastSession({
    required this.id,
    required this.matchId,
    required this.broadcasterId,
    this.status = 'pre-live',
    this.startedAt,
    this.endedAt,
    this.overlayThemeId = 'scorepartner_premium',
    this.overlayConfig = const BroadcastOverlayConfig(),
    this.viewerCount = 0,
    this.peakViewers = 0,
    this.totalViews = 0,
    this.chatEnabled = true,
    this.slowModeSeconds = 0,
    this.crewCode = '',
    this.crew = const {},
    this.title,
    this.description,
  });

  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get isPreLive => status == 'pre-live';

  factory BroadcastSession.fromMap(Map<String, dynamic> data, {String? docId}) {
    return BroadcastSession(
      id: docId ?? data['id'] ?? '',
      matchId: data['matchId'] ?? '',
      broadcasterId: data['broadcasterId'] ?? '',
      status: data['status'] ?? 'pre-live',
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] is DateTime
              ? data['startedAt']
              : DateTime.tryParse(data['startedAt'].toString()))
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] is DateTime
              ? data['endedAt']
              : DateTime.tryParse(data['endedAt'].toString()))
          : null,
      overlayThemeId: data['overlayThemeId'] ?? 'scorepartner_premium',
      overlayConfig: data['overlayConfig'] != null
          ? BroadcastOverlayConfig.fromMap(data['overlayConfig'])
          : const BroadcastOverlayConfig(),
      viewerCount: (data['viewerCount'] as num?)?.toInt() ?? 0,
      peakViewers: (data['peakViewers'] as num?)?.toInt() ?? 0,
      totalViews: (data['totalViews'] as num?)?.toInt() ?? 0,
      chatEnabled: data['chatEnabled'] ?? true,
      slowModeSeconds: (data['slowModeSeconds'] as num?)?.toInt() ?? 0,
      crewCode: data['crewCode'] ?? '',
      crew: (data['crew'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      title: data['title'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'broadcasterId': broadcasterId,
      'status': status,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'overlayThemeId': overlayThemeId,
      'overlayConfig': overlayConfig.toMap(),
      'viewerCount': viewerCount,
      'peakViewers': peakViewers,
      'totalViews': totalViews,
      'chatEnabled': chatEnabled,
      'slowModeSeconds': slowModeSeconds,
      'crewCode': crewCode,
      'crew': crew,
      'title': title,
      'description': description,
    };
  }

  BroadcastSession copyWith({
    String? id,
    String? matchId,
    String? broadcasterId,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? overlayThemeId,
    BroadcastOverlayConfig? overlayConfig,
    int? viewerCount,
    int? peakViewers,
    int? totalViews,
    bool? chatEnabled,
    int? slowModeSeconds,
    String? crewCode,
    Map<String, String>? crew,
    String? title,
    String? description,
  }) {
    return BroadcastSession(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      broadcasterId: broadcasterId ?? this.broadcasterId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      overlayThemeId: overlayThemeId ?? this.overlayThemeId,
      overlayConfig: overlayConfig ?? this.overlayConfig,
      viewerCount: viewerCount ?? this.viewerCount,
      peakViewers: peakViewers ?? this.peakViewers,
      totalViews: totalViews ?? this.totalViews,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      crewCode: crewCode ?? this.crewCode,
      crew: crew ?? this.crew,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }
}

/// Overlay configuration — fully customizable per broadcast
class BroadcastOverlayConfig {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String backgroundColor;
  final String textColor;
  final double transparency;
  final String fontFamily;
  final double cornerRadius;
  final String gradientType; // 'none', 'linear', 'radial'
  final String gradientStartColor;
  final String gradientEndColor;
  final double shadowBlur;
  final double shadowOpacity;
  final double animationSpeed; // 0.5 = slow, 1.0 = normal, 2.0 = fast
  final double borderWidth;
  final String borderColor;
  final double glassBlur;
  final double glassSaturation;
  final String team1Color;
  final String team2Color;
  final List<OverlayWidgetPosition> widgetPositions;
  final String logoPosition; // 'left', 'right', 'center'
  final String sponsorPosition; // 'top', 'bottom', 'corner'
  final bool showSafeArea;
  final bool showScorecard;
  final bool showBatsmen;
  final bool showBowler;
  final bool showRunRate;
  final bool showProjectedScore;
  final bool showWinProbability;
  final bool showSponsor;
  final bool showTournamentLogo;
  final bool showChat;
  final bool showReplays;

  const BroadcastOverlayConfig({
    this.primaryColor = '#FF8D48',
    this.secondaryColor = '#FFDBCA',
    this.accentColor = '#FFFFFF',
    this.backgroundColor = '#1A1A2E',
    this.textColor = '#FFFFFF',
    this.transparency = 0.85,
    this.fontFamily = 'Inter',
    this.cornerRadius = 12.0,
    this.gradientType = 'linear',
    this.gradientStartColor = '#FF8D48',
    this.gradientEndColor = '#FF6B35',
    this.shadowBlur = 8.0,
    this.shadowOpacity = 0.3,
    this.animationSpeed = 1.0,
    this.borderWidth = 0.0,
    this.borderColor = '#FFFFFF',
    this.glassBlur = 20.0,
    this.glassSaturation = 1.2,
    this.team1Color = '#1E88E5',
    this.team2Color = '#E53935',
    this.widgetPositions = const [],
    this.logoPosition = 'left',
    this.sponsorPosition = 'bottom',
    this.showSafeArea = true,
    this.showScorecard = true,
    this.showBatsmen = true,
    this.showBowler = true,
    this.showRunRate = true,
    this.showProjectedScore = false,
    this.showWinProbability = false,
    this.showSponsor = false,
    this.showTournamentLogo = false,
    this.showChat = true,
    this.showReplays = true,
  });

  factory BroadcastOverlayConfig.fromMap(Map<String, dynamic> data) {
    return BroadcastOverlayConfig(
      primaryColor: data['primaryColor'] ?? '#FF8D48',
      secondaryColor: data['secondaryColor'] ?? '#FFDBCA',
      accentColor: data['accentColor'] ?? '#FFFFFF',
      backgroundColor: data['backgroundColor'] ?? '#1A1A2E',
      textColor: data['textColor'] ?? '#FFFFFF',
      transparency: (data['transparency'] as num?)?.toDouble() ?? 0.85,
      fontFamily: data['fontFamily'] ?? 'Inter',
      cornerRadius: (data['cornerRadius'] as num?)?.toDouble() ?? 12.0,
      gradientType: data['gradientType'] ?? 'linear',
      gradientStartColor: data['gradientStartColor'] ?? '#FF8D48',
      gradientEndColor: data['gradientEndColor'] ?? '#FF6B35',
      shadowBlur: (data['shadowBlur'] as num?)?.toDouble() ?? 8.0,
      shadowOpacity: (data['shadowOpacity'] as num?)?.toDouble() ?? 0.3,
      animationSpeed: (data['animationSpeed'] as num?)?.toDouble() ?? 1.0,
      borderWidth: (data['borderWidth'] as num?)?.toDouble() ?? 0.0,
      borderColor: data['borderColor'] ?? '#FFFFFF',
      glassBlur: (data['glassBlur'] as num?)?.toDouble() ?? 20.0,
      glassSaturation: (data['glassSaturation'] as num?)?.toDouble() ?? 1.2,
      team1Color: data['team1Color'] ?? '#1E88E5',
      team2Color: data['team2Color'] ?? '#E53935',
      widgetPositions: (data['widgetPositions'] as List<dynamic>?)
              ?.map((e) => OverlayWidgetPosition.fromMap(e))
              .toList() ??
          [],
      logoPosition: data['logoPosition'] ?? 'left',
      sponsorPosition: data['sponsorPosition'] ?? 'bottom',
      showSafeArea: data['showSafeArea'] ?? true,
      showScorecard: data['showScorecard'] ?? true,
      showBatsmen: data['showBatsmen'] ?? true,
      showBowler: data['showBowler'] ?? true,
      showRunRate: data['showRunRate'] ?? true,
      showProjectedScore: data['showProjectedScore'] ?? false,
      showWinProbability: data['showWinProbability'] ?? false,
      showSponsor: data['showSponsor'] ?? false,
      showTournamentLogo: data['showTournamentLogo'] ?? false,
      showChat: data['showChat'] ?? true,
      showReplays: data['showReplays'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'transparency': transparency,
      'fontFamily': fontFamily,
      'cornerRadius': cornerRadius,
      'gradientType': gradientType,
      'gradientStartColor': gradientStartColor,
      'gradientEndColor': gradientEndColor,
      'shadowBlur': shadowBlur,
      'shadowOpacity': shadowOpacity,
      'animationSpeed': animationSpeed,
      'borderWidth': borderWidth,
      'borderColor': borderColor,
      'glassBlur': glassBlur,
      'glassSaturation': glassSaturation,
      'team1Color': team1Color,
      'team2Color': team2Color,
      'widgetPositions': widgetPositions.map((e) => e.toMap()).toList(),
      'logoPosition': logoPosition,
      'sponsorPosition': sponsorPosition,
      'showSafeArea': showSafeArea,
      'showScorecard': showScorecard,
      'showBatsmen': showBatsmen,
      'showBowler': showBowler,
      'showRunRate': showRunRate,
      'showProjectedScore': showProjectedScore,
      'showWinProbability': showWinProbability,
      'showSponsor': showSponsor,
      'showTournamentLogo': showTournamentLogo,
      'showChat': showChat,
      'showReplays': showReplays,
    };
  }

  BroadcastOverlayConfig copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? backgroundColor,
    String? textColor,
    double? transparency,
    String? fontFamily,
    double? cornerRadius,
    String? gradientType,
    String? gradientStartColor,
    String? gradientEndColor,
    double? shadowBlur,
    double? shadowOpacity,
    double? animationSpeed,
    double? borderWidth,
    String? borderColor,
    double? glassBlur,
    double? glassSaturation,
    String? team1Color,
    String? team2Color,
    List<OverlayWidgetPosition>? widgetPositions,
    String? logoPosition,
    String? sponsorPosition,
    bool? showSafeArea,
    bool? showScorecard,
    bool? showBatsmen,
    bool? showBowler,
    bool? showRunRate,
    bool? showProjectedScore,
    bool? showWinProbability,
    bool? showSponsor,
    bool? showTournamentLogo,
    bool? showChat,
    bool? showReplays,
  }) {
    return BroadcastOverlayConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      transparency: transparency ?? this.transparency,
      fontFamily: fontFamily ?? this.fontFamily,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      gradientType: gradientType ?? this.gradientType,
      gradientStartColor: gradientStartColor ?? this.gradientStartColor,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      glassBlur: glassBlur ?? this.glassBlur,
      glassSaturation: glassSaturation ?? this.glassSaturation,
      team1Color: team1Color ?? this.team1Color,
      team2Color: team2Color ?? this.team2Color,
      widgetPositions: widgetPositions ?? this.widgetPositions,
      logoPosition: logoPosition ?? this.logoPosition,
      sponsorPosition: sponsorPosition ?? this.sponsorPosition,
      showSafeArea: showSafeArea ?? this.showSafeArea,
      showScorecard: showScorecard ?? this.showScorecard,
      showBatsmen: showBatsmen ?? this.showBatsmen,
      showBowler: showBowler ?? this.showBowler,
      showRunRate: showRunRate ?? this.showRunRate,
      showProjectedScore: showProjectedScore ?? this.showProjectedScore,
      showWinProbability: showWinProbability ?? this.showWinProbability,
      showSponsor: showSponsor ?? this.showSponsor,
      showTournamentLogo: showTournamentLogo ?? this.showTournamentLogo,
      showChat: showChat ?? this.showChat,
      showReplays: showReplays ?? this.showReplays,
    );
  }
}

/// Position data for a draggable overlay widget
class OverlayWidgetPosition {
  final String widgetType; // 'score', 'runRate', 'target', 'batsmen', 'bowler', etc.
  final double x; // 0.0 to 1.0 (percentage of screen width)
  final double y; // 0.0 to 1.0 (percentage of screen height)
  final double width; // 0.0 to 1.0
  final double height; // 0.0 to 1.0
  final bool isVisible;
  final Map<String, dynamic> customStyle;

  const OverlayWidgetPosition({
    required this.widgetType,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 1.0,
    this.height = 0.1,
    this.isVisible = true,
    this.customStyle = const {},
  });

  factory OverlayWidgetPosition.fromMap(Map<String, dynamic> data) {
    return OverlayWidgetPosition(
      widgetType: data['widgetType'] ?? '',
      x: (data['x'] as num?)?.toDouble() ?? 0.0,
      y: (data['y'] as num?)?.toDouble() ?? 0.0,
      width: (data['width'] as num?)?.toDouble() ?? 1.0,
      height: (data['height'] as num?)?.toDouble() ?? 0.1,
      isVisible: data['isVisible'] ?? true,
      customStyle: (data['customStyle'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'widgetType': widgetType,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'isVisible': isVisible,
      'customStyle': customStyle,
    };
  }

  OverlayWidgetPosition copyWith({
    String? widgetType,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? isVisible,
    Map<String, dynamic>? customStyle,
  }) {
    return OverlayWidgetPosition(
      widgetType: widgetType ?? this.widgetType,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
      customStyle: customStyle ?? this.customStyle,
    );
  }
}

/// Broadcast crew member
class BroadcastCrewMember {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String role; // 'owner', 'camera', 'scoring', 'commentary', 'media', 'moderator'
  final DateTime joinedAt;
  final bool isOnline;

  const BroadcastCrewMember({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
  });

  String get roleDisplay {
    switch (role) {
      case 'owner': return 'Owner';
      case 'camera': return 'Camera Admin';
      case 'scoring': return 'Scoring Admin';
      case 'commentary': return 'Commentary Admin';
      case 'media': return 'Media Admin';
      case 'moderator': return 'Moderator';
      default: return role;
    }
  }

  factory BroadcastCrewMember.fromMap(Map<String, dynamic> data) {
    return BroadcastCrewMember(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      role: data['role'] ?? 'moderator',
      joinedAt: data['joinedAt'] != null
          ? (data['joinedAt'] is DateTime
              ? data['joinedAt']
              : DateTime.tryParse(data['joinedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'isOnline': isOnline,
    };
  }
}
