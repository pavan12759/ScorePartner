import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../../data/models/match_model.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Row(
              children: [
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(40.r),
                  ),
                  child: user.profileImageUrl.isNotEmpty
                      ? null
                      : Icon(Icons.person, size: 40.sp, color: Colors.grey),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          'ID: ${user.spPId}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),

                      Text(
                        user.location,
                        style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Age: ${user.age}',
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Cricket Details
            Text(
              'Cricket Details',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            _buildDetailRow('Role', user.role),
            _buildDetailRow('Batting Style', user.battingStyle),
            _buildDetailRow('Bowling Style', user.bowlingStyle),
            SizedBox(height: 24.h),

            // Tennis Ball Stats
            _buildStatsSection('Tennis Ball Stats', user.tennisBallStats),
            SizedBox(height: 24.h),

            // Leather Ball Stats
            _buildStatsSection('Leather Ball Stats', user.leatherBallStats),
            SizedBox(height: 24.h),

            // Achievements
            Text(
              'Achievements',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            _buildAchievementRow(
              'Man of the Match',
              (user.tennisBallStats.manOfMatches +
                  user.leatherBallStats.manOfMatches).toString(),
            ),
            _buildAchievementRow(
              'Tournament Wins',
              (user.tennisBallStats.tournamentWins +
                  user.leatherBallStats.tournamentWins).toString(),
            ),
            _buildAchievementRow(
              'Highest Score',
              '${user.tennisBallStats.bestScore}',
            ),

            SizedBox(height: 32.h),

            SizedBox(height: 32.h),
            
            // Recent Matches
            _buildRecentMatches(FirebaseAuth.instance.currentUser?.uid ?? ''),
            
            SizedBox(height: 32.h),

            // Edit Profile Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to edit profile
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(String title, dynamic stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Matches', stats.matches.toString()),
            ),
            SizedBox(width: 8.w),
            Expanded(child: _buildStatCard('Runs', stats.runs.toString())),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildStatCard('Wickets', stats.wickets.toString()),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Strike Rate',
                stats.strikeRate.toStringAsFixed(1),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildStatCard(
                'Economy',
                stats.economy.toStringAsFixed(1),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(child: _buildStatCard('Best', stats.bestBowling)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAchievementRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 20.sp),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMatches(String userId) {
    if (userId.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Matches',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.h),
        FutureBuilder<List<MatchModel>>(
          future: FirebaseDataService.instance.getUserPlayedMatches(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error loading matches: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Text('No matches played yet.'),
              );
            }

            final matches = snapshot.data!;
            return SizedBox(
              height: 140.h, // Height for horizontal cards
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length > 5 ? 5 : matches.length,
                separatorBuilder: (c, i) => SizedBox(width: 12.w),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return Container(
                    width: 280.w,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.05),
                           blurRadius: 5,
                           offset: Offset(0, 2),
                         ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(match.matchName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(match.team1Name, style: TextStyle(fontWeight: FontWeight.bold))),
                            Text('${match.team1Score.runs}/${match.team1Score.wickets}', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(match.team2Name, style: TextStyle(fontWeight: FontWeight.bold))),
                            Text('${match.team2Score.runs}/${match.team2Score.wickets}', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        if (match.status == 'completed' && match.result != null)
                          Text(match.result!.winner == 'Match Tied' ? 'Tie' : '${match.result!.winner} won', 
                             style: TextStyle(fontSize: 10.sp, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold))
                        else
                          Text(match.status.toUpperCase(), 
                              style: TextStyle(fontSize: 10.sp, color: match.status == 'live' ? AppTheme.primaryOrange : Colors.blue)),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
