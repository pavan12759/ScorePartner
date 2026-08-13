import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/tournament/select_team_bottom_sheet.dart'; // Added

/// Screen shown when a player opens a tournament invite link
/// Validates the token, displays tournament info, and allows team selection for registration
class TournamentInvitationScreen extends StatefulWidget {
  final String tournamentId;
  final String inviteToken;

  const TournamentInvitationScreen({
    super.key,
    required this.tournamentId,
    required this.inviteToken,
  });

  @override
  State<TournamentInvitationScreen> createState() => _TournamentInvitationScreenState();
}

class _TournamentInvitationScreenState extends State<TournamentInvitationScreen> {
  final FirebaseDataService _dataService = FirebaseDataService.instance;

  bool _isLoading = true;
  TournamentModel? _tournament;
  String? _errorMessage;

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
      final tournament = await _dataService.validateTournamentInviteToken(widget.tournamentId, widget.inviteToken);

      if (tournament == null) {
        setState(() {
          _errorMessage = 'This invite link is invalid, expired, or has been revoked.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _tournament = tournament;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showSelectTeamBottomSheet() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to register a team'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Since we don't have the widget yet, we will just show a simple bottom sheet 
    // which we will replace in the next task or implement directly here if needed.
    // However, the instructions say to create `select_team_bottom_sheet.dart`.
    // I will use a placeholder here and update it once created.
    
    // For now, I'll import and use it (it will be created in the next task)
    // To prevent build errors, I'll implement a temporary dummy one or just wait.
    // Actually, I can just implement a basic bottom sheet here directly to avoid breaking.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) => SelectTeamBottomSheet(tournament: _tournament!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.user != null;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepBlack : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tournament Invitation'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _tournament != null
                  ? _buildTournamentInfo(isLoggedIn)
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

  Widget _buildTournamentInfo(bool isLoggedIn) {
    final t = _tournament!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          // Tournament Card
          Container(
            width: double.infinity,
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
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Banner
                if (t.bannerUrl != null && t.bannerUrl!.isNotEmpty)
                  Image.network(
                    t.bannerUrl!,
                    height: 150.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150.h,
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      child: const Icon(Icons.emoji_events, size: 60, color: AppTheme.primaryOrange),
                    ),
                  )
                else
                  Container(
                    height: 150.h,
                    width: double.infinity,
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    child: Center(
                      child: Icon(Icons.emoji_events, size: 60.sp, color: AppTheme.primaryOrange),
                    ),
                  ),
                
                Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, size: 16.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              t.location,
                              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 20.h),
                      Divider(color: Colors.grey[300]),
                      SizedBox(height: 16.h),

                      // Info rows
                      _buildInfoRow(Icons.sports_cricket, 'Format', '${t.format.toUpperCase()} (${t.overs} Overs)'),
                      SizedBox(height: 12.h),
                      _buildInfoRow(Icons.groups, 'Teams', '${t.registeredTeamIds.length}/${t.maxTeams}'),
                      SizedBox(height: 12.h),
                      _buildInfoRow(Icons.payments, 'Entry Fee', '₹${t.entryFee.toStringAsFixed(0)}'),
                      SizedBox(height: 12.h),
                      _buildInfoRow(Icons.emoji_events, 'Prize Pool', '₹${t.prizePool.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !isLoggedIn
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please login first to register a team'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  : t.registeredTeamIds.length >= t.maxTeams
                      ? null
                      : _showSelectTeamBottomSheet,
              icon: Icon(Icons.group_add, size: 22.sp),
              label: Text(
                t.registeredTeamIds.length >= t.maxTeams
                    ? 'Tournament Full'
                    : isLoggedIn
                        ? 'Select Team to Register'
                        : 'Login to Register',
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
              'You need to be logged in to register a team',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
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
}

