import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ai_models.dart';
import '../../data/services/ai_service.dart';

/// AI Provider — State management for ScorePartner AI chat
class AIProvider extends ChangeNotifier {
  final ScorePartnerAIService _aiService = ScorePartnerAIService.instance;
  final _uuid = const Uuid();

  List<AIMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<AIMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMessages => _messages.isNotEmpty;

  /// Send a message to ScorePartner AI
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isLoading) return;

    final userMessage = AIMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    // Add user message
    _messages.add(userMessage);
    _error = null;
    _isLoading = true;
    notifyListeners();

    // Add loading placeholder for assistant
    final loadingId = _uuid.v4();
    final loadingMessage = AIMessage(
      id: loadingId,
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(loadingMessage);
    notifyListeners();

    try {
      // Build conversation history (excluding loading messages)
      final history = _messages
          .where((m) => !m.isLoading && m.error == null && m.id != loadingId)
          .toList();

      // Remove the last user message from history since it's sent as the message
      if (history.isNotEmpty && history.last.isUser) {
        history.removeLast();
      }

      final response = await _aiService.sendMessage(
        text.trim(),
        conversationHistory: history,
      );

      // Replace loading message with actual response
      final responseMessage = AIMessage(
        id: loadingId,
        role: 'assistant',
        content: response.message,
        timestamp: DateTime.now(),
        entities: response.entities,
        actions: response.actions,
        isLoading: false,
      );

      final loadingIndex = _messages.indexWhere((m) => m.id == loadingId);
      if (loadingIndex >= 0) {
        _messages[loadingIndex] = responseMessage;
      }
    } catch (e) {
      debugPrint('❌ AI error: $e');
      // Replace loading with error
      final errorMessage = AIMessage(
        id: loadingId,
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isLoading: false,
        error: e.toString(),
      );

      final loadingIndex = _messages.indexWhere((m) => m.id == loadingId);
      if (loadingIndex >= 0) {
        _messages[loadingIndex] = errorMessage;
      }
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear conversation and start fresh
  void clearConversation() {
    _messages = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Retry last failed message
  Future<void> retryLast() async {
    if (_messages.isEmpty) return;

    // Find the last user message
    String? lastUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserMessage = _messages[i].content;
        break;
      }
    }

    if (lastUserMessage == null) return;

    // Remove failed messages
    while (_messages.isNotEmpty && _messages.last.isAssistant) {
      _messages.removeLast();
    }
    // Remove the user message too (sendMessage will re-add it)
    if (_messages.isNotEmpty && _messages.last.isUser) {
      _messages.removeLast();
    }

    notifyListeners();
    await sendMessage(lastUserMessage);
  }
}
