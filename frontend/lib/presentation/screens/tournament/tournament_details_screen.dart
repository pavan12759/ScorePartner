import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../widgets/cinematic_poster_creator_dialog.dart';
import '../../widgets/cinematic_poster_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../matches/live_scoring_screen.dart';
import '../matches/match_detail_screen.dart';
import '../matches/create_match_screen.dart'; // Added
import 'tournament_join_requests_screen.dart'; // Added
import '../../widgets/toss_selection_dialog.dart';
import '../../widgets/match_config_dialog.dart';
import '../../widgets/manage_admins_dialog.dart';
import '../../widgets/qr_scanner_screen.dart';
import '../ground/ground_profile_screen.dart';
import '../profile/player_profile_screen.dart';
import '../../../data/models/user_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../../recalculate_stats_script.dart';

/// Enhanced Tournament Details Screen with Fixtures, Points Table, Stats, MVP
class TournamentDetailsScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentDetailsScreen({super.key, required this.tournament});

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, TeamModel> _teamsMap = {};
  bool _isLoadingTeams = true;
  late TournamentModel _tournament;
  
  // Track expanded state for stat sections
  final Map<String, bool> _expandedStatsSections = {};
  String _activeGalleryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tournament = widget.tournament;
    _tabController = TabController(length: 7, vsync: this);
    _loadTeams();
    
    // Auto-migrate old match data to populate empty bestBowling/Economy arrays
    _runMigrationAndReload();
    
    // Increment views
    FirebaseDataService.instance.incrementTournamentViews(widget.tournament.id);
  }
  
  Future<void> _runMigrationAndReload() async {
    await runRecalculationScript();
    
    // Fetch fresh tournament data after migration
    final updatedTournament = await FirebaseDataService.instance.getTournamentById(widget.tournament.id);
    if (updatedTournament != null && mounted) {
      debugPrint('Reloading UI with fresh tournament data. Economy stats: ${updatedTournament.bestEconomy.length}');
      setState(() {
        _tournament = updatedTournament;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    final teams = <String, TeamModel>{};
    for (final teamId in _tournament.registeredTeamIds) {
      final team = await FirebaseDataService.instance.getTeamById(teamId);
      if (team != null) {
        teams[teamId] = team;
      }
    }
    if (mounted) {
      setState(() {
        _teamsMap = teams;
        _isLoadingTeams = false;
      });
    }
  }

  Future<void> _generateFixtures() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryOrange),
                SizedBox(height: 16.h),
                Text('Generating fixtures...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // Get team models
      final teams = _teamsMap.values.toList();
      
      // Generate fixtures
      final fixtures = await FirebaseDataService.instance.generateFixtures(
        tournamentId: _tournament.id,
        format: _tournament.format,
        teams: teams,
        startDate: _tournament.startDate,
      );
      
      // Reload tournament data
      final updatedTournament = await FirebaseDataService.instance.getTournament(_tournament.id);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (updatedTournament != null) {
          setState(() {
            _tournament = updatedTournament;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Generated ${fixtures.length} fixtures'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareViaApps() {
    final t = _tournament;
    final shareText = '''
🏏 Join my tournament "${t.name}" on ScorePartner!

📍 Location: ${t.location}
📅 Date: ${_formatDate(t.startDate)} - ${_formatDate(t.endDate)}
🎯 Format: ${t.format.toUpperCase()} • ${t.overs} Overs
🏆 Prize Pool: ₹${t.prizePool.toStringAsFixed(0)}
👥 Teams: ${t.registeredTeamIds.length}/${t.maxTeams}

Click here to join or view:
https://scorepartner.in/tournament/${t.id}
''';

    Share.share(shareText, subject: 'Join ${t.name} on ScorePartner');
  }

  void _showEditTournamentDialog() {
    final nameController = TextEditingController(text: _tournament.name);
    final locationController = TextEditingController(text: _tournament.location);
    final descriptionController = TextEditingController(text: _tournament.description);
    final entryFeeController = TextEditingController(text: _tournament.entryFee.toStringAsFixed(0));
    final prizePoolController = TextEditingController(text: _tournament.prizePool.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tournament'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tournament Name',
                  prefixIcon: Icon(Icons.emoji_events, color: AppTheme.primaryOrange),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryOrange),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description, color: AppTheme.primaryOrange),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: entryFeeController,
                decoration: const InputDecoration(
                  labelText: 'Entry Fee (₹)',
                  prefixIcon: Icon(Icons.payments, color: AppTheme.primaryOrange),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: prizePoolController,
                decoration: const InputDecoration(
                  labelText: 'Prize Pool (₹)',
                  prefixIcon: Icon(Icons.emoji_events, color: AppTheme.primaryOrange),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseDataService.instance.updateTournament(
                  _tournament.id,
                  {
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'entryFee': double.tryParse(entryFeeController.text) ?? 0,
                    'prizePool': double.tryParse(prizePoolController.text) ?? 0,
                  },
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Tournament updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManageAdmins() {
    showDialog(
      context: context,
      builder: (context) => ManageAdminsDialog(
        tournamentId: _tournament.id,
        organizerId: _tournament.organizerId,
        currentAdminIds: _tournament.adminIds,
        onAdminsUpdated: (newAdminIds) {
          // Tournament will refresh automatically via stream
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Admins updated successfully')),
          );
        },
      ),
    );
  }

  void _showDeleteTournamentDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tournament'),
        content: Text('Are you sure you want to delete "${_tournament.name}"? This will permanently delete the tournament and all its matches. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog

              // Show loading indicator using the outer context
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
              );

              final success = await FirebaseDataService.instance.deleteTournament(_tournament.id);

              if (mounted) {
                // Pop the loading indicator using screen context
                Navigator.of(context).pop(); 

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tournament deleted successfully')),
                  );
                  Navigator.of(context).pop(); // Go back to previous screen
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete tournament'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadBanner() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryOrange),
                  SizedBox(height: 16.h),
                  Text('Uploading background...'),
                ],
              ),
            ),
          ),
        ),
      );

      final Uint8List rawBytes = await pickedFile.readAsBytes();
      debugPrint('📸 Banner image raw size: ${rawBytes.length} bytes');

      // Resize to 800x400 for banner
      Uint8List finalBytes = rawBytes;
      try {
        final codec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: 800,
          targetHeight: 400,
        );
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          finalBytes = byteData.buffer.asUint8List();
          debugPrint('📸 Resized to 800x400: ${finalBytes.length} bytes');
        }
      } catch (e) {
        debugPrint('⚠️ Resize failed, using original: $e');
      }

      final base64Image = base64Encode(finalBytes);
      final dataUrl = 'data:image/png;base64,$base64Image';

      if (dataUrl.length > 900000) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Image too large. Please choose a smaller image.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await FirebaseDataService.instance.updateTournament(
        _tournament.id,
        {'bannerUrl': dataUrl},
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Background image updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code, color: AppTheme.primaryOrange),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                _tournament.name,
                style: TextStyle(fontSize: 16.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220.w,
              height: 220.h,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: 'https://scorepartner.in/tournament/${_tournament.id}',
                version: QrVersions.auto,
                size: 200.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Tournament ID: ${_tournament.id}',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            const Text(
              'Scan to join tournament',
              style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TournamentModel?>(
      stream: FirebaseDataService.instance.streamTournament(_tournament.id),
      initialData: _tournament,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('Error loading tournament')));
        }
        
        if (snapshot.connectionState == ConnectionState.active && !snapshot.hasData) {
          // Document was deleted. Return a placeholder or empty Scaffold while the deletion pop finishes.
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          _tournament = snapshot.data!;
        }
        return Scaffold(
          backgroundColor: Colors.grey[100],
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 310, // Increased to 310 to push TabBar down and reveal location
                pinned: true,
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: _shareViaApps,
                    tooltip: 'Share Tournament',
                  ),
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final userId = auth.user?.uid;
                      final isOrganizer = userId == _tournament.organizerId;
                      final isAdmin = _tournament.adminIds.contains(userId);
                      final canManage = isOrganizer || isAdmin;
                      return PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert),
                        tooltip: 'More options',
                        onSelected: (value) async {
                          switch (value) {
                            case 'copy_link':
                              final link = 'https://scorepartner.in/tournament/${_tournament.id}';
                              await Clipboard.setData(ClipboardData(text: link));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tournament link copied!')),
                                );
                              }
                              break;

                            case 'qr_code':
                              _showQRCode();
                              break;
                            case 'manage_admins':
                              _showManageAdmins();
                              break;
                            case 'view_join_requests':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TournamentJoinRequestsScreen(tournament: _tournament),
                                ),
                              );
                              break;
                            case 'edit_tournament':
                              _showEditTournamentDialog();
                              break;
                            case 'change_background':
                              _pickAndUploadBanner();
                              break;
                            case 'delete_tournament':
                              _showDeleteTournamentDialog();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'copy_link',
                            child: ListTile(
                              leading: Icon(Icons.copy, color: AppTheme.primaryOrange),
                              title: Text('Copy Link'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),

                          const PopupMenuItem(
                            value: 'qr_code',
                            child: ListTile(
                              leading: Icon(Icons.qr_code, color: AppTheme.primaryOrange),
                              title: Text('Show QR Code'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (isOrganizer)
                            const PopupMenuItem(
                              value: 'manage_admins',
                              child: ListTile(
                                leading: Icon(Icons.admin_panel_settings, color: AppTheme.primaryOrange),
                                title: Text('Manage Admins'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (canManage)
                            const PopupMenuItem(
                              value: 'view_join_requests',
                              child: ListTile(
                                leading: Icon(Icons.group_add, color: AppTheme.primaryOrange),
                                title: Text('Join Requests'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (canManage)
                            const PopupMenuItem(
                              value: 'edit_tournament',
                              child: ListTile(
                                leading: Icon(Icons.edit, color: AppTheme.primaryOrange),
                                title: Text('Edit Tournament'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (canManage)
                            const PopupMenuItem(
                              value: 'change_background',
                              child: ListTile(
                                leading: Icon(Icons.image, color: AppTheme.primaryOrange),
                                title: Text('Change Background'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (canManage)
                            const PopupMenuItem(
                              value: 'delete_tournament',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text('Delete Tournament', style: TextStyle(color: Colors.red)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  collapseMode: CollapseMode.pin,
                  background: _AnimatedTournamentHeader(
                    tournamentName: _tournament.name,
                    location: _tournament.location,
                    status: _tournament.effectiveStatus,
                    teamsCount: _tournament.registeredTeamIds.length,
                    maxTeams: _tournament.maxTeams,
                    views: _tournament.views,
                    bannerUrl: _tournament.bannerUrl,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: _buildNavigationPills(),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildFixturesTab(),
                _buildTeamsTab(),
                _buildPointsTable(),
                _buildStatsTab(),
                _buildMVPTab(),
                _buildGalleryTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _navItems => [
    {'icon': Icons.description_rounded, 'label': 'Overview', 'tabIndex': 0},
    {'icon': Icons.calendar_month_rounded, 'label': 'Fixtures', 'tabIndex': 1},
    {'icon': Icons.groups_rounded, 'label': 'Teams', 'tabIndex': 2},
    {'icon': Icons.table_chart_rounded, 'label': 'Table', 'tabIndex': 3},
    {'icon': Icons.bar_chart_rounded, 'label': 'Stats', 'tabIndex': 4},
    {'icon': Icons.star_rounded, 'label': 'MVPs', 'tabIndex': 5},
    {'icon': Icons.photo_library_rounded, 'label': 'Gallery', 'tabIndex': 6},
  ];

  Widget _buildNavigationPills() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _navItems.length,
            itemBuilder: (context, index) {
              final item = _navItems[index];
              return _buildNavPill(item);
            },
          ),
        );
      },
    );
  }

  Widget _buildNavPill(Map<String, dynamic> item) {
    final isSelected = _tabController.index == item['tabIndex'];

    return Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25.r),
          onTap: () {
            _tabController.animateTo(item['tabIndex']);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
              border: isSelected
                  ? null
                  : Border.all(
                      color: Colors.grey.shade300,
                      width: 1.w,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        item['icon'],
                        color: isSelected ? Colors.white : Colors.black54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  item['label'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13.sp,
                    letterSpacing: isSelected ? 0.3 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverviewTab() {
    final t = _tournament;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======== Tournament Details Card ========
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: icon + title + status badge
                  Row(
                    children: [
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.sports_cricket, size: 18.sp, color: AppTheme.primaryOrange),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Tournament Details',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: _getStatusColor(t.effectiveStatus),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          t.effectiveStatus.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.sp,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Orange gradient divider
                  Container(
                    height: 2.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange,
                          AppTheme.primaryOrange.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1.r),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Two-column grid of details
                  // Row 1: Organizer | Format
                  _buildTwoColumnRow(
                    left: _buildGridDetailItem(Icons.admin_panel_settings, 'Organizer', t.organizerName.isNotEmpty ? t.organizerName : 'Unknown', isOrganizer: true, organizerId: t.organizerId),
                    right: _buildGridDetailItem(Icons.category, 'Format', t.format.toUpperCase()),
                  ),
                  SizedBox(height: 16.h),

                  // Row 2: Start Date | Category
                  _buildTwoColumnRow(
                    left: _buildGridDetailItem(Icons.calendar_today, 'Start Date', _formatDate(t.startDate)),
                    right: _buildGridDetailItem(Icons.label, 'Category', _getCategoryDisplayName(t.category)),
                  ),
                  SizedBox(height: 16.h),

                  // Row 3: End Date | Power Play
                  _buildTwoColumnRow(
                    left: _buildGridDetailItem(Icons.event, 'End Date', _formatDate(t.endDate)),
                    right: t.powerPlayOvers > 0
                        ? _buildGridDetailItem(Icons.flash_on, 'Power Play', '${t.powerPlayOvers} Overs')
                        : SizedBox.shrink(),
                  ),
                  SizedBox(height: 16.h),

                  // Row 4: Ball Type | Teams
                  _buildTwoColumnRow(
                    left: _buildGridDetailItem(Icons.sports_cricket, 'Ball Type', t.ballType.toUpperCase()),
                    right: _buildGridDetailItem(Icons.groups, 'Teams', '${t.registeredTeamIds.length} / ${t.maxTeams}'),
                  ),
                  SizedBox(height: 16.h),

                  // Row 5: Overs (single item)
                  _buildTwoColumnRow(
                    left: _buildGridDetailItem(Icons.timer, 'Overs', '${t.overs}'),
                    right: SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // ======== Prize & Entry Card ========
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + title
                  Row(
                    children: [
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.emoji_events, size: 18.sp, color: AppTheme.primaryOrange),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Prize & Entry',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Orange gradient divider
                  Container(
                    height: 2.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange,
                          AppTheme.primaryOrange.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1.r),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Prize boxes side by side
                  Row(
                    children: [
                      // Entry Fee Box
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.h,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(Icons.payments, size: 18.sp, color: AppTheme.primaryOrange),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Entry Fee',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '₹${t.entryFee.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Prize Pool Box
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.h,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(Icons.emoji_events, size: 18.sp, color: AppTheme.primaryOrange),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prize Pool',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '₹${t.prizePool.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (t.description.isNotEmpty) ...[
            SizedBox(height: 16.h),
            _buildInfoCard('Description', [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(t.description),
              ),
            ]),
          ],

          SizedBox(height: 24.h),

          // Quick Stats
          _buildQuickStats(),
        ],
      ),
    );
  }

  /// Two-column row helper for the tournament details grid
  Widget _buildTwoColumnRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: 12.w),
        Expanded(child: right),
      ],
    );
  }

  /// Single grid detail item: icon (in tinted circle) + label + bold value
  Widget _buildGridDetailItem(
    IconData icon,
    String label,
    String value, {
    bool isOrganizer = false,
    String? organizerId,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34.w,
          height: 34.h,
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 17.sp, color: AppTheme.primaryOrange),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              isOrganizer
                  ? GestureDetector(
                      onTap: () => _navigateToOrganizerProfile(organizerId ?? ''),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryOrange,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primaryOrange,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final t = _tournament;
    return Row(
      children: [
        Expanded(child: _buildStatCard('Teams', '${t.registeredTeamIds.length}', Icons.groups)),
        SizedBox(width: 12.w),
        Expanded(child: _buildStatCard('Fixtures', '${t.fixtures.length}', Icons.sports_cricket)),
        SizedBox(width: 12.w),
        Expanded(child: _buildStatCard('Completed', '${t.fixtures.where((f) => f.status == 'completed').length}', Icons.check_circle)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryOrange, size: 28.sp),
          SizedBox(height: 8.h),
          Text(value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
        ],
      ),
    );
  }

  void _navigateToCreateMatch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(
          tournament: _tournament,
          tournamentTeams: _teamsMap.values.toList(),
        ),
      ),
    );
  }

  // ==================== FIXTURES TAB ====================
  Widget _buildFixturesTab() {
    final fixtures = _tournament.fixtures;

    if (fixtures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_cricket, size: 64.sp, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'No Fixtures Yet',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            SizedBox(height: 8.h),
            Text(
              'Generate fixtures to start the tournament',
                style: TextStyle(color: Colors.grey[500]),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_tournament.registeredTeamIds.length >= 2)
                  ElevatedButton.icon(
                    onPressed: _generateFixtures,
                    icon: Icon(Icons.auto_fix_high),
                    label: const Text('Generate Fixtures'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    ),
                  ),
                SizedBox(width: 12.w),
                 Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final userId = auth.user?.uid;
                    final canManage = userId == _tournament.organizerId || _tournament.adminIds.contains(userId);
                     if (!canManage) return SizedBox.shrink();
                     return OutlinedButton.icon(
                      onPressed: _navigateToCreateMatch,
                      icon: Icon(Icons.add),
                      label: const Text('Create Match'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      ),
                    );
                  }
                 )
              ],
            ),
            if (_tournament.registeredTeamIds.length < 2)
              Container(
                padding: EdgeInsets.all(16.w),
                margin: EdgeInsets.symmetric(horizontal: 32.w),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Add at least 2 teams to generate fixtures',
                        style: TextStyle(color: Colors.amber[800]),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // Group fixtures by round
    final Map<String, List<TournamentFixture>> fixturesByRound = {};
    for (final fixture in fixtures) {
      final round = fixture.groupName ?? fixture.round;
      fixturesByRound.putIfAbsent(round, () => []).add(fixture);
    }

    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: fixturesByRound.length + 1, // +1 for padding at bottom
          itemBuilder: (context, index) {
            if (index == fixturesByRound.length) {
              return SizedBox(height: 80.h); // Spacer for FAB
            }
            final round = fixturesByRound.keys.elementAt(index);
            final roundFixtures = fixturesByRound[round]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  margin: EdgeInsets.only(bottom: 8.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    round,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                  ),
                ),
                ...roundFixtures.map((fixture) => _buildFixtureCard(fixture)),
                SizedBox(height: 16.h),
              ],
            );
          },
        ),
        Positioned(
          bottom: 16.h,
          right: 16.w,
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final userId = auth.user?.uid;
              final canManage = userId == _tournament.organizerId || _tournament.adminIds.contains(userId);
              if (!canManage) return SizedBox.shrink();
              
              return FloatingActionButton.extended(
                onPressed: _navigateToCreateMatch,
                icon: Icon(Icons.add, color: Colors.white),
                label: const Text('Create Match', style: TextStyle(color: Colors.white)),
                backgroundColor: AppTheme.primaryOrange,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFixtureCard(TournamentFixture fixture) {
    final isCompleted = fixture.status == 'completed';
    final isLive = fixture.status == 'live';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: isLive ? Border.all(color: Colors.green, width: 2.w) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onFixtureTap(fixture),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: [
                // Match Number & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fixture.round,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: _getFixtureStatusColor(fixture.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        fixture.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: _getFixtureStatusColor(fixture.status),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Teams
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                            child: Text(
                              fixture.team1Name.isNotEmpty ? fixture.team1Name[0].toUpperCase() : '?',
                              style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            fixture.team1Name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: fixture.winnerId == fixture.team1Id ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12.sp,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Team 1 Score (if available)
                          if (fixture.team1Score != null && fixture.team1Score!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                fixture.team1Score!,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: fixture.winnerId == fixture.team1Id ? Colors.green : Colors.black87,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: Text(
                              fixture.team2Name.isNotEmpty ? fixture.team2Name[0].toUpperCase() : '?',
                              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            fixture.team2Name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: fixture.winnerId == fixture.team2Id ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12.sp,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Team 2 Score (if available)
                          if (fixture.team2Score != null && fixture.team2Score!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                fixture.team2Score!,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: fixture.winnerId == fixture.team2Id ? Colors.green : Colors.black87,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Winner Banner (when completed)
                if (isCompleted && fixture.winnerId != null && fixture.winnerId!.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber, size: 18.sp),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            '${fixture.winnerId == fixture.team1Id ? fixture.team1Name : fixture.team2Name} Won',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (fixture.scheduledDate != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    _formatDate(fixture.scheduledDate!),
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onFixtureTap(TournamentFixture fixture) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    // Check if user is organizer or co-admin
    final isOrganizer = userId == _tournament.organizerId;
    final isAdmin = _tournament.adminIds.contains(userId);
    debugPrint('Admin Access Check: UserID=$userId, OrganizerID=${_tournament.organizerId}, IsAdmin=$isAdmin');
    final canManageMatches = isOrganizer || isAdmin;

    if (!canManageMatches) {
      // For non-admins, just view match details if available
      if (fixture.matchId != null && (fixture.status == 'live' || fixture.status == 'completed')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: fixture.matchId!)),
        );
      }
      return;
    }


    // Admin Actions
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            child: Text(
              '${fixture.team1Name} vs ${fixture.team2Name}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
            ),
          ),
          const Divider(),
          if (fixture.status != 'completed')
             ListTile(
              leading: Icon(Icons.play_arrow, color: Colors.green),
              title: Text(fixture.status == 'live' ? 'Resume Match' : 'Start Match'),
              onTap: () {
                Navigator.pop(context);
                _startOrResumeMatch(fixture);
              },
            ),
          if (fixture.matchId != null)
             ListTile(
              leading: Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Scorecard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: fixture.matchId!)),
                );
              },
            ),
          if (fixture.status == 'pending' || fixture.status == 'scheduled')
             ListTile(
               leading: Icon(Icons.edit, color: Colors.orange),
               title: const Text('Edit Fixture'),
               onTap: () {
                 Navigator.pop(context);
                 // TODO: Implement Edit Fixture (Date/Time/Venue)
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Fixture coming soon')));
               },
             ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Match', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteFixture(fixture);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFixture(TournamentFixture fixture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Match'),
        content: Text(
          'Are you sure you want to delete the match "${fixture.team1Name} vs ${fixture.team2Name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFixture(fixture);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFixture(TournamentFixture fixture) async {
    try {
      final success = await FirebaseDataService.instance.deleteFixtureFromTournament(
        _tournament.id,
        fixture.id,
        matchId: fixture.matchId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Match deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to delete match'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startOrResumeMatch(TournamentFixture fixture) async {
    // If already started, go to live scoring
    if (fixture.matchId != null && fixture.matchId!.isNotEmpty) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LiveScoringScreen(matchId: fixture.matchId!)),
      ).then((_) => setState(() {})); // Refresh on return
      return;
    }

    // Step 1: Match Configuration Dialog
    final matchConfig = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MatchConfigDialog(
        team1Name: fixture.team1Name,
        team2Name: fixture.team2Name,
        defaultOvers: fixture.overs ?? _tournament.overs,
        defaultVenue: fixture.venue ?? _tournament.location,
        matchFormat: _tournament.matchFormat, // Pass format
      ),
    );

    if (matchConfig == null) return; // User cancelled

    final matchOvers = matchConfig['overs'] as int;
    final matchVenue = matchConfig['venue'] as String? ?? fixture.venue ?? _tournament.location;
    final matchLatitude = matchConfig['latitude'] as double?;
    final matchLongitude = matchConfig['longitude'] as double?;

    // Step 2: Toss Selection
    final tossResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TossSelectionDialog(
        team1Name: fixture.team1Name,
        team2Name: fixture.team2Name,
      ),
    );

    if (tossResult == null) return; // User cancelled

    final winnerIndex = tossResult['winnerIndex'] as int;
    final decision = tossResult['decision'] as String;
    
    // Determine Batting Team
    // If Team 1 won toss and chose bat -> Team 1 bats
    // If Team 1 won toss and chose field -> Team 2 bats
    // If Team 2 won toss and chose bat -> Team 2 bats
    // If Team 2 won toss and chose field -> Team 1 bats
    
    final tossWinnerId = winnerIndex == 0 ? fixture.team1Id : fixture.team2Id;
    
    String currentBattingTeam = 'team1';
    String bowlingTeam = 'team2';
    
    if (winnerIndex == 0) { // Team 1 won toss
      if (decision == 'bat') {
        currentBattingTeam = 'team1';
        bowlingTeam = 'team2';
      } else {
        currentBattingTeam = 'team2';
        bowlingTeam = 'team1';
      }
    } else { // Team 2 won toss
      if (decision == 'bat') {
        currentBattingTeam = 'team2';
        bowlingTeam = 'team1';
      } else {
        currentBattingTeam = 'team1';
        bowlingTeam = 'team2';
      }
    }

    // Create Match with configured overs and venue
    final match = MatchModel(
      id: '', 
      matchName: '${_tournament.name} - ${fixture.round}',
      tournamentId: _tournament.id,
      team1Id: fixture.team1Id,
      team1Name: fixture.team1Name,
      team2Id: fixture.team2Id,
      team2Name: fixture.team2Name,
      ground: matchVenue,
      location: matchVenue,
      latitude: matchLatitude,
      longitude: matchLongitude,
      matchType: _tournament.ballType,
      oversPerSide: matchOvers,
      matchFormat: _tournament.matchFormat,
      powerplayConfig: _tournament.matchFormat == 'Custom' && _tournament.powerPlayOvers > 0
          ? [
              PowerplayPhase(name: 'Powerplay', startOver: 1, endOver: _tournament.powerPlayOvers, maxFieldersOutside: 2),
              if (_tournament.powerPlayOvers < matchOvers)
                PowerplayPhase(name: 'Middle/Death Overs', startOver: _tournament.powerPlayOvers + 1, endOver: matchOvers, maxFieldersOutside: 5),
            ]
          : (MatchModel.getFormatDefaults(_tournament.matchFormat)['powerplay'] as List<PowerplayPhase>),
      status: 'live',
      currentInnings: 1,
      currentBattingTeam: currentBattingTeam,
      bowlingTeam: bowlingTeam,
      currentOver: 0,
      currentBall: 0,
      createdBy: _tournament.organizerId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      scheduledDate: fixture.scheduledDate ?? DateTime.now(),
      team1Score: TeamScore(runs: 0, wickets: 0, overs: 0, batters: [], bowlers: []),
      team2Score: TeamScore(runs: 0, wickets: 0, overs: 0, batters: [], bowlers: []),
      ballByBall: [],
      tossWinnerId: tossWinnerId,
      tossDecision: decision,
      playerIds: [],
    );

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final createdMatch = await FirebaseDataService.instance.createMatch(match, _tournament.organizerId);

    if (!mounted) return;
    Navigator.pop(context); // Hide loading

    if (createdMatch != null) {
      // Update Fixture in Tournament
      final updatedFixtures = _tournament.fixtures.map((f) {
        if (f.id == fixture.id) {
          return f.copyWith(
            matchId: createdMatch.id,
            status: 'live',
          );
        }
        return f;
      }).toList();
      
      // Prepare update data - also update status to 'ongoing' if tournament is still 'upcoming' or 'registration'
      final updateData = <String, dynamic>{
        'fixtures': updatedFixtures.map((e) => e.toMap()).toList(),
      };
      
      // Auto-update tournament status to ongoing when first match starts
      if (_tournament.status == 'upcoming' || _tournament.status == 'registration') {
        updateData['status'] = 'ongoing';
      }
      
      final success = await FirebaseDataService.instance.updateTournament(_tournament.id, updateData);

      if (success) {
        // Navigate to Live Scoring
        if (mounted) {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LiveScoringScreen(matchId: createdMatch.id)),
          ).then((_) {
             setState(() {}); 
          }); 
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update tournament fixtures')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create match')));
    }
  }

  // ==================== TEAMS TAB ====================
  Widget _buildTeamsTab() {
    if (_isLoadingTeams) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget content;
    if (_tournament.registeredTeamIds.isEmpty) {
      content = _buildEmptyState(
        icon: Icons.groups_outlined,
        title: 'No Teams Registered',
        subtitle: 'Teams will appear here once registered',
      );
    } else {
      content = ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _tournament.registeredTeamIds.length + 1, // Bottom padding
        itemBuilder: (context, index) {
          if (index == _tournament.registeredTeamIds.length) {
            return SizedBox(height: 80.h);
          }
          final teamId = _tournament.registeredTeamIds[index];
          final team = _teamsMap[teamId];

          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: team != null ? () => _showTeamSquad(team) : null,
                contentPadding: EdgeInsets.all(12.w),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                child: Text(
                  team?.name.isNotEmpty == true ? team!.name[0].toUpperCase() : '?',
                  style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(team?.name ?? 'Unknown Team', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: team != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4.h),
                        Text('Captain: ${team.captainName}', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                        Text('Players: ${team.players.length}', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                      ],
                    )
                  : Text('ID: $teamId', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              trailing: team != null
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        team.spTId ?? 'N/A',
                        style: TextStyle(fontSize: 10.sp, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
              ),
            ),
          );
        },
      );
    }

    return Stack(
      children: [
        content,
         Positioned(
          bottom: 16.h,
          right: 16.w,
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final userId = auth.user?.uid;
              final isOrganizer = userId == _tournament.organizerId;
              final isAdmin = _tournament.adminIds?.contains(userId) ?? false;
              final canManage = isOrganizer || isAdmin;
              
              if (!canManage) return SizedBox.shrink();
              
              return FloatingActionButton.extended(
                onPressed: _showAddTeamDialog,
                icon: Icon(Icons.add, color: Colors.white),
                label: const Text('Add Team', style: TextStyle(color: Colors.white)),
                backgroundColor: AppTheme.primaryOrange,
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== POINTS TABLE TAB ====================
  Widget _buildPointsTable() {
    // if (_tournament.format != 'league' && _tournament.format != 'group') {
    //   return _buildEmptyState(
    //     icon: Icons.table_chart,
    //     title: 'Points Table',
    //     subtitle: 'Points table is available for League and Group formats only',
    //   );
    // }
    
    debugPrint('PointsTable: Registered Teams: ${_tournament.registeredTeamIds.length}');
    debugPrint('PointsTable: Teams Map: ${_teamsMap.length}');

    // Merge points table with all registered teams
    // This ensures teams that haven't played yet still appear in the table
    final Map<String, TeamPoints> pointsMap = {
      for (var p in _tournament.pointsTable) p.teamId: p
    };

    List<TeamPoints> pointsData = _tournament.registeredTeamIds.map((teamId) {
      if (pointsMap.containsKey(teamId)) {
        return pointsMap[teamId]!;
      } else {
        // Create default entry for team with no matches
        final team = _teamsMap[teamId];
        return TeamPoints(
          teamId: teamId,
          teamName: team?.name ?? 'Unknown Team',
        );
      }
    }).toList();

    // Sort by Points (Desc), then NRR (Desc)
    pointsData.sort((a, b) {
      int result = b.points.compareTo(a.points);
      if (result == 0) {
        return b.nrr.compareTo(a.nrr);
      }
      return result;
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Header Legend
          Container(
            padding: EdgeInsets.all(12.w),
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16.sp, color: Colors.green),
                SizedBox(width: 8.w),
                Text(
                  'Qualification Zone - Top 2 teams qualify',
                  style: TextStyle(fontSize: 12.sp, color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Points Table Card (ICC-style)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('TEAM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp))),
                      Expanded(child: Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp), textAlign: TextAlign.center)),
                      Expanded(child: Text('W', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp), textAlign: TextAlign.center)),
                      Expanded(child: Text('L', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp), textAlign: TextAlign.center)),
                      Expanded(child: Text('NRR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp), textAlign: TextAlign.center)),
                      Expanded(child: Text('PTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp), textAlign: TextAlign.center)),
                    ],
                  ),
                ),

                // Table Rows
                if (pointsData.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text('No data available'),
                  )
                else
                  ...pointsData.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final isQualified = idx < 2;

                    return Container(
                      height: 48.h, // Fixed height instead of IntrinsicHeight to prevent RenderFlex overflow
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                        color: isQualified ? Colors.green.withOpacity(0.02) : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children to fill fixed height
                        children: [
                          // Team Cell
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              child: Row(
                                children: [
                                  Text('${idx + 1}', style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      p.teamName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isQualified)
                                    Icon(Icons.check_circle, size: 12.sp, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                          // Stats Cells
                          Expanded(child: Center(child: Text('${p.played}', style: TextStyle(fontSize: 12.sp)))),
                          Expanded(child: Center(child: Text('${p.won}', style: TextStyle(fontSize: 12.sp)))),
                          Expanded(child: Center(child: Text('${p.lost}', style: TextStyle(fontSize: 12.sp)))),
                          Expanded(child: Center(child: Text(p.nrr.toStringAsFixed(3), style: TextStyle(fontSize: 11.sp)))),
                          Expanded(
                            child: Container(
                              color: AppTheme.primaryOrange.withOpacity(0.05),
                              alignment: Alignment.center,
                              child: Text(
                                '${p.points}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTeamDialog() {
    final TextEditingController teamIdController = TextEditingController();
    bool isSearching = false;
    String? errorMessage;
    TeamModel? foundTeam;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (stfContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24.h,
                left: 20.w,
                right: 20.w,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add Team to Tournament',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: teamIdController,
                          decoration: InputDecoration(
                            labelText: 'Team SPT ID',
                            hintText: 'Enter specific Team ID',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            prefixIcon: Icon(Icons.search),
                            errorText: errorMessage,
                          ),
                          onSubmitted: (_) async {
                            final sptId = teamIdController.text.trim();
                            if (sptId.isEmpty) return;

                            setModalState(() {
                              isSearching = true;
                              errorMessage = null;
                              foundTeam = null;
                            });

                            final team = await FirebaseDataService.instance.getTeamBySptId(sptId);

                            setModalState(() {
                              isSearching = false;
                              if (team == null) {
                                errorMessage = 'Team not found. Please check the ID.';
                              } else if (_tournament.registeredTeamIds.contains(team.id)) {
                                errorMessage = 'Team is already in this tournament.';
                              } else if (_tournament.registeredTeamIds.length >= _tournament.maxTeams) {
                                errorMessage = 'Tournament has reached maximum capacity (${_tournament.maxTeams} teams).';
                              } else {
                                foundTeam = team;
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryOrange),
                          onPressed: () async {
                            final String? barcode = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QRScannerScreen(),
                              ),
                            );

                            if (barcode != null && barcode.isNotEmpty) {
                              teamIdController.text = barcode;
                              // Auto-trigger search
                              setModalState(() {
                                isSearching = true;
                                errorMessage = null;
                                foundTeam = null;
                              });

                              final team = await FirebaseDataService.instance.getTeamBySptId(barcode);

                              setModalState(() {
                                isSearching = false;
                                if (team == null) {
                                  errorMessage = 'Team not found. Please check the ID.';
                                } else if (_tournament.registeredTeamIds.contains(team.id)) {
                                  errorMessage = 'Team is already in this tournament.';
                                } else if (_tournament.registeredTeamIds.length >= _tournament.maxTeams) {
                                  errorMessage = 'Tournament has reached maximum capacity (${_tournament.maxTeams} teams).';
                                } else {
                                  foundTeam = team;
                                }
                              });
                            }
                          },
                          tooltip: 'Scan QR Code',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                  if (foundTeam != null) ...[
                    Card(
                      elevation: 0,
                      color: Colors.green.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.2),
                          child: Text(
                            foundTeam!.name.isNotEmpty ? foundTeam!.name[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(foundTeam!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Captain: ${foundTeam!.captainName}\nPlayers: ${foundTeam!.players.length}'),
                        isThreeLine: true,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final teamId = foundTeam!.id;
                        Navigator.pop(modalContext); // Close modal
                        
                        // Show loading dialog using screen context
                        if (!mounted) return;
                        showDialog(
                          context: context, 
                          barrierDismissible: false,
                          builder: (loadingContext) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                        );

                        final success = await FirebaseDataService.instance.addTeamToTournament(_tournament.id, teamId);
                        
                        if (mounted) {
                          Navigator.of(context).pop(); // Close loading dialog
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Team ${foundTeam!.name} added to tournament!')),
                            );
                            _loadTeams(); // Reload teams
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to add team'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.add),
                      label: const Text('Add Team'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: () {
                         // Search logic here
                         final sptId = teamIdController.text.trim();
                          if (sptId.isEmpty) return;

                          setModalState(() {
                            isSearching = true;
                            errorMessage = null;
                            foundTeam = null;
                          });

                          FirebaseDataService.instance.getTeamBySptId(sptId).then((team) {
                            setModalState(() {
                              isSearching = false;
                              if (team == null) {
                                errorMessage = 'Team not found. Please check the ID.';
                              } else if (_tournament.registeredTeamIds.contains(team.id)) {
                                errorMessage = 'Team is already in this tournament.';
                              } else if (_tournament.registeredTeamIds.length >= _tournament.maxTeams) {
                                errorMessage = 'Tournament has reached maximum capacity (${_tournament.maxTeams} teams).';
                              } else {
                                foundTeam = team;
                              }
                            });
                          });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                  SizedBox(height: 24.h),
                  const Divider(),
                  SizedBox(height: 16.h),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(modalContext);
                      
                      // Show loading dialog
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (loadingContext) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                      );

                      final link = await FirebaseDataService.instance.generateTournamentInviteLink(_tournament.id);
                      
                      if (mounted) {
                        Navigator.of(context).pop(); // close loading
                        if (link != null) {
                          Share.share(
                            'Register your team for our tournament "${_tournament.name}" on ScorePartner!\n\nClick the link below:\n$link',
                            subject: 'Register for ${_tournament.name}',
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to generate invite link', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: Icon(Icons.link, color: AppTheme.primaryOrange),
                    label: const Text('Generate Invite Link', style: TextStyle(color: AppTheme.primaryOrange)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primaryOrange),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== STATS TAB ====================
  Widget _buildStatsTab() {
    final bool hasAnyData = (_tournament.topRunScorers.isNotEmpty ||
        _tournament.topWicketTakers.isNotEmpty ||
        _tournament.topSixHitters.isNotEmpty ||
        _tournament.topFourHitters.isNotEmpty ||
        _tournament.bestEconomy.isNotEmpty ||
        _tournament.bestBowlingFigures.isNotEmpty);

    if (!hasAnyData) {
      return _buildEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No Stats Yet',
        subtitle: 'Player statistics will appear once matches are completed',
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      child: Column(
        children: [
          // ── BATTING CATEGORY ──
          _buildCategoryHeader('🏏', 'BATTING', Color(0xFF1A73E8)),
          SizedBox(height: 12.h),
          _buildPremiumStatsCard(
            'Top Run Scorers',
            Icons.sports_cricket_rounded,
            Color(0xFF1A73E8),
            _tournament.topRunScorers ?? [],
            (e) => '${e.value}',
            'runs',
          ),
          SizedBox(height: 12.h),
          _buildPremiumStatsCard(
            'Most Sixes',
            Icons.rocket_launch_rounded,
            Color(0xFF7B1FA2),
            _tournament.topSixHitters ?? [],
            (e) => '${e.value}',
            'sixes',
          ),
          SizedBox(height: 12.h),
          _buildPremiumStatsCard(
            'Most Fours',
            Icons.bolt_rounded,
            Color(0xFFE65100),
            _tournament.topFourHitters ?? [],
            (e) => '${e.value}',
            'fours',
          ),

          SizedBox(height: 24.h),

          // ── BOWLING CATEGORY ──
          _buildCategoryHeader('🎯', 'BOWLING', Color(0xFF2E7D32)),
          SizedBox(height: 12.h),
          _buildPremiumStatsCard(
            'Top Wicket Takers',
            Icons.sports_baseball_rounded,
            Color(0xFF2E7D32),
            _tournament.topWicketTakers ?? [],
            (e) => '${e.value}',
            'wickets',
          ),
          SizedBox(height: 12.h),
          _buildPremiumStatsCard(
            'Best Economy',
            Icons.trending_down_rounded,
            Color(0xFF00838F),
            _tournament.bestEconomy ?? [],
            (e) => e.average > 0 ? e.average.toStringAsFixed(2) : '-',
            'econ',
          ),
          SizedBox(height: 12.h),
          _buildPremiumStatsCard(
            'Best Bowling Figures',
            Icons.military_tech_rounded,
            Color(0xFF4E342E),
            _tournament.bestBowlingFigures ?? [],
            (e) => e.description ?? '${e.value} wkts',
            '',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String emoji, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 24.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          emoji,
          style: TextStyle(fontSize: 18.sp),
        ),
        SizedBox(width: 6.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumStatsCard(
    String title,
    IconData icon,
    Color accentColor,
    List<TournamentLeaderboardEntry> data,
    String Function(TournamentLeaderboardEntry) valueFormatter,
    String unit,
  ) {
    if (data.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[400], size: 20.sp),
            SizedBox(width: 12.w),
            Text(title, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 13.sp)),
            const Spacer(),
            Text('No data', style: TextStyle(color: Colors.grey[400], fontSize: 12.sp)),
          ],
        ),
      );
    }

    final isExpanded = _expandedStatsSections[title] ?? false;
    final displayCount = isExpanded ? data.length : (data.length > 3 ? 3 : data.length);
    final displayData = data.take(displayCount).toList();
    final hasMore = data.length > 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${data.length} players',
                    style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Leader Highlight (Top #1)
          if (data.isNotEmpty)
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.06), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  // Gold Medal
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: Center(
                      child: Text(
                        data.first.playerName.isNotEmpty ? data.first.playerName[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('👑 ', style: TextStyle(fontSize: 12.sp)),
                            Flexible(
                              child: Text(
                                data.first.playerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.sp,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          data.first.teamName,
                          style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${valueFormatter(data.first)}${unit.isNotEmpty ? ' $unit' : ''}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Remaining players
          if (displayData.length > 1) ...[
            Divider(height: 1, color: Colors.grey[200]),
            ...displayData.sublist(1).asMap().entries.map((entry) {
              final idx = entry.key + 1; // 0-based after sublist(1), so actual rank is idx+1
              final player = entry.value;
              final rank = idx + 1;

              Color medalColor;
              if (rank == 2) {
                medalColor = const Color(0xFFC0C0C0); // Silver
              } else if (rank == 3) {
                medalColor = const Color(0xFFCD7F32); // Bronze
              } else {
                medalColor = Colors.grey[300]!;
              }

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 0.5)),
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        color: rank <= 3 ? medalColor : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: rank <= 3 ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.playerName,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            player.teamName,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${valueFormatter(player)}${unit.isNotEmpty ? ' $unit' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Show More / Less
          if (hasMore)
            InkWell(
              onTap: () {
                setState(() {
                  _expandedStatsSections[title] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.04),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isExpanded ? 'Show Less' : 'Show All ${data.length} Players',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: accentColor,
                      size: 18.sp,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== MVP TAB ====================
  Widget _buildMVPTab() {
    // Calculate MVP using weighted formula: runs + (wickets × 25) + (sixes × 6) + (fours × 4)
    final Map<String, _MvpCandidate> mvpScores = {};
    
    // Add runs
    for (var entry in _tournament.topRunScorers) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.runs = entry.value;
      mvpScores[entry.playerId]!.matches = entry.matches;
    }
    // Add wickets
    for (var entry in _tournament.topWicketTakers) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.wickets = entry.value;
    }
    // Add sixes
    for (var entry in _tournament.topSixHitters) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.sixes = entry.value;
    }
    // Add fours
    for (var entry in _tournament.topFourHitters) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.fours = entry.value;
    }
    
    // Sort by MVP score
    final sortedMvp = mvpScores.entries.toList()
      ..sort((a, b) => b.value.mvpScore.compareTo(a.value.mvpScore));
    
    final hasData = sortedMvp.isNotEmpty;
    final mvp = hasData ? sortedMvp.first.value : null;
    
    // Best Batsman = top run scorer
    final bestBatsman = _tournament.topRunScorers.isNotEmpty ? _tournament.topRunScorers.first : null;
    // Best Bowler = top wicket taker
    final bestBowler = _tournament.topWicketTakers.isNotEmpty ? _tournament.topWicketTakers.first : null;
    // Most Sixes
    final mostSixes = _tournament.topSixHitters.isNotEmpty ? _tournament.topSixHitters.first : null;
    // Most Fours
    final mostFours = _tournament.topFourHitters.isNotEmpty ? _tournament.topFourHitters.first : null;
    
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      child: Column(
        children: [
          // ── HERO MVP CARD ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(color: const Color(0xFF1A1A2E).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                // Trophy icon with glow
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: Icon(Icons.emoji_events_rounded, size: 40.sp, color: Colors.white),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    'MOST VALUABLE PLAYER',
                    style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  hasData ? mvp!.name : 'To Be Announced',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (hasData) ...[
                  SizedBox(height: 6.h),
                  Text(
                    mvp!.teamName,
                    style: TextStyle(color: Colors.white60, fontSize: 13.sp, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 20.h),
                  // Stats Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMvpStatPill('Runs', '${mvp.runs}', const Color(0xFF1A73E8)),
                      SizedBox(width: 8.w),
                      _buildMvpStatPill('Wkts', '${mvp.wickets}', const Color(0xFF2E7D32)),
                      SizedBox(width: 8.w),
                      _buildMvpStatPill('6s', '${mvp.sixes}', const Color(0xFF7B1FA2)),
                      SizedBox(width: 8.w),
                      _buildMvpStatPill('4s', '${mvp.fours}', const Color(0xFFE65100)),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // MVP Score Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      ),
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16.sp, color: Colors.white),
                        SizedBox(width: 4.w),
                        Text(
                          'MVP Score: ${mvp.mvpScore}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: EdgeInsets.only(top: 12.h),
                    child: Text(
                      'MVP will be calculated once matches are played',
                      style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ── AWARD CARDS ──
          _buildCategoryHeader('🏆', 'AWARDS', const Color(0xFFBF360C)),
          SizedBox(height: 12.h),
          
          // Awards Grid (2x2)
          Row(
            children: [
              Expanded(child: _buildAwardCard(
                '🏏', 'Best Batsman',
                bestBatsman?.playerName ?? 'TBA',
                bestBatsman != null ? '${bestBatsman.value} runs' : '-',
                bestBatsman?.teamName ?? '',
                const Color(0xFF1A73E8),
              )),
              SizedBox(width: 10.w),
              Expanded(child: _buildAwardCard(
                '⚾', 'Best Bowler',
                bestBowler?.playerName ?? 'TBA',
                bestBowler != null ? '${bestBowler.value} wkts' : '-',
                bestBowler?.teamName ?? '',
                const Color(0xFF2E7D32),
              )),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(child: _buildAwardCard(
                '🚀', 'Most Sixes',
                mostSixes?.playerName ?? 'TBA',
                mostSixes != null ? '${mostSixes.value} sixes' : '-',
                mostSixes?.teamName ?? '',
                const Color(0xFF7B1FA2),
              )),
              SizedBox(width: 10.w),
              Expanded(child: _buildAwardCard(
                '⚡', 'Most Fours',
                mostFours?.playerName ?? 'TBA',
                mostFours != null ? '${mostFours.value} fours' : '-',
                mostFours?.teamName ?? '',
                const Color(0xFFE65100),
              )),
            ],
          ),
          
          // ── MVP LEADERBOARD ──
          if (sortedMvp.length > 1) ...[
            SizedBox(height: 24.h),
            _buildCategoryHeader('📊', 'MVP LEADERBOARD', const Color(0xFF37474F)),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 32.w, child: Text('#', style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w700))),
                        Expanded(child: Text('PLAYER', style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                        SizedBox(width: 45.w, child: Text('R', style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                        SizedBox(width: 35.w, child: Text('W', style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                        SizedBox(width: 55.w, child: Text('PTS', style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  // Rows
                  ...sortedMvp.take(10).toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final candidate = entry.value.value;
                    final rank = idx + 1;

                    Color? rowBg;
                    Color rankBgColor;
                    if (rank == 1) {
                      rowBg = const Color(0xFFFFF8E1);
                      rankBgColor = const Color(0xFFFFD700);
                    } else if (rank == 2) {
                      rowBg = const Color(0xFFF5F5F5);
                      rankBgColor = const Color(0xFFC0C0C0);
                    } else if (rank == 3) {
                      rowBg = const Color(0xFFFBE9E7);
                      rankBgColor = const Color(0xFFCD7F32);
                    } else {
                      rowBg = null;
                      rankBgColor = Colors.grey[200]!;
                    }

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: rowBg,
                        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          // Rank
                          Container(
                            width: 26.w,
                            height: 26.w,
                            margin: EdgeInsets.only(right: 6.w),
                            decoration: BoxDecoration(
                              color: rankBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: rank <= 3 ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          // Player Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate.name,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  candidate.teamName,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 10.sp),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 45.w, child: Text('${candidate.runs}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                          SizedBox(width: 35.w, child: Text('${candidate.wickets}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                          SizedBox(
                            width: 55.w,
                            child: Text(
                              '${candidate.mvpScore}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: rank == 1 ? const Color(0xFFD4A000) : rank <= 3 ? AppTheme.primaryOrange : Colors.black87,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMvpStatPill(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 10.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAwardCard(
    String emoji,
    String award,
    String playerName,
    String stat,
    String teamName,
    Color accentColor,
  ) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accentColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 20.sp)),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  award,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            playerName,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (teamName.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              teamName,
              style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              stat,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.sp, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          SizedBox(height: 8.h),
          Text(subtitle, style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerRow(String organizerId, String organizerName) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, size: 18.sp, color: AppTheme.primaryOrange),
          SizedBox(width: 12.w),
          Expanded(child: Text('Organizer', style: TextStyle(color: Colors.grey[600]))),
          GestureDetector(
            onTap: () => _navigateToOrganizerProfile(organizerId),
            child: Text(
              organizerName.isNotEmpty ? organizerName : 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

void _navigateToOrganizerProfile(String organizerId) async {
    try {
      final user = await FirebaseDataService.instance.getUserById(organizerId);
      if (user != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: user),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load organizer profile')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppTheme.primaryOrange),
          SizedBox(width: 12.w),
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Color _getFixtureStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'live':
        return Colors.red;
      case 'scheduled':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }



  void _showTeamSquad(TeamModel team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryOrange,
                    child: Text(
                      team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${team.players.length} Players',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Player List
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: team.players.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final player = team.players[index];
                  final isWicketKeeper = player.role.toLowerCase().contains('wicket keeper') || player.role.toLowerCase().contains('wk');
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(Icons.person, color: Colors.grey[600]),
                    ),
                    title: Row(
                      children: [
                        Text(player.name, style: TextStyle(fontWeight: FontWeight.w600)),
                        if (player.isCaptain) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Text('C', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (player.isViceCaptain) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Text('VC', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (isWicketKeeper) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text('WK', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(player.role.isNotEmpty ? player.role : 'Player', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
                    trailing: player.isRegistered 
                      ? Icon(Icons.verified, color: Colors.blue, size: 16.sp)
                      : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Get display name for tournament category
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'open':
        return 'Open Tournament';
      case 'corporate':
        return 'Corporate League';
      case 'box_cricket':
        return 'Box Cricket';
      case 'series':
        return 'Series';
      case 'community':
        return 'Community Tournament';
      default:
        return category.toUpperCase();
    }
  }

  // ==================== GALLERY TAB ====================
  Widget _buildGalleryTab() {
    final t = _tournament;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final isOrganizer = currentUser?.uid == t.organizerId;
    final isAdmin = t.adminIds.contains(currentUser?.uid);
    final canManage = isOrganizer || isAdmin;

    // Filtered gallery items
    final filteredItems = t.gallery.where((item) {
      if (_activeGalleryFilter == 'all') return true;
      return item.category.toLowerCase() == _activeGalleryFilter.toLowerCase();
    }).toList();

    final filters = [
      {'key': 'all', 'label': 'All Rhythms 📸'},
      {'key': 'poster', 'label': 'Cinematic Posters 💥'},
      {'key': 'celebration', 'label': 'Celebrations 🥳'},
      {'key': 'trophy', 'label': 'Trophy Lift 👑'},
      {'key': 'match_winning', 'label': 'Match Victory ⚔️'},
      {'key': 'action', 'label': 'Action Shots ⚡'},
      {'key': 'mvp', 'label': 'MVPs 👑'},
      {'key': 'six', 'label': 'Sixes 💥'},
      {'key': 'wicket', 'label': 'Wickets 🎯'},
      {'key': 'century', 'label': 'Centuries 💯'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. Horizontal Scroll Filter Bar
          Container(
            height: 54.h,
            color: Colors.grey[50],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final f = filters[index];
                final isSelected = _activeGalleryFilter == f['key'];
                return Padding(
                  padding: EdgeInsets.only(right: 8.0.w),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeGalleryFilter = f['key']!;
                      });
                    },
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryOrange : Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryOrange : Colors.grey[300]!,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.3), blurRadius: 6, offset: Offset(0, 2))
                        ] : [],
                      ),
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Admin Action Bar
          if (canManage)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)], // Sleek dark AI theme
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 24.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Posters',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Generate premium player moments',
                            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => CinematicPosterCreatorDialog(
                            tournament: t,
                            onPosterSaved: (item) {
                              setState(() {});
                            },
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withOpacity(0.15),
                        foregroundColor: Colors.cyanAccent,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
                        ),
                      ),
                      child: Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Grid of photos
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64.sp, color: Colors.grey[300]),
                        SizedBox(height: 12.h),
                        Text(
                          'No Moments in this category.',
                          style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                        ),
                        if (canManage) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'Tap "Generate" to add your first cinematic sports moment!',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
                          ),
                        ]
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(16.w),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildGalleryCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryCard(TournamentGalleryItem item) {
    ImageProvider? imageProvider;
    if (item.imageUrl.trim().startsWith('data:')) {
      try {
        final base64Str = item.imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        imageProvider = MemoryImage(bytes);
      } catch (_) {}
    } else {
      imageProvider = NetworkImage(item.imageUrl);
    }



    final Color badgeColor = item.badgeType == 'batsman'
        ? Colors.orangeAccent
        : (item.badgeType == 'bowler' ? Colors.cyanAccent : Colors.amberAccent);

    return InkWell(
      onTap: () => _showFullImagePreview(item),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Base Photo
            if (imageProvider != null)
              Positioned.fill(
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Positioned.fill(child: Icon(Icons.photo, color: Colors.grey)),

            // Gradient Tint
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Premium Glassmorphic Badge type indicator top left
            if (item.badgeName != null && item.badgeName!.isNotEmpty)
              Positioned(
                top: 10.h,
                left: 10.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.w),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.badgeType == 'batsman'
                                ? Icons.flash_on
                                : (item.badgeType == 'bowler' ? Icons.local_fire_department : Icons.emoji_events),
                            color: badgeColor,
                            size: 12.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            item.badgeName!.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Text content bottom
            Positioned(
              left: 10.w,
              right: 10.w,
              bottom: 10.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.playerName != null && item.playerName!.isNotEmpty)
                    Text(
                      item.playerName!.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 2.h),
                  Text(
                    item.title.toUpperCase(),
                    style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 8.sp, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 9.sp),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImagePreview(TournamentGalleryItem item) {
    ImageProvider? imageProvider;
    if (item.imageUrl.trim().startsWith('data:')) {
      try {
        final base64Str = item.imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        imageProvider = MemoryImage(bytes);
      } catch (_) {}
    } else {
      imageProvider = NetworkImage(item.imageUrl);
    }

    final Color badgeColor = item.badgeType == 'batsman'
        ? Colors.orangeAccent
        : (item.badgeType == 'bowler' ? Colors.cyanAccent : Colors.amberAccent);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 24.h),
        child: Container(
          width: 360.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large Photo
              Stack(
                children: [
                  Container(
                    height: 420.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: imageProvider != null
                          ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                          : null,
                      color: Colors.black87,
                    ),
                  ),
                  Positioned(
                    top: 12.h,
                    right: 12.w,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Premium Glassmorphic Badge tag
                  if (item.badgeName != null && item.badgeName!.isNotEmpty)
                    Positioned(
                      top: 16.h,
                      left: 16.w,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5.w),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.badgeType == 'batsman'
                                      ? Icons.flash_on
                                      : (item.badgeType == 'bowler' ? Icons.local_fire_department : Icons.emoji_events),
                                  color: badgeColor,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  item.badgeName!.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Bottom details card (premium design)
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.sp,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(item.createdAt),
                          style: TextStyle(color: Colors.grey[500], fontSize: 10.sp, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    if (item.playerName != null && item.playerName!.isNotEmpty) ...[
                      Text(
                        item.playerName!.toUpperCase(),
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 20.sp, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 4.h),
                    ],
                    Text(
                      item.description,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13.sp, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 20.h),

                    // Actions: Share & Close
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Share image file dynamically
                              if (item.imageUrl.startsWith('data:')) {
                                try {
                                  final base64Str = item.imageUrl.split(',').last;
                                  final bytes = base64Decode(base64Str);
                                  
                                  final tempDir = await getTemporaryDirectory();
                                  final file = await File('${tempDir.path}/${item.id}.png').create();
                                  await file.writeAsBytes(bytes);
                                  
                                  await Share.shareXFiles([XFile(file.path)], text: 'Check out this epic moment from the ${widget.tournament.name}! 🏏🏆');
                                } catch (e) {
                                  debugPrint('Error sharing photo: $e');
                                }
                              } else {
                                Share.share('Epic moment in the ${widget.tournament.name}!: ${item.description}\n\nView here: ${item.imageUrl}');
                              }
                            },
                            icon: Icon(Icons.share_rounded),
                            label: const Text('SHARE MOMENT'),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ANIMATED TOURNAMENT HEADER ====================
class _AnimatedTournamentHeader extends StatefulWidget {
  final String tournamentName;
  final String location;
  final String status;
  final int teamsCount;
  final int maxTeams;
  final int views;
  final String? bannerUrl;

  const _AnimatedTournamentHeader({
    required this.tournamentName,
    required this.location,
    required this.status,
    required this.teamsCount,
    required this.maxTeams,
    required this.views,
    this.bannerUrl,
  });

  @override
  State<_AnimatedTournamentHeader> createState() => _AnimatedTournamentHeaderState();
}

class _AnimatedTournamentHeaderState extends State<_AnimatedTournamentHeader>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;

  ImageProvider? _bannerImageProvider;

  @override
  void initState() {
    super.initState();
    _initImageProvider();
    
    // Floating animation for cricket balls
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Shimmer animation for gradient effect
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Pulse animation for status badge
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initImageProvider() {
    if (widget.bannerUrl != null && widget.bannerUrl!.isNotEmpty) {
      if (widget.bannerUrl!.startsWith('data:image')) {
        try {
          final base64String = widget.bannerUrl!.split(',').last;
          _bannerImageProvider = MemoryImage(base64Decode(base64String));
        } catch (e) {
          _bannerImageProvider = const AssetImage('assets/images/placeholder.png');
        }
      } else {
        _bannerImageProvider = NetworkImage(widget.bannerUrl!);
      }
    } else {
      _bannerImageProvider = null;
    }
  }

  @override
  void didUpdateWidget(_AnimatedTournamentHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bannerUrl != widget.bannerUrl) {
      _initImageProvider();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasBanner = widget.bannerUrl != null && widget.bannerUrl!.isNotEmpty;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: Custom image OR animated gradient
        if (_bannerImageProvider != null) ...[
          // Custom banner image background
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _bannerImageProvider!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ] else ...[
          // Default animated gradient background
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Color(0xFFFF6B35),
                      Color(0xFFE64A19),
                      Color(0xFFBF360C),
                    ],
                    stops: [
                      0.0,
                      0.5 + (_shimmerAnimation.value * 0.1).clamp(-0.2, 0.2),
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),
          // Decorative Pattern Overlay (only without banner)
          Positioned.fill(
            child: CustomPaint(
              painter: _CirclePatternPainter(),
            ),
          ),
        ],

        // Floating Cricket Balls
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: 30.h + _floatAnimation.value,
                  right: 20.w,
                  child: _buildFloatingIcon(Icons.sports_cricket, 40, 0.15),
                ),
                Positioned(
                  top: 80.h + (_floatAnimation.value * -0.7),
                  right: 80.w,
                  child: _buildFloatingIcon(Icons.sports_cricket, 25, 0.1),
                ),
                Positioned(
                  top: 50.h + (_floatAnimation.value * 0.5),
                  left: 30.w,
                  child: _buildFloatingIcon(Icons.emoji_events, 30, 0.12),
                ),
                Positioned(
                  bottom: 100.h + (_floatAnimation.value * -0.8),
                  left: 60.w,
                  child: _buildFloatingIcon(Icons.sports_cricket, 20, 0.08),
                ),
              ],
            );
          },
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: 50.h, left: 16.w, right: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge with Pulse Animation
                ScaleTransition(
                  scale: widget.status == 'live' ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.status),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(widget.status).withOpacity(0.4),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.status == 'live')
                          Container(
                            width: 8.w,
                            height: 8.h,
                            margin: EdgeInsets.only(right: 6.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          widget.status.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.sp,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Tournament Name with White Color
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.tournamentName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(Icons.remove_red_eye, color: Colors.white70, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text(
                      '${widget.views}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // Location Row (Tappable)
                InkWell(
                  onTap: () {
                    if (widget.location.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroundProfileScreen(
                            groundName: widget.location,
                            location: widget.location,
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.location_on, color: Colors.white, size: 16.sp),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            widget.location,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right, color: Colors.white70, size: 16.sp),
                      ],
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

  Widget _buildFloatingIcon(IconData icon, double size, double opacity) {
    return Icon(
      icon,
      size: size,
      color: Colors.white.withOpacity(opacity),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'registration':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }
}

// Custom Painter for decorative circle pattern
class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw multiple decorative circles
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      60,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      90,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      40,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      60,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper class to calculate MVP scores
class _MvpCandidate {
  final String name;
  final String teamName;
  int runs = 0;
  int wickets = 0;
  int sixes = 0;
  int fours = 0;
  int matches = 0;

  _MvpCandidate(this.name, this.teamName);

  /// MVP Score: runs + (wickets × 25) + (sixes × 6) + (fours × 4)
  int get mvpScore => runs + (wickets * 25) + (sixes * 6) + (fours * 4);
}
