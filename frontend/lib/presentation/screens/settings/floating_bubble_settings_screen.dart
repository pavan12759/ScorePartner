import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/providers/floating_bubble_provider.dart';

/// Full settings screen for the Floating Live Score Bubble feature.
///
/// Allows users to configure:
/// - Enable/disable bubble
/// - Bubble size (small/medium/large)
/// - Transparency
/// - Lock position
/// - Auto-close after match
/// - Vibration for wickets
/// - Sound effects
/// - Reset to defaults
class FloatingBubbleSettingsScreen extends StatelessWidget {
  const FloatingBubbleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only supported on Android
    if (kIsWeb || !Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Floating Score')),
        body: const Center(
          child: Text('Floating Score Bubble is only available on Android.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Floating Score Bubble'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Consumer<FloatingBubbleProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ──
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryOrange.withOpacity(0.08),
                        AppTheme.primaryOrange.withOpacity(0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppTheme.primaryOrange.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bubble_chart_rounded,
                          color: AppTheme.primaryOrange,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Floating Live Score',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'View live scores over other apps',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // ── Enable/Disable ──
                _buildSectionTitle('General'),
                _buildToggleTile(
                  icon: Icons.toggle_on_outlined,
                  title: 'Enable Floating Bubble',
                  subtitle: 'Show floating score bubble for pinned matches',
                  value: provider.isEnabled,
                  onChanged: (v) => provider.setEnabled(v),
                ),

                SizedBox(height: 20.h),

                // ── Appearance ──
                _buildSectionTitle('Appearance'),
                _buildSizeSelectorTile(context, provider),
                SizedBox(height: 8.h),
                _buildTransparencyTile(context, provider),

                SizedBox(height: 20.h),

                // ── Behaviour ──
                _buildSectionTitle('Behaviour'),
                _buildToggleTile(
                  icon: Icons.lock_outline,
                  title: 'Lock Position',
                  subtitle: 'Prevent accidental dragging',
                  value: provider.lockPosition,
                  onChanged: provider.isEnabled
                      ? (v) => provider.setLockPosition(v)
                      : null,
                ),
                _buildToggleTile(
                  icon: Icons.timer_outlined,
                  title: 'Auto Close After Match',
                  subtitle: 'Automatically dismiss when match ends',
                  value: provider.autoClose,
                  onChanged: provider.isEnabled
                      ? (v) => provider.setAutoClose(v)
                      : null,
                ),

                SizedBox(height: 20.h),

                // ── Feedback ──
                _buildSectionTitle('Feedback'),
                _buildToggleTile(
                  icon: Icons.vibration,
                  title: 'Vibrate on Wickets',
                  subtitle: 'Haptic feedback when a wicket falls',
                  value: provider.vibrateWickets,
                  onChanged: provider.isEnabled
                      ? (v) => provider.setVibrateWickets(v)
                      : null,
                ),
                _buildToggleTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound Effects',
                  subtitle: 'Audio alerts for boundaries and wickets',
                  value: provider.soundEffects,
                  onChanged: provider.isEnabled
                      ? (v) => provider.setSoundEffects(v)
                      : null,
                ),

                SizedBox(height: 24.h),

                // ── Status ──
                if (provider.isActive) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Bubble is currently active',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // ── Reset Button ──
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmReset(context, provider),
                    icon: Icon(
                      Icons.restart_alt,
                      color: Colors.grey.shade600,
                      size: 18.sp,
                    ),
                    label: Text(
                      'Reset to Defaults',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppTheme.primaryOrange, size: 22.sp),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: onChanged != null ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.grey.shade500,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryOrange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _buildSizeSelectorTile(
      BuildContext context, FloatingBubbleProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.aspect_ratio, color: AppTheme.primaryOrange, size: 22.sp),
              SizedBox(width: 12.w),
              Text(
                'Bubble Size',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSizeOption(
                context, provider, 'small', 'S', 32,
              ),
              _buildSizeOption(
                context, provider, 'medium', 'M', 40,
              ),
              _buildSizeOption(
                context, provider, 'large', 'L', 48,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizeOption(
    BuildContext context,
    FloatingBubbleProvider provider,
    String value,
    String label,
    int previewSize,
  ) {
    final isSelected = provider.bubbleSize == value;
    return GestureDetector(
      onTap: provider.isEnabled ? () => provider.setBubbleSize(value) : null,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: previewSize.w,
            height: previewSize.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppTheme.primaryOrange.withOpacity(0.15)
                  : Colors.grey.shade100,
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryOrange
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppTheme.primaryOrange
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value[0].toUpperCase() + value.substring(1),
            style: TextStyle(
              fontSize: 10.sp,
              color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade500,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparencyTile(
      BuildContext context, FloatingBubbleProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.opacity, color: AppTheme.primaryOrange, size: 22.sp),
              SizedBox(width: 12.w),
              Text(
                'Transparency',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(provider.transparency * 100).round()}%',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryOrange,
              inactiveTrackColor: AppTheme.primaryOrange.withOpacity(0.15),
              thumbColor: AppTheme.primaryOrange,
              overlayColor: AppTheme.primaryOrange.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: provider.transparency,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              onChanged: provider.isEnabled
                  ? (v) => provider.setTransparency(v)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, FloatingBubbleProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Reset Settings?'),
        content: const Text(
          'This will reset all floating bubble settings to their default values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetToDefaults();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
