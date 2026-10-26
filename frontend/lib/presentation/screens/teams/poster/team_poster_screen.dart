import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../../../widgets/player_avatar_widget.dart';
import 'team_poster_theme.dart';
import 'team_poster_card.dart';

/// Screen for Generating, Previewing, Customizing, Downloading,
/// and Sharing a High-Res Cricket Team Squad Poster.
class TeamPosterScreen extends StatefulWidget {
  final TeamModel team;

  const TeamPosterScreen({super.key, required this.team});

  @override
  State<TeamPosterScreen> createState() => _TeamPosterScreenState();
}

class _TeamPosterScreenState extends State<TeamPosterScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  TeamPosterTheme _selectedTheme = TeamPosterTheme.defaultTheme;
  PosterFormat _selectedFormat = PosterFormat.auto;
  int _selectedColumns = 0; // 0 = Auto
  String _tagline = 'OFFICIAL SQUAD • 2026';
  bool _showStats = false;
  bool _showQrCode = true;
  bool _showRoles = true;
  bool _showCaptainsBadge = true;
  bool _themeLogo = true;

  bool _isLoading = true;
  bool _isExporting = false;
  final Map<String, String> _resolvedPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadAndPreloadPhotos();
  }

  /// Resolve player photos across in-memory cache and Firestore lookups
  Future<void> _loadAndPreloadPhotos() async {
    try {
      final playerIds = widget.team.players
          .map((p) => p.userId)
          .where((id) => id.isNotEmpty)
          .toList();

      // Prefetch any uncached user data
      if (playerIds.isNotEmpty) {
        await PlayerAvatarWidget.prefetch(playerIds);
      }

      // Populate resolved photo map
      for (final player in widget.team.players) {
        if (player.profileImageUrl.isNotEmpty) {
          _resolvedPhotos[player.userId] = player.profileImageUrl;
          _resolvedPhotos[player.name] = player.profileImageUrl;
        } else {
          final lookupId = player.userId.isNotEmpty ? player.userId : player.name;
          try {
            final user = await FirebaseDataService.instance.findUserByAnyId(lookupId);
            if (user != null && user.profileImageUrl.isNotEmpty) {
              _resolvedPhotos[player.userId] = user.profileImageUrl;
              _resolvedPhotos[player.name] = user.profileImageUrl;
              PlayerAvatarWidget.seedCache(player.userId, user.profileImageUrl, user);
            }
          } catch (_) {}
        }
      }

      // Precache images in Flutter GPU pipeline
      if (mounted) {
        for (final url in _resolvedPhotos.values) {
          if (url.startsWith('http')) {
            try {
              precacheImage(NetworkImage(url), context);
            } catch (_) {}
          }
        }
        if (widget.team.logoUrl.isNotEmpty && widget.team.logoUrl.startsWith('http')) {
          try {
            precacheImage(NetworkImage(widget.team.logoUrl), context);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error preloading team poster photos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// High-resolution image capture of the poster
  Future<Uint8List?> _capturePoster() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      final image = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 200),
      );
      return image;
    } catch (e) {
      debugPrint('❌ Error capturing team poster: $e');
      // Retry once
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await WidgetsBinding.instance.endOfFrame;
        return await _screenshotController.capture(
          pixelRatio: 3.0,
          delay: const Duration(milliseconds: 300),
        );
      } catch (retryError) {
        debugPrint('❌ Retry capture failed: $retryError');
        return null;
      }
    }
  }

  /// Download the poster to Device Gallery or Web Downloads
  Future<void> _downloadPoster() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final image = await _capturePoster();
      if (image == null) throw Exception('Capture failed');

      final safeTeamName = widget.team.name
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(' ', '_');
      final fileName =
          'team_${safeTeamName}_poster_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        final xFile = XFile.fromData(image, name: fileName, mimeType: 'image/png');
        await xFile.saveTo(fileName);
      } else {
        // Save to temporary directory first
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(image);

        // Check & request gallery access
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(filePath, album: 'ScorePartner');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 22),
                SizedBox(width: 10.w),
                const Expanded(
                  child: Text(
                    'Team poster saved to gallery! 📸',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error downloading poster: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't save poster to gallery. Please try again."),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _downloadPoster,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Share the poster via OS Share Dialog
  Future<void> _sharePoster() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final image = await _capturePoster();
      if (image == null) throw Exception('Capture failed');

      final safeTeamName = widget.team.name
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(' ', '_');
      final fileName = 'team_${safeTeamName}_poster.png';

      final caption = '🏏 Official Squad Poster: ${widget.team.name}\n'
          'Captain: ${widget.team.captainName.isNotEmpty ? widget.team.captainName : "TBA"}\n'
          'Squad Members: ${widget.team.players.length}\n\n'
          'Generated on ScorePartner 🏆';

      if (kIsWeb) {
        final xFile = XFile.fromData(image, name: fileName, mimeType: 'image/png');
        await Share.shareXFiles([xFile], text: caption);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(image);

        await Share.shareXFiles([XFile(filePath)], text: caption);
      }
    } catch (e) {
      debugPrint('❌ Error sharing poster: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't share team poster."),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _sharePoster,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Open Customization Bottom Sheet
  void _openCustomizationSheet() {
    final taglineCtrl = TextEditingController(text: _tagline);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20.w,
                16.h,
                20.w,
                MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customize Poster',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Tagline Field
                  Text(
                    'Poster Subtitle / Tagline',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13.sp),
                  ),
                  SizedBox(height: 6.h),
                  TextField(
                    controller: taglineCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      hintText: 'e.g. OFFICIAL SQUAD • 2026',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: AppTheme.primaryOrange.withOpacity(0.5)),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _tagline = val);
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Grid Columns Selector
                  Text(
                    'Grid Columns Density',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13.sp),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _buildColumnOption(0, 'Auto', setSheetState),
                      SizedBox(width: 8.w),
                      _buildColumnOption(2, '2 Cols (Large)', setSheetState),
                      SizedBox(width: 8.w),
                      _buildColumnOption(3, '3 Cols (Standard)', setSheetState),
                      SizedBox(width: 8.w),
                      _buildColumnOption(4, '4 Cols (Compact)', setSheetState),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Toggles
                  _buildSwitchTile('Show Performance Stats', _showStats, (val) {
                    setSheetState(() => _showStats = val);
                    setState(() {});
                  }),
                  _buildSwitchTile('Show Player Roles', _showRoles, (val) {
                    setSheetState(() => _showRoles = val);
                    setState(() {});
                  }),
                  _buildSwitchTile('Show Captain/VC Badges', _showCaptainsBadge, (val) {
                    setSheetState(() => _showCaptainsBadge = val);
                    setState(() {});
                  }),
                  _buildSwitchTile('Show Team QR Code', _showQrCode, (val) {
                    setSheetState(() => _showQrCode = val);
                    setState(() {});
                  }),
                  _buildSwitchTile('Match Logo with Theme Color', _themeLogo, (val) {
                    setSheetState(() => _themeLogo = val);
                    setState(() {});
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColumnOption(int cols, String label, StateSetter setSheetState) {
    final isSelected = _selectedColumns == cols;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setSheetState(() => _selectedColumns = cols);
          setState(() {});
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryOrange : const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppTheme.primaryOrange : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13.sp),
      ),
      value: value,
      activeColor: AppTheme.primaryOrange,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Team Squad Poster'),
            Text(
              widget.team.name,
              style: TextStyle(fontSize: 12.sp, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize Options',
            onPressed: _openCustomizationSheet,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Top Theme Selector Bar
                _buildThemeSelector(),

                // Format Aspect Ratio Selector
                _buildFormatSelector(),

                // Live Preview Canvas
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.r),
                        child: Screenshot(
                          controller: _screenshotController,
                          child: _selectedFormat.ratio == null
                              ? TeamPosterCard(
                                  team: widget.team,
                                  theme: _selectedTheme,
                                  resolvedPhotos: _resolvedPhotos,
                                  tagline: _tagline,
                                  showStats: _showStats,
                                  showQrCode: _showQrCode,
                                  showRoles: _showRoles,
                                  showCaptainsBadge: _showCaptainsBadge,
                                  themeLogo: _themeLogo,
                                  columns: _selectedColumns,
                                )
                              : AspectRatio(
                                  aspectRatio: _selectedFormat.ratio!,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: TeamPosterCard(
                                      team: widget.team,
                                      theme: _selectedTheme,
                                      resolvedPhotos: _resolvedPhotos,
                                      tagline: _tagline,
                                      showStats: _showStats,
                                      showQrCode: _showQrCode,
                                      showRoles: _showRoles,
                                      showCaptainsBadge: _showCaptainsBadge,
                                      themeLogo: _themeLogo,
                                      columns: _selectedColumns,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Export Action Bar
                _buildBottomActionBar(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryOrange),
          SizedBox(height: 16.h),
          Text(
            'Preparing your team squad poster...',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  /// Theme Carousel Selector
  Widget _buildThemeSelector() {
    return Container(
      height: 72.h,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: TeamPosterTheme.allThemes.length,
        itemBuilder: (context, index) {
          final theme = TeamPosterTheme.allThemes[index];
          final isSelected = theme.id == _selectedTheme.id;

          return GestureDetector(
            onTap: () => setState(() => _selectedTheme = theme),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96.w,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.backgroundGradient.first,
                    theme.cardBackground,
                  ],
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected ? theme.accentColor : Colors.white12,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.accentColor.withOpacity(0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(theme.icon, color: theme.accentColor, size: 18.sp),
                  SizedBox(height: 4.h),
                  Text(
                    theme.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  /// Aspect Ratio Filter Bar
  Widget _buildFormatSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: const Color(0xFF0F172A).withOpacity(0.5),
      child: Row(
        children: [
          Text(
            'Format: ',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Row(
              children: PosterFormat.values.map((format) {
                final isSelected = format == _selectedFormat;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(
                      format.label,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryOrange,
                    backgroundColor: const Color(0xFF1E293B),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFormat = format);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Sticky Action Bar
  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Customize Quick Button
          OutlinedButton.icon(
            onPressed: _openCustomizationSheet,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Options'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(width: 10.w),

          // Download Poster Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _downloadPoster,
              icon: _isExporting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(
                _isExporting ? 'Saving...' : 'Download',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 3,
              ),
            ),
          ),
          SizedBox(width: 10.w),

          // Share Poster Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _sharePoster,
              icon: const Icon(Icons.share_outlined),
              label: const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
