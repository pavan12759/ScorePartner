import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:scorepatner/presentation/widgets/mvp_calculator_widget.dart';

import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/widgets/highlight_badge_widgets.dart';

class MilestoneOption {
  final BadgeType type;
  final String title;
  final String description;
  final String? playerName;
  final String? playerId;
  final String key;

  MilestoneOption({
    required this.type,
    required this.title,
    required this.description,
    this.playerName,
    this.playerId,
    required this.key,
  });
}

class MatchHighlightsGeneratorScreen extends StatefulWidget {
  final String matchId;

  const MatchHighlightsGeneratorScreen({super.key, required this.matchId});

  @override
  State<MatchHighlightsGeneratorScreen> createState() => _MatchHighlightsGeneratorScreenState();
}

class _MatchHighlightsGeneratorScreenState extends State<MatchHighlightsGeneratorScreen> {
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  final ScreenshotController _screenshotController = ScreenshotController();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  final Map<String, File> _selectedImages = {};
  final Map<String, Uint8List> _selectedImageBytes = {};
  final Map<String, String> _customDescriptions = {};
  MilestoneOption? _selectedMilestone;
  List<MilestoneOption> _milestones = [];
  bool _isGenerating = false;
  bool _isLoadingMatch = true;
  MatchModel? _match;

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchData() async {
    try {
      final match = await _dataService.getMatchById(widget.matchId);
      if (match != null) {
        final options = _extractMilestones(match);
        setState(() {
          _match = match;
          _milestones = options;
          _isLoadingMatch = false;
          if (options.isNotEmpty) {
            _selectMilestone(options.first);
          }
        });
      } else {
        setState(() {
          _isLoadingMatch = false;
        });
        _showErrorSnackBar('Match details not found.');
      }
    } catch (e) {
      setState(() {
        _isLoadingMatch = false;
      });
      _showErrorSnackBar('Error loading match data: $e');
    }
  }

  List<MilestoneOption> _extractMilestones(MatchModel match) {
    final options = <MilestoneOption>[];

    // 1. Victory Milestone
    if (match.winnerTeam != null && match.winnerTeam!.isNotEmpty) {
      String description = '';
      if (match.winnerTeam == 'Match Tied') {
        description = 'An intense and hard-fought match ends in a historic tie!';
      } else {
        description = '${match.winnerTeam} secured a thrilling victory by ${match.winningMargin}!';
      }
      options.add(MilestoneOption(
        type: BadgeType.win,
        title: match.winnerTeam == 'Match Tied' ? 'MATCH TIED' : 'CHAMPIONS',
        description: description,
        key: 'win_milestone',
      ));
    }

    // 2. Batter Milestones (Fifty / Century)
    final allBatters = [...match.team1Score.batters, ...match.team2Score.batters];
    for (final batter in allBatters) {
      if (batter.runs >= 50) {
        final isCentury = batter.runs >= 100;
        options.add(MilestoneOption(
          type: isCentury ? BadgeType.century : BadgeType.fifty,
          title: isCentury ? 'CENTURY HERO' : 'HALF CENTURY',
          description: 'Blazed ${batter.runs} runs off ${batter.balls} balls (${batter.fours}x4, ${batter.sixes}x6) at a strike rate of ${batter.strikeRate.toStringAsFixed(1)}!',
          playerName: batter.playerName,
          playerId: batter.playerId,
          key: 'bat_${batter.playerId}_${batter.runs}',
        ));
      }
    }

    // 3. Bowler Milestones (Wickets)
    final allBowlers = [...match.team1Score.bowlers, ...match.team2Score.bowlers];
    allBowlers.sort((a, b) {
      final comp = b.wickets.compareTo(a.wickets);
      if (comp != 0) return comp;
      return a.runs.compareTo(b.runs);
    });

    bool addedBowler = false;
    for (final bowler in allBowlers) {
      if (bowler.wickets >= 3) {
        options.add(MilestoneOption(
          type: BadgeType.wicket,
          title: 'STRIKE BOWLER',
          description: 'Sensational bowling spell taking ${bowler.wickets} wickets for ${bowler.runs} runs in ${bowler.oversDisplay} overs!',
          playerName: bowler.playerName,
          playerId: bowler.playerId,
          key: 'bowl_${bowler.playerId}_${bowler.wickets}',
        ));
        addedBowler = true;
      }
    }

    if (!addedBowler && allBowlers.isNotEmpty && allBowlers.first.wickets > 0) {
      final bowler = allBowlers.first;
      options.add(MilestoneOption(
        type: BadgeType.wicket,
        title: 'TOP BOWLER',
        description: 'Brilliant spell of ${bowler.wickets}/${bowler.runs} in ${bowler.oversDisplay} overs to restrict the opposition!',
        playerName: bowler.playerName,
        playerId: bowler.playerId,
        key: 'bowl_${bowler.playerId}_${bowler.wickets}',
      ));
    }

    // 4. Man of the Match (MVP)
    final mvpList = calculateMvpRatings(match);
    if (mvpList.isNotEmpty) {
      // Find declared Man of the Match, otherwise default to highest MVP points
      final mvp = mvpList.firstWhere((p) => p.isManOfMatch, orElse: () => mvpList.first);
      
      options.add(MilestoneOption(
        type: BadgeType.mvp,
        title: 'MAN OF THE MATCH',
        description: 'Spectacular all-round performance securing ${mvp.mvpPoints.toStringAsFixed(0)} MVP points!',
        playerName: mvp.playerName,
        playerId: mvp.playerId,
        key: 'mvp_${mvp.playerId}',
      ));
    }

    return options;
  }

