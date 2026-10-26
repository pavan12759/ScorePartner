import 'dart:typed_data';
import 'dart:async';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../../../../data/services/player_search_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/team_logo_widget.dart';
import '../../widgets/player_avatar_widget.dart';
import '../../widgets/cricket_logo_generator.dart';
import '../../widgets/invite_link_share_sheet.dart';
import '../profile/player_profile_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'join_requests_screen.dart';
import 'poster/team_poster_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final TeamModel team;

  const TeamDetailsScreen({super.key, required this.team});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final FirebaseDataService _dataService = FirebaseDataService.instance;
  final ScreenshotController _qrScreenshotController = ScreenshotController();
  bool _isSharingQr = false;

  @override
  void initState() {
    super.initState();
    // Recalculate team stats from completed matches on load
    _dataService.recalculateTeamStats(widget.team.id);
  }

  Future<void> _shareTeamQr(TeamModel team) async {
    if (_isSharingQr) return;
    setState(() => _isSharingQr = true);

    try {
      await Future.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;

      final image = await _qrScreenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );

      if (image == null) throw Exception('Capture failed');

      final safeName = team.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final fileName = 'team_${safeName}_qr.png';
      final caption = '🏏 Join my cricket team *${team.name}* on ScorePartner!\n\n'
          'Scan this QR code or enter Team ID: *${team.spTId}* to send a join request.\n\n'
          'Download ScorePartner: The Cricket Scoring App 🏆';

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(image);

      await Share.shareXFiles([XFile(filePath)], text: caption);
    } catch (e) {
      debugPrint('❌ Error sharing QR code: $e');
      if (mounted) {
        Share.share(
          '🏏 Join my cricket team *${team.name}* on ScorePartner!\n'
          'Team ID: ${team.spTId}\n\n'
          'Search for this ID in ScorePartner to join our squad!',
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingQr = false);
    }
  }

  /// Check if current user is the team admin (creator)
  bool _isAdmin(TeamModel team) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.user?.uid;
      if (uid == null) return false;
      // Admin = team creator. We check captainId as fallback for old teams without createdBy.
      return uid == team.captainId;
    } catch (_) {
      return false;
    }
  }

  /// Check if current user is the captain
  bool _isCaptain(TeamModel team) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.user?.uid == team.captainId;
    } catch (_) {
      return false;
    }
  }

  /// Check if current user is the vice captain
  bool _isViceCaptain(TeamModel team) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.user?.uid == team.viceCaptainId;
    } catch (_) {
      return false;
    }
  }

  /// Check if current user can manage the team (admin, captain, or vice captain)
  bool _canManage(TeamModel team) {
    return _isAdmin(team) || _isCaptain(team) || _isViceCaptain(team);
  }

  void _showLogoOptions(TeamModel team) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w, height: 4.h,
                decoration: BoxDecoration(color: ThemeHelper.of(context).dividerColor!, borderRadius: BorderRadius.circular(2.r)),
              ),
              SizedBox(height: 16.h),
              Text('Change Team Logo', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 20.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(Icons.photo_library, color: AppTheme.primaryOrange),
                ),
                title: const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Choose your own image', style: TextStyle(fontSize: 12.sp)),
                onTap: () { Navigator.pop(context); _uploadFromGallery(team); },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(Icons.auto_awesome, color: Colors.blue),
                ),
                title: const Text('Choose Cricket Logo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Pick from 6 pre-made designs', style: TextStyle(fontSize: 12.sp)),
                onTap: () { Navigator.pop(context); _showCricketLogoChooser(team); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadFromGallery(TeamModel team) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading logo...'), backgroundColor: Color(0xFFFF6B35)),
      );

      final success = await _dataService.updateTeamLogo(team.id, bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ Logo updated!' : '❌ Failed to update logo'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCricketLogoChooser(TeamModel team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Cricket Logo'),
        content: SizedBox(
          width: double.maxFinite,
          height: 350.h,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: CricketLogoGenerator.designs.length,
            itemBuilder: (context, index) {
              final design = CricketLogoGenerator.designs[index];
              return GestureDetector(
                onTap: () => _selectCricketLogo(team, design),
                child: Column(
                  children: [
                    Expanded(
                      child: CricketLogoGenerator.buildLogoPreview(design, team.name, size: 90.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      design.name,
                      style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _selectCricketLogo(TeamModel team, LogoDesign design) async {
    Navigator.pop(context); // Close chooser dialog

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating & uploading logo...'), backgroundColor: Color(0xFFFF6B35)),
    );

    final bytes = await CricketLogoGenerator.renderLogoToBytes(design, team.name);
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to generate logo'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final success = await _dataService.updateTeamLogo(team.id, bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Logo updated!' : '❌ Failed to upload logo'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showAddPlayerDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    String selectedRole = 'Batsman';
    String selectedBatting = 'Right-hand';
    String selectedBowling = 'Medium';
    
    // SPP ID Lookup
    final sppIdController = TextEditingController();
    bool isLookingUp = false;
    String? lookedUpUserId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          Future<void> lookupPlayer() async {
            final query = sppIdController.text.trim();
            if (query.isEmpty) return;
            
            lookedUpUserId = null; // Reset previous lookup result
            setDialogState(() => isLookingUp = true);
            
            try {
              final result = await PlayerSearchService.instance.searchPlayer(query);
              
              if (result.isSuccess && result.player != null) {
                final user = result.player!;
                nameController.text = user.name;
                lookedUpUserId = user.uid;
                sppIdController.text = user.spPId;
                
                // Try to map role
                if (['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'].contains(user.role)) {
                  selectedRole = user.role;
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Found: ${user.name} (${user.spPId})'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${result.errorMessage ?? "No registered player found"}'), backgroundColor: Colors.orange),
                );
              }
            } catch (e) {
               ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
            } finally {
               setDialogState(() => isLookingUp = false);
            }
          }

          return AlertDialog(
          title: const Text('Add Player'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SPP ID Field with Search
                Container(
                  width: double.maxFinite,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sppIdController,
                          decoration: const InputDecoration(
                            labelText: 'SPP ID or Mobile Number (Optional)',
                            hintText: 'Enter SPP ID or mobile number',
                          ),
                          onSubmitted: (_) => lookupPlayer(),
                        ),
                      ),
                      IconButton(
                        icon: isLookingUp 
                          ? SizedBox(width: 16.w, height: 16.h, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : Icon(Icons.search, color: Colors.orange),
                        onPressed: isLookingUp ? null : lookupPlayer,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Player Name',
                    hintText: 'Enter full name',
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number (Optional)',
                    hintText: 'Enter 10-digit number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper']
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  value: selectedBatting,
                  decoration: const InputDecoration(labelText: 'Batting Style'),
                  items: ['Right-hand', 'Left-hand']
                      .map((style) => DropdownMenuItem(value: style, child: Text(style)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedBatting = val!),
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  value: selectedBowling,
                  decoration: const InputDecoration(labelText: 'Bowling Style'),
                  items: ['Fast', 'Medium', 'Spin', 'None']
                      .map((style) => DropdownMenuItem(value: style, child: Text(style)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedBowling = val!),
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
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter player name')),
                  );
                  return;
                }

                final spPId = sppIdController.text.trim().toUpperCase();
                final mobile = mobileController.text.trim();

                // Check duplicate in team roster
                final isDuplicate = widget.team.players.any((p) {
                  if (lookedUpUserId != null && p.userId == lookedUpUserId) return true;
                  if (spPId.isNotEmpty && p.spPId.isNotEmpty && p.spPId.toUpperCase() == spPId) return true;
                  if (mobile.isNotEmpty && p.mobileNumber.isNotEmpty && p.mobileNumber == mobile) return true;
                  return false;
                });

                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Player is already in this team'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                // Use looked up ID or generate random one for manual players
                final userId = lookedUpUserId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}';
                
                final newPlayer = TeamPlayer(
                  userId: userId,
                  spPId: spPId,
                  name: nameController.text.trim(),
                  mobileNumber: mobile,
                  role: selectedRole,
                  battingStyle: selectedBatting,
                  bowlingStyle: selectedBowling,
                  isRegistered: lookedUpUserId != null, // Registered if we found them via lookup
                );

                final success = await _dataService.addPlayerToTeam(widget.team.id, newPlayer);
                if (success) {
                  if (mounted) Navigator.pop(context);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to add player')),
                    );
                  }
                }
              },
              child: const Text('Add Player'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _removePlayer(TeamPlayer player) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Player'),
        content: Text('Are you sure you want to remove ${player.name} from the team?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _dataService.removePlayerFromTeam(widget.team.id, player);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove player')),
        );
      }
    }
  }

  /// Make a player the captain
  Future<void> _makeCaptain(TeamModel team, TeamPlayer player) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Captain'),
        content: Text('Make ${player.name} the new Captain?\n\nThe current captain will become a regular player.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: Text('Confirm', style: TextStyle(color: ThemeHelper.of(context).cardBg,)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _dataService.changeCaptain(team.id, player.userId, player.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ ${player.name} is now Captain!' : '❌ Failed to change captain'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  /// Make a player the vice-captain
  Future<void> _makeViceCaptain(TeamModel team, TeamPlayer player) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Vice-Captain'),
        content: Text('Make ${player.name} the Vice-Captain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: Text('Confirm', style: TextStyle(color: ThemeHelper.of(context).cardBg,)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _dataService.changeViceCaptain(team.id, player.userId, player.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ ${player.name} is now Vice-Captain!' : '❌ Failed to change vice-captain'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  /// Show management options for a player
  void _showPlayerOptions(TeamModel team, TeamPlayer player) {
    final isAdmin = _isAdmin(team);
    final canManage = _canManage(team);

    if (!canManage) return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ThemeHelper.of(context).dividerColor!,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                player.name,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              Text(
                player.role,
                style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 20.h),

              // Make Captain (admin only — only team creator should reassign captaincy)
              if (isAdmin && !player.isCaptain)
                _buildOptionTile(
                  icon: Icons.star,
                  label: 'Make Captain',
                  subtitle: 'This player will lead the team',
                  color: Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    _makeCaptain(team, player);
                  },
                ),

              // Make Vice-Captain (admin or captain can set VC)
              if (!player.isViceCaptain && !player.isCaptain)
                _buildOptionTile(
                  icon: Icons.star_half,
                  label: 'Make Vice-Captain',
                  subtitle: 'Assign as vice-captain',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _makeViceCaptain(team, player);
                  },
                ),

              // Remove Player (cannot remove captain)
              if (!player.isCaptain)
                _buildOptionTile(
                  icon: Icons.person_remove,
                  label: 'Remove Player',
                  subtitle: 'Remove from team',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _removePlayer(player);
                  },
                ),

              if (player.isCaptain)
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    'Captain cannot be removed. Change captain first.',
                    style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 13.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: color, size: 24.sp),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 12.sp)),
      onTap: onTap,
    );
  }

  Future<void> _editTeamName(TeamModel team) async {
    final nameController = TextEditingController(text: team.name);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Team Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Team Name',
            hintText: 'Enter new team name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: Text('Save', style: TextStyle(color: ThemeHelper.of(context).cardBg,)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updating team name across matches & tournaments...'),
              backgroundColor: Color(0xFFFF6B35),
            ),
          );
        }

        final success = await _dataService.updateTeam(team.id, {'name': newName});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '✅ Team name updated everywhere!' : '❌ Failed to update team name'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TeamModel?>(
      stream: _dataService.streamTeam(widget.team.id),
      initialData: widget.team,
      builder: (context, snapshot) {
        final team = snapshot.data ?? widget.team;
        final canManage = _canManage(team);

        return Scaffold(
          backgroundColor: ThemeHelper.of(context).scaffoldBg,
          appBar: AppBar(
            title: Text(team.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.style_outlined),
                tooltip: 'Team Poster',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamPosterScreen(team: team),
                    ),
                  );
                },
              ),
              if (canManage)
                IconButton(
                  icon: Icon(Icons.link),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => InviteLinkShareSheet(team: team),
                    );
                  },
                  tooltip: 'Invite Player',
                ),
              if (canManage)
                IconButton(
                  icon: Icon(Icons.how_to_reg_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JoinRequestsScreen(
                          teamId: team.id,
                          teamName: team.name,
                        ),
                      ),
                    );
                  },
                  tooltip: 'Join Requests',
                ),
              if (canManage)
                IconButton(
                  icon: Icon(Icons.person_add_alt_1_outlined),
                  onPressed: _showAddPlayerDialog,
                  tooltip: 'Add Player Manually',
                ),
              if (_isAdmin(team)) // Only true creator/admin can delete the whole team
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete Team',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Team'),
                        content: Text('Are you sure you want to delete ${team.name}? This action cannot be undone and will permanently remove all players and team data.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text('Delete', style: TextStyle(color: ThemeHelper.of(context).cardBg,)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final success = await _dataService.deleteTeam(team.id);
                      if (success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Team deleted completely')),
                          );
                          // Pop back to Teams list screen
                          Navigator.pop(context);
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('❌ Failed to delete team')),
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Team Header Info
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  color: ThemeHelper.of(context).cardBg,
                  child: Column(
                    children: [
                      TeamLogoWidget(
                        teamName: team.name,
                        logoUrl: team.logoUrl,
                        size: 80.sp,
                        onTap: canManage ? () => _showLogoOptions(team) : null,
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            team.name,
                            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
                          ),
                          if (canManage)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editTeamName(team),
                              color: AppTheme.primaryOrange,
                            ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Team ID: ${team.spTId}',
                        style: TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Captain & Vice-Captain Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildRoleBadge('Captain', team.captainName, Colors.amber, playerId: team.captainId),
                          SizedBox(width: 12.w),
                          if (team.viceCaptainName.isNotEmpty)
                            _buildRoleBadge('Vice-Captain', team.viceCaptainName, Colors.blue, playerId: team.viceCaptainId),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatBadge('Played', '${team.matchesPlayed}'),
                          SizedBox(width: 12.w),
                          _buildStatBadge('Won', '${team.matchesWon}'),
                          SizedBox(width: 12.w),
                          _buildStatBadge('Win %', '${team.winPercentage.toStringAsFixed(0)}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Team Poster Showcase Banner
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: ThemeHelper.of(context).isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [Colors.white, const Color(0xFFFFF7ED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppTheme.primaryOrange.withOpacity(0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16.r),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamPosterScreen(team: team),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        child: Row(
                          children: [
                            Container(
                              width: 46.w,
                              height: 46.w,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primaryOrange, Color(0xFFFFB703)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withOpacity(0.35),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.style, color: Colors.white, size: 24),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Team Squad Poster',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryOrange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          'NEW',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    'Create & share poster with all player photos & roles',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: ThemeHelper.of(context).textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppTheme.primaryOrange,
                              size: 14.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Players Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Team Members (${team.players.length})',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeamPosterScreen(team: team),
                                ),
                              );
                            },
                            icon: Icon(Icons.photo_library_outlined, size: 16.sp, color: AppTheme.primaryOrange),
                            label: Text(
                              'Poster',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          if (canManage) ...[
                            SizedBox(width: 4.w),
                            TextButton.icon(
                              onPressed: _showAddPlayerDialog,
                              icon: Icon(Icons.add, size: 18.sp),
                              label: const Text('Add Manual'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Players List
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final player = team.players[index];
                      return _buildPlayerCard(team, player);
                    },
                    childCount: team.players.length,
                  ),
                ),
              ),

              // QR Code Section with Embedded App Logo & Share Capability
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  child: Column(
                    children: [
                      Screenshot(
                        controller: _qrScreenshotController,
                        child: Container(
                          padding: EdgeInsets.all(22.w),
                          decoration: BoxDecoration(
                            color: ThemeHelper.of(context).cardBg,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: ThemeHelper.of(context).isDark
                                  ? Colors.white12
                                  : Colors.black.withOpacity(0.06),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeHelper.of(context).isDark
                                    ? Colors.transparent
                                    : Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TeamLogoWidget(
                                    teamName: team.name,
                                    logoUrl: team.logoUrl,
                                    size: 28.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      team.name,
                                      style: TextStyle(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                'Scan to join squad on ScorePartner',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ThemeHelper.of(context).textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // QR Code with Logo in Center (Seamlessly Mixed)
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B35).withOpacity(0.18),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    QrImageView(
                                      data: team.spTId,
                                      version: QrVersions.auto,
                                      size: 200.0.sp,
                                      padding: EdgeInsets.zero,
                                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.circle,
                                        color: Color(0xFFFF6B35),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.circle,
                                        color: Color(0xFFFF6B35),
                                      ),
                                      embeddedImage: const AssetImage('assets/images/app_icon_foreground.png'),
                                      embeddedImageStyle: QrEmbeddedImageStyle(
                                        size: Size(54.sp, 54.sp),
                                      ),
                                    ),
                                    // Clean seamlessly mixed center logo
                                    IgnorePointer(
                                      child: Container(
                                        width: 52.sp,
                                        height: 52.sp,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(4.w),
                                        child: Image.asset(
                                          'assets/images/app_icon_foreground.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // Team ID Tag with Copy Feature
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: team.spTId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Team ID copied to clipboard! 📋'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: AppTheme.primaryOrange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        team.spTId,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          fontSize: 17.sp,
                                          color: AppTheme.primaryOrange,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 16.sp,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Action Buttons: Copy ID & Share Team QR
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: team.spTId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Team ID copied! 📋'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: Icon(Icons.copy_rounded, size: 16.sp),
                              label: const Text('Copy ID'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ThemeHelper.of(context).textPrimary,
                                side: BorderSide(
                                  color: ThemeHelper.of(context).isDark ? Colors.white24 : Colors.black12,
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isSharingQr ? null : () => _shareTeamQr(team),
                              icon: _isSharingQr
                                  ? SizedBox(
                                      width: 16.sp,
                                      height: 16.sp,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.share_rounded, size: 18.sp),
                              label: Text(
                                _isSharingQr ? 'Sharing...' : 'Share Team QR',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: 40.h)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPlayerProfile(String playerId) async {
    if (playerId.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      ),
    );
    try {
      final user = await _dataService.findUserByAnyId(playerId);
      if (mounted) Navigator.pop(context);
      if (user != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerProfileScreen(player: user)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player profile not found or unregistered')),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildRoleBadge(String label, String name, Color color, {String? playerId}) {
    return GestureDetector(
      onTap: playerId != null && playerId.isNotEmpty ? () => _openPlayerProfile(playerId) : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playerId != null && playerId.isNotEmpty) ...[
              PlayerAvatarWidget(
                playerId: playerId,
                playerName: name,
                size: 26.sp,
                enableProfileView: false,
              ),
              SizedBox(width: 8.w),
            ] else ...[
              Icon(
                label == 'Captain' ? Icons.star : Icons.star_half,
                color: color,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10.sp, color: color, fontWeight: FontWeight.bold),
                ),
                Text(
                  name,
                  style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: ThemeHelper.of(context).dividerColor!,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
          Text(label, style: TextStyle(color: ThemeHelper.of(context).textSecondary, fontSize: 10.sp)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(TeamModel team, TeamPlayer player) {
    final canManage = _canManage(team);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: ThemeHelper.of(context).dividerColor!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _openPlayerProfile(player.userId),
        onLongPress: canManage ? () => _showPlayerOptions(team, player) : null,
        child: ListTile(
          leading: PlayerAvatarWidget(
            profileImageUrl: player.profileImageUrl,
            playerId: player.userId,
            playerName: player.name,
            size: 44.sp,
            enableProfileView: true,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(player.name, style: TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
              if (player.isCaptain) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text('C', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.amber[800])),
                ),
              ],
              if (player.isViceCaptain) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text('VC', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                ),
              ],
            ],
          ),
          subtitle: Text('${player.role} • ${player.battingStyle}'),
          trailing: canManage
              ? IconButton(
                  icon: Icon(Icons.more_vert, color: ThemeHelper.of(context).textSecondary, size: 20.sp),
                  onPressed: () => _showPlayerOptions(team, player),
                )
              : null,
        ),
      ),
    );
  }
}
