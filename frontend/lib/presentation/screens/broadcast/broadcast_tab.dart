import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/broadcast_service.dart';
import '../../../data/models/broadcast_model.dart';
import '../../providers/broadcast_provider.dart';
import '../../widgets/broadcast/score_overlay_widget.dart';
import '../../widgets/broadcast/batsman_overlay_widget.dart';
import '../../widgets/broadcast/bowler_overlay_widget.dart';
import '../../widgets/broadcast/broadcast_animation_widget.dart';
import '../../widgets/broadcast/floating_emoji_widget.dart';
import '../../widgets/broadcast/sponsor_banner_widget.dart';
import '../../widgets/broadcast/replay_overlay_widget.dart';
import '../../../data/services/replay_system_service.dart';
import '../../../data/services/video_streaming_service.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'full_screen_broadcast_screen.dart';
import '../../widgets/broadcast/scorepartner_live_overlay.dart';

/// Broadcast tab — embedded in MatchDetailScreen as a new tab.
/// Viewers see the full live broadcast experience: score overlay,
/// animations, live chat, and emoji reactions.
class BroadcastTab extends StatefulWidget {
  final MatchModel match;

  const BroadcastTab({super.key, required this.match});

  @override
  State<BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<BroadcastTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  BroadcastSession? _broadcast;
  late AnimationController _pulseController;
  final GlobalKey _emojiKey = GlobalKey();
  
