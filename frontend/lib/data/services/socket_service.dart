import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/match_model.dart';

/// Service for real-time match updates using Socket.io
class SocketService {
  static final SocketService _instance = SocketService._internal();
  
  factory SocketService() => _instance;
  
  SocketService._internal();
  
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentMatchId;
  
  // Stream controllers for different events
  final _matchUpdateController = StreamController<MatchModel>.broadcast();
  final _ballEventController = StreamController<BallEvent>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  
  // Getters for streams
  Stream<MatchModel> get matchUpdates => _matchUpdateController.stream;
  Stream<BallEvent> get ballEvents => _ballEventController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool get isConnected => _isConnected;
  
  /// Initialize socket connection to backend
  void connect({String? serverUrl}) {
    if (_socket != null && _isConnected) {
      return; // Already connected
    }
    
    final effectiveUrl = serverUrl ??
        const String.fromEnvironment(
          'SOCKET_SERVER_URL',
          defaultValue: 'http://127.0.0.1:5000',
        );

    // Disconnect existing socket if any
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }
    
    print('🔌 Attempting to connect to socket at: $effectiveUrl');
    
    _socket = IO.io(effectiveUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],  // Add polling fallback for web
      'autoConnect': false,  // We'll connect manually
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'forceNew': true,
    });
    
    _setupEventListeners();
    _socket!.connect();
  }
  
  void _setupEventListeners() {
    _socket!.onConnect((_) {
      print('🔌 Socket connected');
      _isConnected = true;
      _connectionStatusController.add(true);
      
      // Rejoin match room if was watching a match
      if (_currentMatchId != null) {
        joinMatch(_currentMatchId!);
      }
    });
    
    _socket!.onDisconnect((_) {
      print('🔌 Socket disconnected');
      _isConnected = false;
      _connectionStatusController.add(false);
    });
    
    _socket!.onConnectError((error) {
      print('❌ Socket connection error: $error');
      _isConnected = false;
      _connectionStatusController.add(false);
    });
    
    _socket!.onReconnect((_) {
      print('🔄 Socket reconnected');
      _isConnected = true;
      _connectionStatusController.add(true);
    });
    
    // Listen for match updates
    _socket!.on('match-update', (data) {
      print('📡 Match update received');
      try {
        final match = MatchModel.fromMap(data as Map<String, dynamic>);
        _matchUpdateController.add(match);
      } catch (e) {
        print('Error parsing match update: $e');
      }
    });
    
    // Listen for ball events
    _socket!.on('ball-event', (data) {
      print('🏏 Ball event received');
      try {
        final eventData = data as Map<String, dynamic>;
        if (eventData['ballEvent'] != null) {
          final ballEvent = BallEvent.fromMap(eventData['ballEvent']);
          _ballEventController.add(ballEvent);
        }
        if (eventData['match'] != null) {
          final match = MatchModel.fromMap(eventData['match']);
          _matchUpdateController.add(match);
        }
      } catch (e) {
        print('Error parsing ball event: $e');
      }
    });
    
    // Listen for match completion
    _socket!.on('match-completed', (data) {
      print('🏆 Match completed');
      try {
        final match = MatchModel.fromMap(data as Map<String, dynamic>);
        _matchUpdateController.add(match);
      } catch (e) {
        print('Error parsing match completed: $e');
      }
    });
    
    // Listen for innings change
    _socket!.on('innings-change', (data) {
      print('🔄 Innings changed');
      try {
        final match = MatchModel.fromMap(data as Map<String, dynamic>);
        _matchUpdateController.add(match);
      } catch (e) {
        print('Error parsing innings change: $e');
      }
    });
  }
  
  /// Join a match room to receive live updates
  void joinMatch(String matchId) {
    if (_socket == null || !_isConnected) {
      print('⚠️ Socket not connected, cannot join match');
      _currentMatchId = matchId; // Store for later when connected
      return;
    }
    
    // Leave previous match if any
    if (_currentMatchId != null && _currentMatchId != matchId) {
      leaveMatch(_currentMatchId!);
    }
    
    _currentMatchId = matchId;
    _socket!.emit('join-match', matchId);
    print('📺 Joined match room: $matchId');
  }
  
  /// Leave a match room
  void leaveMatch(String matchId) {
    if (_socket == null) return;
    
    _socket!.emit('leave-match', matchId);
    print('👋 Left match room: $matchId');
    
    if (_currentMatchId == matchId) {
      _currentMatchId = null;
    }
  }
  
  /// Emit a ball event to server
  void emitBallEvent(String matchId, BallEvent ballEvent) {
    if (_socket == null || !_isConnected) {
      print('⚠️ Socket not connected, cannot emit ball event');
      return;
    }
    
    _socket!.emit('score-ball', {
      'matchId': matchId,
      'ballEvent': ballEvent.toMap(),
    });
  }
  
  /// Emit innings change
  void emitInningsChange(String matchId, int newInnings, int target) {
    if (_socket == null || !_isConnected) return;
    
    _socket!.emit('change-innings', {
      'matchId': matchId,
      'newInnings': newInnings,
      'target': target,
    });
  }
  
  /// Emit match complete
  void emitMatchComplete(String matchId, MatchResult result) {
    if (_socket == null || !_isConnected) return;
    
    _socket!.emit('complete-match', {
      'matchId': matchId,
      'result': result.toMap(),
    });
  }
  
  /// Disconnect socket
  void disconnect() {
    if (_currentMatchId != null) {
      leaveMatch(_currentMatchId!);
    }
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _currentMatchId = null;
  }
  
  /// Dispose socket connection (streams remain open since it's a singleton)
  void dispose() {
    disconnect();
  }
}
