import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

class CommentaryTab extends StatelessWidget {
  final MatchModel match;
  
  const CommentaryTab({super.key, required this.match});
  
  @override
  Widget build(BuildContext context) {
    if (match.ballByBall.isEmpty) {
      return const Center(child: Text("No commentary available", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
    }
    
    // Sort balls by latest first
    // Note: In real app better to sort by timestamp or proper ID
    final sortedBalls = List<BallEvent>.from(match.ballByBall)..sort((a, b) {
      // Assuming ballNumber/overNumber increases over time
      if (a.overNumber != b.overNumber) return b.overNumber.compareTo(a.overNumber);
      return b.ballNumber.compareTo(a.ballNumber);
    });

    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: sortedBalls.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final event = sortedBalls[index];
        bool isWicket = event.wicket != null;
        bool isBoundary = event.runs == 4 || event.runs == 6;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Over Number Circle
            Container(
              width: 50.w,
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Column(
                children: [
                   Text(
                     '${event.overNumber}.${event.ballNumber}', 
                     style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                   ),
                ],
              ),
            ),
            
            // Event Bubble
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isWicket)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4.r)),
                              child: Text('WICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.sp, letterSpacing: 1)),
                            )
                          else if (isBoundary)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: event.runs == 6 ? AppTheme.primaryOrange : Colors.blueAccent, 
                                borderRadius: BorderRadius.circular(4.r)
                              ),
                              child: Text(
                                event.runs == 4 ? 'FOUR' : 'SIX', 
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.sp, letterSpacing: 1)
                              ),
                            )
                          else
                            Text(
                              '${event.runs} RUN(S)', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.sp, letterSpacing: 0.5)
                            ),
                            
                          const Spacer(),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        event.commentary.isNotEmpty ? event.commentary : _generateCommentary(event),
                        style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  String _generateCommentary(BallEvent event) {
    // Fallback if no specific commentary
    if (event.wicket != null) return "OUT! That's a huge wicket.";
    if (event.runs == 6) return "HUGE! That's gone all the way for six!";
    if (event.runs == 4) return "Great shot found the gap for four.";
    if (event.runs == 0) return "Dot ball, good bowling.";
    return "Takes a single.";
  }
}
