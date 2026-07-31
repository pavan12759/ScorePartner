import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/screens/profile/player_profile_screen.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/data/models/team_model.dart';
import 'dart:convert';

class PlayerInfo {
  final String name;
  final String id;
  
  PlayerInfo(this.name, this.id);
  
  @override
  bool operator ==(Object other) => 
    identical(this, other) || 
    other is PlayerInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SquadsTab extends StatefulWidget {
  final MatchModel match;
  
  const SquadsTab({super.key, required this.match});

  @override
  State<SquadsTab> createState() => _SquadsTabState();
}

class _SquadsTabState extends State<SquadsTab> {
  TeamModel? _team1;
  TeamModel? _team2;
  Map<String, String> _profilePhotos = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    final service = FirebaseDataService.instance;
    final team1 = await service.getTeamById(widget.match.team1Id);
    final team2 = await service.getTeamById(widget.match.team2Id);
    
    // Fetch profile photos
    Map<String, String> photos = {};
    List<String> allPlayerIds = [];
    
    widget.match.team1Score.batters.forEach((p) => allPlayerIds.add(p.playerId));
    widget.match.team1Score.bowlers.forEach((p) => allPlayerIds.add(p.playerId));
    widget.match.team2Score.batters.forEach((p) => allPlayerIds.add(p.playerId));
    widget.match.team2Score.bowlers.forEach((p) => allPlayerIds.add(p.playerId));
    
    final uniquePlayerIds = allPlayerIds.toSet().toList();
    
    await Future.wait(uniquePlayerIds.map((id) async {
       try {
           final user = await service.findUserByAnyId(id);
           if (user != null && user.profileImageUrl.isNotEmpty) {
               photos[id] = user.profileImageUrl;
           }
       } catch (_) {}
    }));
    
    if (mounted) {
      setState(() {
        _team1 = team1;
        _team2 = team2;
        _profilePhotos = photos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine batters and bowlers to get a rough squad list
    Set<PlayerInfo> team1Players = {};
    widget.match.team1Score.batters.forEach((p) => team1Players.add(PlayerInfo(p.playerName, p.playerId)));
    widget.match.team1Score.bowlers.forEach((p) => team1Players.add(PlayerInfo(p.playerName, p.playerId)));
    
    Set<PlayerInfo> team2Players = {};
    widget.match.team2Score.batters.forEach((p) => team2Players.add(PlayerInfo(p.playerName, p.playerId)));
    widget.match.team2Score.bowlers.forEach((p) => team2Players.add(PlayerInfo(p.playerName, p.playerId)));
    
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
           Container(
             color: Theme.of(context).cardColor,
             child: TabBar(
               labelColor: AppTheme.primaryOrange,
               unselectedLabelColor: Colors.grey,
               indicatorColor: AppTheme.primaryOrange,
               labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, letterSpacing: 0.5),
               unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12.sp, letterSpacing: 0.5),
               indicatorSize: TabBarIndicatorSize.tab,
               tabs: [
                 Tab(text: widget.match.team1Name.toUpperCase()),
                 Tab(text: widget.match.team2Name.toUpperCase()),
               ],
             ),
           ),
           Expanded(
             child: TabBarView(
               children: [
                 _buildTeamList(context, team1Players.toList(), _team1),
                 _buildTeamList(context, team2Players.toList(), _team2),
               ],
             ),
           ),
        ],
      ),
    );
  }
  
  Widget _buildTeamList(BuildContext context, List<PlayerInfo> players, TeamModel? team) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
    }
    if (players.isEmpty) {
      return const Center(child: Text('Playing XI not announced yet', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
    }

    ImageProvider? getProfileImageProvider(String? url) {
      if (url == null || url.isEmpty) return null;
      if (url.trim().startsWith('data:')) {
        try {
          final base64Str = url.split(',').last.trim();
          return MemoryImage(base64Decode(base64Str));
        } catch (_) {
          return null;
        }
      }
      return NetworkImage(url);
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: players.length,
      itemBuilder: (ctx, index) {
        final player = players[index];
        
        TeamPlayer? fullPlayer;
        if (team != null) {
            try {
                fullPlayer = team.players.firstWhere((p) => p.userId == player.id);
            } catch (_) {}
        }
        
        String role = fullPlayer?.role ?? 'Player';
        if (role.isEmpty) role = 'Player';
        String displayName = player.name.toUpperCase();
        
        if (fullPlayer != null) {
            if (fullPlayer.isCaptain || team?.captainId == fullPlayer.userId) {
                displayName += ' (C)';
            } else if (fullPlayer.isViceCaptain || team?.viceCaptainId == fullPlayer.userId) {
                displayName += ' (VC)';
            }
        }
        
        return Card(
           child: ListTile(
             contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
             leading: CircleAvatar(
               backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
               child: _profilePhotos[player.id] != null && _profilePhotos[player.id]!.isNotEmpty
                   ? ClipOval(
                       child: Image(
                         image: getProfileImageProvider(_profilePhotos[player.id]!)!,
                         width: 40,
                         height: 40,
                         fit: BoxFit.cover,
                         errorBuilder: (context, error, stackTrace) {
                           return Center(
                             child: Text(
                               player.name.isNotEmpty ? player.name[0].toUpperCase() : '?', 
                               style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)
                             ),
                           );
                         },
                       ),
                     )
                   : Text(
                       player.name.isNotEmpty ? player.name[0].toUpperCase() : '?', 
                       style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)
                     ),
             ),
             title: Text(
               displayName, 
               style: TextStyle(
                 fontWeight: FontWeight.bold, 
                 color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, 
                 fontSize: 14.sp, 
                 letterSpacing: 0.5,
                 decoration: TextDecoration.underline,
                 decorationColor: AppTheme.primaryOrange.withOpacity(0.3),
                 decorationStyle: TextDecorationStyle.dotted,
               )
             ),
             subtitle: Text(role.toUpperCase(), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45, fontSize: 10.sp, fontWeight: FontWeight.bold)),
             onTap: () => _navigateToPlayerProfile(context, player.id),
           ),
        );
      },
    );
  }

  Future<void> _navigateToPlayerProfile(BuildContext context, String playerId) async {
    if (playerId.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
    );
    
    try {
      final user = await FirebaseDataService.instance.findUserByAnyId(playerId);
      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      
      if (user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: user),
          ),
        );
      } else {
        if (playerId.startsWith('p_') || playerId.startsWith('manual_') || playerId.startsWith('player_')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player profile not available for manually added players')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Player profile not found')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading profile')),
        );
      }
    }
  }
}
