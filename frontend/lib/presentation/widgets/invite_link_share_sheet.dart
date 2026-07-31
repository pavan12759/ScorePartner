import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';

/// Bottom sheet for generating, sharing, and managing team invite links
class InviteLinkShareSheet extends StatefulWidget {
  final TeamModel team;

  const InviteLinkShareSheet({super.key, required this.team});

  @override
  State<InviteLinkShareSheet> createState() => _InviteLinkShareSheetState();
}

class _InviteLinkShareSheetState extends State<InviteLinkShareSheet> {
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  bool _isGenerating = false;
  bool _isRevoking = false;
  String? _inviteLink;
  bool _linkEnabled = false;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _loadExistingLink();
  }

  void _loadExistingLink() {
    final team = widget.team;
    if (team.inviteLinkEnabled && team.inviteToken.isNotEmpty) {
      // Check if not expired
      if (team.inviteExpiry == null || DateTime.now().isBefore(team.inviteExpiry!)) {
        _inviteLink = 'https://scorepartner.in/join/team/${team.id}?invite=${team.inviteToken}';
        _linkEnabled = true;
        _expiry = team.inviteExpiry;
      }
    }
  }

  Future<void> _generateLink() async {
    setState(() => _isGenerating = true);
    try {
      final link = await _dataService.generateInviteLink(widget.team.id);
      if (link != null && mounted) {
        setState(() {
          _inviteLink = link;
          _linkEnabled = true;
          _expiry = DateTime.now().add(const Duration(days: 7));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invite link generated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to generate link: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _revokeLink() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Invite Link'),
        content: const Text('This will disable the current invite link. Anyone with the old link will no longer be able to use it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRevoking = true);
    try {
      final success = await _dataService.revokeInviteLink(widget.team.id);
      if (success && mounted) {
        setState(() {
          _inviteLink = null;
          _linkEnabled = false;
          _expiry = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite link revoked'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  void _copyLink() {
    if (_inviteLink == null) return;
    Clipboard.setData(ClipboardData(text: _inviteLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Link copied to clipboard!'), backgroundColor: Colors.green),
    );
  }

  void _shareVia(String platform) {
    if (_inviteLink == null) return;
    final message = 'Join my cricket team "${widget.team.name}" on ScorePartner! 🏏\n\n$_inviteLink';

    switch (platform) {
      case 'whatsapp':
        _launchUrl('https://wa.me/?text=${Uri.encodeComponent(message)}');
        break;
      case 'telegram':
        _launchUrl('https://t.me/share/url?url=${Uri.encodeComponent(_inviteLink!)}&text=${Uri.encodeComponent('Join my cricket team "${widget.team.name}" on ScorePartner! 🏏')}');
        break;
      case 'sms':
        _launchUrl('sms:?body=${Uri.encodeComponent(message)}');
        break;
      case 'email':
        _launchUrl('mailto:?subject=${Uri.encodeComponent('Join ${widget.team.name} on ScorePartner')}&body=${Uri.encodeComponent(message)}');
        break;
      case 'share':
        Share.share(message);
        break;
      default:
        Share.share(message);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to native share
        _shareVia('share');
      }
    } catch (_) {
      _shareVia('share');
    }
  }

  String _formatExpiry() {
    if (_expiry == null) return '';
    final diff = _expiry!.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return 'Expires in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours > 0) return 'Expires in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    return 'Expires soon';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),

              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.link, color: AppTheme.primaryOrange, size: 24.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Player',
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Share a link to invite players to ${widget.team.name}',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // Link display / generate area
              if (_inviteLink != null && _linkEnabled) ...[
                // Link card
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16.sp),
                          SizedBox(width: 6.w),
                          Text(
                            'Link Active',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatExpiry(),
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        _inviteLink!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.primaryOrange,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Share buttons grid
                Text(
                  'Share via',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareButton(Icons.content_copy, 'Copy', Colors.blueGrey, () => _copyLink()),
                    _buildShareButton(Icons.chat, 'WhatsApp', const Color(0xFF25D366), () => _shareVia('whatsapp')),
                    _buildShareButton(Icons.send, 'Telegram', const Color(0xFF0088CC), () => _shareVia('telegram')),
                    _buildShareButton(Icons.sms, 'SMS', Colors.deepPurple, () => _shareVia('sms')),
                    _buildShareButton(Icons.email, 'Email', Colors.red, () => _shareVia('email')),
                    _buildShareButton(Icons.share, 'More', Colors.teal, () => _shareVia('share')),
                  ],
                ),

                SizedBox(height: 16.h),

                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRevoking ? null : _revokeLink,
                        icon: _isRevoking
                            ? SizedBox(width: 16.w, height: 16.h, child: const CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.link_off, size: 18.sp),
                        label: const Text('Revoke'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateLink,
                        icon: _isGenerating
                            ? SizedBox(width: 16.w, height: 16.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(Icons.refresh, size: 18.sp),
                        label: const Text('Regenerate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // No link yet — show generate CTA
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.link_off, size: 48.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text(
                        'No active invite link',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Generate a link to invite players to join your team',
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _generateLink,
                          icon: _isGenerating
                              ? SizedBox(width: 18.w, height: 18.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.link, size: 20.sp),
                          label: Text(_isGenerating ? 'Generating...' : 'Generate Invite Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
