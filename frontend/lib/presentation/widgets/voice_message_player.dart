import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int duration; // in seconds
  final bool isMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late AudioPlayer _player;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  late List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.duration);
    _waveformHeights = _generateWaveform(widget.audioUrl);
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _player = AudioPlayer();
    
    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur;
        });
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  List<double> _generateWaveform(String url) {
    final seed = url.hashCode;
    final random = Random(seed);
    return List.generate(24, (index) => 6.0 + random.nextDouble() * 20.0);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
      await _player.setPlaybackRate(_playbackSpeed);
    }
  }

  void _toggleSpeed() async {
    double newSpeed;
    if (_playbackSpeed == 1.0) {
      newSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      newSpeed = 2.0;
    } else {
      newSpeed = 1.0;
    }

    setState(() {
      _playbackSpeed = newSpeed;
    });

    if (_isPlaying) {
      await _player.setPlaybackRate(newSpeed);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _handleSeek(Offset localPosition, Size size) {
    if (_duration == Duration.zero) return;
    final relativePos = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final seekMs = (relativePos * _duration.inMilliseconds).round();
    _player.seek(Duration(milliseconds: seekMs));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final activeBars = (_waveformHeights.length * progress).round();

    final mainColor = widget.isMe ? Colors.white : Colors.black87;
    final secondaryColor = widget.isMe ? Colors.white60 : Colors.black38;
    final activeBarColor = widget.isMe ? Colors.white : AppTheme.primaryOrange;
    final inactiveBarColor = widget.isMe ? Colors.white24 : Colors.grey[300]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause Button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white24 : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: mainColor,
              size: 24.sp,
            ),
          ),
        ),
        SizedBox(width: 8.w),

        // Waveform / Interactive Slider
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            _handleSeek(box.globalToLocal(details.globalPosition), box.size);
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            _handleSeek(box.globalToLocal(details.globalPosition), box.size);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform Row
              Row(
                children: List.generate(_waveformHeights.length, (index) {
                  final isActive = index < activeBars;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 1.5.w),
                    width: 3.w,
                    height: _waveformHeights[index].h,
                    decoration: BoxDecoration(
                      color: isActive ? activeBarColor : inactiveBarColor,
                      borderRadius: BorderRadius.circular(1.5.r),
                    ),
                  );
                }),
              ),
              SizedBox(height: 4.h),
              // Time status
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10.w),

        // Speed Toggle (1x, 1.5x, 2x)
        GestureDetector(
          onTap: _toggleSpeed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white24 : Colors.grey[200],
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              '${_playbackSpeed == 1.0 ? '1' : _playbackSpeed}x',
              style: TextStyle(
                color: mainColor,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
