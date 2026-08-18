import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_summary_poster_data.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'match_summary_theme.dart';
import 'match_poster_customization.dart';
import 'match_summary_poster_card.dart';

/// Main screen for generating, previewing, customizing, downloading
/// and sharing a match summary poster. Purely a presentation layer —
/// it never modifies match statistics.
class MatchSummaryPosterScreen extends StatefulWidget {
  final String matchId;

  const MatchSummaryPosterScreen({super.key, required this.matchId});

  @override
  State<MatchSummaryPosterScreen> createState() =>
      _MatchSummaryPosterScreenState();
}

class _MatchSummaryPosterScreenState extends State<MatchSummaryPosterScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final MatchPosterCustomization _customization = MatchPosterCustomization();
  final ImagePicker _imagePicker = ImagePicker();


  MatchSummaryPosterData? _posterData;
  String? _team1LogoUrl;
  String? _team2LogoUrl;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  // Cache
  Uint8List? _cachedImage;
  int _cachedVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadMatchData();
    _customization.addListener(_onCustomizationChanged);
  }

  @override
  void dispose() {
    _customization.removeListener(_onCustomizationChanged);
    _customization.dispose();
    super.dispose();
  }

  void _onCustomizationChanged() {
    setState(() {});
  }

  Future<void> _loadMatchData() async {
    try {
      final match =
          await FirebaseDataService.instance.getMatchById(widget.matchId);
      if (match == null) {
        setState(() {
          _errorMessage = 'Match not found';
          _isLoading = false;
        });
        return;
      }

      // Load team logos
      String? team1Logo;
      String? team2Logo;
      try {
        final team1 =
            await FirebaseDataService.instance.getTeamById(match.team1Id);
        final team2 =
            await FirebaseDataService.instance.getTeamById(match.team2Id);
        team1Logo = team1?.logoUrl;
        team2Logo = team2?.logoUrl;
      } catch (_) {
        // Non-critical — logos are optional
      }

      setState(() {
        _posterData = MatchSummaryPosterData.fromMatch(match);
        _team1LogoUrl = team1Logo;
        _team2LogoUrl = team2Logo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load match data';
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _captureImage() async {
    // Return cached version if customization hasn't changed
    if (_cachedImage != null &&
        _cachedVersion == _customization.cacheVersion) {
      return _cachedImage;
    }

    try {
      // Wait for the current frame to finish painting
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      final image = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 200),
      );
      if (image != null) {
        _cachedImage = image;
        _cachedVersion = _customization.cacheVersion;
      }
      return image;
    } catch (e) {
      debugPrint('❌ Error capturing poster: $e');
      // Retry once after a longer delay
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await WidgetsBinding.instance.endOfFrame;
        final retryImage = await _screenshotController.capture(
          pixelRatio: 3.0,
          delay: const Duration(milliseconds: 300),
        );
        if (retryImage != null) {
          _cachedImage = retryImage;
          _cachedVersion = _customization.cacheVersion;
        }
        return retryImage;
      } catch (retryError) {
        debugPrint('❌ Retry capture also failed: $retryError');
        return null;
      }
    }
  }

  Future<void> _downloadImage() async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final image = await _captureImage();
      if (image == null) throw Exception('Capture failed');

      final fileName =
          'match_summary_${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        final xFile = XFile.fromData(image, name: fileName, mimeType: 'image/png');
        await xFile.saveTo(fileName);
      } else {
        // Save to temp file first
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(image);

        // Request gallery access and save
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(filePath, album: 'ScorePartner');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Saved to gallery! 📸'),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error downloading poster: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't create match summary."),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: _downloadImage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareImage() async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final image = await _captureImage();
      if (image == null) throw Exception('Capture failed');

      final fileName =
          'match_summary_${widget.matchId}.png';
      final caption =
          '🏏 Match Result\n\n${_posterData?.resultText ?? 'Match Completed'}\n\nMatch scored on ScorePartner.';

      if (kIsWeb) {
        final xFile = XFile.fromData(image, name: fileName, mimeType: 'image/png');
        await Share.shareXFiles([xFile], text: caption);
      } else {
        // Save to temp file for sharing
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(image);

        await Share.shareXFiles(
          [XFile(filePath)],
          text: caption,
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing poster: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't share match summary."),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: _shareImage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Match Summary'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryOrange),
          SizedBox(height: 16),
          Text(
            'Creating your match summary...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? "Couldn't create match summary.",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadMatchData();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final allThemes = MatchSummaryThemes.allWithTeamColors(
      _posterData!.team1Name,
      _posterData!.team2Name,
    );

    return Column(
      children: [
        // Preview area
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Theme selector (horizontal)
                SizedBox(
                  height: 80.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allThemes.length,
                    itemBuilder: (context, index) {
                      final theme = allThemes[index];
                      final isSelected =
                          theme.id == _customization.selectedTheme.id;
                      return GestureDetector(
                        onTap: () =>
                            _customization.selectedTheme = theme,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 90.w,
                          margin: EdgeInsets.only(right: 8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.backgroundColor,
                                theme.cardColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryOrange
                                  : Colors.white12,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                theme.icon,
                                color: theme.accentColor,
                                size: 20.sp,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                theme.name,
                                style: TextStyle(
                                  color: theme.textPrimaryColor,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16.h),

                // Aspect ratio selector
                SizedBox(
                  height: 32.h,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: PosterAspectRatio.values.map((ratio) {
                      final isSelected =
                          ratio == _customization.aspectRatio;
                      return GestureDetector(
                        onTap: () =>
                            _customization.aspectRatio = ratio,
                        child: Container(
                          margin: EdgeInsets.only(right: 8.w),
                          padding:
                              EdgeInsets.symmetric(horizontal: 12.w),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryOrange
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ratio.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16.h),

                // Poster preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: _customization.aspectRatio == PosterAspectRatio.standard
                        ? MatchSummaryPosterCard(
                            data: _posterData!,
                            theme: _customization.selectedTheme,
                            customization: _customization,
                            team1LogoUrl: _team1LogoUrl,
                            team2LogoUrl: _team2LogoUrl,
                            matchId: widget.matchId,
                          )
                        : AspectRatio(
                            aspectRatio: _customization.aspectRatio.ratio,
                            child: MatchSummaryPosterCard(
                              data: _posterData!,
                              theme: _customization.selectedTheme,
                              customization: _customization,
                              team1LogoUrl: _team1LogoUrl,
                              team2LogoUrl: _team2LogoUrl,
                              matchId: widget.matchId,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),

        // Bottom action bar
        Container(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            border: Border(
              top: BorderSide(color: Colors.white10, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Customize button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting
                        ? null
                        : () => _showCustomizeSheet(),
                    icon: Icon(Icons.tune, size: 18.sp),
                    label: Text(
                      'Customize',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Download button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _downloadImage,
                    icon: _isExporting
                        ? SizedBox(
                            width: 18.sp,
                            height: 18.sp,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.download, size: 18.sp),
                    label: Text(
                      'Download',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Share button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _shareImage,
                    icon: Icon(Icons.share, size: 18.sp),
                    label: Text(
                      'Share',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== CUSTOMIZE BOTTOM SHEET =====
  void _showCustomizeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => _CustomizeSheet(
          customization: _customization,
          scrollController: scrollController,
          imagePicker: _imagePicker,
        ),
      ),
    );
  }
}

/// Customization bottom sheet content
class _CustomizeSheet extends StatefulWidget {
  final MatchPosterCustomization customization;
  final ScrollController scrollController;
  final ImagePicker imagePicker;

  const _CustomizeSheet({
    required this.customization,
    required this.scrollController,
    required this.imagePicker,
  });

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  @override
  void initState() {
    super.initState();
    widget.customization.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.customization.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customization;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.all(20.w),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'CUSTOMIZE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 20.h),

        // === BACKGROUND ===
        _sectionTitle('Background'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterBackgroundType.values.map((type) {
            final isSelected = c.backgroundType == type;
            return ChoiceChip(
              label: Text(type.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.backgroundType = type;
                if (type == PosterBackgroundType.customImage) {
                  _pickBackgroundImage();
                }
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === FONT FAMILY ===
        _sectionTitle('Font Style'),
        SizedBox(height: 8.h),
        SizedBox(
          height: 36.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: MatchPosterCustomization.availableFonts.map((font) {
              final isSelected = c.fontFamily == font;
              return GestureDetector(
                onTap: () => c.fontFamily = font,
                child: Container(
                  margin: EdgeInsets.only(right: 8.w),
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryOrange : Colors.white10,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    font,
                    style: GoogleFonts.getFont(
                      font,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 16.h),

        // === CARD STYLE ===
        _sectionTitle('Card Style'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterCardStyle.values.map((style) {
            final isSelected = c.cardStyle == style;
            return ChoiceChip(
              label: Text(style.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.cardStyle = style;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === TEAM LOGO SIZE ===
        _sectionTitle('Team Logo Size'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterLogoSize.values.map((size) {
            final isSelected = c.teamLogoSize == size;
            return ChoiceChip(
              label: Text(size.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.teamLogoSize = size;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === SCORE EMPHASIS ===
        _sectionTitle('Score Emphasis'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterScoreEmphasis.values.map((emph) {
            final isSelected = c.scoreEmphasis == emph;
            return ChoiceChip(
              label: Text(emph.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.scoreEmphasis = emph;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === ACCENT STYLE ===
        _sectionTitle('Accent Style'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterAccentStyle.values.map((style) {
            final isSelected = c.accentStyle == style;
            return ChoiceChip(
              label: Text(style.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.accentStyle = style;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === BORDER STYLE ===
        _sectionTitle('Border Style'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterBorderStyle.values.map((style) {
            final isSelected = c.borderStyle == style;
            return ChoiceChip(
              label: Text(style.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.borderStyle = style;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === SHADOW STYLE ===
        _sectionTitle('Shadow Style'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: PosterShadowStyle.values.map((style) {
            final isSelected = c.shadowStyle == style;
            return ChoiceChip(
              label: Text(style.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.shadowStyle = style;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === COLOR SCHEME ===
        _sectionTitle('Color Scheme'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: ColorSchemeType.values.map((scheme) {
            final isSelected = c.colorScheme == scheme;
            return ChoiceChip(
              label: Text(scheme.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.colorScheme = scheme;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === SPONSOR LAYOUT ===
        _sectionTitle('Sponsor Layout'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: SponsorLayout.values.map((layout) {
            final isSelected = c.sponsorLayout == layout;
            return ChoiceChip(
              label: Text(layout.label),
              selected: isSelected,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.sp,
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.white24,
              ),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              onSelected: (sel) {
                if (sel) c.sponsorLayout = layout;
              },
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),

        // === TOP SPONSORS ===
        _sectionTitle('Top Sponsors (up to 4)'),
        SizedBox(height: 8.h),
        ...List.generate(4, (index) => _buildSponsorSlot(
            'Top Sponsor ${index + 1}',
            c.topSponsors.length > index ? c.topSponsors[index] : null,
            (image) => _updateTopSponsor(index, image),
            (v) => c.showSponsorLogo = v,
        )),
        SizedBox(height: 16.h),

        // === BOTTOM SPONSORS ===
        _sectionTitle('Bottom Sponsors (up to 4)'),
        SizedBox(height: 8.h),
        ...List.generate(4, (index) => _buildSponsorSlot(
            'Bottom Sponsor ${index + 1}',
            c.bottomSponsors.length > index ? c.bottomSponsors[index] : null,
            (image) => _updateBottomSponsor(index, image),
            (v) => c.showSponsorLogo = v,
        )),
        SizedBox(height: 16.h),

        // === SPONSOR SETTINGS ===
        _sectionTitle('Sponsor Settings'),
        SizedBox(height: 8.h),
        _sliderTile('Sponsor Height', c.sponsorHeight, 20, 80, (v) => c.sponsorHeight = v),
        _sliderTile('Sponsor Spacing', c.sponsorSpacing, 4, 40, (v) => c.sponsorSpacing = v),
        SizedBox(height: 16.h),

        // === VISIBILITY TOGGLES ===
        _sectionTitle('Show / Hide Sections'),
        SizedBox(height: 8.h),
        _toggleTile('Top Batters', c.showTopBatters,
            (v) => c.showTopBatters = v),
        _toggleTile('Top Bowlers', c.showTopBowlers,
            (v) => c.showTopBowlers = v),
        _toggleTile('Player of Match', c.showPlayerOfMatch,
            (v) => c.showPlayerOfMatch = v),
        _toggleTile('Match Result', c.showMatchResult,
            (v) => c.showMatchResult = v),
        _toggleTile('Tournament Name', c.showTournamentLogo,
            (v) => c.showTournamentLogo = v),
        _toggleTile('QR Code', c.showQrCode, (v) => c.showQrCode = v),
        _toggleTile(
            'Sponsor Logo', c.showSponsorLogo, (v) {
          c.showSponsorLogo = v;
          if (v && c.sponsorImage == null) _pickSponsorImage();
        }),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white54,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _toggleTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: TextStyle(color: Colors.white, fontSize: 13.sp),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryOrange,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildSponsorSlot(String label, Uint8List? currentImage, Function(Uint8List?) onImageSelected, ValueChanged<bool> onToggle) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
                if (currentImage != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Image selected ✓',
                    style: TextStyle(color: Colors.green[400], fontSize: 11.sp),
                  ),
                ],
              ],
            ),
          ),
          if (currentImage != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20.sp),
              onPressed: () => onImageSelected(null),
            ),
          IconButton(
            icon: Icon(Icons.add_photo_alternate, color: AppTheme.primaryOrange, size: 20.sp),
            onPressed: () => _pickSponsorImageForSlot(onImageSelected),
          ),
        ],
      ),
    );
  }

  Widget _sliderTile(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
            Text(value.round().toString(), style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 2).round(),
          activeColor: AppTheme.primaryOrange,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _pickSponsorImageForSlot(Function(Uint8List?) onSelected) async {
    try {
      final picked = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 200,
        imageQuality: 90,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        onSelected(bytes);
      }
    } catch (e) {
      debugPrint('Error picking sponsor image: $e');
    }
  }

  Future<void> _updateTopSponsor(int index, Uint8List? image) async {
    final sponsors = List<Uint8List?>.from(widget.customization.topSponsors);
    while (sponsors.length <= index) {
      sponsors.add(null);
    }
    sponsors[index] = image;
    widget.customization.topSponsors = sponsors;
  }

  Future<void> _updateBottomSponsor(int index, Uint8List? image) async {
    final sponsors = List<Uint8List?>.from(widget.customization.bottomSponsors);
    while (sponsors.length <= index) {
      sponsors.add(null);
    }
    sponsors[index] = image;
    widget.customization.bottomSponsors = sponsors;
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final picked = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.customization.customBackgroundImage = bytes;
      }
    } catch (e) {
      debugPrint('Error picking background image: $e');
    }
  }

  Future<void> _pickSponsorImage() async {
    try {
      final picked = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 200,
        imageQuality: 90,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.customization.sponsorImage = bytes;
      }
    } catch (e) {
      debugPrint('Error picking sponsor image: $e');
    }
  }
}