  BroadcastProvider? _broadcastProvider;
  int _lastProcessedBallCount = -1;
  String? _videoError;
  bool _videoJoinInProgress = false;
  bool _isVideoRequested = false; // video only starts when user taps Watch Live

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadBroadcast();
  }

  Future<void> _loadBroadcast() async {
    final broadcast = await BroadcastService.instance
        .getActiveBroadcastForMatch(widget.match.id);
    if (!mounted) return;

    BroadcastProvider? providerToJoin;
    setState(() {
      _broadcast = broadcast;
      _videoError = null;
      if (broadcast != null && _broadcastProvider == null) {
        _broadcastProvider = BroadcastProvider();
        providerToJoin = _broadcastProvider;
        _lastProcessedBallCount = widget.match.ballByBall.length;
      }
    });

    if (providerToJoin != null) {
      providerToJoin!.joinBroadcast(broadcast!.id);
    }

    if (broadcast != null) {
      // Do NOT auto-connect video — Agora engine init can crash on some devices
      // when triggered at app load. User taps "Watch Live" to start video.
      // await _connectToAudience(); ← removed intentionally
    }
  }

  Future<void> _connectToAudience() async {
    if (_videoJoinInProgress) return;

    _videoJoinInProgress = true;
    final streamingService = VideoStreamingService.instance;
    try {
      final joined = await streamingService.joinAsAudience(
        channelId: VideoStreamingService.defaultChannel,
      );
      if (!mounted) return;

      setState(() {
        _videoError = joined
            ? null
            : streamingService.lastError ??
                'Could not connect to the live video. Tap refresh to retry.';
      });
    } finally {
      _videoJoinInProgress = false;
    }
  }

  @override
  void didUpdateWidget(BroadcastTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check for new balls and process them for auto-highlights
    if (_broadcastProvider != null) {
      final currentBalls = widget.match.ballByBall.length;
      if (_lastProcessedBallCount != -1 && currentBalls > _lastProcessedBallCount) {
        final newBalls = widget.match.ballByBall.skip(_lastProcessedBallCount).toList();
        for (final ball in newBalls) {
          _broadcastProvider!.processBallEvent(ball, widget.match);
          
          // Generate mock commentary if none exists
          _broadcastProvider!.updateCommentary(
            '${ball.overNumber}.${ball.ballNumber}',
            '${ball.bowlerName} to ${ball.batsmanName}, ${ball.runs} runs${ball.wicket != null ? " - WICKET!" : ""}',
          );
        }
      }
      _lastProcessedBallCount = currentBalls;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _broadcastProvider?.dispose();
    VideoStreamingService.instance.leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // If no active broadcast, show placeholder
    if (_broadcast == null) {
      return _buildNoBroadcast();
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _broadcastProvider!),
      ],
      child: _buildBroadcastView(),
    );
  }

  Widget _buildNoBroadcast() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0A1A), Color(0xFF1A1A2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated broadcast icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + _pulseController.value * 0.1,
                  child: Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF8D48).withOpacity(0.2),
                          const Color(0xFFFF6B35).withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFF8D48).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.videocam_off_outlined,
                      color: const Color(0xFFFF8D48).withOpacity(0.6),
                      size: 36.sp,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20.h),
            Text(
              'No Live Broadcast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'The organizer hasn\'t started a broadcast yet.\nCheck back when the match is live!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13.sp,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            // Refresh button
            TextButton.icon(
              onPressed: _loadBroadcast,
              icon: const Icon(Icons.refresh, color: Color(0xFFFF8D48)),
              label: Text(
                'Refresh',
                style: TextStyle(
                  color: const Color(0xFFFF8D48),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFFFF8D48).withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastView() {
    return Consumer<BroadcastProvider>(
      builder: (context, broadcastProv, _) {
        final theme = broadcastProv.selectedTheme;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF050510), Color(0xFF0A0A1A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Background — mock camera/field gradient
              _buildBackground(),

              Positioned.fill(
                child: ScorePartnerLiveOverlay(
                  match: widget.match,
                  theme: theme,
                  viewerCount: broadcastProv.viewerCount,
                ),
              ),

              // Sponsor Banner Slot
              Positioned(
                right: 16.w,
                top: 110.h,
                child: SponsorBannerWidget(theme: theme),
              ),

              // Replay Overlay (if active)
              ListenableBuilder(
                listenable: ReplaySystemService.instance,
                builder: (context, _) {
                  final replayService = ReplaySystemService.instance;
                  if (replayService.isReplaying && replayService.activeReplay != null) {
                    return ReplayOverlayWidget(
                      highlight: replayService.activeReplay!,
                      theme: theme,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Commentary banner
              if (broadcastProv.latestCommentary != null)
                Positioned(
                  left: 16.w,
                  right: 80.w,
                  top: 190.h,
                  child: _buildCommentaryBanner(broadcastProv),
                ),

              // Broadcast Animation (full screen)
              BroadcastAnimationWidget(
                animationType: broadcastProv.currentAnimation,
                onComplete: broadcastProv.clearAnimation,
              ),

              // Floating Emoji Reactions
              FloatingEmojiWidget(
                key: _emojiKey,
                recentEmojis: const [], // Reactions disabled with chat
                onTapReaction: () {
                  // Will be triggered on tap
                },
              ),

              // Match status / ended overlay
              if (broadcastProv.currentBroadcast?.isEnded == true)
                _buildEndedOverlay(),

              // Full Screen Toggle Button
              Positioned(
                right: 12.w,
                bottom: 12.h,
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => FullScreenBroadcastScreen(
                          match: widget.match,
                          broadcastProvider: broadcastProv,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    final streamingService = VideoStreamingService.instance;
    return StreamBuilder<int?>(
      stream: streamingService.onRemoteUserChanged,
      initialData: streamingService.remoteUid,
      builder: (context, snapshot) {
        final remoteUid = snapshot.data;
        final engine = streamingService.engine;

        if (remoteUid != null && engine != null) {
          return SizedBox.expand(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(
                  uid: remoteUid,
                  renderMode: RenderModeType.renderModeHidden,
                ),
                connection: RtcConnection(
                  channelId: VideoStreamingService.defaultChannel,
                ),
                useFlutterTexture: true,
                useAndroidSurfaceView: false,
              ),
            ),
          );
        }

        String statusMessage = 'Live Stream Ready';
        if (_videoJoinInProgress) {
          statusMessage = 'Connecting to live video...';
        } else if (streamingService.isJoined) {
          statusMessage = 'Waiting for broadcaster video...';
        } else if (_videoError != null) {
          statusMessage = 'Live video unavailable';
        } else if (!_isVideoRequested) {
          statusMessage = 'Live Video Stream Available';
        }

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                const Color(0xFF0D2818).withOpacity(0.8),
                const Color(0xFF050510),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_videoJoinInProgress) ...[
                  SizedBox(
                    width: 36.w,
                    height: 36.w,
                    child: const CircularProgressIndicator(
                      color: Color(0xFFFF8D48),
                      strokeWidth: 3,
                    ),
                  ),
                ] else ...[
                  Icon(
                    _videoError == null
                        ? Icons.videocam_outlined
                        : Icons.cloud_off_outlined,
                    color: _videoError == null
                        ? const Color(0xFFFF8D48)
                        : const Color(0xFFFF6B6B),
                    size: 44.sp,
                  ),
                ],
                SizedBox(height: 12.h),
                Text(
                  statusMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_isVideoRequested && !_videoJoinInProgress && _videoError == null) ...[
                  SizedBox(height: 14.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _isVideoRequested = true);
                      _connectToAudience();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: const Text(
                      'Watch Live Stream',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8D48),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                  ),
                ],
                if (_videoError != null) ...[
                  SizedBox(height: 6.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 320.w),
                    child: Text(
                      _videoError!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.58),
                        fontSize: 12.sp,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextButton.icon(
                    onPressed: _connectToAudience,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry video'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8D48),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentaryBanner(BroadcastProvider prov) {
    return AnimatedOpacity(
      opacity: prov.latestCommentary != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8D48),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    prov.latestCommentaryBall ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    prov.latestCommentary ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndedOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop_circle_outlined, color: Colors.white54, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              'Broadcast Ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Check the Scorecard tab for final results',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
