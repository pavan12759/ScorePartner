import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/presentation/screens/tournament/tournament_details_screen.dart';
import 'package:scorepatner/presentation/screens/ground/ground_profile_screen.dart';
import '../../../widgets/head_to_head_widget.dart';

class InfoTab extends StatelessWidget {
  final MatchModel match;

  const InfoTab({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildInfoCard('Match Info', [
            _buildSeriesRow(context),
            _buildInfoRow(context, 'Match', '${match.team1Name} vs ${match.team2Name}'),
            _buildInfoRow(context, 'Date', '${match.scheduledDate.day}/${match.scheduledDate.month}/${match.scheduledDate.year}'),
            _buildInfoRow(context, 'Time', '${match.scheduledDate.hour}:${match.scheduledDate.minute.toString().padLeft(2, '0')}'),
            _buildVenueRow(context, 'Venue', match.ground),
            _buildInfoRow(context, 'Location', match.location),
            _buildInfoRow(context, 'Toss', _getTossResult()),
            _buildInfoRow(context, 'Umpire', 'TBA'),
          ]),
          
          SizedBox(height: 16.h),

          // Head-to-Head record
          HeadToHeadCard(
            team1Id: match.team1Id,
            team2Id: match.team2Id,
            team1Name: match.team1Name,
            team2Name: match.team2Name,
          ),
          
          SizedBox(height: 16.h),
          
          _buildInfoCard('Venue Guide', [
             _buildVenueRow(context, 'Stadium', match.ground),
             _buildInfoRow(context, 'City', match.location),
             _buildInfoRow(context, 'Capacity', 'N/A'),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryOrange,
                letterSpacing: 1.2,
              ),
            ),
            Divider(height: 24.h, color: Colors.grey),
            ...children,
          ],
        ),
      ),
    );
  }

  String _getTossResult() {
    if (match.tossWinnerId != null && match.tossDecision != null && match.tossWinnerId!.isNotEmpty) {
      final winnerName = match.tossWinnerId == match.team1Id ? match.team1Name : match.team2Name;
      final decision = match.tossDecision == 'bat' ? 'Bat' : 'Field';
      return '$winnerName elected to $decision';
    }
    return 'TBA';
  }

  Widget _buildSeriesRow(BuildContext context) {
    final hasTournament = match.tournamentId != null && 
        match.tournamentName != null && 
        match.tournamentName!.isNotEmpty;
    final seriesName = hasTournament ? match.tournamentName! : 'Friendly Match';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              'SERIES',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: hasTournament
                ? GestureDetector(
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                      );
                      try {
                        final tournament = await FirebaseDataService.instance.getTournamentById(match.tournamentId!);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (tournament != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TournamentDetailsScreen(tournament: tournament)),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            seriesName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right, size: 18.sp, color: AppTheme.primaryOrange),
                      ],
                    ),
                  )
                : Text(
                    seriesName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tappable venue/ground row that navigates to Ground Profile Screen
  Widget _buildVenueRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (value.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroundProfileScreen(
                        groundName: value,
                        location: match.location,
                        latitude: match.latitude,
                        longitude: match.longitude,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.chevron_right, size: 18.sp, color: AppTheme.primaryOrange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