  void _selectMilestone(MilestoneOption milestone) {
    if (_selectedMilestone != null) {
      _customDescriptions[_selectedMilestone!.key] = _descController.text;
    }
    setState(() {
      _selectedMilestone = milestone;
      _descController.text = _customDescriptions[milestone.key] ?? milestone.description;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedMilestone == null) return;
    final milestoneKey = _selectedMilestone!.key;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes[milestoneKey] = bytes;
          });
        } else {
          final file = File(image.path);
          setState(() {
            _selectedImages[milestoneKey] = file;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick photo: $e');
    }
  }

  Future<void> _generateAndShareHighlight() async {
    if (_match == null || _milestones.isEmpty) return;
    
    if (_selectedMilestone != null) {
      _customDescriptions[_selectedMilestone!.key] = _descController.text;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      bool allSavedToFirebase = true;
      List<MatchHighlight> generatedHighlights = [];

      for (final milestone in _milestones) {
        final desc = _customDescriptions[milestone.key] ?? milestone.description;
        
        String? base64Photo;
        if (kIsWeb && _selectedImageBytes.containsKey(milestone.key)) {
           base64Photo = 'data:image/png;base64,' + base64Encode(_selectedImageBytes[milestone.key]!);
        } else if (!kIsWeb && _selectedImages.containsKey(milestone.key)) {
           final bytes = await _selectedImages[milestone.key]!.readAsBytes();
           base64Photo = 'data:image/png;base64,' + base64Encode(bytes);
        }

        final highlightId = const Uuid().v4();
        final dataUrl = base64Photo ?? '';

        final newHighlight = MatchHighlight(
          id: highlightId,
          imageUrl: dataUrl,
          type: milestone.type.toString().split('.').last,
          title: milestone.title,
          description: desc,
          playerId: milestone.playerId,
          playerName: milestone.playerName,
          createdAt: DateTime.now(),
        );

        generatedHighlights.add(newHighlight);
      }

      final success = await _dataService.saveMatchHighlightsBatch(
        matchId: _match!.id,
        highlights: generatedHighlights,
      );

      if (!success) {
        allSavedToFirebase = false;
      }

      if (allSavedToFirebase) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 All highlights uploaded to Stars successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showErrorSnackBar('Failed to upload some highlights to match record.');
      }
    } catch (e) {
      _showErrorSnackBar('Error generating highlights: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMatch) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Generate Highlight Badge'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_match == null) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: Text('Could not load match details.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        title: const Text(
          'Share Key Moment Badge',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_milestones.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(left: 16.0.w, top: 16.0.h, bottom: 8.0.h),
                child: Text(
                  'Select Achievement'.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              SizedBox(
                height: 100.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12.0.w),
                  itemCount: _milestones.length,
                  itemBuilder: (context, index) {
                    final milestone = _milestones[index];
                    final isSelected = _selectedMilestone?.key == milestone.key;
                    IconData icon;
                    Color color;
                    switch (milestone.type) {
                      case BadgeType.win:
                        icon = Icons.emoji_events;
                        color = Colors.amber;
                        break;
                      case BadgeType.fifty:
                        icon = Icons.star;
                        color = Colors.cyan;
                        break;
                      case BadgeType.century:
                        icon = Icons.workspace_premium;
                        color = Colors.orange;
                        break;
                      case BadgeType.wicket:
                        icon = Icons.local_fire_department;
                        color = Colors.lightGreen;
                        break;
                      case BadgeType.mvp:
                        icon = Icons.emoji_events;
                        color = Colors.purpleAccent;
                        break;
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0.w, vertical: 8.0.h),
                      child: InkWell(
                        onTap: () => _selectMilestone(milestone),
                        borderRadius: BorderRadius.circular(16.r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 140.w,
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.2) : Colors.grey[900],
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: isSelected ? color : Colors.white.withOpacity(0.08),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: color, size: 20.sp),
                              SizedBox(height: 4.h),
                              Text(
                                milestone.playerName ?? 'Team Victory',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                milestone.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Padding(
                padding: EdgeInsets.all(24.0.w),
                child: Text(
                  'No achievements recorded for this match yet.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            Divider(color: Colors.white12, height: 24.h),

            if (_selectedMilestone != null) ...[
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    child: HighlightBadgeCard(
                      type: _selectedMilestone!.type,
                      title: _selectedMilestone!.title,
                      description: _descController.text.trim(),
                      matchName: _match!.matchName,
                      ground: _match!.ground,
                      date: DateFormat('dd MMM yyyy').format(_match!.scheduledDate),
                      playerName: _selectedMilestone!.playerName,
                      playerPhoto: kIsWeb ? _selectedImageBytes[_selectedMilestone!.key] : _selectedImages[_selectedMilestone!.key],
                      team1Name: _match!.team1Name,
                      team2Name: _match!.team2Name,
                      team1Score: '${_match!.team1Score.runs}/${_match!.team1Score.wickets} (${_match!.team1Score.oversDisplay} ov)',
                      team2Score: '${_match!.team2Score.runs}/${_match!.team2Score.wickets} (${_match!.team2Score.oversDisplay} ov)',
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Customize Description',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _descController,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter description...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryOrange),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        fillColor: Colors.grey[900],
                        filled: true,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _customDescriptions[_selectedMilestone!.key] = val;
                        });
                      },
                    ),

                    SizedBox(height: 16.h),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: Icon(Icons.photo_library),
                            label: const Text('Add Gallery Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton(
                      onPressed: _isGenerating ? null : _generateAndShareHighlight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primaryOrange.withOpacity(0.5),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 5,
                      ),
                      child: _isGenerating
                          ? SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload, size: 20.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'UPLOAD ALL TO TIMELINE',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
