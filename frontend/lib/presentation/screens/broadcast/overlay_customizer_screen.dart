import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/broadcast/overlay_theme_data.dart';
import '../../../data/models/match_model.dart';

/// OverlayCustomizerScreen — Visual editor for tuning overlay parameters
/// (Colors, Transparency, Corner Radius, Border Width, & Fonts) in real time.
class OverlayCustomizerScreen extends StatefulWidget {
  final OverlayThemeData initialTheme;
  final MatchModel? match;

  const OverlayCustomizerScreen({
    super.key,
    required this.initialTheme,
    this.match,
  });

  @override
  State<OverlayCustomizerScreen> createState() => _OverlayCustomizerScreenState();
}

class _OverlayCustomizerScreenState extends State<OverlayCustomizerScreen> {
  late Color _bgColor;
  late Color _scoreColor;
  late Color _accentColor;
  late double _transparency;
  late double _cornerRadius;
  late double _borderWidth;

  final List<Color> _presetColors = [
    const Color(0xFF0F0C20),
    const Color(0xFF0D2818),
    const Color(0xFF1E1035),
    const Color(0xFF261105),
    const Color(0xFF000000),
    const Color(0xFFFF8D48),
    const Color(0xFFFF3B30),
    const Color(0xFF2196F3),
    const Color(0xFF00E676),
    const Color(0xFFFFD700),
  ];

  @override
  void initState() {
    super.initState();
    _loadFromTheme(widget.initialTheme);
  }

  void _loadFromTheme(OverlayThemeData theme) {
    _bgColor = theme.backgroundColor;
    _scoreColor = theme.scoreColor;
    _accentColor = theme.accentColor;
    _transparency = theme.transparency;
    _cornerRadius = theme.cornerRadius;
    _borderWidth = theme.borderWidth;
  }

  OverlayThemeData get _customizedTheme {
    return widget.initialTheme.copyWith(
      backgroundColor: _bgColor,
      scoreColor: _scoreColor,
      accentColor: _accentColor,
      transparency: _transparency,
      cornerRadius: _cornerRadius,
      borderWidth: _borderWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _customizedTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Customizer & Style',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _loadFromTheme(widget.initialTheme));
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, theme);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: const Color(0xFFFF8D48),
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Preview Header Card
          Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF15102A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE OVERLAY PREVIEW',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildLivePreviewWidget(theme),
              ],
            ),
          ),

          // Customizer Settings Controls
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                _buildSectionHeader('BACKGROUND COLOR'),
                SizedBox(height: 8.h),
                _buildColorPalette((color) => setState(() => _bgColor = color), _bgColor),

                SizedBox(height: 20.h),
                _buildSectionHeader('SCORE TEXT COLOR'),
                SizedBox(height: 8.h),
                _buildColorPalette((color) => setState(() => _scoreColor = color), _scoreColor),

                SizedBox(height: 20.h),
                _buildSectionHeader('ACCENT HIGHLIGHT COLOR'),
                SizedBox(height: 8.h),
                _buildColorPalette((color) => setState(() => _accentColor = color), _accentColor),

                SizedBox(height: 20.h),
                _buildSliderTile(
                  label: 'Background Transparency',
                  value: _transparency,
                  min: 0.1,
                  max: 1.0,
                  valueDisplay: '${(_transparency * 100).toInt()}%',
                  onChanged: (v) => setState(() => _transparency = v),
                ),

                SizedBox(height: 12.h),
                _buildSliderTile(
                  label: 'Corner Radius',
                  value: _cornerRadius,
                  min: 0.0,
                  max: 24.0,
                  valueDisplay: '${_cornerRadius.toInt()}px',
                  onChanged: (v) => setState(() => _cornerRadius = v),
                ),

                SizedBox(height: 12.h),
                _buildSliderTile(
                  label: 'Border Width',
                  value: _borderWidth,
                  min: 0.0,
                  max: 4.0,
                  valueDisplay: '${_borderWidth.toStringAsFixed(1)}px',
                  onChanged: (v) => setState(() => _borderWidth = v),
                ),

                SizedBox(height: 30.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewWidget(OverlayThemeData theme) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(theme.transparency),
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        border: theme.borderWidth > 0
            ? Border.all(color: theme.borderColor, width: theme.borderWidth)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INDIA',
                style: TextStyle(
                  color: theme.teamNameColor,
                  fontSize: 14.sp,
                  fontWeight: theme.teamNameFontWeight,
                ),
              ),
              Text(
                '186 / 4',
                style: TextStyle(
                  color: theme.scoreColor,
                  fontSize: 18.sp,
                  fontWeight: theme.scoreFontWeight,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overs: 18.4  |  CRR: 9.96',
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.7),
                  fontSize: 11.sp,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TARGET 210',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white54,
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildColorPalette(ValueChanged<Color> onSelected, Color activeColor) {
    return SizedBox(
      height: 36.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _presetColors.length,
        itemBuilder: (context, index) {
          final color = _presetColors[index];
          final isSelected = color.value == activeColor.value;

          return GestureDetector(
            onTap: () => onSelected(color),
            child: Container(
              width: 36.w,
              height: 36.w,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF8D48) : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueDisplay,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF15102A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                valueDisplay,
                style: TextStyle(color: const Color(0xFFFF8D48), fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFF8D48),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: const Color(0xFFFF8D48),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
