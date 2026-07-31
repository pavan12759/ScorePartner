import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

/// VideoStreamingService — Wrapper around Agora RTC Engine
/// Handles live video streaming for broadcaster and viewer (audience) roles.
/// Tokens are fetched from the backend — never hardcoded in the app.
class VideoStreamingService {
  static VideoStreamingService? _instance;
  static VideoStreamingService get instance =>
      _instance ??= VideoStreamingService._();

  VideoStreamingService._();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _isPreviewStarted = false;
  bool _isMuted = false;
  bool _isFrontCamera = true;
  int? _remoteUid;
  String _currentChannel = '';
  String _pendingChannel = '';
  String? _lastError;
  Completer<bool>? _joinCompleter;

  // Active token state — refreshed from the backend
  String _activeToken = '';
  int _activeUid = 0;
  String _activeRole = 'publisher'; // 'publisher' | 'subscriber'
  int? _tokenExpiresAt; // Unix seconds; used to trigger proactive refresh

  // Getters
  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;
  bool get isFrontCamera => _isFrontCamera;
  int? get remoteUid => _remoteUid;
  String get currentChannel => _currentChannel;
  String? get lastError => _lastError;

  // Stream controllers for state updates
  final StreamController<bool> _joinedController =
      StreamController<bool>.broadcast();
  final StreamController<int?> _remoteUidController =
      StreamController<int?>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<bool> get onJoinedStateChanged => _joinedController.stream;
  Stream<int?> get onRemoteUserChanged => _remoteUidController.stream;
  Stream<String> get onError => _errorController.stream;

