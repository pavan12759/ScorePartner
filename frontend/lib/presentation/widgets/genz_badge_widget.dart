import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/achievement_model.dart';

class GenZBadgeWidget extends StatelessWidget {
  final PlayerAchievement achievement;

  const GenZBadgeWidget({Key? key, required this.achievement}) : super(key: key);

  List<Color> _getGradientForBadge(String type) {
    switch (type) {
      // Batsman Badges
      case 'badge_first_blood':
        return [Colors.blue.shade300, Colors.blue.shade700];
      case 'badge_run_machine':
        return [Colors.orange.shade400, Colors.red.shade600];
      case 'badge_certified_batsman':
        return [Colors.cyan.shade300, Colors.blueAccent.shade700];
      case 'badge_local_legend':
        return [Colors.purple.shade400, Colors.deepPurple.shade900];
      case 'badge_goat_batter':
        return [Colors.amber.shade400, Colors.orange.shade800];
      case 'badge_six_hunter':
        return [Colors.redAccent, Colors.deepOrange];
      case 'badge_boundary_boss':
        return [Colors.green.shade400, Colors.teal.shade700];
      case 'badge_quick_fire':
        return [Colors.yellow.shade600, Colors.deepOrangeAccent];
      case 'badge_ice_cold':
        return [Colors.lightBlueAccent, Colors.blue.shade800];

      // Bowler Badges
      case 'badge_breakthrough':
        return [Colors.indigo.shade300, Colors.indigo.shade800];
      case 'badge_wicket_dealer':
        return [Colors.pinkAccent, Colors.purpleAccent];
      case 'badge_bowling_brain':
        return [Colors.tealAccent.shade400, Colors.cyan.shade800];
      case 'badge_nightmare':
        return [Colors.deepPurple, Colors.black87];
      case 'badge_death_bringer':
        return [Colors.red.shade900, Colors.black87];
      case 'badge_economy_freak':
        return [Colors.cyanAccent, Colors.lightBlue.shade700];

      // Flex Badges
      case 'badge_man_of_moments':
        return [Colors.amberAccent, Colors.orange.shade600];
      case 'badge_veteran':
        return [Colors.blueGrey.shade400, Colors.blueGrey.shade800];

      // Standard Match Badges
      case 'century':
      case 'half_century':
      case 'fifty':
        return [Colors.blue.shade300, Colors.blueAccent.shade700];
      case 'five_wickets':
      case 'wicket':
        return [Colors.deepOrange.shade300, Colors.red.shade700];
      case 'man_of_match':
      case 'mvp':
        return [Colors.amber.shade300, Colors.orange.shade700];
      case 'tournament_win':
      case 'win':
        return [Colors.yellow.shade400, Colors.amber.shade800];
      case 'top_scorer':
      case 'top_wicket_taker':
        return [Colors.purple.shade300, Colors.deepPurple.shade700];

      default:
        return [Colors.grey.shade400, Colors.grey.shade700];
    }
  }

  void _showBadgeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getGradientForBadge(achievement.type),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: _getGradientForBadge(achievement.type).last.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  achievement.badgeIcon,
                  style: TextStyle(fontSize: 64.sp),
                ),
                SizedBox(height: 16.h),
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('EPIC', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeDetails(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: LinearGradient(
            colors: _getGradientForBadge(achievement.type),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _getGradientForBadge(achievement.type).last.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.badgeIcon,
              style: TextStyle(fontSize: 18.sp),
            ),
            SizedBox(width: 8.w),
            Text(
              achievement.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
