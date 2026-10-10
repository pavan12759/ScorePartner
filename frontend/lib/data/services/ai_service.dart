import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ai_models.dart';

/// ScorePartner AI Service — Communicates with the backend AI API.
/// All AI requests go through Node.js backend, never directly to AI providers.
class ScorePartnerAIService {
  // Singleton
  static ScorePartnerAIService? _instance;
  static ScorePartnerAIService get instance =>
      _instance ??= ScorePartnerAIService._();
  ScorePartnerAIService._();

  // Base URL — same as ApiService
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  static String? _workingBaseUrl;

  List<String> get _candidateBaseUrls {
    // If we already found a working URL, try it first
    if (_workingBaseUrl != null) {
      return [_workingBaseUrl!];
    }

    // On web (Chrome), only localhost works (same machine, no CORS issues)
    if (kIsWeb) {
      return ['http://localhost:5000/api'];
    }

    // On mobile devices, try multiple network addresses
    final urls = <String>[_baseUrl];
    if (_baseUrl.contains('localhost')) {
      urls.add(_baseUrl.replaceAll('localhost', '10.0.2.2'));  // Android emulator
    }
    return urls;
  }

  /// Get Firebase auth token for API calls
  Future<String?> _getAuthToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('⚠️ Failed to get auth token: $e');
      return null;
    }
  }

  /// Send a chat message to ScorePartner AI
  Future<AIResponse> sendMessage(
    String message, {
    List<AIMessage>? conversationHistory,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw AIServiceException('Please sign in to use ScorePartner AI');
    }

    // Build conversation history for context
    final history = conversationHistory
            ?.where((m) => !m.isLoading && m.error == null)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList() ??
        [];

    final body = jsonEncode({
      'message': message,
      'conversationHistory': history,
    });

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Try candidate URLs
    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/ai/chat'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          _workingBaseUrl = baseUrl;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return AIResponse.fromJson(data);
        } else if (response.statusCode == 401) {
          throw AIServiceException('Please sign in to use ScorePartner AI');
        } else if (response.statusCode == 429) {
          throw AIServiceException(
              'You\'ve sent too many messages. Please wait a moment.');
        } else if (response.statusCode == 503) {
          throw AIServiceException(
              'ScorePartner AI is not available right now. Please try again later.');
        } else {
          final errorData = jsonDecode(response.body);
          throw AIServiceException(
              errorData['error'] ?? 'Something went wrong');
        }
      } catch (e) {
        if (e is AIServiceException) rethrow;
        _workingBaseUrl = null;
        debugPrint('⚠️ AI request to $baseUrl failed: $e');
      }
    }

    throw AIServiceException(
        'Unable to connect to ScorePartner. Check your internet connection.');
  }

  /// Fetch current cricket news
  Future<List<NewsArticle>> getCricketNews({String? query, int limit = 5}) async {
    final token = await _getAuthToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final queryParams = <String, String>{};
    if (query != null) queryParams['q'] = query;
    queryParams['limit'] = limit.toString();

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/ai/news')
            .replace(queryParameters: queryParams);
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          _workingBaseUrl = baseUrl;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final articles = (data['articles'] as List<dynamic>?)
                  ?.map(
                      (a) => NewsArticle.fromJson(a as Map<String, dynamic>))
                  .toList() ??
              [];
          return articles;
        }
      } catch (e) {
        debugPrint('⚠️ News request to $baseUrl failed: $e');
      }
    }

    return [];
  }
}

/// Exception class for AI service errors
class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);

  @override
  String toString() => message;
}
