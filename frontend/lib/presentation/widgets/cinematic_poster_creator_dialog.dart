import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/widgets/cinematic_poster_card.dart';

class DetectedMoment {
  final String playerId;
  final String playerName;
  final String title;
  final String description;
  final String badgeType; // 'batsman', 'bowler', 'team'
  final String suggestedBadge;
  final String category; // 'action', 'six', 'wicket', 'century', 'mvp', 'celebration'

  DetectedMoment({
    required this.playerId,
    required this.playerName,
    required this.title,
    required this.description,
    required this.badgeType,
    required this.suggestedBadge,
    required this.category,
  });
}

class CinematicPosterCreatorDialog extends StatefulWidget {
  final TournamentModel tournament;
  final Function(TournamentGalleryItem) onPosterSaved;

  const CinematicPosterCreatorDialog({
    super.key,
    required this.tournament,
    required this.onPosterSaved,
  });

  @override
  State<CinematicPosterCreatorDialog> createState() => _CinematicPosterCreatorDialogState();
}

class _CinematicPosterCreatorDialogState extends State<CinematicPosterCreatorDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Real-time customization states
  dynamic _selectedPhoto; // File or Uint8List
  String _playerName = 'CRICKET HERO';
  String _achievementTitle = 'BEAST PERFORMANCE';
  String _achievementDesc = 'Smashed an incredible spell in the local cricket tournament!';
  String _badgeName = 'Boundary Beast 💥';
  String _badgeType = 'batsman'; // 'batsman', 'bowler', 'team'
  String _overlayStyle = 'all'; // 'glowing_border', 'orange_particles', 'spotlight_focus', 'stadium_light', 'all'
  String _shareFormat = 'trophy_card'; // 'instagram_story', 'instagram_post', 'whatsapp_status', 'match_poster', 'trophy_card', 'mvp_card', 'banner'
  String _galleryCategory = 'poster'; // category to save under
  bool _isNormalPhoto = false;

  List<DetectedMoment> _detectedMoments = [];
  bool _isLoadingMoments = true;
  bool _isSaving = false;

  final List<String> _batsmanBadges = [
    'Boundary Beast 💥',
    'Six Storm ⚡',
    'Century Emperor 👑',
    'Infinity Striker ♾️',
    'Ragnarok Finisher 🔥',
  ];

  final List<String> _bowlerBadges = [
    'Wicket Hunter 🎯',
    'Death Reaper ☠️',
    'Phantom Spinner 👻',
    'Thunder Spell ⚡',
    'Dragon Fury 🐉',
  ];

  final List<String> _teamBadges = [
    'Arena Champions 🏆',
    'Dynasty Kings 👑',
    'Battle Winners ⚔️',
    'Trophy Titans 🔥',
  ];

  @override
  void initState() {
    super.initState();
    _scanTournamentForMoments();
  }

  Future<void> _scanTournamentForMoments() async {
    try {
      final List<DetectedMoment> moments = [];

      // 1. Scan Registered Teams for Team-level Milestones
      for (final teamId in widget.tournament.registeredTeamIds) {
        final team = await FirebaseDataService.instance.getTeamById(teamId);
        if (team != null) {
          moments.add(DetectedMoment(
            playerId: '',
            playerName: team.name,
            title: 'Trophy Contender',
            description: 'Ready to battle as registered contenders in ${widget.tournament.name}!',
            badgeType: 'team',
            suggestedBadge: 'Trophy Titans 🔥',
            category: 'celebration',
          ));
        }
      }

      // 2. Fetch matches associated with this tournament to extract real achievements
      for (final matchId in widget.tournament.matchIds) {
        final match = await FirebaseDataService.instance.getMatchById(matchId);
        if (match != null && match.status == 'past') {
          // A. Victory
          if (match.winnerTeam != null && match.winnerTeam!.isNotEmpty) {
            moments.add(DetectedMoment(
              playerId: '',
              playerName: match.winnerTeam!,
              title: 'Match Winners',
              description: 'Defeated ${match.winnerTeam == match.team1Name ? match.team2Name : match.team1Name} by ${match.winningMargin}!',
              badgeType: 'team',
              suggestedBadge: 'Battle Winners ⚔️',
              category: 'match_winning',
            ));
          }

          // B. Batters (Sixes, Runs)
          final allBatters = [...match.team1Score.batters, ...match.team2Score.batters];
          for (final batter in allBatters) {
            if (batter.runs >= 30) {
              final isCentury = batter.runs >= 100;
              final isFifty = batter.runs >= 50;
              moments.add(DetectedMoment(
                playerId: batter.playerId,
                playerName: batter.playerName,
                title: isCentury ? 'CENTURY EMPEROR' : (isFifty ? 'HALF CENTURY' : 'RUN MACHINE'),
                description: 'Smashed ${batter.runs} runs off ${batter.balls} balls (${batter.sixes}x6, ${batter.fours}x4)!',
                badgeType: 'batsman',
                suggestedBadge: isCentury ? 'Century Emperor 👑' : 'Boundary Beast 💥',
                category: isCentury ? 'century' : 'action',
              ));
            }
            if (batter.sixes >= 3) {
              moments.add(DetectedMoment(
                playerId: batter.playerId,
                playerName: batter.playerName,
                title: 'SIX STORM',
                description: 'Lit up the stadium with ${batter.sixes} massive sixes in a single match!',
                badgeType: 'batsman',
                suggestedBadge: 'Six Storm ⚡',
                category: 'six',
              ));
            }
          }

          // C. Bowlers (Wickets)
          final allBowlers = [...match.team1Score.bowlers, ...match.team2Score.bowlers];
          for (final bowler in allBowlers) {
            if (bowler.wickets >= 2) {
              moments.add(DetectedMoment(
                playerId: bowler.playerId,
                playerName: bowler.playerName,
                title: 'DEATH REAPER',
                description: 'Stunned the opposition taking ${bowler.wickets} wickets for ${bowler.runs} runs!',
                badgeType: 'bowler',
                suggestedBadge: bowler.wickets >= 4 ? 'Death Reaper ☠️' : 'Wicket Hunter 🎯',
                category: 'wicket',
              ));
            }
          }
        }
      }

      // Add a fallback generic champion moment
      moments.add(DetectedMoment(
        playerId: '',
        playerName: 'Arena Gladiators',
        title: 'Trophy Lifting',
        description: 'Lifting the prestigious trophy in the ultimate ${widget.tournament.name} clash!',
        badgeType: 'team',
        suggestedBadge: 'Arena Champions 🏆',
        category: 'trophy',
      ));

      setState(() {
        _detectedMoments = moments;
        _isLoadingMoments = false;
        
        // Auto-fill first moment
        if (moments.isNotEmpty) {
          _applyMoment(moments.first);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoments = false;
      });
    }
  }

  void _applyMoment(DetectedMoment moment) {
    setState(() {
      _playerName = moment.playerName;
      _achievementTitle = moment.title;
      _achievementDesc = moment.description;
      _badgeType = moment.badgeType;
      _badgeName = moment.suggestedBadge;
      _galleryCategory = moment.category;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1350,
        imageQuality: 85,
      );

      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _selectedPhoto = bytes;
          });
        } else {
          setState(() {
            _selectedPhoto = File(picked.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _captureAndSavePoster() async {
    setState(() => _isSaving = true);

    try {
      String base64Image;
      if (_isNormalPhoto) {
        if (_selectedPhoto == null) {
          throw Exception('No photo selected');
        }
        Uint8List bytes;
        if (_selectedPhoto is Uint8List) {
          bytes = _selectedPhoto as Uint8List;
        } else if (_selectedPhoto is File) {
          bytes = await (_selectedPhoto as File).readAsBytes();
        } else if (_selectedPhoto is String && (_selectedPhoto as String).startsWith('data:')) {
          base64Image = _selectedPhoto as String;
          bytes = Uint8List(0);
        } else {
          throw Exception('Unsupported photo format');
        }
        
        if (bytes.isNotEmpty) {
          base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
        } else {
          base64Image = _selectedPhoto as String;
        }
      } else {
        // Capture the screenshot of the CinematicPosterCard
        final Uint8List? imageBytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 300),
        );
        if (imageBytes == null) throw Exception('Screenshot capture failed');
        base64Image = 'data:image/png;base64,${base64Encode(imageBytes)}';
      }

      // Create the tournament gallery item
      final galleryItem = TournamentGalleryItem(
        id: const Uuid().v4(),
        imageUrl: base64Image,
        category: _galleryCategory,
        title: _achievementTitle,
        description: _achievementDesc,
        createdAt: DateTime.now(),
        badgeType: _isNormalPhoto ? null : _badgeType,
        badgeName: _isNormalPhoto ? null : _badgeName,
        overlayStyle: _isNormalPhoto ? null : _overlayStyle,
        shareFormat: _isNormalPhoto ? null : _shareFormat,
        playerName: _isNormalPhoto ? null : _playerName,
      );

      // Upload and save into Tournament gallery array
      final updatedGallery = List<TournamentGalleryItem>.from(widget.tournament.gallery)
        ..add(galleryItem);

      final success = await FirebaseDataService.instance.updateTournament(
        widget.tournament.id,
        {
          'gallery': updatedGallery.map((g) => g.toMap()).toList(),
        },
      );

      if (success) {
        widget.onPosterSaved(galleryItem);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isNormalPhoto
                  ? '🎉 Sports Photo uploaded to Gallery!'
                  : '🎉 Premium Sports Poster uploaded to Gallery!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to save to database');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error generating poster: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildRawPhotoPreview() {
    ImageProvider? imageProvider;
    if (_selectedPhoto == null) return SizedBox.shrink();
    if (_selectedPhoto is File) {
      imageProvider = FileImage(_selectedPhoto as File);
    } else if (_selectedPhoto is Uint8List) {
      imageProvider = MemoryImage(_selectedPhoto as Uint8List);
    } else if (_selectedPhoto is String) {
      final photoStr = _selectedPhoto as String;
      if (photoStr.startsWith('http')) {
        imageProvider = NetworkImage(photoStr);
      } else if (photoStr.startsWith('data:')) {
        final base64Str = photoStr.split(',').last;
        imageProvider = MemoryImage(base64Decode(base64Str));
      } else {
        imageProvider = FileImage(File(photoStr));
      }
    }
    
    if (imageProvider == null) return SizedBox.shrink();

    return Container(
      width: 340.w,
      height: 480.h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image(
        image: imageProvider,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: Text(
            'Cinematic Poster Creator 📸',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18.sp),
          ),
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_selectedPhoto != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _captureAndSavePoster,
                  icon: _isSaving
                      ? SizedBox(width: 14.w, height: 14.h, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.cloud_upload_rounded),
                  label: const Text('GENERATE & POST'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 768;
            if (isNarrow) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Top: Preview Area
                    Container(
                      color: Colors.grey[100],
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                      child: _selectedPhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 60.sp, color: Colors.grey[400]),
                                SizedBox(height: 8.h),
                                Text(
                                  'SELECT A BASE PHOTO FIRST',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey[500], fontSize: 13.sp),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Add a celebration, trophy, or action photo to build your cinematic poster.',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LIVE PREVIEW 💫',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11.sp, color: Colors.grey[600], letterSpacing: 1.0),
                                ),
                                SizedBox(height: 12.h),
                                Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _isNormalPhoto
                                        ? _buildRawPhotoPreview()
                                        : Screenshot(
                                            controller: _screenshotController,
                                            child: CinematicPosterCard(
                                              photo: _selectedPhoto,
                                              playerName: _playerName,
                                              achievementTitle: _achievementTitle,
                                              achievementDesc: _achievementDesc,
                                              badgeName: _badgeName,
                                              badgeType: _badgeType,
                                              overlayStyle: _overlayStyle,
                                              shareFormat: _shareFormat,
                                              tournamentName: widget.tournament.name,
                                              date: DateFormat('dd MMM yyyy').format(DateTime.now()),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Divider(height: 1.h, thickness: 1),
                    // Bottom: Customizer inputs
                    Padding(
                      padding: EdgeInsets.all(20.w),
                      child: _buildCustomizerInputs(context),
                    ),
                  ],
                ),
              );
            } else {
              // Wide screen side-by-side Row
              return Row(
                children: [
                  // Left Column: Customizer inputs
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20.w),
                      child: _buildCustomizerInputs(context),
                    ),
                  ),

                  // Vertical separator
                  Container(width: 1.w, color: Colors.grey[200]),

                  // Right Column: Live Poster preview
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: Colors.grey[100],
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(24.w),
                      child: _selectedPhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 70.sp, color: Colors.grey[400]),
                                SizedBox(height: 12.h),
                                Text(
                                  'SELECT A BASE PHOTO FIRST',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey[500]),
                                ),
                                Text(
                                  'Add a celebration, trophy, or action photo to build your cinematic poster.',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'LIVE PREVIEW 💫',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.sp, color: Colors.grey[600], letterSpacing: 1.0),
                                ),
                                SizedBox(height: 14.h),
                                // Capture Screenshot Boundary
                                Expanded(
                                  child: Center(
                                    child: SingleChildScrollView(
                                      child: _isNormalPhoto
                                          ? _buildRawPhotoPreview()
                                          : Screenshot(
                                              controller: _screenshotController,
                                              child: CinematicPosterCard(
                                                photo: _selectedPhoto,
                                                playerName: _playerName,
                                                achievementTitle: _achievementTitle,
                                                achievementDesc: _achievementDesc,
                                                badgeName: _badgeName,
                                                badgeType: _badgeType,
                                                overlayStyle: _overlayStyle,
                                                shareFormat: _shareFormat,
                                                tournamentName: widget.tournament.name,
                                                date: DateFormat('dd MMM yyyy').format(DateTime.now()),
                                              ),
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
          },
        ),
      ),
    );
  }

  Widget _buildCustomizerInputs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Mode selector
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _isNormalPhoto = false;
                    _galleryCategory = 'poster';
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: !_isNormalPhoto ? AppTheme.primaryOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Center(
                      child: Text(
                        'Cinematic Poster 🤖',
                        style: TextStyle(
                          color: !_isNormalPhoto ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _isNormalPhoto = true;
                    _galleryCategory = 'celebration';
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _isNormalPhoto ? AppTheme.primaryOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Center(
                      child: Text(
                        'Normal Photo 📸',
                        style: TextStyle(
                          color: _isNormalPhoto ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // 1. Moments detected by AI
        Text(
          'AI DETECTED TOURNAMENT ACHIEVEMENTS 🤖',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: AppTheme.primaryOrange, letterSpacing: 0.5),
        ),
        SizedBox(height: 8.h),
        _isLoadingMoments
            ? Center(child: Padding(padding: EdgeInsets.all(12.w), child: CircularProgressIndicator(color: AppTheme.primaryOrange)))
            : _detectedMoments.isEmpty
                ? Text('No moments detected yet. Register teams or complete matches to trigger AI extraction.', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp))
                : Container(
                    height: 110.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _detectedMoments.length,
                      itemBuilder: (context, index) {
                        final m = _detectedMoments[index];
                        return GestureDetector(
                          onTap: () => _applyMoment(m),
                          child: Container(
                            width: 160.w,
                            margin: EdgeInsets.only(right: 10.w),
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: _playerName == m.playerName && _achievementTitle == m.title
                                    ? AppTheme.primaryOrange
                                    : Colors.grey[200]!,
                                width: 1.5.w,
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(m.playerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(m.title, style: TextStyle(fontSize: 10.sp, color: Colors.grey[500], fontWeight: FontWeight.bold), maxLines: 1),
                                SizedBox(height: 2.h),
                                Text(m.description, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        SizedBox(height: 20.h),

        // 2. Upload photo
        Text(
          'PHOTO SELECTION 📸',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),

        // 3. Customize Text
        Text(
          _isNormalPhoto ? 'PHOTO CAPTION & DETAILS ✍️' : 'CUSTOMIZE SPORTS TEXT 🏏',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
        ),
        SizedBox(height: 10.h),
        if (!_isNormalPhoto) ...[
          TextField(
            onChanged: (v) => setState(() => _playerName = v),
            controller: TextEditingController()..text = _playerName..selection = TextSelection.collapsed(offset: _playerName.length),
            decoration: const InputDecoration(labelText: 'Player Name', border: OutlineInputBorder()),
          ),
          SizedBox(height: 10.h),
        ],
        TextField(
          onChanged: (v) => setState(() => _achievementTitle = v),
          controller: TextEditingController()..text = _achievementTitle..selection = TextSelection.collapsed(offset: _achievementTitle.length),
          decoration: InputDecoration(
            labelText: _isNormalPhoto ? 'Photo Title / Caption (e.g. Squad Victory)' : 'Achievement Title (e.g. BOUNDARY BEAST)',
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          onChanged: (v) => setState(() => _achievementDesc = v),
          controller: TextEditingController()..text = _achievementDesc..selection = TextSelection.collapsed(offset: _achievementDesc.length),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: _isNormalPhoto ? 'Photo Description / Story' : 'Statistic Text',
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 20.h),

        if (!_isNormalPhoto) ...[
          // 4. Badge Selection
          Text(
            'AI SPORTS BADGES 🏆',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: _badgeType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Badge Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'batsman', child: Text('Batsman Badges 💥')),
              DropdownMenuItem(value: 'bowler', child: Text('Bowler Badges ⚡')),
              DropdownMenuItem(value: 'team', child: Text('Team Badges 👑')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _badgeType = val;
                  _badgeName = val == 'batsman'
                      ? _batsmanBadges.first
                      : (val == 'bowler' ? _bowlerBadges.first : _teamBadges.first);
                });
              }
            },
          ),
          SizedBox(height: 10.h),
          DropdownButtonFormField<String>(
            value: _badgeName,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Badge Name', border: OutlineInputBorder()),
            items: (_badgeType == 'batsman'
                    ? _batsmanBadges
                    : (_badgeType == 'bowler' ? _bowlerBadges : _teamBadges))
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _badgeName = val);
              }
            },
          ),
          SizedBox(height: 20.h),

          // 5. Cinematic Overlay Style
          Text(
            'AI CINEMATIC STYLES 🎭',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: _overlayStyle,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cinematic Overlay Style', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Marvel Cinematic Style 🔥 (All Overlays)')),
              DropdownMenuItem(value: 'orange_particles', child: Text('Orange Floating Particles ⚡')),
              DropdownMenuItem(value: 'glowing_border', child: Text('Glowing Borders Glow 💥')),
              DropdownMenuItem(value: 'spotlight_focus', child: Text('Stadium Spotlight Halo 👑')),
              DropdownMenuItem(value: 'stadium_light', child: Text('Stadium Lighting Beams 🏟️')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _overlayStyle = val);
              }
            },
          ),
          SizedBox(height: 20.h),

          // 6. Share Format & Ratios
          Text(
            'SHARE CARD ASPECT RATIO 📱',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: _shareFormat,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Social Aspect Ratio', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'instagram_story', child: Text('Instagram Story (9:16 - 1080x1920)')),
              DropdownMenuItem(value: 'instagram_post', child: Text('Instagram Post (4:5 - 1080x1350)')),
              DropdownMenuItem(value: 'whatsapp_status', child: Text('WhatsApp Status (9:16)')),
              DropdownMenuItem(value: 'match_poster', child: Text('IPL Match Poster (Horizontal)')),
              DropdownMenuItem(value: 'banner', child: Text('Team Widescreen Celebration Banner')),
              DropdownMenuItem(value: 'trophy_card', child: Text('Sleek Trophy Card (Premium Portrait)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _shareFormat = val);
              }
            },
          ),
          SizedBox(height: 20.h),
        ],

        // 7. Gallery Category
        Text(
          'GALLERY FILTER CATEGORY 📁',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: _galleryCategory,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Gallery Filter Category', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'poster', child: Text('Tournament Poster 🏆')),
            DropdownMenuItem(value: 'celebration', child: Text('Team Celebration 🥳')),
            DropdownMenuItem(value: 'trophy', child: Text('Trophy Lifting 👑')),
            DropdownMenuItem(value: 'match_winning', child: Text('Match Victory Moment ⚔️')),
            DropdownMenuItem(value: 'action', child: Text('Player Action Shot ⚡')),
            DropdownMenuItem(value: 'mvp', child: Text('MVP Celebration 👑')),
            DropdownMenuItem(value: 'six', child: Text('Six Celebration 💥')),
            DropdownMenuItem(value: 'wicket', child: Text('Wicket Moments 🎯')),
            DropdownMenuItem(value: 'century', child: Text('Century Milestones 💯')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _galleryCategory = val);
            }
          },
        ),
      ],
    );
  }
}
