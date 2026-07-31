import 'dart:async';
import 'package:flutter/material.dart';
import '../models/broadcast_highlight_model.dart';
import '../models/match_model.dart';

/// ReplaySystemService — Buffers recent match highlights & ball events for Instant Replays.
class ReplaySystemService extends ChangeNotifier {
  static ReplaySystemService? _instance;
  static ReplaySystemService get instance => _instance ??= ReplaySystemService._();

  ReplaySystemService._();

  final List<BroadcastHighlight> _replayBuffer = [];
  bool _isReplaying = false;
  BroadcastHighlight? _activeReplay;
  Timer? _replayTimer;

  List<BroadcastHighlight> get replayBuffer => List.unmodifiable(_replayBuffer);
  bool get isReplaying => _isReplaying;
  BroadcastHighlight? get activeReplay => _activeReplay;

  /// Add ball event highlight to replay buffer
  void addHighlight(BroadcastHighlight highlight) {
    _replayBuffer.insert(0, highlight);
    if (_replayBuffer.length > 20) {
      _replayBuffer.removeLast();
    }
    notifyListeners();
  }

  /// Trigger instant replay for a specific highlight
  void triggerReplay(BroadcastHighlight highlight, {int durationSeconds = 4}) {
    _activeReplay = highlight;
    _isReplaying = true;
    notifyListeners();

    _replayTimer?.cancel();
    _replayTimer = Timer(Duration(seconds: durationSeconds), () {
      _isReplaying = false;
      _activeReplay = null;
      notifyListeners();
    });
  }

  /// Stop current replay
  void stopReplay() {
    _replayTimer?.cancel();
    _isReplaying = false;
    _activeReplay = null;
    notifyListeners();
  }
}
