import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';

/// Dialog shown at match start to select opening batsmen and bowler
class MatchInitializationDialog extends StatefulWidget {
  final MatchModel match;
  
  const MatchInitializationDialog({
    super.key,
    required this.match,
  });

  @override
  State<MatchInitializationDialog> createState() => _MatchInitializationDialogState();
}

class _MatchInitializationDialogState extends State<MatchInitializationDialog> {
  List<TeamPlayer> battingTeamPlayers = [];
  List<TeamPlayer> bowlingTeamPlayers = [];
  bool isLoading = true;
  
  String? selectedStrikerId;
  String? selectedStrikerName;
  String? selectedNonStrikerId;
  String? selectedNonStrikerName;
  String? selectedBowlerId;
  String? selectedBowlerName;
  
  @override
  void initState() {
    super.initState();
    _loadTeamPlayers();
  }
  
  Future<void> _loadTeamPlayers() async {
    final isTeam1Batting = widget.match.currentBattingTeam == 'team1';
    final battingTeamId = isTeam1Batting ? widget.match.team1Id : widget.match.team2Id;
    final bowlingTeamId = isTeam1Batting ? widget.match.team2Id : widget.match.team1Id;
    
    try {
      // Fetch batting team players
      if (battingTeamId.isNotEmpty && battingTeamId != 't1' && battingTeamId != 't2') {
        final battingTeam = await FirebaseDataService.instance.getTeamById(battingTeamId);
        if (battingTeam != null) {
          battingTeamPlayers = battingTeam.players;
        }
      }

      // Fallback for Batting Team (Quick Match or incomplete Team)
      // Check if we have players in the score object (e.g. from previous innings if they batted, or just generally)
      if (battingTeamPlayers.isEmpty) {
         final score = isTeam1Batting ? widget.match.team1Score : widget.match.team2Score;
         final existingPlayers = <String, TeamPlayer>{};
         
         // Add from batters
         for (var b in score.batters) {
           if (b.playerName != 'Batsman' && b.playerName != 'Select Striker' && b.playerName != 'Select Non-Striker') {
             existingPlayers[b.playerId] = TeamPlayer(userId: b.playerId, name: b.playerName, role: 'Player');
           }
         }
         // Add from bowlers (if they bowled)
         for (var b in score.bowlers) {
             if (b.playerName != 'Bowler' && b.playerName != 'Select Bowler') {
              existingPlayers[b.playerId] = TeamPlayer(userId: b.playerId, name: b.playerName, role: 'Player');
             }
         }
         
         if (existingPlayers.isNotEmpty) {
           battingTeamPlayers = existingPlayers.values.toList();
         }
      }
      
      // Fetch bowling team players
      if (bowlingTeamId.isNotEmpty && bowlingTeamId != 't1' && bowlingTeamId != 't2') {
        final bowlingTeam = await FirebaseDataService.instance.getTeamById(bowlingTeamId);
        if (bowlingTeam != null) {
          bowlingTeamPlayers = bowlingTeam.players;
        }
      }

      // Fallback for Bowling Team (Quick Match - CRITICAL for 2nd Innings)
      // For 2nd innings, the current bowling team has ALREADY batted. So their players are in their score.batters list.
      if (bowlingTeamPlayers.isEmpty) {
         // The bowling team's score object is the OTHER team's score.
         final score = isTeam1Batting ? widget.match.team2Score : widget.match.team1Score;
         final existingPlayers = <String, TeamPlayer>{};
         
         // Add from batters (Most important for 2nd innings bowling selection)
         for (var b in score.batters) {
           if (b.playerName != 'Batsman' && b.playerName != 'Select Striker' && b.playerName != 'Select Non-Striker') {
             existingPlayers[b.playerId] = TeamPlayer(userId: b.playerId, name: b.playerName, role: 'Player');
           }
         }
         // Add from bowlers
         for (var b in score.bowlers) {
             if (b.playerName != 'Bowler' && b.playerName != 'Select Bowler') {
              existingPlayers[b.playerId] = TeamPlayer(userId: b.playerId, name: b.playerName, role: 'Player');
             }
         }

         if (existingPlayers.isNotEmpty) {
           bowlingTeamPlayers = existingPlayers.values.toList();
         }
      }

    } catch (e) {
      debugPrint('Error loading teams: $e');
    }
    
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTeam1Batting = widget.match.currentBattingTeam == 'team1';
    final battingTeamName = isTeam1Batting ? widget.match.team1Name : widget.match.team2Name;
    final bowlingTeamName = isTeam1Batting ? widget.match.team2Name : widget.match.team1Name;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 450, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.sports_cricket, color: Colors.white, size: 40.sp),
                  SizedBox(height: 8.h),
                  Text(
                    'Start Match',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$battingTeamName batting first',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14.sp),
                  ),
                ],
              ),
            ),
            
            if (isLoading)
              Padding(
                padding: EdgeInsets.all(40.w),
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Opening Batsmen Section
                      _buildSectionTitle('🏏 Opening Batsmen', battingTeamName),
                      SizedBox(height: 8.h),
                      _buildPlayerSelector(
                        'Striker',
                        selectedStrikerName,
                        battingTeamPlayers,
                        excludeId: selectedNonStrikerId,
                        onSelect: (player) {
                          setState(() {
                            selectedStrikerId = player.userId.isNotEmpty 
                                ? player.userId 
                                : 'p_${player.name.replaceAll(' ', '_')}';
                            selectedStrikerName = player.name;
                          });
                        },
                      ),
                      SizedBox(height: 8.h),
                      _buildPlayerSelector(
                        'Non-Striker',
                        selectedNonStrikerName,
                        battingTeamPlayers,
                        excludeId: selectedStrikerId,
                        onSelect: (player) {
                          setState(() {
                            selectedNonStrikerId = player.userId.isNotEmpty 
                                ? player.userId 
                                : 'p_${player.name.replaceAll(' ', '_')}';
                            selectedNonStrikerName = player.name;
                          });
                        },
                      ),
                      
                      SizedBox(height: 20.h),
                      
                      // Opening Bowler Section
                      _buildSectionTitle('⚾ Opening Bowler', bowlingTeamName),
                      SizedBox(height: 8.h),
                      _buildPlayerSelector(
                        'Bowler',
                        selectedBowlerName,
                        bowlingTeamPlayers,
                        onSelect: (player) {
                          setState(() {
                            selectedBowlerId = player.userId.isNotEmpty 
                                ? player.userId 
                                : 'p_${player.name.replaceAll(' ', '_')}';
                            selectedBowlerName = player.name;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            
            // Action Buttons
            Padding(
              padding: EdgeInsets.all(16.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canStartMatch() ? _startMatch : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  child: Text(
                    'Start Scoring',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, String teamName) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(teamName, style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
        ),
      ],
    );
  }
  
  Widget _buildPlayerSelector(
    String label,
    String? selectedName,
    List<TeamPlayer> players, {
    String? excludeId,
    required Function(TeamPlayer) onSelect,
  }) {
    final availablePlayers = players.where((p) {
      final playerId = p.userId.isNotEmpty ? p.userId : 'p_${p.name.replaceAll(' ', '_')}';
      return playerId != excludeId;
    }).toList();
    
    return InkWell(
      onTap: () => _showPlayerPicker(label, availablePlayers, onSelect),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          border: Border.all(color: selectedName != null ? AppTheme.primaryOrange : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10.r),
          color: selectedName != null ? AppTheme.primaryOrange.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              selectedName != null ? Icons.check_circle : Icons.person_outline,
              color: selectedName != null ? AppTheme.primaryOrange : Colors.grey,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                selectedName ?? 'Select $label',
                style: TextStyle(
                  color: selectedName != null ? Colors.black87 : Colors.grey[600],
                  fontWeight: selectedName != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  
  void _showPlayerPicker(String label, List<TeamPlayer> players, Function(TeamPlayer) onSelect) {
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredPlayers = players.where((p) => 
            p.name.toLowerCase().contains(searchQuery.toLowerCase())
          ).toList();
          
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Text('Select $label', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search or add player...',
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(vertical: 0.h),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                ),
                Divider(height: 1.h),
                Flexible(
                  child: filteredPlayers.isEmpty && searchQuery.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(32.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_off, size: 48.sp, color: Colors.grey[400]),
                              SizedBox(height: 12.h),
                              const Text('No players found in team squad'),
                              SizedBox(height: 16.h),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _addManualPlayer(label, onSelect);
                                },
                                icon: Icon(Icons.add),
                                label: const Text('Add Player Manually'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredPlayers.length + (searchQuery.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredPlayers.length) {
                              return ListTile(
                                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.add, color: Colors.white)),
                                title: Text('Add "$searchQuery"'),
                                subtitle: const Text('Add as manual player'),
                                onTap: () {
                                  Navigator.pop(context);
                                  onSelect(TeamPlayer(name: searchQuery, userId: '', role: 'Player'));
                                },
                              );
                            }
                            
                            final player = filteredPlayers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                                child: Text(player.name.substring(0, 1).toUpperCase(), style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(player.name, style: TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(player.role.isNotEmpty ? player.role : 'Player'),
                              trailing: player.isCaptain 
                                  ? Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text('C', style: TextStyle(color: Colors.blue, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                onSelect(player);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
  
  void _addManualPlayer(String label, Function(TeamPlayer) onSelect) async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $label'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Player Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      onSelect(TeamPlayer(
        userId: 'p_${result.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
        name: result,
        role: '',
      ));
    }
  }
  
  bool _canStartMatch() {
    return selectedStrikerId != null && 
           selectedNonStrikerId != null && 
           selectedBowlerId != null;
  }
  
  void _startMatch() {
    Navigator.pop(context, {
      'strikerId': selectedStrikerId,
      'strikerName': selectedStrikerName,
      'nonStrikerId': selectedNonStrikerId,
      'nonStrikerName': selectedNonStrikerName,
      'bowlerId': selectedBowlerId,
      'bowlerName': selectedBowlerName,
    });
  }
}

/// Dialog for selecting dismissal type
class DismissalTypeDialog extends StatelessWidget {
  const DismissalTypeDialog({super.key});
  
  static const List<Map<String, dynamic>> dismissalTypes = [
    {'type': 'bowled', 'label': 'Bowled', 'icon': Icons.sports_cricket, 'needsFielder': false},
    {'type': 'caught', 'label': 'Caught', 'icon': Icons.catching_pokemon, 'needsFielder': true},
    {'type': 'lbw', 'label': 'LBW', 'icon': Icons.gavel, 'needsFielder': false},
    {'type': 'run_out', 'label': 'Run Out', 'icon': Icons.directions_run, 'needsFielder': true},
    {'type': 'stumped', 'label': 'Stumped', 'icon': Icons.sports_kabaddi, 'needsFielder': true},
    {'type': 'hit_wicket', 'label': 'Hit Wicket', 'icon': Icons.warning, 'needsFielder': false},
    {'type': 'retired', 'label': 'Retired Hurt', 'icon': Icons.healing, 'needsFielder': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            width: double.infinity,
            child: Column(
              children: [
                Icon(Icons.sports_cricket, color: Colors.white, size: 32.sp),
                SizedBox(height: 8.h),
                Text(
                  'How was the batsman out?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...dismissalTypes.map((type) => ListTile(
            leading: Icon(type['icon'] as IconData, color: Colors.red.shade400),
            title: Text(type['label'] as String),
            onTap: () => Navigator.pop(context, type),
          )),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

/// Dialog for selecting next batsman after wicket
class NextBatsmanDialog extends StatelessWidget {
  final List<BatterStats> availableBatters;
  final String teamName;
  
  const NextBatsmanDialog({
    super.key,
    required this.availableBatters,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to only show batters who haven't batted or aren't out
    final yetToBat = availableBatters.where((b) => !b.isOut && !b.isPlaying).toList();
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.person_add, color: Colors.white, size: 32.sp),
                  SizedBox(height: 8.h),
                  Text(
                    'Select Next Batsman',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    teamName,
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: yetToBat.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning, size: 48.sp, color: Colors.orange),
                          SizedBox(height: 12.h),
                          Text('All Out!', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                          Text('No more batters available'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: yetToBat.length,
                      itemBuilder: (context, index) {
                        final batter = yetToBat[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryOrange.withOpacity(0.2),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(batter.playerName, style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Yet to bat'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                          onTap: () => Navigator.pop(context, batter),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for selecting fielder (for caught/stumped/run out)
class FielderSelectionDialog extends StatelessWidget {
  final List<BowlerStats> fieldingTeamPlayers;
  final String fielderLabel;
  
  const FielderSelectionDialog({
    super.key,
    required this.fieldingTeamPlayers,
    this.fielderLabel = 'Fielder',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.catching_pokemon, color: Colors.white, size: 32.sp),
                  SizedBox(height: 8.h),
                  Text(
                    'Select $fielderLabel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: fieldingTeamPlayers.length,
                itemBuilder: (context, index) {
                  final player = fieldingTeamPlayers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        player.playerName.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(player.playerName),
                    onTap: () => Navigator.pop(context, player.playerName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for changing bowler at end of over
class EndOfOverBowlerDialog extends StatelessWidget {
  final List<BowlerStats> bowlers;
  final String? lastBowlerId; // Can't bowl consecutive overs
  
  const EndOfOverBowlerDialog({
    super.key,
    required this.bowlers,
    this.lastBowlerId,
  });

  @override
  Widget build(BuildContext context) {
    final availableBowlers = bowlers.where((b) => b.playerId != lastBowlerId).toList();
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.sports_baseball, color: Colors.white, size: 32.sp),
                  SizedBox(height: 8.h),
                  Text(
                    'Over Complete!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Select next bowler',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableBowlers.length + 1,
                itemBuilder: (context, index) {
                  if (index == availableBowlers.length) {
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryOrange, 
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                      title: const Text('Add Bowler Manually', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
                      subtitle: const Text('If player is missing from list'),
                      onTap: () async {
                        final nameController = TextEditingController();
                        final name = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Add Bowler'),
                            content: TextField(
                              controller: nameController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'Bowler Name',
                                hintText: 'Enter name',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (nameController.text.trim().isNotEmpty) {
                                    Navigator.pop(context, nameController.text.trim());
                                  }
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        );
                        
                        if (name != null && context.mounted) {
                          Navigator.pop(context, BowlerStats(
                            playerId: 'manual_bowler_${DateTime.now().millisecondsSinceEpoch}',
                            playerName: name,
                          ));
                        }
                      },
                    );
                  }

                  final bowler = availableBowlers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        bowler.playerName.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(bowler.playerName, style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${bowler.oversDisplay} - ${bowler.maidens} - ${bowler.runs} - ${bowler.wickets}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Text(
                      'Eco: ${bowler.economy.toStringAsFixed(1)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
                    ),
                    onTap: () => Navigator.pop(context, bowler),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog shown at the end of 1st innings to show summary and target
class InningsEndDialog extends StatelessWidget {
  final MatchModel match;
  final TeamScore score;
  final String teamName;
  final VoidCallback onStartSecondInnings;

  const InningsEndDialog({
    super.key,
    required this.match,
    required this.score,
    required this.teamName,
    required this.onStartSecondInnings,
  });

  @override
  Widget build(BuildContext context) {
    final target = score.runs + 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            width: double.infinity,
            child: Column(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.white, size: 40.sp),
                SizedBox(height: 8.h),
                Text(
                  'Innings Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                Text(
                  teamName,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${score.runs}/${score.wickets}',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                Text(
                  '(${score.oversDisplay} Overs)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16.sp),
                ),
                SizedBox(height: 24.h),
                const Divider(),
                SizedBox(height: 16.h),
                Text(
                  'TARGET',
                  style: TextStyle(fontSize: 14.sp, letterSpacing: 2, color: Colors.grey),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$target',
                  style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Runs in ${match.oversPerSide} overs',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onStartSecondInnings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text(
                      'START NEXT INNINGS',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog to ask who is out (Striker or Non-Striker)
class WhoIsOutDialog extends StatelessWidget {
  final BatterStats striker;
  final BatterStats nonStriker;

  const WhoIsOutDialog({
    super.key,
    required this.striker,
    required this.nonStriker,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            width: double.infinity,
            child: Column(
              children: [
                Icon(Icons.person_off, color: Colors.white, size: 32.sp),
                SizedBox(height: 8.h),
                Text(
                  'Who is out?',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Text('S', style: TextStyle(color: Colors.white))),
            title: Text(striker.playerName),
            subtitle: const Text('Striker'),
            onTap: () => Navigator.pop(context, striker.playerId),
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.red.withOpacity(0.5), child: const Text('N', style: TextStyle(color: Colors.white))),
            title: Text(nonStriker.playerName),
            subtitle: const Text('Non-Striker'),
            onTap: () => Navigator.pop(context, nonStriker.playerId),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

/// Dialog to ask if batsmen crossed
class CrossingDialog extends StatelessWidget {
  const CrossingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Did Batsmen Cross?'),
      content: const Text('Did the batsmen cross each other before the catch was taken?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
          child: const Text('YES'),
        ),
      ],
    );
  }
}

/// Dialog to ask for runs completed during run out
class RunOutRunsDialog extends StatelessWidget {
  const RunOutRunsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            width: double.infinity,
            child: Text(
              'Runs Completed?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [0, 1, 2, 3].map((r) => ElevatedButton(
                onPressed: () => Navigator.pop(context, r),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: CircleBorder(), padding: EdgeInsets.all(20.w)),
                child: Text('$r', style: TextStyle(fontSize: 20.sp, color: Colors.white)),
              )).toList(),
            ),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}
