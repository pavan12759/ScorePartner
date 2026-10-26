import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../widgets/cinematic_poster_creator_dialog.dart';
import '../../widgets/cinematic_poster_card.dart';
import '../../widgets/team_logo_widget.dart';
import '../teams/team_details_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../../data/services/player_search_service.dart';
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
import '../../widgets/player_avatar_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  
  String _activeGalleryFilter = 'all';
  String _teamsSearchQuery = '';
  String _selectedGroupFilter = 'All';
  String? _expandedTeamPointsId;

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
                color: ThemeHelper.of(context).cardBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: ThemeHelper.of(context).dividerColor!),
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
              style: TextStyle(fontSize: 11.sp, color: ThemeHelper.of(context).textSecondary),
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
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          _tournament = snapshot.data!;
        }
        return Scaffold(
          backgroundColor: ThemeHelper.of(context).dividerColor!,
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
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryOrange : ThemeHelper.of(context).dividerColor!,
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
                      color: ThemeHelper.of(context).dividerColor!,
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
                        color: isSelected ? Colors.white : ThemeHelper.of(context).textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  item['label'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : ThemeHelper.of(context).textPrimary,
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
              color: ThemeHelper.of(context).cardBg,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.06),
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
                            color: ThemeHelper.of(context).cardBg,
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
              color: ThemeHelper.of(context).cardBg,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.06),
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
                                        color: ThemeHelper.of(context).textSecondary,
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
                                        color: ThemeHelper.of(context).textSecondary,
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
                  color: ThemeHelper.of(context).textSecondary,
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
                        color: ThemeHelper.of(context).textPrimary,
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
        color: ThemeHelper.of(context).cardBg,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryOrange, size: 28.sp),
          SizedBox(height: 8.h),
          Text(value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp)),
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
            Icon(Icons.sports_cricket, size: 64.sp, color: ThemeHelper.of(context).textSecondary),
            SizedBox(height: 16.h),
            Text(
              'No Fixtures Yet',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: ThemeHelper.of(context).textSecondary),
            ),
            SizedBox(height: 8.h),
            Text(
              'Generate fixtures to start the tournament',
                style: TextStyle(color: ThemeHelper.of(context).textSecondary),
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

    return StreamBuilder<List<MatchModel>>(
      stream: FirebaseDataService.instance.streamTournamentMatches(_tournament.id),
      builder: (context, snapshot) {
        final matches = snapshot.data ?? [];
        final Map<String, MatchModel> matchById = {
          for (var m in matches) m.id: m,
        };

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
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
                      margin: EdgeInsets.only(bottom: 10.h, top: index == 0 ? 0 : 6.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_cricket, size: 13.sp, color: AppTheme.primaryOrange),
                          SizedBox(width: 5.w),
                          Text(
                            round,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '${roundFixtures.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...roundFixtures.map((fixture) {
                      MatchModel? match;
                      if (fixture.matchId != null && fixture.matchId!.isNotEmpty) {
                        match = matchById[fixture.matchId!];
                      }
                      if (match == null) {
                        for (final m in matches) {
                          if ((m.team1Id == fixture.team1Id && m.team2Id == fixture.team2Id) ||
                              (m.team1Id == fixture.team2Id && m.team2Id == fixture.team1Id)) {
                            match = m;
                            break;
                          }
                        }
                      }
                      return _buildFixtureCard(fixture, match: match);
                    }),
                    SizedBox(height: 10.h),
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
                  if (!canManage) return const SizedBox.shrink();
                  
                  return FloatingActionButton.extended(
                    onPressed: _navigateToCreateMatch,
                    icon: Icon(Icons.add, color: ThemeHelper.of(context).cardBg),
                    label: Text('Create Match', style: TextStyle(color: ThemeHelper.of(context).cardBg)),
                    backgroundColor: AppTheme.primaryOrange,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFixtureCard(TournamentFixture fixture, {MatchModel? match}) {
    if (match != null) {
      return _buildFixtureCardContent(fixture, match: match);
    }

    if (fixture.matchId != null && fixture.matchId!.isNotEmpty) {
      return StreamBuilder<MatchModel?>(
        stream: FirebaseDataService.instance.streamMatch(fixture.matchId!),
        builder: (context, snapshot) {
          return _buildFixtureCardContent(fixture, match: snapshot.data);
        },
      );
    }

    return _buildFixtureCardContent(fixture, match: null);
  }

  Widget _buildFixtureCardContent(TournamentFixture fixture, {MatchModel? match}) {
    final th = ThemeHelper.of(context);
    final isMatchLive = match != null && match.status.toLowerCase() == 'live';
    final isMatchCompleted = match != null &&
        (match.status.toLowerCase() == 'completed' || match.status.toLowerCase() == 'finished');
    final isFixtureLive = fixture.status.toLowerCase() == 'live';
    final isFixtureCompleted = fixture.status.toLowerCase() == 'completed';

    final isLive = isMatchLive || isFixtureLive;
    final isCompleted = isMatchCompleted || isFixtureCompleted;
    final isScheduled = !isLive &&
        !isCompleted &&
        (fixture.status.toLowerCase() == 'scheduled' || match?.status.toLowerCase() == 'scheduled');

    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    if (isLive) {
      statusColor = const Color(0xFF2E7D32);
      statusBgColor = const Color(0xFF2E7D32).withOpacity(0.12);
      statusText = 'LIVE';
      statusIcon = Icons.fiber_manual_record;
    } else if (isCompleted) {
      statusColor = Colors.grey[700]!;
      statusBgColor = Colors.grey.withOpacity(0.12);
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (isScheduled) {
      statusColor = const Color(0xFF0288D1);
      statusBgColor = const Color(0xFF0288D1).withOpacity(0.12);
      statusText = 'SCHEDULED';
      statusIcon = Icons.calendar_month_rounded;
    } else {
      statusColor = Colors.orange[800]!;
      statusBgColor = Colors.orange.withOpacity(0.12);
      statusText = 'PENDING';
      statusIcon = Icons.schedule_rounded;
    }

    final team1 = _teamsMap[fixture.team1Id];
    final team2 = _teamsMap[fixture.team2Id];

    // Determine winner
    String? effectiveWinnerId = fixture.winnerId;
    if (isCompleted && match != null) {
      if (match.winnerTeamId != null && match.winnerTeamId!.isNotEmpty) {
        effectiveWinnerId = match.winnerTeamId;
      } else if (match.winnerTeam != null && match.winnerTeam!.isNotEmpty) {
        if (match.winnerTeam == fixture.team1Name || match.winnerTeam == match.team1Name) {
          effectiveWinnerId = fixture.team1Id;
        } else if (match.winnerTeam == fixture.team2Name || match.winnerTeam == match.team2Name) {
          effectiveWinnerId = fixture.team2Id;
        }
      }
    }
    final bool isTeam1Winner = isCompleted && effectiveWinnerId != null && effectiveWinnerId == fixture.team1Id;
    final bool isTeam2Winner = isCompleted && effectiveWinnerId != null && effectiveWinnerId == fixture.team2Id;

    // Check if match teams are reversed
    final bool isMatchReversed =
        match != null && match.team1Id == fixture.team2Id && match.team2Id == fixture.team1Id;
    final TeamScore? team1MatchScore =
        match == null ? null : (isMatchReversed ? match.team2Score : match.team1Score);
    final TeamScore? team2MatchScore =
        match == null ? null : (isMatchReversed ? match.team1Score : match.team2Score);

    // Determine currently batting team
    bool isTeam1Batting = false;
    bool isTeam2Batting = false;
    if (isLive && match != null) {
      final currentBatting = match.currentBattingTeam.toLowerCase().trim();
      final currentBattingId = (currentBatting == 'team1'
          ? match.team1Id
          : (currentBatting == 'team2' ? match.team2Id : match.currentBattingTeam));

      if (currentBattingId == fixture.team1Id) {
        isTeam1Batting = true;
      } else if (currentBattingId == fixture.team2Id) {
        isTeam2Batting = true;
      } else if (currentBatting.contains(fixture.team1Name.toLowerCase())) {
        isTeam1Batting = true;
      } else if (currentBatting.contains(fixture.team2Name.toLowerCase())) {
        isTeam2Batting = true;
      }
    }

    final oversCount = match?.oversPerSide ?? (fixture.overs ?? _tournament.overs);
    final roundName = fixture.round.isNotEmpty ? fixture.round : 'Fixture';

    String? scheduledStr;
    if (fixture.scheduledDate != null) {
      scheduledStr = DateFormat('d MMM').format(fixture.scheduledDate!);
      if (fixture.scheduledTime != null) {
        final hour = fixture.scheduledTime!.hourOfPeriod == 0 ? 12 : fixture.scheduledTime!.hourOfPeriod;
        final minute = fixture.scheduledTime!.minute.toString().padLeft(2, '0');
        final period = fixture.scheduledTime!.period == DayPeriod.am ? 'AM' : 'PM';
        scheduledStr += ' • $hour:$minute $period';
      }
    }

    final venue = fixture.venue?.trim().isNotEmpty == true
        ? fixture.venue!.trim()
        : (_tournament.location.trim().isNotEmpty ? _tournament.location.trim() : null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final canManage = userId == _tournament.organizerId || _tournament.adminIds.contains(userId);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isLive
              ? const Color(0xFF2E7D32).withOpacity(0.5)
              : (th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
          width: isLive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onFixtureTap(fixture, match: match),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row (Status Pill + Round / Format Badges)
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLive) ...[
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ] else ...[
                            Icon(statusIcon, size: 10.sp, color: statusColor),
                            SizedBox(width: 3.w),
                          ],
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                        decoration: BoxDecoration(
                          color: th.dividerColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            oversCount > 0 ? '$roundName • ${oversCount} Ov' : roundName,
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w600,
                              color: th.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 6.h),

                // 2. Teams Container
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: th.dividerColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      // Team 1 Row
                      _buildFixtureTeamRow(
                        context,
                        th,
                        teamId: fixture.team1Id,
                        teamName: fixture.team1Name,
                        teamModel: team1,
                        teamScore: team1MatchScore,
                        staticScore: fixture.team1Score,
                        isBatting: isTeam1Batting,
                        isWinner: isTeam1Winner,
                        isUpcoming: !isLive && !isCompleted,
                        matchInnings: match?.currentInnings,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Divider(
                          height: 1,
                          thickness: 0.8,
                          color: th.dividerColor.withOpacity(0.5),
                        ),
                      ),
                      // Team 2 Row
                      _buildFixtureTeamRow(
                        context,
                        th,
                        teamId: fixture.team2Id,
                        teamName: fixture.team2Name,
                        teamModel: team2,
                        teamScore: team2MatchScore,
                        staticScore: fixture.team2Score,
                        isBatting: isTeam2Batting,
                        isWinner: isTeam2Winner,
                        isUpcoming: !isLive && !isCompleted,
                        matchInnings: match?.currentInnings,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 5.h),

                // 3. Equation / Result Banner Strip
                _buildFixtureEquationStrip(
                  match,
                  fixture,
                  isLive,
                  !isLive && !isCompleted,
                  isCompleted,
                ),

                SizedBox(height: 5.h),

                // 4. Downside: Tournament Name (prominent and fully visible)
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 12.sp, color: Colors.amber[700]),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_tournament.name} • $roundName',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: th.isDark ? Colors.amber[300] : const Color(0xFFD97706),
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4.h),

                // 5. Footer (Venue, Date/Time, Manage Action)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (venue != null) ...[
                            Icon(Icons.location_on_outlined, size: 12.sp, color: th.textSecondary),
                            SizedBox(width: 3.w),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  venue,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: th.textSecondary,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            if (scheduledStr != null) ...[
                              SizedBox(width: 4.w),
                              Text('•', style: TextStyle(fontSize: 10.sp, color: th.textSecondary)),
                              SizedBox(width: 4.w),
                            ],
                          ],
                          if (scheduledStr != null) ...[
                            Icon(Icons.calendar_today_outlined, size: 11.sp, color: th.textSecondary),
                            SizedBox(width: 3.w),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  scheduledStr,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: th.textSecondary,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLive
                              ? (canManage ? 'Resume' : 'Live')
                              : (isCompleted ? 'Scorecard' : (canManage ? 'Start' : 'View')),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(Icons.arrow_forward_rounded, size: 12.sp, color: AppTheme.primaryOrange),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixtureEquationStrip(
    MatchModel? match,
    TournamentFixture fixture,
    bool isLive,
    bool isUpcoming,
    bool isCompleted,
  ) {
    String message = '';
    IconData icon = Icons.info_outline;
    Color color = AppTheme.primaryOrange;
    Color bgColor = AppTheme.primaryOrange.withOpacity(0.08);
    Color borderColor = AppTheme.primaryOrange.withOpacity(0.25);

    if (isLive) {
      color = const Color(0xFF2E7D32);
      bgColor = const Color(0xFF2E7D32).withOpacity(0.08);
      borderColor = const Color(0xFF2E7D32).withOpacity(0.25);
      icon = Icons.flash_on_rounded;

      if (match != null) {
        if (match.currentInnings == 2 && match.target != null && match.target! > 0) {
          final runsReq = match.runsRequired;
          final ballsRem = match.ballsRemaining;
          if (runsReq <= 0) {
            message = 'Scores level! Need 1 run to win';
          } else if (ballsRem > 0) {
            message = 'Need $runsReq off $ballsRem balls (Target: ${match.target})';
          } else {
            message = 'Target: ${match.target} • Match in balance';
          }
        } else if (match.currentRunRate > 0) {
          message = 'CRR: ${match.currentRunRate.toStringAsFixed(2)} • 1st Innings in progress';
        } else {
          message = 'Match in progress • Live';
        }
      } else {
        message = 'Match in progress • Tap to view live scorecard';
      }
    } else if (isCompleted) {
      color = const Color(0xFF2E7D32);
      bgColor = Colors.green.withOpacity(0.08);
      borderColor = Colors.green.withOpacity(0.25);
      icon = Icons.emoji_events;

      if (match != null) {
        final winner = match.winnerTeam;
        final margin = match.winningMargin;
        if (winner == 'Match Tied') {
          message = 'Match Tied';
        } else if (winner != null && winner.isNotEmpty) {
          message = margin.isNotEmpty ? '$winner won by $margin' : '$winner won';
        } else if (match.result != null && match.result!.winner.isNotEmpty) {
          message = match.result!.margin.isNotEmpty
              ? '${match.result!.winner} won by ${match.result!.margin}'
              : '${match.result!.winner} won';
        } else {
          message = 'Match Completed';
        }
      } else if (fixture.winnerId != null && fixture.winnerId!.isNotEmpty) {
        final winnerName = fixture.winnerId == fixture.team1Id ? fixture.team1Name : fixture.team2Name;
        message = '$winnerName Won';
      } else {
        message = 'Match Completed';
      }
    } else {
      // Scheduled / Pending
      color = const Color(0xFF0288D1);
      bgColor = const Color(0xFF0288D1).withOpacity(0.08);
      borderColor = const Color(0xFF0288D1).withOpacity(0.25);
      icon = Icons.calendar_month_rounded;
      if (fixture.scheduledDate != null) {
        String dateStr = DateFormat('EEE, d MMM').format(fixture.scheduledDate!);
        if (fixture.scheduledTime != null) {
          final hour = fixture.scheduledTime!.hourOfPeriod == 0 ? 12 : fixture.scheduledTime!.hourOfPeriod;
          final minute = fixture.scheduledTime!.minute.toString().padLeft(2, '0');
          final period = fixture.scheduledTime!.period == DayPeriod.am ? 'AM' : 'PM';
          dateStr += ' at $hour:$minute $period';
        }
        message = 'Scheduled • $dateStr';
      } else {
        message = 'Fixture scheduled • Yet to start';
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureTeamRow(
    BuildContext context,
    ThemeHelper th, {
    required String teamId,
    required String teamName,
    TeamModel? teamModel,
    TeamScore? teamScore,
    String? staticScore,
    required bool isBatting,
    required bool isWinner,
    required bool isUpcoming,
    int? matchInnings,
  }) {
    void navigateToTeamProfile() {
      if (teamModel != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeamDetailsScreen(team: teamModel)),
        );
      }
    }

    Widget buildScoreWidget() {
      // 1. Live/streamed Match score
      if (teamScore != null) {
        final hasBatted = teamScore.runs > 0 || teamScore.wickets > 0 || teamScore.overs > 0;
        if (!hasBatted && !isBatting) {
          if (isUpcoming) {
            return Text(
              '-',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: th.textSecondary,
              ),
            );
          }
          return Text(
            'Yet to bat',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: th.textSecondary.withOpacity(0.8),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${teamScore.runs}/${teamScore.wickets}',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
                color: isWinner
                    ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange)
                    : (isBatting ? AppTheme.primaryOrange : th.textPrimary),
              ),
            ),
            SizedBox(width: 3.w),
            Text(
              '(${teamScore.overs})',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: th.textSecondary,
              ),
            ),
          ],
        );
      }

      // 2. Static score string on fixture (e.g. "145/6 (18.2)")
      if (staticScore != null && staticScore.trim().isNotEmpty) {
        final trimmed = staticScore.trim();
        if (trimmed.contains('(') && trimmed.contains(')')) {
          final parts = trimmed.split('(');
          final scorePart = parts[0].trim();
          final oversPart = '(${parts[1].trim()}';
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                scorePart,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w800,
                  color: isWinner
                      ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange)
                      : th.textPrimary,
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                oversPart,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: th.textSecondary,
                ),
              ),
            ],
          );
        }
        return Text(
          trimmed,
          style: TextStyle(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w800,
            color: isWinner
                ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange)
                : th.textPrimary,
          ),
        );
      }

      // 3. Upcoming
      if (isUpcoming) {
        return Text(
          '-',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: th.textSecondary,
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Team Logo
        GestureDetector(
          onTap: teamModel != null ? navigateToTeamProfile : null,
          child: TeamLogoWidget(
            teamName: teamName,
            logoUrl: teamModel?.logoUrl,
            size: 26.sp,
          ),
        ),
        SizedBox(width: 8.w),

        // Team Name & Badges
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: teamModel != null ? navigateToTeamProfile : null,
            child: Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      teamName.isNotEmpty ? teamName : 'TBD',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: isWinner || isBatting ? FontWeight.w800 : FontWeight.w600,
                        color: isWinner
                            ? (th.isDark ? Colors.amberAccent : AppTheme.primaryOrange)
                            : (isBatting ? AppTheme.primaryOrange : th.textPrimary),
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                if (isWinner) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.emoji_events, size: 12.sp, color: Colors.amber),
                ],
                if (isBatting) ...[
                  SizedBox(width: 5.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3), width: 0.7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_cricket, size: 9.sp, color: AppTheme.primaryOrange),
                        SizedBox(width: 2.5.w),
                        Text(
                          'Batting',
                          style: TextStyle(
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryOrange,
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
        SizedBox(width: 6.w),

        // Score Display
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: buildScoreWidget(),
        ),
      ],
    );
  }

  void _onFixtureTap(TournamentFixture fixture, {MatchModel? match}) {
    final effectiveMatchId = match?.id ?? fixture.matchId;
    final isLive = (match != null && match.status.toLowerCase() == 'live') || fixture.status.toLowerCase() == 'live';
    final isCompleted = (match != null &&
            (match.status.toLowerCase() == 'completed' || match.status.toLowerCase() == 'finished')) ||
        fixture.status.toLowerCase() == 'completed';

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    // Check if user is organizer or co-admin
    final isOrganizer = userId == _tournament.organizerId;
    final isAdmin = _tournament.adminIds.contains(userId);
    debugPrint('Admin Access Check: UserID=$userId, OrganizerID=${_tournament.organizerId}, IsAdmin=$isAdmin');
    final canManageMatches = isOrganizer || isAdmin;

    if (!canManageMatches) {
      // For non-admins, just view match details if available
      if (effectiveMatchId != null && effectiveMatchId.isNotEmpty && (isLive || isCompleted)) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: effectiveMatchId)),
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
          if (!isCompleted)
             ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.green),
              title: Text(isLive ? 'Resume Match' : 'Start Match'),
              onTap: () {
                Navigator.pop(context);
                _startOrResumeMatch(fixture, existingMatch: match);
              },
            ),
          if (effectiveMatchId != null && effectiveMatchId.isNotEmpty)
             ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Scorecard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: effectiveMatchId)),
                );
              },
            ),
          if (!isLive && !isCompleted)
             ListTile(
               leading: const Icon(Icons.edit, color: Colors.orange),
               title: const Text('Edit Fixture'),
               onTap: () {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Fixture coming soon')));
               },
             ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
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

  Future<void> _startOrResumeMatch(TournamentFixture fixture, {MatchModel? existingMatch}) async {
    final effectiveMatchId = existingMatch?.id ?? fixture.matchId;
    // If already started, go to live scoring
    if (effectiveMatchId != null && effectiveMatchId.isNotEmpty) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LiveScoringScreen(matchId: effectiveMatchId)),
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

    final th = ThemeHelper.of(context);
    final allRegisteredIds = _tournament.registeredTeamIds;

    if (allRegisteredIds.isEmpty) {
      return Stack(
        children: [
          _buildEmptyState(
            icon: Icons.groups_outlined,
            title: 'No Teams Registered',
            subtitle: 'Teams will appear here once registered to ${_tournament.name}',
          ),
          _buildAddTeamFAB(),
        ],
      );
    }

    // Filter teams by search query
    final filteredTeamIds = allRegisteredIds.where((teamId) {
      final team = _teamsMap[teamId];
      if (_teamsSearchQuery.trim().isEmpty) return true;
      final q = _teamsSearchQuery.toLowerCase().trim();
      final nameMatches = (team?.name ?? '').toLowerCase().contains(q);
      final captainMatches = (team?.captainName ?? '').toLowerCase().contains(q);
      return nameMatches || captainMatches;
    }).toList();

    // Map points table data by teamId for quick stats display
    final Map<String, TeamPoints> pointsMap = {
      for (var p in _tournament.pointsTable) p.teamId: p
    };

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Summary Card
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: th.cardBg,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: th.isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.groups_rounded, size: 20.sp, color: AppTheme.primaryOrange),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${allRegisteredIds.length}',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                                    Text(
                                      ' / ${_tournament.maxTeams} Teams',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: th.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  _tournament.slotsAvailable > 0
                                      ? '${_tournament.slotsAvailable} spots remaining for registration'
                                      : 'Tournament capacity full',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: th.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: _tournament.slotsAvailable > 0
                                  ? const Color(0xFF2E7D32).withOpacity(0.12)
                                  : Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                            child: Text(
                              _tournament.slotsAvailable > 0 ? 'OPEN' : 'FULL',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: _tournament.slotsAvailable > 0
                                    ? const Color(0xFF2E7D32)
                                    : Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // Search input
                    Container(
                      height: 42.h,
                      decoration: BoxDecoration(
                        color: th.cardBg,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: th.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _teamsSearchQuery = val;
                          });
                        },
                        style: TextStyle(fontSize: 13.sp, color: th.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search teams or captains...',
                          hintStyle: TextStyle(fontSize: 12.5.sp, color: th.textSecondary),
                          prefixIcon: Icon(Icons.search, size: 18.sp, color: th.textSecondary),
                          suffixIcon: _teamsSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 16.sp, color: th.textSecondary),
                                  onPressed: () {
                                    setState(() {
                                      _teamsSearchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (filteredTeamIds.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48.sp, color: th.textSecondary),
                        SizedBox(height: 10.h),
                        Text(
                          'No teams match "$_teamsSearchQuery"',
                          style: TextStyle(fontSize: 14.sp, color: th.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final teamId = filteredTeamIds[index];
                      final team = _teamsMap[teamId];
                      final points = pointsMap[teamId];
                      return _buildTeamCard(teamId, team, points, th);
                    },
                    childCount: filteredTeamIds.length,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(height: 80.h), // Spacer for FAB
            ),
          ],
        ),
        _buildAddTeamFAB(),
      ],
    );
  }

  Widget _buildTeamCard(
    String teamId,
    TeamModel? team,
    TeamPoints? points,
    ThemeHelper th,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final isOrganizer = userId == _tournament.organizerId;
    final isAdmin = _tournament.adminIds.contains(userId);
    final canManage = isOrganizer || isAdmin;

    final teamName = team?.name ?? 'Unknown Team';
    final captainName = team?.captainName ?? 'Not Assigned';
    final playerCount = team?.players.length ?? 0;

    void openTeamProfile() {
      if (team != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeamDetailsScreen(team: team)),
        );
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: th.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: th.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openTeamProfile,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Logo, Team Name, Captain, More Options
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Team Logo
                    GestureDetector(
                      onTap: openTeamProfile,
                      child: TeamLogoWidget(
                        teamName: teamName,
                        logoUrl: team?.logoUrl,
                        size: 46.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Team Name & Captain
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              teamName,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: th.textPrimary,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 13.sp, color: Colors.amber[700]),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Captain: $captainName',
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: th.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (team != null && team.viceCaptainName.trim().isNotEmpty) ...[
                            SizedBox(height: 1.h),
                            Text(
                              'VC: ${team.viceCaptainName}',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                color: th.textSecondary.withOpacity(0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions Menu (for organizer) or Chevron
                    if (canManage)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18.sp, color: th.textSecondary),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'profile') {
                            openTeamProfile();
                          } else if (value == 'squad') {
                            if (team != null) _showTeamSquad(team);
                          } else if (value == 'remove') {
                            _confirmRemoveTeam(teamId, teamName);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 18.sp, color: AppTheme.primaryOrange),
                                SizedBox(width: 8.w),
                                const Text('View Profile'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'squad',
                            child: Row(
                              children: [
                                Icon(Icons.groups_outlined, size: 18.sp, color: Colors.blue),
                                SizedBox(width: 8.w),
                                const Text('View Squad'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18.sp, color: Colors.red),
                                SizedBox(width: 8.w),
                                const Text('Remove Team', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Icon(Icons.chevron_right_rounded, size: 20.sp, color: th.textSecondary.withOpacity(0.7)),
                  ],
                ),

                SizedBox(height: 10.h),
                Divider(height: 1, thickness: 0.7, color: th.dividerColor.withOpacity(0.5)),
                SizedBox(height: 8.h),

                // Bottom Row: Stats Pills & Quick Buttons
                Row(
                  children: [
                    // Squad Count Chip
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: th.dividerColor.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined, size: 12.sp, color: th.textSecondary),
                          SizedBox(width: 4.w),
                          Text(
                            '$playerCount Players',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              color: th.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (points != null && points.played > 0) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2), width: 0.8),
                        ),
                        child: Text(
                          '${points.won}W • ${points.lost}L • ${points.points} Pts',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Quick Squad Button
                    if (team != null)
                      InkWell(
                        onTap: () => _showTeamSquad(team),
                        borderRadius: BorderRadius.circular(6.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.format_list_bulleted_rounded, size: 12.sp, color: AppTheme.primaryOrange),
                              SizedBox(width: 4.w),
                              Text(
                                'Squad',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(width: 6.w),

                    // Quick Profile Button
                    InkWell(
                      onTap: openTeamProfile,
                      borderRadius: BorderRadius.circular(6.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                        decoration: BoxDecoration(
                          color: th.dividerColor.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w600,
                                color: th.textPrimary,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Icon(Icons.arrow_forward_rounded, size: 11.sp, color: th.textSecondary),
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
      ),
    );
  }

  void _confirmRemoveTeam(String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team'),
        content: Text('Are you sure you want to remove "$teamName" from ${_tournament.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await FirebaseDataService.instance.removeTeamFromTournament(
                _tournament.id,
                teamId,
              );
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ $teamName removed from tournament'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadTeams();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Failed to remove team'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTeamFAB() {
    return Positioned(
      bottom: 16.h,
      right: 16.w,
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final userId = auth.user?.uid;
          final isOrganizer = userId == _tournament.organizerId;
          final isAdmin = _tournament.adminIds.contains(userId);
          final canManage = isOrganizer || isAdmin;

          if (!canManage) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _showAddTeamDialog,
            icon: Icon(Icons.add, color: ThemeHelper.of(context).cardBg),
            label: Text('Add Team', style: TextStyle(color: ThemeHelper.of(context).cardBg)),
            backgroundColor: AppTheme.primaryOrange,
          );
        },
      ),
    );
  }

  // ==================== POINTS TABLE TAB ====================
  Widget _buildPointsTable() {
    final th = ThemeHelper.of(context);

    // Merge points table with all registered teams
    final Map<String, TeamPoints> pointsMap = {
      for (var p in _tournament.pointsTable) p.teamId: p
    };

    List<TeamPoints> pointsData = _tournament.registeredTeamIds.map((teamId) {
      if (pointsMap.containsKey(teamId)) {
        return pointsMap[teamId]!;
      } else {
        final team = _teamsMap[teamId];
        return TeamPoints(
          teamId: teamId,
          teamName: team?.name ?? 'Unknown Team',
        );
      }
    }).toList();

    // Check for Groups if defined in tournament
    final Map<String, List<String>>? groups = _tournament.groups;
    final List<String> availableGroups = ['All'];
    if (groups != null && groups.isNotEmpty) {
      availableGroups.addAll(groups.keys);
    }

    // Filter by selected group
    if (_selectedGroupFilter != 'All' && groups != null && groups.containsKey(_selectedGroupFilter)) {
      final groupTeamIds = groups[_selectedGroupFilter]!.toSet();
      pointsData = pointsData.where((p) => groupTeamIds.contains(p.teamId)).toList();
    }

    // Sort by Points (Desc), then NRR (Desc), then Won (Desc)
    pointsData.sort((a, b) {
      int result = b.points.compareTo(a.points);
      if (result == 0) {
        result = b.nrr.compareTo(a.nrr);
      }
      if (result == 0) {
        result = b.won.compareTo(a.won);
      }
      return result;
    });

    final qualificationCutoff = _tournament.registeredTeamIds.length >= 8 ? 4 : 2;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 30.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Qualification Zone Banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.25), width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 16.sp, color: const Color(0xFF2E7D32)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Qualification Zone: Top $qualificationCutoff teams advance to the playoffs',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Group Switcher Pills (if groups exist)
          if (availableGroups.length > 1) ...[
            SizedBox(height: 10.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableGroups.map((group) {
                  final isSelected = _selectedGroupFilter == group;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ChoiceChip(
                      label: Text(group),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedGroupFilter = group;
                          });
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : th.textPrimary,
                      ),
                      selectedColor: AppTheme.primaryOrange,
                      backgroundColor: th.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryOrange : th.dividerColor!,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          SizedBox(height: 12.h),

          // 3. Points Table Container Card
          Container(
            decoration: BoxDecoration(
              color: th.cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: th.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 9.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28.w,
                          child: Text(
                            'POS',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.sp),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            'TEAM',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.sp),
                          ),
                        ),
                        _buildTableHeaderCell('P', width: 28.w),
                        _buildTableHeaderCell('W', width: 28.w),
                        _buildTableHeaderCell('L', width: 28.w),
                        _buildTableHeaderCell('NR', width: 28.w),
                        _buildTableHeaderCell('NRR', width: 48.w),
                        _buildTableHeaderCell('PTS', width: 36.w),
                      ],
                    ),
                  ),

                  // Table Rows
                  if (pointsData.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(28.w),
                      child: Text('No standings data available yet', style: TextStyle(color: th.textSecondary)),
                    )
                  else
                    ...pointsData.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      final isQualified = idx < qualificationCutoff;
                      final team = _teamsMap[p.teamId];
                      final isExpanded = _expandedTeamPointsId == p.teamId;

                      return _buildPointsTableRow(
                        idx: idx,
                        p: p,
                        team: team,
                        isQualified: isQualified,
                        isExpanded: isExpanded,
                        th: th,
                      );
                    }),
                ],
              ),
            ),
          ),

          SizedBox(height: 14.h),

          // 4. Legend & Info Footer
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: th.cardBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: th.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14.sp, color: th.textSecondary),
                    SizedBox(width: 6.w),
                    Text(
                      'Table Legend & Tie Breakers',
                      style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: th.textPrimary),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 4.h,
                  children: [
                    _buildLegendItem('P', 'Played', th),
                    _buildLegendItem('W', 'Won', th),
                    _buildLegendItem('L', 'Lost', th),
                    _buildLegendItem('NR', 'No Result / Tie', th),
                    _buildLegendItem('NRR', 'Net Run Rate', th),
                    _buildLegendItem('PTS', 'Points (Win: 2, NR: 1, Loss: 0)', th),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  '💡 Tap any team row to inspect recent match form, runs scored & conceded breakdown.',
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontStyle: FontStyle.italic,
                    color: th.textSecondary.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsTableRow({
    required int idx,
    required TeamPoints p,
    required TeamModel? team,
    required bool isQualified,
    required bool isExpanded,
    required ThemeHelper th,
  }) {
    final rank = idx + 1;
    final teamName = p.teamName.isNotEmpty ? p.teamName : (team?.name ?? 'Team');

    void openTeamProfile() {
      if (team != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeamDetailsScreen(team: team)),
        );
      }
    }

    // Rank badge styling
    Widget rankWidget;
    if (rank == 1) {
      rankWidget = Container(
        width: 20.w,
        height: 20.h,
        decoration: const BoxDecoration(
          color: Color(0xFFFFB300),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '1',
          style: TextStyle(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w900),
        ),
      );
    } else if (rank == 2) {
      rankWidget = Container(
        width: 20.w,
        height: 20.h,
        decoration: const BoxDecoration(
          color: Color(0xFF90A4AE),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '2',
          style: TextStyle(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w900),
        ),
      );
    } else if (rank == 3) {
      rankWidget = Container(
        width: 20.w,
        height: 20.h,
        decoration: const BoxDecoration(
          color: Color(0xFFB08D57),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '3',
          style: TextStyle(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w900),
        ),
      );
    } else {
      rankWidget = Text(
        '$rank',
        style: TextStyle(
          fontSize: 11.sp,
          color: th.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // NRR styling (+ / - and color)
    final nrr = p.nrr;
    final nrrString = nrr > 0 ? '+${nrr.toStringAsFixed(3)}' : nrr.toStringAsFixed(3);
    final nrrColor = nrr > 0
        ? const Color(0xFF2E7D32)
        : (nrr < 0 ? const Color(0xFFC62828) : th.textSecondary);

    final formList = _getTeamRecentForm(p.teamId);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedTeamPointsId = isExpanded ? null : p.teamId;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppTheme.primaryOrange.withOpacity(0.06)
                  : (isQualified
                      ? const Color(0xFF2E7D32).withOpacity(0.025)
                      : null),
              border: Border(
                left: isQualified
                    ? const BorderSide(color: Color(0xFF2E7D32), width: 3.5)
                    : BorderSide.none,
                bottom: BorderSide(color: th.dividerColor.withOpacity(0.4), width: 0.7),
              ),
            ),
            child: Row(
              children: [
                // Position
                SizedBox(
                  width: 28.w,
                  child: Center(child: rankWidget),
                ),
                SizedBox(width: 4.w),

                // Team Logo + Name
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: openTeamProfile,
                        child: TeamLogoWidget(
                          teamName: teamName,
                          logoUrl: team?.logoUrl,
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: openTeamProfile,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  teamName,
                                  style: TextStyle(
                                    fontWeight: isQualified ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12.5.sp,
                                    color: th.textPrimary,
                                  ),
                                  maxLines: 1,
                                ),
                                if (isQualified) ...[
                                  SizedBox(width: 4.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Q',
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats Columns
                _buildTableDataCell('${p.played}', width: 28.w, th: th),
                _buildTableDataCell('${p.won}', width: 28.w, th: th, isBold: p.won > 0),
                _buildTableDataCell('${p.lost}', width: 28.w, th: th),
                _buildTableDataCell('${p.noResult + p.tied}', width: 28.w, th: th),
                _buildTableDataCell(
                  nrrString,
                  width: 48.w,
                  th: th,
                  color: nrrColor,
                  fontSize: 10.5.sp,
                ),

                // PTS Pill
                Container(
                  width: 36.w,
                  height: 26.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.25), width: 0.6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${p.points}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5.sp,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Breakdown Card
        if (isExpanded)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: th.dividerColor.withOpacity(0.25),
              border: Border(
                bottom: BorderSide(color: th.dividerColor.withOpacity(0.5), width: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form Guide
                Row(
                  children: [
                    Text(
                      'Recent Form:',
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: th.textSecondary),
                    ),
                    SizedBox(width: 8.w),
                    if (formList.isEmpty)
                      Text('No matches played yet', style: TextStyle(fontSize: 11.sp, fontStyle: FontStyle.italic, color: th.textSecondary))
                    else
                      Row(
                        children: formList.map((f) {
                          Color badgeColor;
                          if (f == 'W') {
                            badgeColor = const Color(0xFF2E7D32);
                          } else if (f == 'L') {
                            badgeColor = const Color(0xFFC62828);
                          } else {
                            badgeColor = const Color(0xFF0288D1);
                          }
                          return Container(
                            width: 18.w,
                            height: 18.h,
                            margin: EdgeInsets.only(right: 4.w),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              f,
                              style: TextStyle(color: Colors.white, fontSize: 9.5.sp, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),

                SizedBox(height: 6.h),

                // Runs breakdown
                if (p.ballsFor > 0 || p.ballsAgainst > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.sports_cricket, size: 12.sp, color: th.textSecondary),
                      SizedBox(width: 4.w),
                      Text(
                        'Scored: ${p.runsFor} (${(p.ballsFor / 6.0).toStringAsFixed(1)} ov) • Conceded: ${p.runsAgainst} (${(p.ballsAgainst / 6.0).toStringAsFixed(1)} ov)',
                        style: TextStyle(fontSize: 10.5.sp, color: th.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                ],

                // Action button to profile
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: openTeamProfile,
                      icon: Icon(Icons.person_outline, size: 14.sp),
                      label: const Text('View Full Team Profile'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.primaryOrange,
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String title, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 10.5.sp,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableDataCell(
    String value, {
    required double width,
    required ThemeHelper th,
    bool isBold = false,
    Color? color,
    double? fontSize,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        style: TextStyle(
          fontSize: fontSize ?? 11.5.sp,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? th.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLegendItem(String abbr, String meaning, ThemeHelper th) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$abbr: ',
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
        Text(
          meaning,
          style: TextStyle(
            fontSize: 10.5.sp,
            color: th.textSecondary,
          ),
        ),
      ],
    );
  }

  List<String> _getTeamRecentForm(String teamId) {
    final completed = _tournament.fixtures
        .where((f) =>
            f.status.toLowerCase() == 'completed' &&
            (f.team1Id == teamId || f.team2Id == teamId))
        .toList();

    final form = <String>[];
    for (final f in completed) {
      if (f.winnerId == null || f.winnerId!.isEmpty) {
        form.add('T');
      } else if (f.winnerId == teamId) {
        form.add('W');
      } else {
        form.add('L');
      }
    }
    if (form.length > 5) {
      return form.sublist(form.length - 5);
    }
    return form;
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
                            SnackBar(content: Text('Failed to generate invite link', style: TextStyle(color: ThemeHelper.of(context).cardBg,)), backgroundColor: Colors.red),
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

    return Column(
      children: [
        // Category Tabs
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: ThemeHelper.of(context).cardBg,
            border: Border(bottom: BorderSide(color: ThemeHelper.of(context).dividerColor!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCategoryTab('BATTING', 0),
              ),
              Expanded(
                child: _buildStatCategoryTab('BOWLING', 1),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _selectedStatCategory == 0 ? _buildBattingStats() : _buildBowlingStats(),
        ),
      ],
    );
  }

  int _selectedStatCategory = 0;

  Widget _buildStatCategoryTab(String label, int index) {
    final isSelected = _selectedStatCategory == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatCategory = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryOrange : ThemeHelper.of(context).textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildBattingStats() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClassicStatsTable(
            'Top Run Scorers',
            Icons.sports_cricket,
            _tournament.topRunScorers ?? [],
            (e) => '${e.value} runs',
          ),
          SizedBox(height: 12.h),
          _buildClassicStatsTable(
            'Most Sixes',
            Icons.rocket_launch,
            _tournament.topSixHitters ?? [],
            (e) => '${e.value} sixes',
          ),
          SizedBox(height: 12.h),
          _buildClassicStatsTable(
            'Most Fours',
            Icons.bolt,
            _tournament.topFourHitters ?? [],
            (e) => '${e.value} fours',
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingStats() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClassicStatsTable(
            'Top Wicket Takers',
            Icons.sports_baseball,
            _tournament.topWicketTakers ?? [],
            (e) => '${e.value} wickets',
          ),
          SizedBox(height: 12.h),
          _buildClassicStatsTable(
            'Best Economy',
            Icons.trending_down,
            _tournament.bestEconomy ?? [],
            (e) => e.average > 0 ? e.average.toStringAsFixed(2) : '-',
          ),
          SizedBox(height: 12.h),
          _buildClassicStatsTable(
            'Best Bowling Figures',
            Icons.military_tech,
            _tournament.bestBowlingFigures ?? [],
            (e) => e.description ?? '${e.value} wkts',
          ),
        ],
      ),
    );
  }

  Widget _buildClassicStatsTable(
    String title,
    IconData icon,
    List<TournamentLeaderboardEntry> data,
    String Function(TournamentLeaderboardEntry) valueFormatter,
  ) {
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: ThemeHelper.of(context).dividerColor!),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThemeHelper.of(context).textSecondary, size: 20.sp),
            SizedBox(width: 12.w),
            Text(title, style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontWeight: FontWeight.w500, fontSize: 13.sp)),
            Spacer(),
            Text('No data', style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.of(context).cardBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: ThemeHelper.of(context).dividerColor!),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
              border: Border(bottom: BorderSide(color: ThemeHelper.of(context).dividerColor!)),
            ),
            child: Row(
              children: [
                Icon(icon, color: ThemeHelper.of(context).textSecondary, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: ThemeHelper.of(context).textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                Text(
                  '${data.length} players',
                  style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Top performer highlight (first row)
          if (data.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border(bottom: BorderSide(color: ThemeHelper.of(context).dividerColor!)),
              ),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.of(context).cardBg,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.first.playerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                            color: ThemeHelper.of(context).textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          data.first.teamName,
                          style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                  // Value
                  Text(
                    valueFormatter(data.first),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                      color: ThemeHelper.of(context).textPrimary,
                    ),
                  ),
                ],
              ),
            ),

          // Remaining players
          ...data.skip(1).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;
            final rank = index + 2;

            final isLast = index == data.length - 2;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.grey[50] : Colors.white,
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: ThemeHelper.of(context).dividerColor!, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: BoxDecoration(
                      color: rank == 2
                          ? ThemeHelper.of(context).dividerColor!
                          : rank == 3
                              ? Colors.amber[200]
                              : Colors.transparent,
                      shape: rank <= 3 ? BoxShape.circle : BoxShape.rectangle,
                      border: rank > 3 ? Border.all(color: ThemeHelper.of(context).dividerColor!) : null,
                      borderRadius: rank > 3 ? BorderRadius.circular(14.r) : null,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: rank == 2
                              ? Colors.white
                              : rank == 3
                                  ? ThemeHelper.of(context).textPrimary
                                  : ThemeHelper.of(context).textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.playerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12.sp,
                            color: ThemeHelper.of(context).textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          player.teamName,
                          style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 10.sp),
                        ),
                      ],
                    ),
                  ),
                  // Value
                  Text(
                    valueFormatter(player),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                      color: ThemeHelper.of(context).textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
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

// ==================== MVP TAB ====================
  Widget _buildMVPTab() {
    // Calculate MVP using weighted formula: runs + (wickets × 25) + (sixes × 6) + (fours × 4)
    final Map<String, _MvpCandidate> mvpScores = {};
    
    // Add runs
    for (var entry in _tournament.topRunScorers) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerId, entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.runs = entry.value;
      mvpScores[entry.playerId]!.matches = entry.matches;
    }
    // Add wickets
    for (var entry in _tournament.topWicketTakers) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerId, entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.wickets = entry.value;
    }
    // Add sixes
    for (var entry in _tournament.topSixHitters) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerId, entry.playerName, entry.teamName));
      mvpScores[entry.playerId]!.sixes = entry.value;
    }
    // Add fours
    for (var entry in _tournament.topFourHitters) {
      mvpScores.putIfAbsent(entry.playerId, () => _MvpCandidate(entry.playerId, entry.playerName, entry.teamName));
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
    
    final isDark = ThemeHelper.of(context).isDark;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── HERO MVP PODIUM CARD ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0A0F1D),
                ],
              ),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Crown Badge + Matches Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 14.sp, color: const Color(0xFF451A03)),
                          SizedBox(width: 5.w),
                          Text(
                            'TOURNAMENT MVP 👑',
                            style: TextStyle(
                              color: const Color(0xFF451A03),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasData && mvp != null && mvp.matches > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '${mvp.matches} Matches',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 18.h),

                // Player Avatar
                if (hasData && mvp != null)
                  PlayerAvatarWidget(
                    playerId: mvp.playerId,
                    playerName: mvp.name,
                    size: 84.sp,
                    border: Border.all(color: const Color(0xFFFFD700), width: 3.5),
                    enableProfileView: true,
                    badge: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD700),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Icon(Icons.star_rounded, size: 16.sp, color: const Color(0xFF451A03)),
                    ),
                  )
                else
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(Icons.emoji_events_rounded, size: 44.sp, color: const Color(0xFF451A03)),
                  ),
                SizedBox(height: 14.h),

                // Player Name
                Text(
                  hasData ? mvp!.name : 'Race for MVP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (hasData) ...[
                  SizedBox(height: 6.h),
                  if (mvp!.teamName.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        mvp.teamName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  SizedBox(height: 16.h),

                  // MVP Points Showcase Banner
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.white, size: 18.sp),
                        SizedBox(width: 6.w),
                        Text(
                          '${mvp.mvpScore}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          'MVP POINTS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),

                  // 4-Column Stat Matrix
                  Row(
                    children: [
                      Expanded(
                        child: _buildMvpGlassStat('Runs', '${mvp.runs}', const Color(0xFF38BDF8), Icons.sports_cricket_rounded),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildMvpGlassStat('Wkts', '${mvp.wickets}', const Color(0xFF34D399), Icons.sports_baseball_rounded),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildMvpGlassStat('6s', '${mvp.sixes}', const Color(0xFFC084FC), Icons.rocket_launch_rounded),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildMvpGlassStat('4s', '${mvp.fours}', const Color(0xFFFB923C), Icons.flash_on_rounded),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Matches are underway! The player with the highest all-round impact will be crowned tournament MVP.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ── TOURNAMENT HONORS / AWARDS ──
          _buildCategoryHeader('🏆', 'TOURNAMENT AWARDS', AppTheme.primaryOrange),
          SizedBox(height: 14.h),

          // Awards 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildAwardCard(
                  Icons.sports_cricket_rounded,
                  'Best Batsman',
                  bestBatsman?.playerName ?? 'TBA',
                  bestBatsman != null ? '${bestBatsman.value} runs' : 'No stats yet',
                  bestBatsman?.teamName ?? '',
                  const Color(0xFFFF5722),
                  playerId: bestBatsman?.playerId,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildAwardCard(
                  Icons.sports_baseball_rounded,
                  'Best Bowler',
                  bestBowler?.playerName ?? 'TBA',
                  bestBowler != null ? '${bestBowler.value} wkts' : 'No stats yet',
                  bestBowler?.teamName ?? '',
                  const Color(0xFF10B981),
                  playerId: bestBowler?.playerId,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildAwardCard(
                  Icons.rocket_launch_rounded,
                  'Maximum Sixes',
                  mostSixes?.playerName ?? 'TBA',
                  mostSixes != null ? '${mostSixes.value} sixes' : 'No stats yet',
                  mostSixes?.teamName ?? '',
                  const Color(0xFFA855F7),
                  playerId: mostSixes?.playerId,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildAwardCard(
                  Icons.flash_on_rounded,
                  'Most Fours',
                  mostFours?.playerName ?? 'TBA',
                  mostFours != null ? '${mostFours.value} fours' : 'No stats yet',
                  mostFours?.teamName ?? '',
                  const Color(0xFFF59E0B),
                  playerId: mostFours?.playerId,
                ),
              ),
            ],
          ),

          // ── MVP LEADERBOARD ──
          if (sortedMvp.length > 1) ...[
            SizedBox(height: 26.h),
            _buildCategoryHeader('📊', 'MVP LEADERBOARD', const Color(0xFF0284C7)),
            SizedBox(height: 14.h),
            Container(
              decoration: BoxDecoration(
                color: ThemeHelper.of(context).cardBg,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: ThemeHelper.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30.w,
                          child: Text(
                            '#',
                            style: TextStyle(
                              color: ThemeHelper.of(context).textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'PLAYER',
                            style: TextStyle(
                              color: ThemeHelper.of(context).textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44.w,
                          child: Text(
                            'R',
                            style: TextStyle(
                              color: ThemeHelper.of(context).textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 36.w,
                          child: Text(
                            'W',
                            style: TextStyle(
                              color: ThemeHelper.of(context).textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 60.w,
                          child: Text(
                            'POINTS',
                            style: TextStyle(
                              color: ThemeHelper.of(context).textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rows
                  ...sortedMvp.take(10).toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final candidate = entry.value.value;
                    final rank = idx + 1;
                    final isLast = idx == (sortedMvp.take(10).length - 1);

                    Color rowBg;
                    Widget rankWidget;

                    if (rank == 1) {
                      rowBg = isDark ? const Color(0xFF2A2210) : const Color(0xFFFFFBEB);
                      rankWidget = Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '1',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: const Color(0xFF451A03)),
                          ),
                        ),
                      );
                    } else if (rank == 2) {
                      rowBg = isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC);
                      rankWidget = Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '2',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                          ),
                        ),
                      );
                    } else if (rank == 3) {
                      rowBg = isDark ? const Color(0xFF2A1C14) : const Color(0xFFFFF7ED);
                      rankWidget = Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFFDBA74), Color(0xFFD97706)]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '3',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: const Color(0xFF431407)),
                          ),
                        ),
                      );
                    } else {
                      rowBg = ThemeHelper.of(context).cardBg;
                      rankWidget = Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          color: ThemeHelper.of(context).dividerColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: ThemeHelper.of(context).textSecondary,
                            ),
                          ),
                        ),
                      );
                    }

                    return InkWell(
                      onTap: () {
                        final effectiveId = candidate.playerId.isNotEmpty ? candidate.playerId : candidate.name;
                        if (effectiveId.isNotEmpty) {
                          _navigateToOrganizerProfile(effectiveId);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: rowBg,
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: ThemeHelper.of(context).dividerColor.withValues(alpha: 0.6),
                                    width: 0.5,
                                  ),
                                ),
                          borderRadius: isLast
                              ? BorderRadius.vertical(bottom: Radius.circular(20.r))
                              : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 30.w, child: rankWidget),
                            SizedBox(width: 6.w),
                            PlayerAvatarWidget(
                              playerId: candidate.playerId,
                              playerName: candidate.name,
                              size: 34.sp,
                              enableProfileView: true,
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5.sp,
                                      color: ThemeHelper.of(context).textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    candidate.teamName,
                                    style: TextStyle(
                                      color: ThemeHelper.of(context).textSecondary,
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 44.w,
                              child: Text(
                                '${candidate.runs}',
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: ThemeHelper.of(context).textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 36.w,
                              child: Text(
                                '${candidate.wickets}',
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: ThemeHelper.of(context).textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 60.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                      : rank <= 3
                                          ? AppTheme.primaryOrange.withValues(alpha: 0.12)
                                          : ThemeHelper.of(context).dividerColor.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  '${candidate.mvpScore}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w900,
                                    color: rank == 1
                                        ? const Color(0xFFD97706)
                                        : rank <= 3
                                            ? AppTheme.primaryOrange
                                            : ThemeHelper.of(context).textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          SizedBox(height: 24.h),

          // ── MVP FORMULA EXPLAINER ──
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: ThemeHelper.of(context).cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: ThemeHelper.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calculate_rounded, size: 18.sp, color: AppTheme.primaryOrange),
                    SizedBox(width: 8.w),
                    Text(
                      'MVP Calculation Formula',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: ThemeHelper.of(context).textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildFormulaChip('1 Run = 1 Pt', const Color(0xFF38BDF8)),
                    _buildFormulaChip('1 Wkt = 25 Pts', const Color(0xFF34D399)),
                    _buildFormulaChip('1 Six = 6 Pts', const Color(0xFFC084FC)),
                    _buildFormulaChip('1 Four = 4 Pts', const Color(0xFFFB923C)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMvpGlassStat(String label, String value, Color accentColor, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14.sp, color: accentColor),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accentColor,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAwardCard(
    IconData icon,
    String award,
    String playerName,
    String stat,
    String teamName,
    Color accentColor, {
    String? playerId,
  }) {
    final effectiveId = playerId?.isNotEmpty == true ? playerId! : playerName;
    final isTba = playerName == 'TBA' || playerName.isEmpty;

    return InkWell(
      onTap: isTba
          ? null
          : () {
              if (effectiveId.isNotEmpty) {
                _navigateToOrganizerProfile(effectiveId);
              }
            },
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: ThemeHelper.of(context).cardBg,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon Badge & Award Title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14.sp, color: accentColor),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    award.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Player Avatar & Name
            Row(
              children: [
                PlayerAvatarWidget(
                  playerId: playerId,
                  playerName: playerName,
                  size: 34.sp,
                  enableProfileView: !isTba,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: ThemeHelper.of(context).textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (teamName.isNotEmpty) ...[
                        SizedBox(height: 1.h),
                        Text(
                          teamName,
                          style: TextStyle(
                            color: ThemeHelper.of(context).textSecondary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Stat Pill
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                stat,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5.sp,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }


    // ==================== HELPER WIDGETS ====================
  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.sp, color: ThemeHelper.of(context).textSecondary),
          SizedBox(height: 16.h),
          Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: ThemeHelper.of(context).textSecondary)),
          SizedBox(height: 8.h),
          Text(subtitle, style: TextStyle(color: ThemeHelper.of(context).textSecondary), textAlign: TextAlign.center),
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
          Expanded(child: Text('Organizer', style: TextStyle(color: ThemeHelper.of(context).textSecondary))),
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
          Expanded(child: Text(label, style: TextStyle(color: ThemeHelper.of(context).textSecondary))),
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
    final th = ThemeHelper.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height: MediaQuery.of(modalContext).size.height * 0.78,
        decoration: BoxDecoration(
          color: th.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: th.dividerColor?.withOpacity(0.6) ?? Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Header with TeamLogoWidget
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: th.dividerColor?.withOpacity(0.4) ?? Colors.grey.withOpacity(0.2),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TeamLogoWidget(
                    teamName: team.name,
                    logoUrl: team.logoUrl,
                    size: 46.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: th.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                ' Players',
                                style: TextStyle(
                                  color: AppTheme.primaryOrange,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InkWell(
                              onTap: () {
                                Navigator.pop(modalContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TeamDetailsScreen(team: team)),
                                );
                              },
                              child: Row(
                                children: [
                                  Text(
                                    'Full Profile',
                                    style: TextStyle(
                                      color: th.textSecondary,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 14.sp, color: th.textSecondary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20.sp, color: th.textSecondary),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
            ),
            
            // Player List
            Expanded(
              child: team.players.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined, size: 42.sp, color: th.textSecondary),
                          SizedBox(height: 8.h),
                          Text(
                            'No players in squad yet',
                            style: TextStyle(fontSize: 13.sp, color: th.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      itemCount: team.players.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.6,
                        color: th.dividerColor?.withOpacity(0.35) ?? Colors.grey.withOpacity(0.2),
                      ),
                      itemBuilder: (context, index) {
                        final player = team.players[index];
                        final isWicketKeeper = player.role.toLowerCase().contains('wicket keeper') || player.role.toLowerCase().contains('wk');
                        final roleName = player.role.isNotEmpty ? player.role : 'Player';
                        
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Row(
                            children: [
                              // Avatar
                              PlayerAvatarWidget(
                                profileImageUrl: player.profileImageUrl,
                                playerId: player.userId,
                                playerName: player.name,
                                size: 36.sp,
                                enableProfileView: true,
                              ),
                              SizedBox(width: 10.w),

                              // Name + badges
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            player.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.sp,
                                              color: th.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (player.isCaptain) ...[
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                            decoration: BoxDecoration(
                                              color: Colors.amber[800],
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                            child: Text('C', style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                        if (player.isViceCaptain) ...[
                                          SizedBox(width: 5.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[700],
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                            child: Text('VC', style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                        if (isWicketKeeper) ...[
                                          SizedBox(width: 5.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2E7D32),
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                            child: Text('WK', style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      roleName,
                                      style: TextStyle(
                                        color: th.textSecondary,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Add Player to Squad button (for organizers)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showAddPlayerToTournamentTeamDialog(context, team);
                  },
                  icon: Icon(Icons.person_add_rounded, size: 18.sp),
                  label: Text('Add Player to Squad', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPlayerToTournamentTeamDialog(BuildContext parentContext, TeamModel team) {
    final searchController = TextEditingController();
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    String selectedRole = 'Batsman';
    String? lookedUpUserId;
    bool isLookingUp = false;

    showDialog(
      context: parentContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> lookupPlayer() async {
            final query = searchController.text.trim();
            if (query.isEmpty) return;

            setDialogState(() => isLookingUp = true);
            lookedUpUserId = null;

            try {
              final result = await PlayerSearchService.instance.searchPlayer(query);
              if (result.isSuccess && result.player != null) {
                final user = result.player!;
                nameController.text = user.name;
                lookedUpUserId = user.uid;
                searchController.text = user.spPId;
                if (['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'].contains(user.role)) {
                  selectedRole = user.role;
                }
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text('✅ Found: ${user.name} (${user.spPId})'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text('❌ ${result.errorMessage ?? "No registered player found"}'), backgroundColor: Colors.orange),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            } finally {
              setDialogState(() => isLookingUp = false);
            }
          }

          return AlertDialog(
            title: Text('Add Player to ${team.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: 'SPP ID or Mobile Number',
                            hintText: 'Enter SPP ID or mobile number',
                          ),
                          onSubmitted: (_) => lookupPlayer(),
                        ),
                      ),
                      IconButton(
                        icon: isLookingUp
                            ? SizedBox(width: 16.w, height: 16.h, child: const CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search, color: Colors.orange),
                        onPressed: isLookingUp ? null : lookupPlayer,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Player Name', hintText: 'Enter player name'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile Number (Optional)', hintText: 'Enter mobile number'),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selectedRole = val ?? 'Batsman'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Please enter player name')),
                    );
                    return;
                  }

                  final spPId = searchController.text.trim().toUpperCase();
                  final mobile = mobileController.text.trim();

                  // Duplicate check
                  final isDuplicate = team.players.any((p) {
                    if (lookedUpUserId != null && p.userId == lookedUpUserId) return true;
                    if (spPId.isNotEmpty && p.spPId.isNotEmpty && p.spPId.toUpperCase() == spPId) return true;
                    if (mobile.isNotEmpty && p.mobileNumber.isNotEmpty && p.mobileNumber == mobile) return true;
                    return false;
                  });

                  if (isDuplicate) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Player is already in this team'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  final newPlayer = TeamPlayer(
                    userId: lookedUpUserId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    spPId: spPId,
                    name: name,
                    mobileNumber: mobile,
                    role: selectedRole,
                    isRegistered: lookedUpUserId != null,
                  );

                  final success = await FirebaseDataService.instance.addPlayerToTeam(team.id, newPlayer);
                  if (success) {
                    team.players.add(newPlayer);
                    if (parentContext.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text('✅ Added ${newPlayer.name} to ${team.name}'), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    if (parentContext.mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('Failed to add player')),
                      );
                    }
                  }
                },
                child: const Text('Add Player'),
              ),
            ],
          );
        },
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
      backgroundColor: ThemeHelper.of(context).scaffoldBg,
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
                          color: isSelected ? AppTheme.primaryOrange : ThemeHelper.of(context).dividerColor!,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.3), blurRadius: 6, offset: Offset(0, 2))
                        ] : [],
                      ),
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : ThemeHelper.of(context).textPrimary,
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
                  border: Border.all(color: ThemeHelper.of(context).cardBg.withOpacity(0.1), width: 1),
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
                        color: ThemeHelper.of(context).cardBg.withOpacity(0.05),
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
                              color: ThemeHelper.of(context).cardBg,
                              fontWeight: FontWeight.w900,
                              fontSize: 16.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Generate premium player moments',
                            style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 11.sp),
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
                        Icon(Icons.photo_library_outlined, size: 64.sp, color: ThemeHelper.of(context).dividerColor!),
                        SizedBox(height: 12.h),
                        Text(
                          'No Moments in this category.',
                          style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontWeight: FontWeight.bold),
                        ),
                        if (canManage) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'Tap "Generate" to add your first cinematic sports moment!',
                            style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp),
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
          color: ThemeHelper.of(context).cardBg,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(0.06),
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
              Positioned.fill(child: Icon(Icons.photo, color: ThemeHelper.of(context).textSecondary)),

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
                        color: ThemeHelper.of(context).cardBg.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: ThemeHelper.of(context).cardBg.withOpacity(0.3), width: 1.w),
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
                              color: ThemeHelper.of(context).cardBg,
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
                      style: TextStyle(color: ThemeHelper.of(context).cardBg, fontWeight: FontWeight.bold, fontSize: 12.sp),
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
                    style: TextStyle(color: ThemeHelper.of(context).cardBg.withOpacity(0.75), fontSize: 9.sp),
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
            color: ThemeHelper.of(context).cardBg,
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
                      color: ThemeHelper.of(context).textPrimary,
                    ),
                  ),
                  Positioned(
                    top: 12.h,
                    right: 12.w,
                    child: IconButton(
                      icon: Icon(Icons.close, color: ThemeHelper.of(context).cardBg, size: 24.sp),
                      style: IconButton.styleFrom(backgroundColor: ThemeHelper.of(context).textSecondary),
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
                              color: ThemeHelper.of(context).cardBg.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: ThemeHelper.of(context).cardBg.withOpacity(0.3), width: 1.5.w),
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
                                    color: ThemeHelper.of(context).cardBg,
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
                          style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 10.sp, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    if (item.playerName != null && item.playerName!.isNotEmpty) ...[
                      Text(
                        item.playerName!.toUpperCase(),
                        style: TextStyle(color: ThemeHelper.of(context).textPrimary, fontWeight: FontWeight.w900, fontSize: 20.sp, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 4.h),
                    ],
                    Text(
                      item.description,
                      style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 13.sp, height: 1.4, fontWeight: FontWeight.w500),
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
                                  
                                  final shareText = 'Check out this epic moment from the ${widget.tournament.name}! 🏏🏆';
                                  if (kIsWeb) {
                                    final xFile = XFile.fromData(bytes, name: '${item.id}.png', mimeType: 'image/png');
                                    await Share.shareXFiles([xFile], text: shareText);
                                  } else {
                                    final tempDir = await getTemporaryDirectory();
                                    final file = await File('${tempDir.path}/${item.id}.png').create();
                                    await file.writeAsBytes(bytes);
                                    
                                    await Share.shareXFiles([XFile(file.path)], text: shareText);
                                  }
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
                              color: ThemeHelper.of(context).cardBg,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          widget.status.toUpperCase(),
                          style: TextStyle(
                            color: ThemeHelper.of(context).cardBg,
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
                          color: ThemeHelper.of(context).cardBg,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: ThemeHelper.of(context).textSecondary,
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
                    Icon(Icons.remove_red_eye, color: ThemeHelper.of(context).textSecondary, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text(
                      '${widget.views}',
                      style: TextStyle(
                        color: ThemeHelper.of(context).textSecondary,
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
                            color: ThemeHelper.of(context).cardBg.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.location_on, color: ThemeHelper.of(context).cardBg, size: 16.sp),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            widget.location,
                            style: TextStyle(
                              color: ThemeHelper.of(context).cardBg,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right, color: ThemeHelper.of(context).textSecondary, size: 16.sp),
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
      color: ThemeHelper.of(context).cardBg.withOpacity(opacity),
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
  final String playerId;
  final String name;
  final String teamName;
  int runs = 0;
  int wickets = 0;
  int sixes = 0;
  int fours = 0;
  int matches = 0;

  _MvpCandidate(this.playerId, this.name, this.teamName);

  /// MVP Score: runs + (wickets × 25) + (sixes × 6) + (fours × 4)
  int get mvpScore => runs + (wickets * 25) + (sixes * 6) + (fours * 4);
}
