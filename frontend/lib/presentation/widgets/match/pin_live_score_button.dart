import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/providers/floating_bubble_provider.dart';

/// A reusable button/icon for pinning a live match to the floating bubble.
///
/// Usage: Place in app bar actions or match card context menu.
/// Only visible on Android for live matches.
class PinLiveScoreButton extends StatelessWidget {
  final String matchId;
  final String team1Name;
  final String team2Name;
  final bool isLive;

  /// If true, renders as an IconButton (for app bar).
  /// If false, renders as a full text button.
  final bool iconOnly;

  const PinLiveScoreButton({
    super.key,
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    this.isLive = true,
    this.iconOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on Android, for live matches
    if (kIsWeb || !Platform.isAndroid || !isLive) {
      return const SizedBox.shrink();
    }

    return Consumer<FloatingBubbleProvider>(
      builder: (context, provider, _) {
        final isPinned = provider.isMatchPinned(matchId);
        final isOtherPinned =
            provider.isActive && !isPinned && provider.pinnedMatchId != null;

        if (iconOnly) {
          return IconButton(
            icon: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: isPinned ? AppTheme.primaryOrange : Colors.black87,
            ),
            tooltip: isPinned ? 'Unpin Live Score' : 'Pin Live Score',
            onPressed: provider.isLoading
                ? null
                : () => _handleTap(context, provider, isPinned, isOtherPinned),
          );
        }

        // Full button variant
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: provider.isLoading
                ? null
                : () => _handleTap(context, provider, isPinned, isOtherPinned),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isPinned
                    ? AppTheme.primaryOrange.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isPinned
                      ? AppTheme.primaryOrange.withOpacity(0.3)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.isLoading)
                    SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryOrange,
                      ),
                    )
                  else
                    Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 16.sp,
                      color: isPinned
                          ? AppTheme.primaryOrange
                          : Colors.grey.shade700,
                    ),
                  SizedBox(width: 8.w),
                  Text(
                    isPinned ? 'Pinned ✓' : '📌 Pin Live Score',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isPinned
                          ? AppTheme.primaryOrange
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    FloatingBubbleProvider provider,
    bool isPinned,
    bool isOtherPinned,
  ) async {
    if (isPinned) {
      // Unpin
      await provider.unpinMatch();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📌 Live score unpinned'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.grey,
          ),
        );
      }
      return;
    }

    // If another match is pinned, ask for confirmation
    if (isOtherPinned) {
      final confirmed = await _showReplaceDialog(context);
      if (!confirmed || !context.mounted) return;
    }

    // Pin the match
    final success = await provider.pinMatch(matchId);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📌 $team1Name vs $team2Name pinned!'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
    } else {
      // Permission denied or error
      _showPermissionExplanation(context);
    }
  }

  Future<bool> _showReplaceDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.swap_horiz, color: AppTheme.primaryOrange),
                SizedBox(width: 8.w),
                const Expanded(child: Text('Replace Pinned Match?')),
              ],
            ),
            content: Text(
              'Another match is currently pinned. Replacing it will show $team1Name vs $team2Name instead.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showPermissionExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryOrange),
            SizedBox(width: 8.w),
            const Expanded(child: Text('Permission Required')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ScorePartner needs the "Display over other apps" permission to show live scores while you use other apps.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
            ),
            SizedBox(height: 12.h),
            Text(
              'Please go to Settings → Apps → ScorePartner → Display over other apps and enable it.',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it',
              style: TextStyle(color: AppTheme.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }
}
