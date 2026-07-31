import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../../data/models/match_model.dart';
import '../../providers/broadcast_provider.dart';
import '../../../data/services/video_streaming_service.dart';
import '../../widgets/broadcast/score_overlay_widget.dart';
import '../../widgets/broadcast/batsman_overlay_widget.dart';
import '../../widgets/broadcast/bowler_overlay_widget.dart';
import '../../widgets/broadcast/scorepartner_live_overlay.dart';
import '../../widgets/broadcast/sponsor_banner_widget.dart';
import '../../widgets/broadcast/broadcast_animation_widget.dart';
import '../../widgets/broadcast/floating_emoji_widget.dart';

class FullScreenBroadcastScreen extends StatefulWidget {
  final MatchModel match;
  final BroadcastProvider broadcastProvider;

  const FullScreenBroadcastScreen({
    super.key,
    required this.match,
    required this.broadcastProvider,
  });

  @override
  State<FullScreenBroadcastScreen> createState() => _FullScreenBroadcastScreenState();
}

class _FullScreenBroadcastScreenState extends State<FullScreenBroadcastScreen>
    with WidgetsBindingObserver {
  final GlobalKey<FloatingEmojiWidgetState> _emojiKey = GlobalKey<FloatingEmojiWidgetState>();
  int _videoViewRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Make the broadcast route immersive on Android and iOS.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Recreate the remote platform view after fullscreen orientation changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _videoViewRevision++);
    });
  }

  Widget _buildBackground() {
    return StreamBuilder<int?>(
      stream: VideoStreamingService.instance.onRemoteUserChanged,
      initialData: VideoStreamingService.instance.remoteUid,
      builder: (context, snapshot) {
        final remoteUid = snapshot.data;
        final engine = VideoStreamingService.instance.engine;

        if (remoteUid != null && engine != null) {
          return ClipRect(
            child: KeyedSubtree(
              key: ValueKey('remote-video-$remoteUid-$_videoViewRevision'),
              child: SizedBox.expand(
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
              ),
            ),
          );
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
                Icon(
                  Icons.sports_cricket,
                  color: Colors.white.withOpacity(0.05),
                  size: 80.sp, // Scaled down for landscape
                ),
                SizedBox(height: 8.h),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.06),
                    fontSize: 32.sp, // Scaled down for landscape
                    fontWeight: FontWeight.w900,
                    letterSpacing: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.broadcastProvider,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<BroadcastProvider>(
          builder: (context, broadcastProv, _) {
            final theme = broadcastProv.selectedTheme;

            return Stack(
              children: [
                // Background — video feed or placeholder
                _buildBackground(),

                Positioned.fill(
                  child: ScorePartnerLiveOverlay(
                    match: widget.match,
                    theme: theme,
                    viewerCount: broadcastProv.viewerCount,
                  ),
                ),

                // Sponsor Banner - Top Right
                Positioned(
                  right: 60.w, // Leave room for close button
                  top: 20.h,
                  child: SponsorBannerWidget(theme: theme),
                ),

                // Broadcast Animation
                BroadcastAnimationWidget(
                  animationType: broadcastProv.currentAnimation,
                  onComplete: broadcastProv.clearAnimation,
                ),

                // Floating Emoji Reactions
                FloatingEmojiWidget(
                  key: _emojiKey,
                  recentEmojis: const [],
                  onTapReaction: () {},
                ),

                // Close Button
                Positioned(
                  right: 16.w,
                  top: 16.h,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_fullscreen,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
