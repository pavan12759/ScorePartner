import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/broadcast_model.dart';
import '../../data/models/broadcast_highlight_model.dart';
import '../../data/models/match_model.dart';
import '../../data/services/broadcast_service.dart';
import '../../data/services/socket_service.dart';
import '../../core/broadcast/overlay_theme_data.dart';

/// Provider for managing broadcast state — theme, overlay config,
/// animations, graphics, crew, and viewer tracking.
class BroadcastProvider extends ChangeNotifier {
  final BroadcastService _broadcastService = BroadcastService.instance;
  final SocketService _socketService = SocketService();

  // State
  BroadcastSession? _currentBroadcast;
  OverlayThemeData _selectedTheme = OverlayThemes.scorePartnerPremium;
  BroadcastOverlayConfig _overlayConfig = const BroadcastOverlayConfig();
  bool _isLive = false;
  int _viewerCount = 0;
  bool _isLoading = false;
  String? _error;

  // Animation queue
  final List<String> _pendingAnimations = [];
  String? _currentAnimation;
  String? _currentGraphic;
  bool _showingGraphic = false;

  // Commentary
  String? _latestCommentary;
  String? _latestCommentaryBall;

  // Subscriptions
  StreamSubscription? _broadcastSub;
  StreamSubscription? _viewerCountSub;
  bool _isDisposed = false;

  // Getters
  BroadcastSession? get currentBroadcast => _currentBroadcast;
  OverlayThemeData get selectedTheme => _selectedTheme;
  BroadcastOverlayConfig get overlayConfig => _overlayConfig;
  bool get isLive => _isLive;
  int get viewerCount => _viewerCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentAnimation => _currentAnimation;
  String? get currentGraphic => _currentGraphic;
  bool get showingGraphic => _showingGraphic;
  String? get latestCommentary => _latestCommentary;
  String? get latestCommentaryBall => _latestCommentaryBall;

  // ── Broadcast Lifecycle ─────────────────────────────────

