import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/join_request_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../profile/player_profile_screen.dart';

/// Admin screen to review, accept, and reject join requests for a team
class JoinRequestsScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const JoinRequestsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  final FirebaseDataService _dataService = FirebaseDataService.instance;

  Future<void> _acceptRequest(JoinRequestModel request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request'),
        content: Text('Add ${request.playerName} to ${widget.teamName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reviewerUid = authProvider.user?.uid ?? '';

    final success = await _dataService.acceptJoinRequest(request.id, reviewerUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✅ ${request.playerName} has been added to the team!'
              : '❌ Failed to accept request'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(JoinRequestModel request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text('Decline ${request.playerName}\'s request to join?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reviewerUid = authProvider.user?.uid ?? '';

    final success = await _dataService.rejectJoinRequest(request.id, reviewerUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Request from ${request.playerName} declined'
              : '❌ Failed to reject request'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  Future<void> _viewProfile(JoinRequestModel request) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      ),
    );

    try {
      final user = await _dataService.getUserById(request.playerId);
      if (mounted) Navigator.pop(context); // dismiss loading

      if (user != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerProfileScreen(player: user),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player profile not found')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepBlack : Colors.grey[50],
      appBar: AppBar(
        title: Text('Join Requests'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<JoinRequestModel>>(
        stream: _dataService.getJoinRequestsForTeam(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48.sp, color: Colors.red[300]),
                  SizedBox(height: 12.h),
                  Text(
                    'Error loading requests',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Please check your connection',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inbox_outlined, size: 56.sp, color: AppTheme.primaryOrange),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No Pending Requests',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Share your invite link to get join requests',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index], isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(JoinRequestModel request, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player info header
            Row(
              children: [
                // Player avatar
                CircleAvatar(
                  radius: 28.r,
                  backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                  backgroundImage: request.playerPhotoUrl.isNotEmpty
                      ? NetworkImage(request.playerPhotoUrl)
                      : null,
                  child: request.playerPhotoUrl.isEmpty
                      ? Text(
                          request.playerName.isNotEmpty ? request.playerName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.playerName,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
                      if (request.playerSpPId.isNotEmpty)
                        Text(
                          request.playerSpPId,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (request.playerCity.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12.sp, color: Colors.grey[500]),
                            SizedBox(width: 2.w),
                            Text(
                              request.playerCity,
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Player details chips
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                if (request.playerRole.isNotEmpty)
                  _buildChip(Icons.sports_cricket, request.playerRole, Colors.blue),
                if (request.battingStyle.isNotEmpty)
                  _buildChip(Icons.swipe_right, request.battingStyle, Colors.green),
                if (request.bowlingStyle.isNotEmpty)
                  _buildChip(Icons.sports, request.bowlingStyle, Colors.purple),
              ],
            ),

            SizedBox(height: 12.h),

            // Fetch and show player stats
            FutureBuilder<UserModel?>(
              future: _dataService.getUserById(request.playerId),
              builder: (context, userSnap) {
                if (!userSnap.hasData || userSnap.data == null) {
                  return const SizedBox.shrink();
                }

                final user = userSnap.data!;
                final stats = user.tennisBallStats;

                return Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Matches', '${stats.matches}'),
                      _buildMiniStat('Runs', '${stats.runs}'),
                      _buildMiniStat('Wickets', '${stats.wickets}'),
                      _buildMiniStat('SR', stats.strikeRate.toStringAsFixed(1)),
                      _buildMiniStat('Eco', stats.economy.toStringAsFixed(1)),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 14.h),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(request),
                    icon: Icon(Icons.close, size: 18.sp, color: Colors.red),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewProfile(request),
                    icon: Icon(Icons.person, size: 18.sp),
                    label: const Text('Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(request),
                    icon: Icon(Icons.check, size: 18.sp),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
