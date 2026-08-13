import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/tournament_join_request_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';

class SelectTeamBottomSheet extends StatefulWidget {
  final TournamentModel tournament;

  const SelectTeamBottomSheet({
    super.key,
    required this.tournament,
  });

  @override
  State<SelectTeamBottomSheet> createState() => _SelectTeamBottomSheetState();
}

class _SelectTeamBottomSheetState extends State<SelectTeamBottomSheet> {
  bool _isLoading = true;
  List<TeamModel> _userTeams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserTeams();
  }

  Future<void> _loadUserTeams() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all teams for this user where they have verified status (Owner, Admin, Captain, Vice-Captain, Player)
      // Since a user is a member if they are in the players list, we first get all their teams.
      final teams = await FirebaseDataService.instance.getUserTeams(currentUser.uid);
      
      if (mounted) {
        setState(() {
          _userTeams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load teams';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestToJoin(TeamModel team) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    // Find user role in the team
    final player = team.players.firstWhere(
      (p) => p.userId == currentUser.uid,
      orElse: () => TeamPlayer(userId: currentUser.uid, name: currentUser.name, role: 'player'),
    );

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
    );

    try {
      final request = TournamentJoinRequestModel(
        id: '',
        tournamentId: widget.tournament.id,
        tournamentName: widget.tournament.name,
        teamId: team.id,
        teamName: team.name,
        teamLogoUrl: team.logoUrl,
        requestedByUserId: currentUser.uid,
        requestedByUserName: currentUser.name,
        requestedByUserRole: player.role,
        requestedAt: DateTime.now(),
      );

      final error = await FirebaseDataService.instance.createTournamentJoinRequest(request);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close bottom sheet
        
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration request submitted! Tournament organizer will review it.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Select Team',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            'Choose a team to register for ${widget.tournament.name}',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      )
                    : _userTeams.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off, size: 64.sp, color: Colors.grey[400]),
                                SizedBox(height: 16.h),
                                Text(
                                  'No Teams Found',
                                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'You need to be part of a team to register for this tournament.',
                                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _userTeams.length,
                            itemBuilder: (context, index) {
                              final team = _userTeams[index];
                              final isAlreadyRegistered = widget.tournament.registeredTeamIds.contains(team.id);
                              
                              return Card(
                                margin: EdgeInsets.only(bottom: 12.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                elevation: 0,
                                color: isAlreadyRegistered ? Colors.grey[200] : Colors.white,
                                child: ListTile(
                                  contentPadding: EdgeInsets.all(12.w),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                                    backgroundImage: team.logoUrl.isNotEmpty 
                                        ? NetworkImage(team.logoUrl) 
                                        : null,
                                    child: team.logoUrl.isEmpty
                                        ? Text(
                                            team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                                            style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    team.name,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text('${team.players.length} Players'),
                                  trailing: isAlreadyRegistered
                                      ? Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            'Registered',
                                            style: TextStyle(fontSize: 10.sp, color: Colors.green, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _requestToJoin(team),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryOrange,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                          ),
                                          child: const Text('Select'),
                                        ),
                                ),
                              );
                            },
                          ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