  /// Start a new broadcast
  Future<bool> startBroadcast({
    required String matchId,
    String? themeId,
    String? title,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (themeId != null) {
        _selectedTheme = OverlayThemes.getById(themeId);
      }

      final broadcast = await _broadcastService.startBroadcast(
        matchId: matchId,
        overlayThemeId: _selectedTheme.id,
        overlayConfig: _overlayConfig,
        title: title,
      );

      if (broadcast == null) {
        _error = 'Failed to start broadcast';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentBroadcast = broadcast;
      _isLive = true;
      _isLoading = false;

      // Start listening
      _subscribeToBroadcast(broadcast.id);
      _subscribeToViewerCount(broadcast.id);

      // Emit socket event
      _socketService.connect();

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Join an existing broadcast as viewer
  Future<void> joinBroadcast(String broadcastId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final broadcast = await _broadcastService.getBroadcastById(broadcastId);
      if (broadcast == null) {
        _error = 'Broadcast not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentBroadcast = broadcast;
      _selectedTheme = OverlayThemes.getById(broadcast.overlayThemeId);
      _overlayConfig = broadcast.overlayConfig;
      _isLive = broadcast.isLive;

      // Track viewer
      await _broadcastService.joinAsViewer(broadcastId);

      // Start listening
      _subscribeToBroadcast(broadcastId);
      _subscribeToViewerCount(broadcastId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// End the current broadcast
  Future<void> endBroadcast() async {
    if (_currentBroadcast == null) return;

    try {
      await _broadcastService.endBroadcast(_currentBroadcast!.id);
      _isLive = false;
      _currentBroadcast = _currentBroadcast!.copyWith(status: 'ended');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Leave broadcast as viewer
  Future<void> leaveBroadcast() async {
    if (_currentBroadcast == null) return;

    try {
      await _broadcastService.leaveAsViewer(_currentBroadcast!.id);
      _broadcastSub?.cancel();
      _viewerCountSub?.cancel();
    } catch (e) {
      debugPrint('Error leaving broadcast: $e');
    }
  }

  // ── Theme & Overlay ─────────────────────────────────────

  /// Switch overlay theme
  void switchTheme(String themeId) {
    _selectedTheme = OverlayThemes.getById(themeId);

    if (_currentBroadcast != null) {
      _broadcastService.updateOverlayTheme(_currentBroadcast!.id, themeId);
    }

    notifyListeners();
  }

  /// Alias for switchTheme, takes OverlayThemeData
  void setOverlayTheme(OverlayThemeData theme) {
    switchTheme(theme.id);
  }

  /// Update overlay config
  void updateOverlayConfig(BroadcastOverlayConfig config) {
    _overlayConfig = config;

    if (_currentBroadcast != null) {
      _broadcastService.updateOverlayConfig(_currentBroadcast!.id, config);
    }

    notifyListeners();
  }

  /// Update a single overlay config property
  void updateConfigProperty({
    String? primaryColor,
    String? secondaryColor,
    double? transparency,
    String? fontFamily,
    double? cornerRadius,
    double? glassBlur,
    double? animationSpeed,
    double? borderWidth,
    String? team1Color,
    String? team2Color,
  }) {
    _overlayConfig = _overlayConfig.copyWith(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      transparency: transparency,
      fontFamily: fontFamily,
      cornerRadius: cornerRadius,
      glassBlur: glassBlur,
      animationSpeed: animationSpeed,
      borderWidth: borderWidth,
      team1Color: team1Color,
      team2Color: team2Color,
    );
    notifyListeners();
  }

  // ── Animations ──────────────────────────────────────────

  /// Trigger a broadcast animation (four, six, wicket, etc.)
  void triggerAnimation(String animationType) {
    _currentAnimation = animationType;
    notifyListeners();

    // Auto-clear after animation duration
    Future.delayed(_selectedTheme.animationDuration + const Duration(milliseconds: 500), () {
      if (_currentAnimation == animationType) {
        _currentAnimation = null;
        notifyListeners();
      }
    });
  }

  /// Clear current animation
  void clearAnimation() {
    _currentAnimation = null;
    notifyListeners();
  }

  // ── Graphics ────────────────────────────────────────────

  /// Show a broadcast graphic (player card, worm graph, etc.)
  void showGraphic(String graphicType) {
    _currentGraphic = graphicType;
    _showingGraphic = true;
    notifyListeners();
  }

  /// Hide the current graphic
  void hideGraphic() {
    _showingGraphic = false;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      _currentGraphic = null;
      notifyListeners();
    });
  }

  // ── Commentary ──────────────────────────────────────────

  /// Update live commentary
  void updateCommentary(String ball, String commentary) {
    _latestCommentaryBall = ball;
    _latestCommentary = commentary;
    notifyListeners();
  }

  // ── Auto-detect highlights from ball events ─────────────

  /// Process a ball event and auto-detect highlights
  void processBallEvent(BallEvent ball, MatchModel match) {
    // Auto-trigger animations
    if (ball.runs == 4 && ball.extraType == null) {
      triggerAnimation('boundary');
    } else if (ball.runs == 6) {
      triggerAnimation('maximum');
    } else if (ball.wicket != null) {
      triggerAnimation('wicket');
    }

    // Auto-detect milestones
    if (_currentBroadcast != null) {
      _checkMilestones(ball, match);
    }
  }

  void _checkMilestones(BallEvent ball, MatchModel match) {
    final battingScore = match.currentBattingTeam == 'team1' ? match.team1Score : match.team2Score;

    // Check for century/fifty
    for (final batter in battingScore.batters) {
      if (batter.playerId == ball.batsmanId) {
        if (batter.runs >= 100 && (batter.runs - ball.runs) < 100) {
          triggerAnimation('century');
          _addAutoHighlight('century', ball, 'CENTURY! ${batter.playerName} reaches 100!');
        } else if (batter.runs >= 50 && (batter.runs - ball.runs) < 50) {
          triggerAnimation('fifty');
          _addAutoHighlight('fifty', ball, 'FIFTY! ${batter.playerName} reaches 50!');
        }
      }
    }

    // Check for hat trick
    if (ball.wicket != null) {
      final bowlerBalls = match.ballByBall
          .where((b) => b.bowlerId == ball.bowlerId)
          .toList();
      if (bowlerBalls.length >= 3) {
        final lastThree = bowlerBalls.reversed.take(3).toList();
        if (lastThree.every((b) => b.wicket != null)) {
          triggerAnimation('hat_trick');
          _addAutoHighlight('hatTrick', ball, 'HAT TRICK! 🎩');
        }
      }
    }
  }

  void _addAutoHighlight(String type, BallEvent ball, String title) {
    if (_currentBroadcast == null) return;

    final highlight = BroadcastHighlight(
      id: '',
      matchId: _currentBroadcast!.matchId,
      broadcastId: _currentBroadcast!.id,
      type: type,
      timestamp: DateTime.now(),
      title: title,
      batsmanName: ball.batsmanName,
      bowlerName: ball.bowlerName,
      runs: ball.runs,
    );

    _broadcastService.addHighlight(_currentBroadcast!.id, highlight);
  }

  // ── Crew ────────────────────────────────────────────────

  /// Join crew with code
  Future<bool> joinCrew(String code, String role) async {
    final broadcast = await _broadcastService.joinBroadcastCrew(code, role);
    if (broadcast != null) {
      _currentBroadcast = broadcast;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Subscriptions ───────────────────────────────────────

  void _subscribeToBroadcast(String broadcastId) {
    _broadcastSub?.cancel();
    _broadcastSub = _broadcastService.streamBroadcast(broadcastId).listen((broadcast) {
      if (broadcast != null) {
        _currentBroadcast = broadcast;
        _isLive = broadcast.isLive;

        // Sync theme if changed by another crew member
        if (broadcast.overlayThemeId != _selectedTheme.id) {
          _selectedTheme = OverlayThemes.getById(broadcast.overlayThemeId);
        }

        notifyListeners();
      }
    });
  }

  void _subscribeToViewerCount(String broadcastId) {
    _viewerCountSub?.cancel();
    _viewerCountSub = _broadcastService.streamViewerCount(broadcastId).listen((count) {
      _viewerCount = count;
      notifyListeners();
    });
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _broadcastSub?.cancel();
    _viewerCountSub?.cancel();
    super.dispose();
  }
}
