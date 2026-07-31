import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/join_request_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/team_logo_widget.dart';

/// Screen shown when a player opens a team invite link
/// Validates the token, displays team info, and allows requesting to join
class TeamInvitationScreen extends StatefulWidget {
  final String teamId;
  final String inviteToken;

  const TeamInvitationScreen({
    super.key,
    required this.teamId,
    required this.inviteToken,
  });

  @override
  State<TeamInvitationScreen> createState() => _TeamInvitationScreenState();
}

class _TeamInvitationScreenState extends State<TeamInvitationScreen> {
  final FirebaseDataService _dataService = FirebaseDataService.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  TeamModel? _team;
  String? _errorMessage;
  String? _successMessage;
  bool _alreadyMember = false;
  bool _alreadyRequested = false;

  @override
  void initState() {
    super.initState();
    _validateAndLoad();
  }

  Future<void> _validateAndLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate the invite token
      final team = await _dataService.validateInviteToken(widget.teamId, widget.inviteToken);

      if (team == null) {
        setState(() {
          _errorMessage = 'This invite link is invalid, expired, or has been revoked.';
          _isLoading = false;
        });
        return;
      }

      // Check if current user is logged in
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      if (currentUser != null) {
        // Check if already a member
        final isMember = team.players.any(
          (p) => p.userId == currentUser.uid ||
                 (currentUser.spPId.isNotEmpty && p.spPId == currentUser.spPId),
        );

        if (isMember) {
          setState(() {
            _alreadyMember = true;
          });
        } else {
          // Check for existing pending request
          final existingRequest = await _dataService.getPlayerPendingRequestForTeam(
            currentUser.uid,
            team.id,
          );
          if (existingRequest != null) {
            setState(() {
              _alreadyRequested = true;
            });
          }
        }
      }

      setState(() {
        _team = team;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestToJoin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to join the team'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = JoinRequestModel(
        id: '',
        teamId: _team!.id,
        teamName: _team!.name,
        playerId: currentUser.uid,
        playerName: currentUser.name,
        playerPhotoUrl: currentUser.profileImageUrl,
        playerSpPId: currentUser.spPId,
        playerRole: currentUser.role,
        battingStyle: currentUser.battingStyle,
        bowlingStyle: currentUser.bowlingStyle,
        playerCity: currentUser.location,
        requestedAt: DateTime.now(),
      );

      final error = await _dataService.createJoinRequest(request);

      if (error == null) {
        setState(() {
          _successMessage = 'Your request has been submitted! The team admin will review it.';
          _alreadyRequested = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.user != null;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepBlack : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Team Invitation'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _team != null
                  ? _buildTeamInfo(isLoggedIn)
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.link_off, size: 64.sp, color: Colors.red[400]),
            ),
            SizedBox(height: 24.h),
            Text(
              'Invalid Invite Link',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInfo(bool isLoggedIn) {
    final team = _team!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          // Team Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Team Logo
                TeamLogoWidget(
                  teamName: team.name,
                  logoUrl: team.logoUrl,
                  size: 90.sp,
                ),
                SizedBox(height: 16.h),

                // Team Name
                Text(
                  team.name,
                  style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),

                // Team ID
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    team.spTId,
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ),

                SizedBox(height: 20.h),
                Divider(color: Colors.grey[300]),
                SizedBox(height: 16.h),

                // Info rows
                _buildInfoRow(Icons.person, 'Captain', team.captainName),
                SizedBox(height: 12.h),
                if (team.viceCaptainName.isNotEmpty) ...[
                  _buildInfoRow(Icons.person_outline, 'Vice-Captain', team.viceCaptainName),
                  SizedBox(height: 12.h),
                ],
                _buildInfoRow(Icons.group, 'Players', '${team.totalPlayers} members'),
                SizedBox(height: 12.h),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Played',
                        '${team.matchesPlayed}',
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildStatCard(
                        'Won',
                        '${team.matchesWon}',
                        Colors.green,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildStatCard(
                        'Lost',
                        '${team.matchesLost}',
                        Colors.red,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildStatCard(
                        'Win %',
                        '${team.winPercentage.toStringAsFixed(0)}%',
                        AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Success message
          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(fontSize: 14.sp, color: Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),

          // Already a member message
          if (_alreadyMember)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue, size: 24.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'You are already a member of this team!',
                      style: TextStyle(fontSize: 14.sp, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),

          // Already requested message
          if (_alreadyRequested && _successMessage == null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, color: Colors.orange, size: 24.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Your request is pending. The admin will review it soon.',
                      style: TextStyle(fontSize: 14.sp, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

          // CTA Button
          if (!_alreadyMember && !_alreadyRequested && _successMessage == null) ...[
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !isLoggedIn
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please login first to join the team'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    : _isSubmitting
                        ? null
                        : _requestToJoin,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.group_add, size: 22.sp),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : isLoggedIn
                          ? 'Request to Join Team'
                          : 'Login to Join Team',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  elevation: 2,
                ),
              ),
            ),

            if (!isLoggedIn) ...[
              SizedBox(height: 8.h),
              Text(
                'You need to be logged in to request joining this team',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: AppTheme.primaryOrange),
        SizedBox(width: 10.w),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
