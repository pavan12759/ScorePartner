import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

/// Player Leaderboard Screen - Rankings by runs, wickets, etc.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Most Runs'),
            Tab(text: 'Most Wickets'),
            Tab(text: 'Best SR'),
            Tab(text: 'Best Eco'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboard('runs', 'Most Runs', Icons.sports_cricket),
          _buildLeaderboard('wickets', 'Most Wickets', Icons.sports_baseball),
          _buildLeaderboard('strikeRate', 'Best Strike Rate', Icons.flash_on),
          _buildLeaderboard('economy', 'Best Economy', Icons.speed),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(String type, String title, IconData icon) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchLeaderboard(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final players = snapshot.data ?? _getMockData(type);

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: players.length,
          itemBuilder: (context, index) {
            return _buildPlayerCard(players[index], index + 1, type);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLeaderboard(String type) async {
    // In a real app, you'd aggregate stats from matches
    // For now, return mock data
    return _getMockData(type);
  }

  List<Map<String, dynamic>> _getMockData(String type) {
    if (type == 'runs') {
      return [
        {'name': 'Virat Kohli', 'value': 1245, 'matches': 28, 'avg': 45.5},
        {'name': 'Rohit Sharma', 'value': 1180, 'matches': 25, 'avg': 52.3},
        {'name': 'KL Rahul', 'value': 985, 'matches': 22, 'avg': 48.7},
        {'name': 'Shubman Gill', 'value': 920, 'matches': 20, 'avg': 51.2},
        {'name': 'Ishan Kishan', 'value': 875, 'matches': 24, 'avg': 38.6},
        {'name': 'Rishabh Pant', 'value': 780, 'matches': 18, 'avg': 46.5},
        {'name': 'Hardik Pandya', 'value': 650, 'matches': 22, 'avg': 35.8},
        {'name': 'Suryakumar Yadav', 'value': 620, 'matches': 16, 'avg': 58.2},
        {'name': 'Shreyas Iyer', 'value': 580, 'matches': 15, 'avg': 42.1},
        {'name': 'Ravindra Jadeja', 'value': 485, 'matches': 20, 'avg': 32.5},
      ];
    } else if (type == 'wickets') {
      return [
        {'name': 'Jasprit Bumrah', 'value': 48, 'matches': 22, 'avg': 18.5},
        {'name': 'Mohammed Shami', 'value': 42, 'matches': 20, 'avg': 22.3},
        {'name': 'Ravindra Jadeja', 'value': 38, 'matches': 25, 'avg': 25.6},
        {'name': 'Axar Patel', 'value': 35, 'matches': 18, 'avg': 27.2},
        {'name': 'Kuldeep Yadav', 'value': 32, 'matches': 16, 'avg': 24.8},
        {'name': 'Mohammed Siraj', 'value': 28, 'matches': 15, 'avg': 29.5},
        {'name': 'Shardul Thakur', 'value': 25, 'matches': 14, 'avg': 32.1},
        {'name': 'Yuzvendra Chahal', 'value': 22, 'matches': 12, 'avg': 28.4},
        {'name': 'Arshdeep Singh', 'value': 20, 'matches': 10, 'avg': 26.7},
        {'name': 'Mukesh Kumar', 'value': 18, 'matches': 8, 'avg': 30.2},
      ];
    } else if (type == 'strikeRate') {
      return [
        {'name': 'Suryakumar Yadav', 'value': 185.6, 'matches': 16, 'runs': 620},
        {'name': 'Hardik Pandya', 'value': 172.3, 'matches': 22, 'runs': 650},
        {'name': 'Rishabh Pant', 'value': 168.5, 'matches': 18, 'runs': 780},
        {'name': 'Ishan Kishan', 'value': 155.2, 'matches': 24, 'runs': 875},
        {'name': 'Rohit Sharma', 'value': 148.9, 'matches': 25, 'runs': 1180},
        {'name': 'Virat Kohli', 'value': 142.5, 'matches': 28, 'runs': 1245},
        {'name': 'Shubman Gill', 'value': 138.7, 'matches': 20, 'runs': 920},
        {'name': 'KL Rahul', 'value': 132.4, 'matches': 22, 'runs': 985},
        {'name': 'Shreyas Iyer', 'value': 128.6, 'matches': 15, 'runs': 580},
        {'name': 'Ravindra Jadeja', 'value': 125.8, 'matches': 20, 'runs': 485},
      ];
    } else {
      return [
        {'name': 'Jasprit Bumrah', 'value': 4.85, 'matches': 22, 'wickets': 48},
        {'name': 'Mohammed Shami', 'value': 5.12, 'matches': 20, 'wickets': 42},
        {'name': 'Ravindra Jadeja', 'value': 5.45, 'matches': 25, 'wickets': 38},
        {'name': 'Axar Patel', 'value': 5.68, 'matches': 18, 'wickets': 35},
        {'name': 'Mohammed Siraj', 'value': 5.92, 'matches': 15, 'wickets': 28},
        {'name': 'Kuldeep Yadav', 'value': 6.15, 'matches': 16, 'wickets': 32},
        {'name': 'Arshdeep Singh', 'value': 6.42, 'matches': 10, 'wickets': 20},
        {'name': 'Shardul Thakur', 'value': 6.78, 'matches': 14, 'wickets': 25},
        {'name': 'Yuzvendra Chahal', 'value': 7.05, 'matches': 12, 'wickets': 22},
        {'name': 'Mukesh Kumar', 'value': 7.32, 'matches': 8, 'wickets': 18},
      ];
    }
  }

  Widget _buildPlayerCard(Map<String, dynamic> player, int rank, String type) {
    Color rankColor;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankColor = Colors.brown[300]!;
    } else {
      rankColor = Colors.grey[200]!;
    }

    String statLabel;
    String statValue;
    String subtitle;

    switch (type) {
      case 'runs':
        statLabel = 'Runs';
        statValue = '${player['value']}';
        subtitle = '${player['matches']} matches • Avg: ${player['avg']}';
        break;
      case 'wickets':
        statLabel = 'Wickets';
        statValue = '${player['value']}';
        subtitle = '${player['matches']} matches • Avg: ${player['avg']}';
        break;
      case 'strikeRate':
        statLabel = 'SR';
        statValue = '${player['value']}';
        subtitle = '${player['matches']} matches • ${player['runs']} runs';
        break;
      case 'economy':
        statLabel = 'Eco';
        statValue = '${player['value']}';
        subtitle = '${player['matches']} matches • ${player['wickets']} wkts';
        break;
      default:
        statLabel = 'Value';
        statValue = '${player['value']}';
        subtitle = '';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      elevation: rank <= 3 ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: rank <= 3 ? BorderSide(color: rankColor, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: rankColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: rank <= 3
                    ? Icon(
                        Icons.emoji_events,
                        color: rank == 1 ? Colors.white : Colors.black54,
                        size: 20.sp,
                      )
                    : Text(
                        '$rank',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                      ),
              ),
            ),
            SizedBox(width: 12.w),

            // Player Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player['name'] as String,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Stat Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  statValue,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                Text(
                  statLabel,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
