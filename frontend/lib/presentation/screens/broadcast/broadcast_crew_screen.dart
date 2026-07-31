import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/models/broadcast_model.dart';

/// BroadcastCrewScreen — Manage roles (Camera, Scorer, Commentary, Moderator) & 6-digit invite codes.
class BroadcastCrewScreen extends StatefulWidget {
  final BroadcastSession broadcast;

  const BroadcastCrewScreen({
    super.key,
    required this.broadcast,
  });

  @override
  State<BroadcastCrewScreen> createState() => _BroadcastCrewScreenState();
}

class _BroadcastCrewScreenState extends State<BroadcastCrewScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.broadcast.crewCode ?? '849201';
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _codeController.text));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Crew Invite Code copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
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
          'Broadcast Crew & Team',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Invite Code & QR Card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF15102A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text(
                  '6-DIGIT CREW INVITE CODE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _codeController.text,
                      style: TextStyle(
                        color: const Color(0xFFFF8D48),
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    IconButton(
                      icon: Icon(
                        _isCopied ? Icons.check_circle : Icons.copy,
                        color: _isCopied ? Colors.green : Colors.white70,
                      ),
                      onPressed: _copyCode,
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // QR Code
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: 'scorepartner://crew/${widget.broadcast.id}/${_codeController.text}',
                    version: QrVersions.auto,
                    size: 140.w,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Scan QR code or enter 6-digit code in app to join as crew',
                  style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),
          Text(
            'ACTIVE CREW MEMBERS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12.h),

          // List of Roles
          _buildCrewRoleItem(
            name: 'Broadcast Owner (You)',
            role: 'Producer & Director',
            icon: Icons.video_camera_front_rounded,
            color: const Color(0xFFFF8D48),
          ),
          SizedBox(height: 8.h),
          _buildCrewRoleItem(
            name: 'Camera Operator #1',
            role: 'Main Pitch Camera',
            icon: Icons.videocam,
            color: Colors.blueAccent,
          ),
          SizedBox(height: 8.h),
          _buildCrewRoleItem(
            name: 'Match Scorer',
            role: 'Ball-by-Ball Sync Admin',
            icon: Icons.edit_note_rounded,
            color: Colors.greenAccent,
          ),
          SizedBox(height: 8.h),
          _buildCrewRoleItem(
            name: 'Commentary & Chat Mod',
            role: 'Live Chat Moderator',
            icon: Icons.record_voice_over,
            color: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildCrewRoleItem({
    required String name,
    required String role,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF15102A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  role,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ONLINE',
              style: TextStyle(
                color: Colors.green,
                fontSize: 9.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
