import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/team_logo_widget.dart';


/// Screen to create a new team
class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _playerNameController = TextEditingController();
  final _spPIdController = TextEditingController();
  final _mobileController = TextEditingController();

  String _selectedRole = 'Batsman';
  List<TeamPlayer> _players = [];
  bool _isLoading = false;
  bool _isLookingUp = false;
  String? _lookedUpUserId; // Stores the Firebase UID from SPP ID lookup

  // Logo state
  Uint8List? _logoBytes;

  final List<String> _roles = ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'];

  @override
  void initState() {
    super.initState();
    // Add captain (current user) automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        setState(() {
          _players.add(TeamPlayer(
            userId: user.uid,
            spPId: user.spPId,
            name: user.name,
            role: user.role.isNotEmpty ? user.role : 'All-rounder',
            battingStyle: user.battingStyle,
            bowlingStyle: user.bowlingStyle,
            isCaptain: true,
            isRegistered: true,
          ));
        });
      }
    });
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _playerNameController.dispose();
    _spPIdController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  /// Show logo picker options
  void _showLogoPicker() {
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Team Logo',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20.h),
              _buildPickerOption(
                icon: Icons.photo_library,
                label: 'Upload from Gallery',
                subtitle: 'Choose a custom image',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              SizedBox(height: 12.h),
              _buildPickerOption(
                icon: Icons.auto_awesome,
                label: 'Generate from Name',
                subtitle: 'Auto-create initials logo',
                onTap: () {
                  Navigator.pop(context);
                  // Clear custom logo to use auto-generated initials
                  setState(() => _logoBytes = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Using auto-generated logo from team name'),
                      backgroundColor: Color(0xFFFF6B35),
                    ),
                  );
                },
              ),
              if (_logoBytes != null) ...[
                SizedBox(height: 12.h),
                _buildPickerOption(
                  icon: Icons.delete_outline,
                  label: 'Remove Logo',
                  subtitle: 'Use default initials',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _logoBytes = null);
                  },
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: (color ?? const Color(0xFFFF6B35)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color ?? const Color(0xFFFF6B35)),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12.sp)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _logoBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _lookupPlayer() async {
    final sppId = _spPIdController.text.trim().toUpperCase();
    if (sppId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an SPP ID to search')),
      );
      return;
    }

    setState(() => _isLookingUp = true);

    try {
      final user = await FirebaseDataService.instance.getUserBySppId(sppId);
      
      if (user != null) {
        setState(() {
          _playerNameController.text = user.name;
          _lookedUpUserId = user.uid; // Store the actual Firebase UID
          _selectedRole = _roles.firstWhere(
            (r) => r.toLowerCase() == user.role.toLowerCase(),
            orElse: () => 'All-rounder',
          );
          _spPIdController.text = user.spPId;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Player found: ${user.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ No player found with SPP ID: $sppId'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLookingUp = false);
    }
  }

  void _addPlayer() {
    final name = _playerNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter player name')),
      );
      return;
    }

    final spPId = _spPIdController.text.trim().toUpperCase();
    final mobile = _mobileController.text.trim();

    setState(() {
      _players.add(TeamPlayer(
        userId: _lookedUpUserId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}',
        spPId: spPId,
        name: name,
        mobileNumber: mobile,
        role: _selectedRole.toLowerCase(),
        isCaptain: false,
        isRegistered: _lookedUpUserId != null,
      ));
      _playerNameController.clear();
      _spPIdController.clear();
      _mobileController.clear();
      _selectedRole = 'Batsman';
      _lookedUpUserId = null; // Reset after adding
    });
  }

  void _removePlayer(int index) {
    if (_players[index].isCaptain) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove captain!')),
      );
      return;
    }
    setState(() => _players.removeAt(index));
  }

  void _createTeam() async {
    if (!_formKey.currentState!.validate()) return;

    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 players to create a team')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // Generate purely numeric SPT ID
      final numericId = DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13);
      final spTId = 'SPT$numericId';

      final team = TeamModel(
        id: '',
        spTId: spTId,
        name: _teamNameController.text.trim(),
        captainId: user.uid,
        captainName: user.name,
        players: _players,
        matchesPlayed: 0,
        matchesWon: 0,
        matchesLost: 0,
        createdAt: DateTime.now(),
      );

      final createdTeam = await FirebaseDataService.instance.createTeam(team, user.uid);

      if (createdTeam == null) {
        throw Exception('Failed to create team');
      }

      // Upload logo if selected
      if (_logoBytes != null) {
        await FirebaseDataService.instance.updateTeamLogo(createdTeam.id, _logoBytes!);
      }

      debugPrint('✅ Team created in Firebase: ${createdTeam.spTId}');

      if (!mounted) return;

      _showTeamQR(createdTeam);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating team: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showTeamQR(TeamModel team) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Container(
          width: 320.w,
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Team Created! 🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              TeamLogoWidget(
                teamName: team.name,
                logoUrl: team.logoUrl,
                size: 80.sp,
              ),
              SizedBox(height: 16.h),
              Text('Team ID: ${team.spTId}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: Color(0xFFFF6B35))),
              SizedBox(height: 20.h),
              SizedBox(
                width: 200.w,
                height: 200.h,
                child: QrImageView(
                  data: team.spTId,
                  version: QrVersions.auto,
                  size: 200.0.sp,
                  foregroundColor: const Color(0xFFFF6B35),
                ),
              ),
              SizedBox(height: 10.h),
              const Text('Scan to Join Team', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, team); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Team'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Logo Section
              _buildSectionTitle('Team Logo'),
              SizedBox(height: 12.h),
              Center(
                child: Column(
                  children: [
                    TeamLogoWidget(
                      teamName: _teamNameController.text.isEmpty
                          ? 'New Team'
                          : _teamNameController.text,
                      imageBytes: _logoBytes,
                      size: 100.sp,
                      onTap: _showLogoPicker,
                    ),
                    SizedBox(height: 10.h),
                    TextButton.icon(
                      onPressed: _showLogoPicker,
                      icon: Icon(Icons.edit, size: 16.sp),
                      label: Text(
                        _logoBytes != null ? 'Change Logo' : 'Add Logo',
                        style: TextStyle(color: Color(0xFFFF6B35)),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Team Name
              _buildSectionTitle('Team Details'),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _teamNameController,
                onChanged: (_) => setState(() {}), // Rebuild to update logo initials
                decoration: InputDecoration(
                  labelText: 'Team Name',
                  hintText: 'Enter your team name',
                  prefixIcon: Icon(Icons.sports_cricket, color: Color(0xFFFF6B35)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2.w),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Enter team name' : null,
              ),

              SizedBox(height: 24.h),

              // Add Players
              _buildSectionTitle('Add Players (${_players.length})'),
              SizedBox(height: 12.h),

              // Add Player Form
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _spPIdController,
                            decoration: InputDecoration(
                              labelText: 'SPP ID (Optional)',
                              hintText: 'SPP12345678',
                              prefixIcon: Icon(Icons.badge),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          onPressed: _isLookingUp ? null : _lookupPlayer,
                          icon: _isLookingUp 
                            ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.search, color: Color(0xFFFF6B35)),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange[50],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _playerNameController,
                      decoration: InputDecoration(
                        labelText: 'Player Name',
                        hintText: 'Enter player name',
                        prefixIcon: Icon(Icons.person_add),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number (Optional)',
                        hintText: 'For non-app players',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            items: _roles.map((role) {
                              return DropdownMenuItem(value: role, child: Text(role));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedRole = value!),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        ElevatedButton.icon(
                          onPressed: _addPlayer,
                          icon: Icon(Icons.add),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Players List
              if (_players.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _players.length,
                    separatorBuilder: (_, __) => Divider(height: 1.h, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final player = _players[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: player.isCaptain
                              ? const Color(0xFFFF6B35)
                              : Colors.grey[200],
                          child: Text(
                            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: player.isCaptain ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(player.name, style: TextStyle(fontWeight: FontWeight.w600)),
                            if (player.isCaptain) ...[
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Text(
                                  'Captain',
                                  style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(player.role.isEmpty ? 'Player' : player.role),
                        trailing: player.isCaptain
                            ? null
                            : IconButton(
                                icon: Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => _removePlayer(index),
                              ),
                      );
                    },
                  ),
                ),
              ],

              SizedBox(height: 24.h),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Create Team',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
