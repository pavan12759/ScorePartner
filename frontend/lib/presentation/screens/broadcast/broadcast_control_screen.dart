import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/broadcast_model.dart';
import '../../../data/services/broadcast_service.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../../data/services/video_streaming_service.dart';
import '../../../core/broadcast/overlay_theme_data.dart';
import '../../providers/broadcast_provider.dart';
import '../../widgets/broadcast/score_overlay_widget.dart';
import '../../widgets/broadcast/scorepartner_live_overlay.dart';
import '../../widgets/broadcast/sponsor_banner_widget.dart';
import '../../widgets/broadcast/broadcast_animation_widget.dart';
import '../../widgets/broadcast/replay_overlay_widget.dart';
import '../../../data/services/replay_system_service.dart';
import '../../../data/models/broadcast_highlight_model.dart';
import 'overlay_theme_gallery_screen.dart';
import 'overlay_customizer_screen.dart';
import 'overlay_builder_screen.dart';
import 'broadcast_crew_screen.dart';
import 'broadcast_analytics_screen.dart';

/// BroadcastControlScreen — Redesigned ScorePartner Live Studio Pro
/// Gives stream organizers full control over local camera, mic, overlays,
/// graphics animations, instant replays, and themes with an elegant UI.
class BroadcastControlScreen extends StatefulWidget {
  final String broadcastId;
  final String matchId;
  final bool halfScreenCapture;

  const BroadcastControlScreen({
    super.key,
    required this.broadcastId,
    required this.matchId,
    this.halfScreenCapture = false,
  });

  @override
  State<BroadcastControlScreen> createState() => _BroadcastControlScreenState();
}

