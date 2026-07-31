import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/broadcast_model.dart';

/// OverlayBuilderScreen — Layout & Position Editor
/// Configure which elements appear on screen (Score, Batsmen, Bowler, Sponsor, Chat)
class OverlayBuilderScreen extends StatefulWidget {
  final BroadcastOverlayConfig initialConfig;

  const OverlayBuilderScreen({
    super.key,
    required this.initialConfig,
  });

  @override
  State<OverlayBuilderScreen> createState() => _OverlayBuilderScreenState();
}

class _OverlayBuilderScreenState extends State<OverlayBuilderScreen> {
  late bool _showScorecard;
  late bool _showBatsmen;
  late bool _showBowler;
  late bool _showSponsor;
  late bool _showChat;
  late bool _showReplays;

  @override
  void initState() {
    super.initState();
    _showScorecard = widget.initialConfig.showScorecard;
    _showBatsmen = widget.initialConfig.showBatsmen;
    _showBowler = widget.initialConfig.showBowler;
    _showSponsor = widget.initialConfig.showSponsor;
    _showChat = widget.initialConfig.showChat;
    _showReplays = widget.initialConfig.showReplays;
  }

  BroadcastOverlayConfig get _updatedConfig {
    return widget.initialConfig.copyWith(
      showScorecard: _showScorecard,
      showBatsmen: _showBatsmen,
      showBowler: _showBowler,
      showSponsor: _showSponsor,
      showChat: _showChat,
      showReplays: _showReplays,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Overlay Layout Builder',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _updatedConfig);
            },
            child: Text(
              'Apply',
              style: TextStyle(
                color: const Color(0xFFFF8D48),
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Text(
            'ELEMENT VISIBILITY & POSITIONS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12.h),

          _buildToggleTile(
            title: 'Main Scoreboard Banner',
            subtitle: 'Runs, Wickets, Overs, & Run Rate bar at top',
            icon: Icons.scoreboard_outlined,
            value: _showScorecard,
            onChanged: (v) => setState(() => _showScorecard = v),
          ),
          SizedBox(height: 10.h),

          _buildToggleTile(
            title: 'Striker & Non-Striker Strip',
            subtitle: 'Current batsmen runs, balls, 4s, 6s & strike indicator',
            icon: Icons.sports_cricket_outlined,
            value: _showBatsmen,
            onChanged: (v) => setState(() => _showBatsmen = v),
          ),
          SizedBox(height: 10.h),

          _buildToggleTile(
            title: 'Current Bowler Strip',
            subtitle: 'Bowler overs, maidens, runs, wickets & current over dots',
            icon: Icons.sports_baseball_outlined,
            value: _showBowler,
            onChanged: (v) => setState(() => _showBowler = v),
          ),
          SizedBox(height: 10.h),

          _buildToggleTile(
            title: 'Sponsor & Brand Ticker',
            subtitle: 'Display sponsor logo and tagline on broadcast',
            icon: Icons.stars_rounded,
            value: _showSponsor,
            onChanged: (v) => setState(() => _showSponsor = v),
          ),
          SizedBox(height: 10.h),

          _buildToggleTile(
            title: 'Live Chat Overlay',
            subtitle: 'Semi-transparent chat messages from audience',
            icon: Icons.chat_bubble_outline,
            value: _showChat,
            onChanged: (v) => setState(() => _showChat = v),
          ),
          SizedBox(height: 10.h),

          _buildToggleTile(
            title: 'Instant Replays & Highlights',
            subtitle: 'Trigger instant replay banners on boundary & wicket balls',
            icon: Icons.replay_circle_filled_outlined,
            value: _showReplays,
            onChanged: (v) => setState(() => _showReplays = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF15102A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? const Color(0xFFFF8D48).withOpacity(0.5) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: value ? const Color(0xFFFF8D48).withOpacity(0.15) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFFFF8D48) : Colors.white54,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFFFF8D48),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
