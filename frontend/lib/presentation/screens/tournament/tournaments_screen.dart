import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import 'create_tournament_screen.dart';
import 'tournament_details_screen.dart';
import 'tournament_setup_screen.dart';
import '../../widgets/state/scorepartner_skeleton.dart';
import '../../widgets/state/scorepartner_empty_state.dart';
import '../../widgets/state/scorepartner_error_state.dart';

/// Tournaments List Screen
class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tournaments'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
          );
          if (result == true) {
            setState(() {}); // Refresh list
          }
        },
        backgroundColor: AppTheme.primaryOrange,
        icon: Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchTournaments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: ScorePartnerSkeleton(
                  width: double.infinity,
                  height: 180.h,
                  borderRadius: 16.r,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return ScorePartnerErrorState(message: snapshot.error.toString());
          }

          final tournaments = snapshot.data ?? [];

          if (tournaments.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: ScorePartnerEmptyState(
                title: 'No tournaments yet',
                description: 'Create your first tournament to get started.',
                icon: Icons.emoji_events_outlined,
                primaryButtonText: 'Create Tournament',
                onPrimaryAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTournamentScreen()),
                  );
                },
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              return _buildTournamentCard(tournaments[index]);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTournaments() async {
    // Return mock tournament data
    return [
      {
        'id': 'tournament_1',
        'name': 'Mahbubnagar Premier League',
        'location': 'Mahbubnagar',
        'overs': 20,
        'status': 'ongoing',
        'start_date': DateTime.now().subtract(const Duration(days: 5)),
        'end_date': DateTime.now().add(const Duration(days: 10)),
        'max_teams': 8,
        'registered_team_ids': ['team_1', 'team_2', 'team_3', 'team_4', 'team_5', 'team_6'],
        'ball_type': 'Tennis',
        'entry_fee': 500,
        'prize_pool': 25000,
        'organizer_id': 'user_1',
        'organizer_name': 'Sports Club',
      },
      {
        'id': 'tournament_2',
        'name': 'Street Cricket Cup 2026',
        'location': 'Hyderabad',
        'overs': 10,
        'status': 'upcoming',
        'start_date': DateTime.now().add(const Duration(days: 15)),
        'end_date': DateTime.now().add(const Duration(days: 20)),
        'max_teams': 16,
        'registered_team_ids': ['team_1', 'team_2', 'team_3'],
        'ball_type': 'Tennis',
        'entry_fee': 1000,
        'prize_pool': 50000,
        'organizer_id': 'user_2',
        'organizer_name': 'Gully Sports',
      },
    ];
  }

  Widget _buildTournamentCard(Map<String, dynamic> data) {
    final tournament = TournamentModel.fromMap({
      ...data,
      // Map snake_case to camelCase
      'organizerId': data['organizer_id'],
      'organizerName': data['organizer_name'],
      'startDate': data['start_date'],
      'endDate': data['end_date'],
      'maxTeams': data['max_teams'],
      'registeredTeamIds': data['registered_team_ids'] ?? [],
      'ballType': data['ball_type'],
      'entryFee': data['entry_fee'],
      'prizePool': data['prize_pool'],
      'winnerId': data['winner_id'],
      'runnerUpId': data['runner_up_id'],
    });

    final statusColor = tournament.effectiveStatus == 'ongoing'
        ? Colors.green
        : tournament.effectiveStatus == 'completed'
            ? Colors.grey
            : Colors.orange;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TournamentSetupScreen(
                tournamentName: tournament.name,
                tournamentId: tournament.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tournament.name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      tournament.effectiveStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              // Info Row
              Row(
                children: [
                  Icon(Icons.location_on, size: 14.sp, color: Colors.grey[600]),
                  SizedBox(width: 4.w),
                  Text(tournament.location, style: TextStyle(color: Colors.grey[600])),
                  SizedBox(width: 16.w),
                  Icon(Icons.sports_cricket, size: 14.sp, color: Colors.grey[600]),
                  SizedBox(width: 4.w),
                  Text('${tournament.overs} overs', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              SizedBox(height: 8.h),

              // Date & Teams
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatDate(tournament.startDate)} - ${_formatDate(tournament.endDate)}',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                  ),
                  Row(
                    children: [
                      Icon(Icons.groups, size: 16.sp, color: AppTheme.primaryOrange),
                      SizedBox(width: 4.w),
                      Text(
                        '${tournament.registeredTeamIds.length}/${tournament.maxTeams}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                      ),
                    ],
                  ),
                ],
              ),

              // Prize & Entry Fee
              if (tournament.prizePool > 0 || tournament.entryFee > 0) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (tournament.prizePool > 0)
                        Row(
                          children: [
                            Icon(Icons.emoji_events, size: 16.sp, color: Colors.amber),
                            SizedBox(width: 4.w),
                            Text('₹${tournament.prizePool.toStringAsFixed(0)}',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      if (tournament.entryFee > 0)
                        Row(
                          children: [
                            Icon(Icons.payments, size: 16.sp, color: Colors.grey[700]),
                            SizedBox(width: 4.w),
                            Text('Entry: ₹${tournament.entryFee.toStringAsFixed(0)}'),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
}