class _BroadcastControlScreenState extends State<BroadcastControlScreen>
    with TickerProviderStateMixin {
  final VideoStreamingService _streamingService = VideoStreamingService.instance;
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  final BroadcastService _broadcastService = BroadcastService.instance;
  late final BroadcastProvider _broadcastProvider;

  late AnimationController _pulseController;
  StreamSubscription<String>? _videoErrorSubscription;
  late Timer _timer;
  
  int _secondsElapsed = 0;
  bool _showOverlay = true;
  bool _isCameraReady = false;
  bool _isStopping = false;
  bool _halfScreenCapture = false;
  bool _isMuted = false;
  int _cameraViewRevision = 0;

  VideoViewController? _videoViewController;

  @override
  void initState() {
    super.initState();
    _halfScreenCapture = widget.halfScreenCapture;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyCaptureSystemUi();
    });

    _broadcastProvider = BroadcastProvider();
    _broadcastProvider.joinBroadcast(widget.broadcastId);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _videoErrorSubscription = _streamingService.onError.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    _startTimer();
    _initVideoStreaming();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  Future<void> _applyCaptureSystemUi() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _initVideoStreaming() async {
    final hasPermissions = await _streamingService.requestPermissions();
    if (!hasPermissions) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Camera & Microphone permissions are required to stream live!'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // IMPORTANT (black-screen fix): create the local video view BEFORE
    // joining the channel, exactly like the official Agora example:
    //   prepare engine → create VideoViewController/AgoraVideoView
    //   → startPreview → joinChannel
    // Creating the view only after joinAsBroadcaster() returns (as the old
    // code did) leaves the local camera preview without a bound renderer,
    // which shows a black screen on Android while the published stream
    // keeps working for viewers.
    final prepared = await _streamingService.prepareBroadcasterPreview();
    if (!prepared || _streamingService.engine == null) {
      if (mounted) {
        setState(() => _isCameraReady = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _streamingService.lastError ?? 'Could not start the camera.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      // Render the local camera with a Flutter Texture (useFlutterTexture: true)
      // instead of a native platform view. Platform views inside frequently
      // rebuilt trees (1s stopwatch timer, Firestore match updates) lose their
      // texture on Android and render a black screen.
      _videoViewController = VideoViewController(
        rtcEngine: _streamingService.engine!,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
        ),
        useFlutterTexture: true,
        useAndroidSurfaceView: false,
      );
      setState(() {
        _isCameraReady = true;
        _cameraViewRevision++;
      });
    }

    // If the user left the screen while permissions/setup were in progress,
    // do NOT start the preview or join the channel — otherwise a stream
    // would keep running with no UI to end it.
    if (!mounted) return;

    // Let frames flow into the mounted view, then join the channel to
    // publish to viewers.
    await _streamingService.startLocalPreview();

    // Re-check before the join: if the user left during startLocalPreview,
    // don't join — otherwise a stream would run with no UI to end it.
    if (!mounted) return;

    final success = await _streamingService.joinAsBroadcaster(
      channelId: VideoStreamingService.defaultChannel,
    );

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _streamingService.lastError ?? 'Could not join the live video channel.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _videoErrorSubscription?.cancel();
    _pulseController.dispose();
    _broadcastProvider.dispose();
    _videoViewController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String get _formattedDuration {
    final hours = _secondsElapsed ~/ 3600;
    final minutes = (_secondsElapsed % 3600) ~/ 60;
    final seconds = _secondsElapsed % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _broadcastProvider),
      ],
      child: StreamBuilder<MatchModel?>(
        stream: _dataService.streamMatch(widget.matchId),
        builder: (context, snapshot) {
          final match = snapshot.data;

          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // 1. Live Camera Surface Viewfinder
                if (_halfScreenCapture)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _halfScreenHeight(context),
                    child: _buildCameraSurface(),
                  )
                else
                  Positioned.fill(child: _buildCameraSurface()),

                if (_halfScreenCapture)
                  Positioned(
                    top: _halfScreenHeight(context),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: const ColoredBox(color: Color(0xFF090711)),
                  ),

                // 2. Live Graphics Score Overlay Layer
                if (_showOverlay && match != null) ...[
                  Consumer<BroadcastProvider>(
                    builder: (context, broadcastProv, _) {
                      final theme = broadcastProv.selectedTheme;

                      return Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: _halfScreenCapture ? null : 0,
                            height: _halfScreenCapture
                                ? _halfScreenHeight(context)
                                : null,
                            child: ScorePartnerLiveOverlay(
                              match: match,
                              theme: theme,
                              viewerCount: broadcastProv.viewerCount,
                            ),
                          ),

                          // Sponsor Banner Slot
                          Positioned(
                            right: 16.w,
                            top: 150.h,
                            child: SponsorBannerWidget(theme: theme),
                          ),

                          // Replay Overlay (if active)
                          ListenableBuilder(
                            listenable: ReplaySystemService.instance,
                            builder: (context, _) {
                              final replayService = ReplaySystemService.instance;
                              if (replayService.isReplaying &&
                                  replayService.activeReplay != null) {
                                return ReplayOverlayWidget(
                                  highlight: replayService.activeReplay!,
                                  theme: theme,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          // Broadcast Event Animation Overlay
                          BroadcastAnimationWidget(
                            animationType: broadcastProv.currentAnimation,
                            onComplete: broadcastProv.clearAnimation,
                          ),
                        ],
                      );
                    },
                  ),
                ],

                // 3. Top Studio Status Header Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopStudioHeader(),
                ),

                // 4. Quick Action Sidebar (Right Side Tools)
                Positioned(
                  right: 12.w,
                  top: 100.h,
                  child: _buildQuickActionSidebar(),
                ),

                // 5. Bottom Master Control Bar
                Positioned(
                  left: 12.w,
                  right: 12.w,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: EdgeInsets.only(bottom: 12.h),
                    child: _buildBottomStudioControls(match),
                  ),
                ),

                // 6. Stopping Progress Overlay
                if (_isStopping)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xE6050510),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32.w,
                              height: 32.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFFFF8D48),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              'Ending Live Broadcast...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _halfScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.54;
  }

  Widget _buildCameraSurface() {
    // No RepaintBoundary here: compositing a video view inside a repaint
    // boundary is a known Agora black-screen trigger on Android when the
    // surrounding tree rebuilds (stopwatch timer, match stream, viewer
    // count updates). The Flutter Texture renderer handles rebuilds fine.
    return ClipRect(
      child: KeyedSubtree(
        key: ValueKey('local-camera-$_cameraViewRevision'),
        child: _buildCameraView(),
      ),
    );
  }

  Widget _buildCameraView() {
    if (_isCameraReady && _videoViewController != null) {
      return SizedBox.expand(
        child: AgoraVideoView(
          controller: _videoViewController!,
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0C20), Color(0xFF15102A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36.w,
              height: 36.w,
              child: const CircularProgressIndicator(
                color: Color(0xFFFF8D48),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              _streamingService.lastError == null
                  ? 'Connecting to live camera...'
                  : 'Camera feed unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_streamingService.lastError != null) ...[
              SizedBox(height: 6.h),
              Text(
                _streamingService.lastError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Top Studio Header — Live Indicator, Stopwatch, Viewer Counter, End Stream Button
  Widget _buildTopStudioHeader() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        child: Row(
          children: [
            // LIVE Badge
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),

            // Live Timer Stopwatch
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.white70, size: 14.sp),
                      SizedBox(width: 4.w),
                      Text(
                        _formattedDuration,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.sp,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),

            // Viewer Counter
            Consumer<BroadcastProvider>(
              builder: (context, prov, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: const Color(0xFFFF8D48), size: 14.sp),
                          SizedBox(width: 4.w),
                          Text(
                            '${prov.viewerCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const Spacer(),

            // HD Status Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Text(
                'HD 1080p',
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.sp,
                ),
              ),
            ),
            SizedBox(width: 8.w),

            // Close / End Broadcast Button
            GestureDetector(
              onTap: () => _confirmEndBroadcast(context, _broadcastProvider),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 18.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick Action Sidebar — Overlay Toggle, Theme Gallery, Customizer, Replay & FX
  Widget _buildQuickActionSidebar() {
    return Column(
      children: [
        // Score Overlay Toggle Button
        _buildSidebarIconButton(
          icon: _showOverlay ? Icons.visibility : Icons.visibility_off,
          label: 'Overlay',
          isActive: _showOverlay,
          onTap: () => setState(() => _showOverlay = !_showOverlay),
        ),
        SizedBox(height: 10.h),

        // Theme Gallery Launcher
        _buildSidebarIconButton(
          icon: Icons.palette_outlined,
          label: 'Themes',
          onTap: () async {
            final selected = await Navigator.push<OverlayThemeData>(
              context,
              MaterialPageRoute(
                builder: (_) => OverlayThemeGalleryScreen(
                  currentThemeId: _broadcastProvider.selectedTheme.id,
                ),
              ),
            );
            if (selected != null) {
              _broadcastProvider.setOverlayTheme(selected);
            }
          },
        ),
        SizedBox(height: 10.h),

        // Theme Customizer Launcher
        _buildSidebarIconButton(
          icon: Icons.tune_rounded,
          label: 'Customize',
          onTap: () async {
            final updated = await Navigator.push<OverlayThemeData>(
              context,
              MaterialPageRoute(
                builder: (_) => OverlayCustomizerScreen(
                  initialTheme: _broadcastProvider.selectedTheme,
                ),
              ),
            );
            if (updated != null) {
              _broadcastProvider.setOverlayTheme(updated);
            }
          },
        ),
        SizedBox(height: 10.h),

        // Instant Replay Trigger
        _buildSidebarIconButton(
          icon: Icons.replay_rounded,
          label: 'Replay',
          color: const Color(0xFFFF3B30),
          onTap: () {
            ReplaySystemService.instance.triggerReplay(
              BroadcastHighlight(
                id: 'highlight-${DateTime.now().millisecondsSinceEpoch}',
                matchId: widget.matchId,
                broadcastId: widget.broadcastId,
                title: 'KEY MOMENT',
                description: 'Instant Replay Highlight',
                type: 'six',
                timestamp: DateTime.now(),
              ),
            );
          },
        ),
        SizedBox(height: 10.h),

        // Graphics FX Animations Sheet
        _buildSidebarIconButton(
          icon: Icons.auto_awesome_rounded,
          label: 'FX',
          color: const Color(0xFFFF8D48),
          onTap: () => _showFxSheet(_broadcastProvider),
        ),
      ],
    );
  }

  Widget _buildSidebarIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = true,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48.w,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: isActive ? Colors.black54 : Colors.black26,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isActive ? color.withOpacity(0.4) : Colors.white10,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isActive ? color : Colors.white38, size: 20.sp),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? color : Colors.white38,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom Studio Controls Bar — Mic, Camera Flip, Viewfinder Toggle, Tools & End Stream
  Widget _buildBottomStudioControls(MatchModel? match) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute / Unmute Mic
              _buildBottomControlButton(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _isMuted ? 'Muted' : 'Mic ON',
                activeColor: _isMuted ? const Color(0xFFFF3B30) : const Color(0xFFFF8D48),
                onTap: () async {
                  await _streamingService.toggleMute();
                  setState(() => _isMuted = !_isMuted);
                },
              ),

              // Switch Front / Rear Camera
              _buildBottomControlButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip Cam',
                onTap: () async {
                  await _streamingService.switchCameraForBroadcast();
                },
              ),

              // Half / Full Screen Viewfinder Mode
              _buildBottomControlButton(
                icon: _halfScreenCapture ? Icons.fullscreen_rounded : Icons.splitscreen_rounded,
                label: _halfScreenCapture ? 'Full Cam' : 'Split Cam',
                onTap: () {
                  setState(() => _halfScreenCapture = !_halfScreenCapture);
                },
              ),

              // Studio Tools Menu
              _buildBottomControlButton(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: () => _showStudioToolsMenu(match),
              ),

              // End Broadcast Button
              ElevatedButton.icon(
                onPressed: () => _confirmEndBroadcast(context, _broadcastProvider),
                icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 16),
                label: Text(
                  'END STREAM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.sp,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color activeColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: activeColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: activeColor, size: 18.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Graphics Animation Sheet Launcher (FOUR, SIX, WICKET, FIFTY, CENTURY, OUT)
  void _showFxSheet(BroadcastProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15102A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: const Color(0xFFFF8D48), size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Trigger Broadcast Animation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 12.w,
                runSpacing: 12.h,
                children: [
                  _buildFxButton('BOUNDARY 4', 'four', const Color(0xFF34C759), prov),
                  _buildFxButton('SIXER 6', 'six', const Color(0xFFFF8D48), prov),
                  _buildFxButton('WICKET!', 'wicket', const Color(0xFFFF3B30), prov),
                  _buildFxButton('50 RUNS', 'fifty', const Color(0xFF5856D6), prov),
                  _buildFxButton('100 RUNS', 'century', const Color(0xFFFFD60A), prov),
                  _buildFxButton('OUT', 'out', const Color(0xFFFF2D55), prov),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFxButton(
    String label,
    String animType,
    Color color,
    BroadcastProvider prov,
  ) {
    return ElevatedButton(
      onPressed: () {
        prov.triggerAnimation(animType);
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp),
      ),
    );
  }

  /// Studio Tools Drawer / Sheet
  void _showStudioToolsMenu(MatchModel? match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15102A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Studio Production Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Color(0xFFFF8D48)),
                title: const Text('Broadcast Crew', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Manage commentators & camera operators', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(ctx);
                  final session = BroadcastSession(
                    id: widget.broadcastId,
                    matchId: widget.matchId,
                    broadcasterId: 'streamer',
                    status: 'live',
                    startedAt: DateTime.now(),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BroadcastCrewScreen(broadcast: session),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.insights_rounded, color: Colors.blueAccent),
                title: const Text('Stream Analytics', style: TextStyle(color: Colors.white)),
                subtitle: const Text('View audience engagement & stats', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(ctx);
                  final session = BroadcastSession(
                    id: widget.broadcastId,
                    matchId: widget.matchId,
                    broadcasterId: 'streamer',
                    status: 'live',
                    startedAt: DateTime.now(),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BroadcastAnalyticsScreen(
                        broadcast: session,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF10B981)),
                title: const Text('Layout Builder', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Customize overlay positions', style: TextStyle(color: Colors.white54)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final updatedConfig = await Navigator.push<BroadcastOverlayConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OverlayBuilderScreen(
                        initialConfig: _broadcastProvider.overlayConfig,
                      ),
                    ),
                  );
                  if (updatedConfig != null) {
                    _broadcastProvider.updateOverlayConfig(updatedConfig);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Confirmation Dialog before ending stream
  void _confirmEndBroadcast(
    BuildContext parentContext,
    BroadcastProvider prov,
  ) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF15102A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'End Live Broadcast?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to stop the live stream? All active viewers will be disconnected.',
            style: TextStyle(color: Colors.white70, fontSize: 13.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                if (!mounted || _isStopping) return;
                setState(() => _isStopping = true);
                try {
                  await _broadcastService.endBroadcast(widget.broadcastId);
                } catch (e) {
                  debugPrint('Error ending broadcast: $e');
                }
                await _streamingService.release();
                if (mounted) {
                  Navigator.pop(parentContext); // Exit broadcast screen
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('End Stream', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
