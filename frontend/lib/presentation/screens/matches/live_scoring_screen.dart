
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/scoring_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/dialogs/manage_access_dialog.dart';
import 'tabs/match_scoring_tab.dart';
import '../broadcast/go_live_screen.dart';

class LiveScoringScreen extends StatelessWidget {
  final String matchId;

  const LiveScoringScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScoringProvider()
        ..initializeSocket()
        ..joinMatch(matchId),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF061E1A),
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?q=80&w=2000&auto=format&fit=crop'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(const Color(0xFF061E1A).withOpacity(0.85), BlendMode.srcOver),
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, size: 20.sp),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('LIVE SCORING', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00), letterSpacing: 1)),
                SizedBox(width: 8.w),
                Container(width: 8.w, height: 8.h, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF3B30),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF3B30).withOpacity(0.6), blurRadius: 6)])),
              ],
            ),
            centerTitle: true,
            actions: [
              StreamBuilder<MatchModel?>(
                stream: FirebaseDataService.instance.streamMatch(matchId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return SizedBox.shrink();
                  final match = snapshot.data!;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  
                  if (currentUser != null && (match.createdBy == currentUser.uid || match.adminIds.contains(currentUser.uid))) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.videocam, color: Color(0xFFFF3B30)),
                          tooltip: 'GO LIVE (Broadcast)',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GoLiveScreen(preselectedMatchId: match.id),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.person_add_alt_1, color: Colors.white),
                          tooltip: 'Manage Access',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageAccessDialog(match: match),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.share, color: Colors.white),
                          tooltip: 'Share Match',
                          onPressed: () {
                            Share.share('Check out this live match on ScorePartner: ${match.team1Name} vs ${match.team2Name}!\n\nLive Score: https://scorepartner.in/match/${match.id}');
                          },
                        ),
                      ],
                    );
                  }
                  
                  return IconButton(
                    icon: Icon(Icons.share, color: Colors.white),
                    tooltip: 'Share Match',
                    onPressed: () {
                      Share.share('Check out this live match on ScorePartner: ${match.team1Name} vs ${match.team2Name}!\n\nLive Score: https://scorepartner.in/match/${match.id}');
                    },
                  );
                },
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
                return const Center(child: Text("Match not found", style: TextStyle(color: Colors.white)));
              }
              
              final match = snapshot.data!;
              
              return MatchScoringTab(match: match);
            },
          ),
        ),
      ),
    );
  }
}
