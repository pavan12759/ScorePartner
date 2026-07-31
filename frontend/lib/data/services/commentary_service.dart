class CommentaryService {
  bool _isEnabled = false;

  CommentaryService();
  
  void toggle(bool enable) {
    _isEnabled = enable;
  }
  
  bool get isEnabled => _isEnabled;

  Future<void> speakEvent(String eventType, int runs) async {
    // User requested to remove commentary voice when admin is entering score.
    // This maintains the method signatures for scoring_provider but does nothing.
    return;
  }
}
