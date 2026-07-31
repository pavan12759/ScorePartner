import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/broadcast_service.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../../core/broadcast/overlay_theme_data.dart';
import '../../providers/broadcast_provider.dart';
import '../../widgets/broadcast/score_overlay_widget.dart';
import 'overlay_theme_gallery_screen.dart';
import 'broadcast_control_screen.dart';

/// Pre-broadcast setup screen — choose match, overlay theme, and go live.
/// Provides a live preview of the selected overlay theme.
class GoLiveScreen extends StatefulWidget {
  final String? preselectedMatchId;

  const GoLiveScreen({super.key, this.preselectedMatchId});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen>
    with TickerProviderStateMixin {
  OverlayThemeData _selectedTheme = OverlayThemes.scorePartnerPremium;
  String? _selectedMatchId;
  MatchModel? _selectedMatch;
  bool _isLoading = false;
  bool _isGoingLive = false;
  List<MatchModel> _liveMatches = [];

  late AnimationController _glowController;
  late AnimationController _countdownController;
  bool _showCountdown = false;
  int _countdownValue = 3;
  bool _halfScreenCapture = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _selectedMatchId = widget.preselectedMatchId;
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get user's live matches
      final matches = await FirebaseDataService.instance.getUserMatches(uid);
      final liveMatches = matches
          .where((m) => m.status == 'live' || m.status == 'in-progress')
          .toList();

      setState(() {
        _liveMatches = liveMatches;
        _isLoading = false;
      });

      // Auto-select preselected match
      if (_selectedMatchId != null) {
        final match = liveMatches.where((m) => m.id == _selectedMatchId).toList();
        if (match.isNotEmpty) {
          setState(() => _selectedMatch = match.first);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF050510), Color(0xFF0A0A1A), Color(0xFF0D1117)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: _showCountdown ? _buildCountdown() : _buildSetupContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupContent() {
    return Column(
      children: [
        // App bar
        _buildAppBar(),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),

                // Preview area
                _buildPreview(),

                SizedBox(height: 24.h),

                // Select Match
                _buildSectionHeader('SELECT MATCH', Icons.sports_cricket),
                SizedBox(height: 8.h),
                _buildMatchSelector(),

                SizedBox(height: 20.h),

                // Select Theme
                _buildSectionHeader('OVERLAY THEME', Icons.palette_outlined),
                SizedBox(height: 8.h),
                _buildThemeSelector(),

                SizedBox(height: 20.h),

                // Capture layout
                _buildSectionHeader('CAPTURE LAYOUT', Icons.view_agenda_outlined),
                SizedBox(height: 8.h),
                _buildCaptureLayoutSelector(),

                SizedBox(height: 20.h),

                // Settings
                _buildSectionHeader('BROADCAST SETTINGS', Icons.settings_outlined),
                SizedBox(height: 8.h),
                _buildSettings(),

                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),

        // GO LIVE button
        _buildGoLiveButton(),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ScorePartner Live+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Set up your broadcast',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8D48), Color(0xFFFF6B35)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'LIVE+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200.h,
        decoration: BoxDecoration(
          color: const Color(0xFF0D2818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            // Field background
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    const Color(0xFF0D2818).withOpacity(0.9),
                    const Color(0xFF050510),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.sports_cricket,
                  color: Colors.white.withOpacity(0.08),
                  size: 60.sp,
                ),
              ),
            ),
            // Overlay preview
            if (_selectedMatch != null)
              Positioned(
                left: 8.w,
                right: 8.w,
                bottom: 8.h,
                child: Transform.scale(
                  scale: 0.85,
                  alignment: Alignment.bottomCenter,
                  child: ScoreOverlayWidget(
                    match: _selectedMatch!,
                    theme: _selectedTheme,
                    viewerCount: 0,
                    showLiveIndicator: true,
                  ),
                ),
              ),
            // "Preview" badge
            Positioned(
              top: 8.h,
              right: 8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PREVIEW',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF8D48), size: 16.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSelector() {
    if (_isLoading) {
      return Container(
        height: 56.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8D48), strokeWidth: 2),
        ),
      );
    }

