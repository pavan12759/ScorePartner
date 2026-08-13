import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/tournament_join_request_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';

class TournamentJoinRequestsScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentJoinRequestsScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentJoinRequestsScreen> createState() => _TournamentJoinRequestsScreenState();
}

class _TournamentJoinRequestsScreenState extends State<TournamentJoinRequestsScreen> {
  bool _isLoading = true;
  List<TournamentJoinRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    
    final requests = await FirebaseDataService.instance.getTournamentJoinRequests(widget.tournament.id);
    
    if (mounted) {
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status, {String rejectionReason = ''}) async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
    );

    final success = await FirebaseDataService.instance.updateTournamentJoinRequestStatus(
      requestId,
      status,
      userId,
      rejectionReason: rejectionReason,
    );

    if (mounted) {
      Navigator.pop(context); // close loading
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == TournamentJoinRequestStatus.accepted.name ? 'Team Accepted' : 'Team Rejected'),
            backgroundColor: status == TournamentJoinRequestStatus.accepted.name ? Colors.green : Colors.red,
          ),
        );
        _loadRequests(); // reload
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(TournamentJoinRequestModel request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject ${request.teamName}?'),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateRequestStatus(
                request.id, 
                TournamentJoinRequestStatus.rejected.name,
                rejectionReason: reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join Requests', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              widget.tournament.name,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : _requests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  color: AppTheme.primaryOrange,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(_requests[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'No Requests Yet',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          SizedBox(height: 8.h),
          Text(
            'Share the invite link to get teams to join.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(TournamentJoinRequestModel request) {
    final isPending = request.status == TournamentJoinRequestStatus.pending;
    
    Color statusColor;
    switch (request.status) {
      case TournamentJoinRequestStatus.accepted:
        statusColor = Colors.green;
        break;
      case TournamentJoinRequestStatus.rejected:
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                  backgroundImage: request.teamLogoUrl.isNotEmpty 
                      ? NetworkImage(request.teamLogoUrl) 
                      : null,
                  child: request.teamLogoUrl.isEmpty
                      ? Text(
                          request.teamName.isNotEmpty ? request.teamName[0].toUpperCase() : '?',
                          style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 20.sp),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.teamName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Requested by: ${request.requestedByUserName} (${request.requestedByUserRole})',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                      Text(
                        timeago.format(request.requestedAt),
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    request.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            if (isPending) ...[
              SizedBox(height: 16.h),
              const Divider(height: 1),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(request),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateRequestStatus(request.id, TournamentJoinRequestStatus.accepted.name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
            
            if (request.status == TournamentJoinRequestStatus.rejected && request.rejectionReason.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 16.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Reason: ${request.rejectionReason}',
                        style: TextStyle(color: Colors.red[700], fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
