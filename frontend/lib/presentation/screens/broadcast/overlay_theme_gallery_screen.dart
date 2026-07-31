import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Overlay theme gallery with animated preview cards for every broadcast style.
/// Each card shows a mini score preview rendered in that theme's style.
class OverlayThemeGalleryScreen extends StatefulWidget {
  final String currentThemeId;
  final MatchModel? match;

  const OverlayThemeGalleryScreen({
    super.key,
    required this.currentThemeId,
    this.match,
  });

  @override
  State<OverlayThemeGalleryScreen> createState() =>
      _OverlayThemeGalleryScreenState();
}

class _OverlayThemeGalleryScreenState extends State<OverlayThemeGalleryScreen> {
  late String _selectedThemeId;
  String _filterCategory = 'All';

  final List<String> _categories = [
    'All',
    'Classic',
    'Modern',
    'Premium',
    'ScorePartner',
    'Gaming',
    'Clean',
    'Events',
    'Night',
    'Vintage',
    'Casual',
    'Apple',
    'Broadcast',
    'Compact',
    'League Style',
    'Subtle',
    'Sports',
  ];

  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.currentThemeId;
  }

  List<OverlayThemeData> get _filteredThemes {
    if (_filterCategory == 'All') return OverlayThemes.all;
    return OverlayThemes.all
        .where((t) => t.category == _filterCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Overlay Themes',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, OverlayThemes.getById(_selectedThemeId));
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
      body: Column(
        children: [
          // Category filter
          _buildCategoryFilter(),
          SizedBox(height: 8.h),
          // Theme grid
          Expanded(child: _buildThemeGrid()),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 36.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _filterCategory;

          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _filterCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF8D48)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 11.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeGrid() {
    final themes = _filteredThemes;

    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.75,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) => _buildThemeCard(themes[index]),
    );
  }

  Widget _buildThemeCard(OverlayThemeData theme) {
    final isSelected = theme.id == _selectedThemeId;

    return GestureDetector(
      onTap: () => setState(() => _selectedThemeId = theme.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF8D48)
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8D48).withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Theme preview background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.gradientStart, theme.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Dark overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Mini score preview
              Positioned(
                left: 8.w,
                right: 8.w,
                top: 20.h,
                child: _buildMiniPreview(theme),
              ),

              // Theme info at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (theme.isPremium)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 1.h,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA000),
                                      ],
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
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            theme.category,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF8D48),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8D48).withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 14.sp),
                  ),
                ),

              // Special effects badges
              if (theme.hasNeonBorder || theme.hasScanlines || theme.hasShimmer)
                Positioned(
                  top: 6.h,
                  left: 6.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '✨ FX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPreview(OverlayThemeData theme) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(
          theme.transparency.clamp(0.3, 0.9),
        ),
        borderRadius: BorderRadius.circular(theme.cornerRadius.clamp(0, 16)),
        border: theme.borderWidth > 0
            ? Border.all(
                color: theme.borderColor,
                width: theme.borderWidth.clamp(0.5, 2),
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini live badge
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 6.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          // Team 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team A',
                style: TextStyle(
                  color: theme.teamNameColor,
                  fontSize: 9.sp,
                  fontWeight: theme.teamNameFontWeight,
                ),
              ),
              Text(
                '186/4',
                style: TextStyle(
                  color: theme.scoreColor,
                  fontSize: 12.sp,
                  fontWeight: theme.scoreFontWeight,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(height: 0.5, color: theme.dividerColor),
          SizedBox(height: 2.h),
          // Team 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team B',
                style: TextStyle(
                  color: theme.teamNameColor.withOpacity(0.6),
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '142/7',
                style: TextStyle(
                  color: theme.scoreColor.withOpacity(0.6),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