    if (_liveMatches.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white38, size: 18.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'No live matches found. Start scoring a match first.',
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMatchId,
          hint: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(
              'Choose a match...',
              style: TextStyle(color: Colors.white38, fontSize: 13.sp),
            ),
          ),
          dropdownColor: const Color(0xFF1A1A2E),
          isExpanded: true,
          icon: Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: Icon(Icons.expand_more, color: Colors.white38, size: 20.sp),
          ),
          items: _liveMatches.map((match) {
            return DropdownMenuItem<String>(
              value: match.id,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '${match.team1Name} vs ${match.team2Name}',
                        style: TextStyle(color: Colors.white, fontSize: 13.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              _selectedMatchId = id;
              _selectedMatch = _liveMatches.firstWhere((m) => m.id == id);
            });
          },
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<OverlayThemeData>(
          context,
          MaterialPageRoute(
            builder: (_) => OverlayThemeGalleryScreen(
              currentThemeId: _selectedTheme.id,
              match: _selectedMatch,
            ),
          ),
        );
        if (result != null) {
          setState(() => _selectedTheme = result);
        }
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            // Theme color preview
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [_selectedTheme.gradientStart, _selectedTheme.gradientEnd],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Center(
                child: Text(
                  _selectedTheme.name[0],
                  style: TextStyle(
                    color: _selectedTheme.textColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedTheme.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_selectedTheme.isPremium) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 7.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _selectedTheme.category,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38, size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          _buildSettingRow('Live Chat', Icons.chat_outlined, true, (_) {}),
          Divider(height: 1, color: Colors.white.withOpacity(0.08)),
          _buildSettingRow('Emoji Reactions', Icons.emoji_emotions_outlined, true, (_) {}),
          Divider(height: 1, color: Colors.white.withOpacity(0.08)),
          _buildSettingRow('Auto Highlights', Icons.auto_awesome, true, (_) {}),
          Divider(height: 1, color: Colors.white.withOpacity(0.08)),
          _buildSettingRow('Event Animations', Icons.animation, true, (_) {}),
        ],
      ),
    );
  }

  Widget _buildCaptureLayoutSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCaptureLayoutOption(
              title: 'Full screen',
              subtitle: 'Camera fills the screen',
              icon: Icons.fullscreen,
              halfScreen: false,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: _buildCaptureLayoutOption(
              title: 'Half screen',
              subtitle: 'Camera plus controls',
              icon: Icons.vertical_split,
              halfScreen: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureLayoutOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool halfScreen,
  }) {
    final selected = _halfScreenCapture == halfScreen;
    return GestureDetector(
      onTap: () => setState(() => _halfScreenCapture = halfScreen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF8D48).withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF8D48)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFFFF8D48) : Colors.white54,
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF8D48),
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildGoLiveButton() {
    final isReady = _selectedMatchId != null;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, const Color(0xFF050510).withOpacity(0.95)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isReady
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withOpacity(0.3 + _glowController.value * 0.2),
                        blurRadius: 20 + _glowController.value * 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: isReady && !_isGoingLive ? _startCountdown : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isReady ? const Color(0xFFFF3B30) : Colors.grey.shade800,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 54.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isGoingLive
                  ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'GO LIVE',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.5 + value * 0.5,
            child: Opacity(
              opacity: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_countdownValue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 96.sp,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFF3B30).withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Going Live...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdownValue = 3;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _countdownValue = 2);

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _countdownValue = 1);

        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          _goLive();
        });
      });
    });
  }

  Future<void> _goLive() async {
    setState(() => _isGoingLive = true);

    try {
      final broadcast = await BroadcastService.instance.startBroadcast(
        matchId: _selectedMatchId!,
        overlayThemeId: _selectedTheme.id,
      );

      if (broadcast != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BroadcastControlScreen(
              broadcastId: broadcast.id,
              matchId: _selectedMatchId!,
              halfScreenCapture: _halfScreenCapture,
            ),
          ),
        );
      } else if (mounted) {
        setState(() {
          _isGoingLive = false;
          _showCountdown = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start broadcast: Initialization returned null. Check permissions.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoingLive = false;
          _showCountdown = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start broadcast: $e')),
        );
      }
    }
  }
}