  /// App ID — safe to be in the app (not secret)
  static const String defaultAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '322de5c0787644cfab724b93aa68d4ca',
  );

  /// Default channel name — used as fallback when no channelId is supplied by the caller
  static const String defaultChannel = String.fromEnvironment(
    'AGORA_CHANNEL',
    defaultValue: 'pavan_channel',
  );

  /// Backend base URL — tokens are fetched from here
  static const String _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5000',
  );

  // ─── Token Fetching ──────────────────────────────────────────────────────────

  /// Fetch a fresh Agora token from your Node.js backend.
  /// The App Certificate (secret) never leaves the server.
  Future<String?> fetchToken({
    required String channelName,
    int uid = 0,
    String role = 'publisher',
  }) async {
    try {
      // Get Firebase ID token for authenticating with backend (optional)
      String? idToken;
      try {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          idToken = await firebaseUser.getIdToken();
        }
      } catch (e) {
        debugPrint('⚠️ ID token fetch error: $e');
      }

      // Determine backend URLs to try (localhost, ADB forwarded port, 10.0.2.2 for emulator, 192.168.1.10 for physical Wi-Fi device)
      final candidateUrls = <String>[_backendUrl];
      if (_backendUrl.contains('localhost')) {
        candidateUrls.add(_backendUrl.replaceAll('localhost', '192.168.1.10'));
        candidateUrls.add(_backendUrl.replaceAll('localhost', '10.0.2.2'));
      }

      http.Response? response;
      for (final baseUrl in candidateUrls) {
        try {
          final headers = <String, String>{
            'Content-Type': 'application/json',
          };
          if (idToken != null && idToken.isNotEmpty) {
            headers['Authorization'] = 'Bearer $idToken';
          }

          final res = await http.post(
            Uri.parse('$baseUrl/api/agora/token'),
            headers: headers,
            body: jsonEncode({
              'channelName': channelName,
              'uid': uid,
              'role': role,
            }),
          ).timeout(const Duration(seconds: 4));
          
          response = res;
          if (res.statusCode == 200) {
            break;
          }
        } catch (e) {
          debugPrint('⚠️ Error connecting to $baseUrl: $e');
        }
      }

      if (response == null) {
        _reportError('Could not reach backend server. Ensure server is running on port 5000.');
        return null;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        final expiresAt = data['expiresAt'] as int?;

        if (token != null && token.isNotEmpty) {
          _activeToken = token;
          _activeUid = uid;
          _activeRole = role;
          _tokenExpiresAt = expiresAt;
          debugPrint('✅ Agora token fetched from backend | channel=$channelName | expires=$expiresAt');
          return token;
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          _reportError(data['error'] ?? 'Server error (${response.statusCode})');
        } catch (_) {
          _reportError('Failed to get stream token (${response.statusCode}). Try again.');
        }
        return null;
      }
    } on TimeoutException {
      _reportError('Could not reach the server. Check your connection.');
      return null;
    } catch (e) {
      debugPrint('⚠️ fetchToken error: $e');
      _reportError('Failed to fetch stream token: $e');
      return null;
    }
  }

  // ─── Token Renewal ───────────────────────────────────────────────────────────

  /// Called by onTokenPrivilegeWillExpire — silently renews the token mid-stream.
  Future<void> _renewToken() async {
    if (_currentChannel.isEmpty) return;
    debugPrint('🔄 Renewing Agora token for channel=$_currentChannel...');

    final newToken = await fetchToken(
      channelName: _currentChannel,
      uid: _activeUid,
      role: _activeRole,
    );

    if (newToken != null && _engine != null) {
      await _engine!.renewToken(newToken);
      debugPrint('✅ Agora token renewed successfully.');
    } else {
      _reportError('Token renewal failed. Stream may disconnect soon.');
    }
  }


  /// Request permissions for Camera and Microphone
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true; // Handled by browser dialogs

    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

    return cameraGranted && micGranted;
  }

  /// Initialize Agora RTC Engine
  Future<bool> initEngine({
    String? appId,
    bool startCameraPreview = true,
  }) async {
    if (_isInitialized && _engine != null) return true;

    final targetAppId = (appId != null && appId.isNotEmpty)
        ? appId
        : defaultAppId;

    try {
      // A previous web initialization can leave a half-created engine behind.
      // Release it before retrying so the new Iris bridge is used cleanly.
      if (_engine != null) {
        final previousEngine = _engine!;
        try {
          await previousEngine.leaveChannel();
        } catch (_) {
          // The previous engine may never have joined a channel.
        }
        try {
          if (_isPreviewStarted) {
            await previousEngine.stopPreview();
          }
        } catch (_) {
          // The previous engine may not have had a local preview.
        }
        await previousEngine.release();
        _engine = null;
        _isPreviewStarted = false;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: targetAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _registerEventHandlers();

      await _engine!.enableVideo();
      await _engine!.enableAudio();
      if (startCameraPreview) {
        await _startPreviewIfNeeded();
      }

      _isInitialized = true;
      _lastError = null;
      debugPrint('🎥 Agora RTC Engine Initialized successfully with AppID');
      return true;
    } catch (e) {
      _isInitialized = false;
      _engine = null;
      debugPrint('⚠️ Agora Engine Init error: $e');
      _reportError('Failed to initialize video engine: $e');
      return false;
    }
  }

  /// Register Agora event handlers
  void _registerEventHandlers() {
    if (_engine == null) return;

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
            '🎥 Joined channel: ${connection.channelId}, uid: ${connection.localUid}',
          );
          _isJoined = true;
          _currentChannel = connection.channelId ?? '';
          _joinedController.add(true);
          _completePendingJoin(true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint(
            '👤 Remote user joined: $remoteUid in channel: ${connection.channelId}',
          );
          _remoteUid = remoteUid;
          _remoteUidController.add(remoteUid);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint('👋 Remote user left: $remoteUid');
              if (_remoteUid == remoteUid) {
                _remoteUid = null;
                _remoteUidController.add(null);
              }
            },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('❌ Agora Error [$err]: $msg');
          _reportError('Streaming error: ${msg.isEmpty ? err.name : msg}');
          if (!_isJoined) {
            _completePendingJoin(false);
          }
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              if (state == ConnectionStateType.connectionStateFailed) {
                _reportError('Could not join the live channel: ${reason.name}.');
                _completePendingJoin(false);
              }
            },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('⚠️ Agora token will expire soon — auto-renewing...');
          _renewToken(); // silently fetch a fresh token from the backend
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('🚪 Left channel: ${connection.channelId}');
          _isJoined = false;
          _remoteUid = null;
          _joinedController.add(false);
          _remoteUidController.add(null);
          _completePendingJoin(false);
        },
      ),
    );
  }

  void _reportError(String message) {
    _lastError = message;
    _errorController.add(message);
  }

  void _completePendingJoin(bool succeeded) {
    final completer = _joinCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(succeeded);
    }
  }

  Future<bool> _waitForChannelJoin() async {
    final completer = _joinCompleter;
    if (completer == null) return false;

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _completePendingJoin(false);
        if (_lastError == null || _lastError!.isEmpty) {
          _reportError(
            'Timed out joining channel "$_pendingChannel". '
            'Check your internet connection and try again.',
          );
        }
        return false;
      },
    );
  }

  /// Join as Broadcaster (Organizer streaming video)
  /// Fetches a fresh token from the backend before joining.
  Future<bool> joinAsBroadcaster({
    required String channelId,
    int uid = 0,
    String token = '', // if non-empty, skips backend fetch (for testing only)
  }) async {
    if (!_isInitialized) {
      final initialized = await initEngine(startCameraPreview: false);
      if (!initialized) return false;
    }

    try {
      if (_isJoined) {
        if (_currentChannel == channelId) return true;
        await leaveChannel();
      }

      // Fetch a fresh token from the backend (or use the override for dev)
      String channelToken = token;
      if (channelToken.isEmpty) {
        final fetched = await fetchToken(
          channelName: channelId,
          uid: uid,
          role: 'publisher',
        );
        if (fetched == null) return false; // fetchToken already set _lastError
        channelToken = fetched;
      }

      _lastError = null;
      _pendingChannel = channelId;
      _joinCompleter = Completer<bool>();
      debugPrint(
        'Agora broadcaster join: channel=$channelId | '
        'appIdPrefix=${defaultAppId.substring(0, 6)} | tokenOk=true',
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableVideo();
      // NOTE: setupLocalVideo is intentionally NOT called here. The local
      // VideoCanvas binding is handled by the app's VideoViewController/
      // AgoraVideoView (created before joining via prepareBroadcasterPreview).
      // Calling setupLocalVideo here with a canvas that has no view handle can
      // conflict with the texture/platform renderer and cause a black local
      // preview while the stream keeps publishing.
      await _startPreviewIfNeeded();

      await _engine!.joinChannel(
        token: channelToken,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );

      return await _waitForChannelJoin();
    } catch (e) {
      debugPrint('❌ Join as broadcaster error: $e');
      _reportError('Failed to start live video stream: $e');
      _completePendingJoin(false);
      return false;
    }
  }

  /// Join as Audience (Viewer watching stream)
  /// Fetches a fresh token from the backend before joining.
  Future<bool> joinAsAudience({
    required String channelId,
    int uid = 0,
    String token = '', // if non-empty, skips backend fetch (for testing only)
  }) async {
    if (!_isInitialized) {
      final initialized = await initEngine(startCameraPreview: false);
      if (!initialized) return false;
    }

    try {
      if (_isJoined) {
        if (_currentChannel == channelId) return true;
        await leaveChannel();
      }

      // Fetch a fresh token from the backend (or use the override for dev)
      String channelToken = token;
      if (channelToken.isEmpty) {
        final fetched = await fetchToken(
          channelName: channelId,
          uid: uid,
          role: 'subscriber',
        );
        if (fetched == null) return false; // fetchToken already set _lastError
        channelToken = fetched;
      }

      _lastError = null;
      _pendingChannel = channelId;
      _joinCompleter = Completer<bool>();
      debugPrint(
        'Agora audience join: channel=$channelId | '
        'appIdPrefix=${defaultAppId.substring(0, 6)} | tokenOk=true',
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.enableVideo();

      await _engine!.joinChannel(
        token: channelToken,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );

      return await _waitForChannelJoin();
    } catch (e) {
      debugPrint('❌ Join as audience error: $e');
      _reportError('Failed to join live stream: $e');
      _completePendingJoin(false);
      return false;
    }
  }

  /// Prepare the engine + broadcaster role + video for the local camera
  /// WITHOUT joining the channel or binding a renderer.
  ///
  /// IMPORTANT: Call this BEFORE mounting [VideoViewController]/[AgoraVideoView]
  /// so the local view can bind to the camera before [joinAsBroadcaster] is
  /// called. This is the order recommended by the official Agora example:
  ///   prepare → create view → startPreview → joinChannel
  /// Creating the view after joining is a known cause of a black local
  /// preview while the published stream keeps working for viewers.
  Future<bool> prepareBroadcasterPreview() async {
    if (!_isInitialized) {
      final initialized = await initEngine(startCameraPreview: false);
      if (!initialized) return false;
    }
    try {
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableVideo();
      _lastError = null;
      return true;
    } catch (e) {
      debugPrint('❌ prepareBroadcasterPreview error: $e');
      _reportError('Failed to prepare the camera: $e');
      return false;
    }
  }

  /// Start local camera capture so frames flow into the mounted video view.
  Future<bool> startLocalPreview() async {
    if (_engine == null) return false;
    try {
      await _engine!.enableVideo();
      await _startPreviewIfNeeded();
      return true;
    } catch (e) {
      debugPrint('❌ startLocalPreview error: $e');
      _reportError('Could not start the camera preview: $e');
      return false;
    }
  }

  /// Switch front/back camera
  Future<void> switchCamera() async {
    if (_engine == null || !_isJoined) return;
    try {
      await _engine!.switchCamera();
      _isFrontCamera = !_isFrontCamera;
    } catch (e) {
      debugPrint('⚠️ Switch camera error: $e');
    }
  }

  /// Switch cameras without waiting for the join callback.
  /// Mobile camera preview can be ready while the RTC join event is pending.
  Future<bool> switchCameraForBroadcast() async {
    if (_engine == null) {
      _reportError('Camera engine is not ready yet.');
      return false;
    }

    try {
      await _engine!.switchCamera();
      _isFrontCamera = !_isFrontCamera;
      return true;
    } catch (e) {
      debugPrint('Camera switch error: $e');
      _reportError('Could not switch camera: $e');
      return false;
    }
  }

  /// Re-start the local preview after a screen rotation or platform-view
  /// reattachment. Agora keeps publishing, but the preview surface can be
  /// detached while the Flutter viewport changes size.
  Future<bool> ensureBroadcasterPreview() async {
    if (_engine == null || !_isInitialized) return false;

    try {
      await _engine!.enableVideo();
      await _startPreviewIfNeeded();
      return true;
    } catch (e) {
      debugPrint('Local preview restart error: $e');
      _reportError('Could not restore the camera preview: $e');
      return false;
    }
  }

  /// Toggle microphone mute
  Future<void> toggleMute() async {
    if (_engine == null) return;
    try {
      _isMuted = !_isMuted;
      await _engine!.muteLocalAudioStream(_isMuted);
    } catch (e) {
      debugPrint('⚠️ Toggle mute error: $e');
    }
  }

  /// Leave stream channel
  Future<void> leaveChannel() async {
    if (_engine == null) return;
    final engine = _engine!;
    try {
      await engine.leaveChannel();
      if (_isPreviewStarted) {
        await engine.stopPreview();
      }
    } catch (e) {
      debugPrint('⚠️ Leave channel error: $e');
    } finally {
      _isPreviewStarted = false;
      _isJoined = false;
      _remoteUid = null;
      _currentChannel = '';
      _joinedController.add(false);
      _remoteUidController.add(null);
      _completePendingJoin(false);
    }
  }

  /// Clean up resources
  Future<void> release() async {
    try {
      await leaveChannel();
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }
      _isInitialized = false;
      _isPreviewStarted = false;
    } catch (e) {
      debugPrint('⚠️ Release engine error: $e');
    }
  }

  Future<void> _startPreviewIfNeeded() async {
    if (_engine == null || _isPreviewStarted) return;
    await _engine!.startPreview();
    _isPreviewStarted = true;
  }
}
