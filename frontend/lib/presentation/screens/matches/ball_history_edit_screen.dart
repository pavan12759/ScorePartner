import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/providers/scoring_provider.dart';
import 'package:scorepatner/presentation/widgets/dialogs/edit_ball_dialog.dart';
import 'package:intl/intl.dart';

class BallHistoryEditScreen extends StatelessWidget {
  final String matchId;

  const BallHistoryEditScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ball History'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            tooltip: 'Sync Scores with History',
            onPressed: () => _showSyncDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<MatchModel?>(
        stream: FirebaseDataService.instance.streamMatch(matchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Match not found'));
          }

          final match = snapshot.data!;
          final balls = match.ballByBall.reversed.toList();

          if (balls.isEmpty) {
            return Center(
              child: Text('No balls recorded yet', 
                style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(12.w),
            itemCount: balls.length,
            itemBuilder: (context, index) {
              final ball = balls[index];
              final originalIndex = match.ballByBall.length - 1 - index;
              
              // Only allow editing actual ball events, not system events (ballNumber 0)
              bool isSystemEvent = ball.ballNumber == 0 && ball.overNumber == 0;

              return Card(
                elevation: 0,
                margin: EdgeInsets.only(bottom: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      // Ball identity (Over.Ball)
                      Container(
                        width: 45.w,
                        height: 45.h,
                        decoration: BoxDecoration(
                          color: isSystemEvent ? Colors.blue[50] : AppTheme.primaryOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            isSystemEvent ? 'SYS' : '${ball.overNumber}.${ball.ballNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: isSystemEvent ? Colors.blue[800] : AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      
                      // Result and Commentary
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  ball.displayString,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                if (ball.wicket != null) ...[
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'WICKET',
                                      style: TextStyle(color: Colors.red[700], fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              ball.commentary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13.sp),
                            ),
                            Text(
                              DateFormat('HH:mm:ss').format(ball.timestamp),
                              style: TextStyle(color: Colors.grey[400], fontSize: 11.sp),
                            ),
                          ],
                        ),
                      ),
                      
                      // Edit Button
                      if (!isSystemEvent)
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => EditBallDialog(
                                match: match,
                                ballIndex: originalIndex,
                                ball: ball,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Ball History'),
        content: const Text('This will recalculate the entire match score and player stats from the current ball history. User this if you notice any inconsistency.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            onPressed: () {
              // Get match from provider or stream and sync
              // For simplicity, we assume we need to fetch it first or pass it
              // We'll use the provider method
              Navigator.pop(context);
              _performSync(context);
            },
            child: const Text('Sync Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync(BuildContext context) async {
    final provider = Provider.of<ScoringProvider>(context, listen: false);
    final match = await FirebaseDataService.instance.getMatchById(matchId);
    if (match != null) {
      provider.syncBallHistory(match);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing match data...'), duration: Duration(seconds: 1)),
      );
    }
  }
}
