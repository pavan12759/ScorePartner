import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';

/// API Service for communicating with Node.js backend
class ApiService {
  // Singleton
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  // Base URL - configurable for different environments
  // Override via --dart-define=API_BASE_URL=http://your.server.ip:5000/api
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );
  // For Android emulator use: 'http://10.0.2.2:5000/api'
  // For iOS simulator use: 'http://localhost:5000/api'
  // For real device use your computer's IP: 'http://192.168.x.x:5000/api'

  List<String> get _candidateBaseUrls {
    final urls = <String>[_baseUrl];
    if (_baseUrl.contains('localhost')) {
      urls.add(_baseUrl.replaceAll('localhost', '192.168.1.42'));
      urls.add(_baseUrl.replaceAll('localhost', '10.0.2.2'));
    }
    return urls;
  }

  String? _authToken;
  
  /// Initialize the service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    debugPrint('🔗 API Service initialized');
  }

  /// Set auth token
  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  /// Get auth token
  String? get authToken => _authToken;

  /// Check if authenticated
  bool get isAuthenticated => _authToken != null;

  /// Get headers for requests
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<Map<String, String>> get _headersAsync async {
    final headers = Map<String, String>.from(_headers);
    if (_authToken == null) {
      try {
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null) {
          headers['Authorization'] = 'Bearer $idToken';
        }
      } catch (_) {}
    }
    return headers;
  }

  // ==================== HTTP METHODS ====================

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ GET $endpoint error: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ POST $endpoint error: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _headersAsync;
    Object? lastError;

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 4));
        return _handleResponse(response);
      } catch (e) {
        lastError = e;
        debugPrint('⚠️ PUT $baseUrl$endpoint error: $e');
      }
    }
    debugPrint('❌ PUT $endpoint error: $lastError');
    throw ApiException('Network error: $lastError');
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl$endpoint'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ DELETE $endpoint error: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      // Clear token on unauthorized
      setAuthToken(null);
      throw ApiException(body['error'] ?? 'Unauthorized', statusCode: 401);
    } else {
      throw ApiException(
        body['error'] ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
  }

  // ==================== AUTH ENDPOINTS ====================

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    final response = await post('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    });
    
    // Save token
    if (response['token'] != null) {
      await setAuthToken(response['token']);
    }
    
    return response;
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await post('/auth/login', {
      'email': email,
      'password': password,
    });
    
    // Save token
    if (response['token'] != null) {
      await setAuthToken(response['token']);
    }
    
    return response;
  }

  /// Get current user profile
  Future<Map<String, dynamic>> getProfile() async {
    return get('/auth/profile');
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return put('/auth/profile', data);
  }

  /// Logout
  Future<void> logout() async {
    await setAuthToken(null);
  }

  // ==================== MATCH ENDPOINTS ====================

  /// Get all matches
  Future<Map<String, dynamic>> getMatches({
    String? status,
    String? ballType,
    int page = 1,
    int limit = 20,
  }) async {
    String endpoint = '/matches?page=$page&limit=$limit';
    if (status != null) endpoint += '&status=$status';
    if (ballType != null) endpoint += '&ballType=$ballType';
    return get(endpoint);
  }

  /// Get live matches
  Future<Map<String, dynamic>> getLiveMatches() async {
    return get('/matches/live');
  }

  /// Get upcoming matches
  Future<Map<String, dynamic>> getUpcomingMatches() async {
    return get('/matches/upcoming');
  }

  /// Get user matches
  Future<Map<String, dynamic>> getUserMatches(String userId) async {
    return get('/matches/user/$userId');
  }

  /// Get match by ID
  Future<Map<String, dynamic>> getMatch(String matchId) async {
    return get('/matches/$matchId');
  }

  /// Create match
  Future<Map<String, dynamic>> createMatch(Map<String, dynamic> matchData) async {
    return post('/matches', matchData);
  }

  /// Update match
  Future<Map<String, dynamic>> updateMatch(String matchId, Map<String, dynamic> data) async {
    return put('/matches/$matchId', data);
  }

  /// Add ball event
  Future<Map<String, dynamic>> addBallEvent(String matchId, Map<String, dynamic> ballEvent) async {
    return post('/matches/$matchId/ball', ballEvent);
  }

  /// Complete match
  Future<Map<String, dynamic>> completeMatch(String matchId, Map<String, dynamic> result) async {
    return put('/matches/$matchId/complete', result);
  }

  /// Delete match
  Future<Map<String, dynamic>> deleteMatch(String matchId) async {
    return delete('/matches/$matchId');
  }

  // ==================== TEAM ENDPOINTS ====================

  /// Get all teams
  Future<Map<String, dynamic>> getTeams({int page = 1, int limit = 20}) async {
    return get('/teams?page=$page&limit=$limit');
  }

  /// Get user teams
  Future<Map<String, dynamic>> getUserTeams(String userId) async {
    return get('/teams/user/$userId');
  }

  /// Get team by ID
  Future<Map<String, dynamic>> getTeam(String teamId) async {
    return get('/teams/$teamId');
  }

  /// Create team
  Future<Map<String, dynamic>> createTeam(Map<String, dynamic> teamData) async {
    return post('/teams', teamData);
  }

  /// Lookup team by SPT ID
  Future<Map<String, dynamic>> lookupTeamBySptId(String sptId) async {
    return get('/teams/sptid/$sptId');
  }

  /// Update team
  Future<Map<String, dynamic>> updateTeam(String teamId, Map<String, dynamic> data) async {
    return put('/teams/$teamId', data);
  }

  /// Add player to team
  Future<Map<String, dynamic>> addPlayerToTeam(String teamId, Map<String, dynamic> player) async {
    return post('/teams/$teamId/players', player);
  }

  /// Remove player from team
  Future<Map<String, dynamic>> removePlayerFromTeam(String teamId, String playerId) async {
    return delete('/teams/$teamId/players/$playerId');
  }

  /// Delete team
  Future<Map<String, dynamic>> deleteTeam(String teamId) async {
    return delete('/teams/$teamId');
  }

  // ==================== TOURNAMENT ENDPOINTS ====================

  /// Get all tournaments
  Future<Map<String, dynamic>> getTournaments({String? status, int page = 1, int limit = 20}) async {
    String endpoint = '/tournaments?page=$page&limit=$limit';
    if (status != null) endpoint += '&status=$status';
    return get(endpoint);
  }

  /// Get upcoming tournaments
  Future<Map<String, dynamic>> getUpcomingTournaments() async {
    return get('/tournaments/upcoming');
  }

  /// Get tournament by ID
  Future<Map<String, dynamic>> getTournament(String tournamentId) async {
    return get('/tournaments/$tournamentId');
  }

  /// Create tournament
  Future<Map<String, dynamic>> createTournament(Map<String, dynamic> data) async {
    return post('/tournaments', data);
  }

  /// Update tournament
  Future<Map<String, dynamic>> updateTournament(String tournamentId, Map<String, dynamic> data) async {
    return put('/tournaments/$tournamentId', data);
  }

  /// Register team for tournament
  Future<Map<String, dynamic>> registerTeamForTournament(String tournamentId, String teamId) async {
    return post('/tournaments/$tournamentId/register', {'teamId': teamId});
  }

  /// Unregister team from tournament
  Future<Map<String, dynamic>> unregisterTeamFromTournament(String tournamentId, String teamId) async {
    return delete('/tournaments/$tournamentId/register/$teamId');
  }

  /// Delete tournament
  Future<Map<String, dynamic>> deleteTournament(String tournamentId) async {
    return delete('/tournaments/$tournamentId');
  }

  // ==================== USER ENDPOINTS ====================

  /// Get user by ID
  Future<Map<String, dynamic>> getUser(String userId) async {
    return get('/users/$userId');
  }

  /// Get user stats
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    return get('/users/$userId/stats');
  }

  /// Search users
  Future<Map<String, dynamic>> searchUsers(String query) async {
    return get('/users/search/$query');
  }

  /// Lookup user by SPP ID
  Future<Map<String, dynamic>> lookupUserBySppId(String sppId) async {
    return get('/users/sppid/$sppId');
  }
}

/// API Exception class
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
