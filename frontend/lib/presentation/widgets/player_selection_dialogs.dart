import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_model.dart';

/// Dialog for selecting a player from a team squad
class PlayerSelectionDialog extends StatefulWidget {
  final String title;
  final List<BatterStats> batters;
  final List<BowlerStats> bowlers;
  final String? excludePlayerId; // Player to exclude (e.g., already selected)
  final bool showBatters;
  final bool showBowlers;

  const PlayerSelectionDialog({
    super.key,
    required this.title,
    this.batters = const [],
    this.bowlers = const [],
    this.excludePlayerId,
    this.showBatters = true,
    this.showBowlers = false,
  });

  @override
  State<PlayerSelectionDialog> createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filter players based on search
    final filteredBatters = widget.batters.where((b) {
      if (b.playerId == widget.excludePlayerId) return false;
      if (_searchQuery.isEmpty) return true;
      return b.playerName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredBowlers = widget.bowlers.where((b) {
      if (b.playerId == widget.excludePlayerId) return false;
      if (_searchQuery.isEmpty) return true;
      return b.playerName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: EdgeInsets.all(12.w),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search player...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Player list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.showBatters && filteredBatters.isNotEmpty) ...[
                    _buildSectionHeader('Batters'),
                    ...filteredBatters.map((b) => _buildBatterTile(b)),
                  ],
                  if (widget.showBowlers && filteredBowlers.isNotEmpty) ...[
                    _buildSectionHeader('Bowlers'),
                    ...filteredBowlers.map((b) => _buildBowlerTile(b)),
                  ],
                  if (filteredBatters.isEmpty && filteredBowlers.isEmpty) ...[
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.person_add, size: 48.sp, color: Colors.grey),
                            SizedBox(height: 12.h),
                            Text('No players found', style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 8.h),
                            Text('Add a new player below', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Add Player Button
            Padding(
              padding: EdgeInsets.all(12.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddPlayerDialog(context),
                  icon: Icon(Icons.person_add),
                  label: const Text('Add New Player'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAddPlayerDialog(BuildContext context) async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Player'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Player Name',
            hintText: 'Enter player name',
            border: OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // Create a new player and return it
      final playerId = 'p_${DateTime.now().millisecondsSinceEpoch}';
      if (widget.showBatters) {
        Navigator.pop(context, {
          'type': 'batter',
          'player': BatterStats(playerId: playerId, playerName: result),
          'isNew': true,
        });
      } else if (widget.showBowlers) {
        Navigator.pop(context, {
          'type': 'bowler',
          'player': BowlerStats(playerId: playerId, playerName: result),
          'isNew': true,
        });
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: Colors.grey[100],
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildBatterTile(BatterStats batter) {
    final isOut = batter.isOut;
    final isPlaying = batter.isPlaying;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isOut
            ? Colors.red.shade100
            : isPlaying
                ? AppTheme.primaryOrange.withOpacity(0.2)
                : Colors.grey.shade200,
        child: Text(
          batter.playerName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: isOut ? Colors.red : AppTheme.primaryOrange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        batter.playerName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isOut ? Colors.grey : Colors.black87,
          decoration: isOut ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        isOut
            ? '${batter.runs}(${batter.balls}) - OUT'
            : isPlaying
                ? '${batter.runs}(${batter.balls}) - On crease'
                : 'Yet to bat',
        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
      ),
      trailing: isOut
          ? Icon(Icons.close, color: Colors.red, size: 18.sp)
          : isPlaying
              ? Icon(Icons.sports_cricket, color: AppTheme.primaryOrange, size: 18.sp)
              : null,
      enabled: !isOut,
      onTap: isOut
          ? null
          : () => Navigator.pop(context, {
                'type': 'batter',
                'player': batter,
              }),
    );
  }

  Widget _buildBowlerTile(BowlerStats bowler) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: bowler.isBowling
            ? Colors.red.shade100
            : Colors.grey.shade200,
        child: Text(
          bowler.playerName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: bowler.isBowling ? Colors.red : Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        bowler.playerName,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${bowler.oversDisplay}-${bowler.maidens}-${bowler.runs}-${bowler.wickets}',
        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
      ),
      trailing: bowler.isBowling
          ? Icon(Icons.sports_baseball, color: Colors.red, size: 18.sp)
          : null,
      onTap: () => Navigator.pop(context, {
        'type': 'bowler',
        'player': bowler,
      }),
    );
  }
}

/// Dialog for selecting new batsman after wicket
class NewBatsmanDialog extends StatelessWidget {
  final List<BatterStats> availableBatters;
  final String teamName;

  const NewBatsmanDialog({
    super.key,
    required this.availableBatters,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to only show batters who haven't batted yet
    final yetToBat = availableBatters.where((b) => !b.isOut && !b.isPlaying).toList();

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
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Text(
                    'Select New Batsman',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
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
                      child: Text('No batters available'),
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
                          title: Text(
                            batter.playerName,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
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

/// Dialog for changing bowler at end of over
class ChangeBowlerDialog extends StatelessWidget {
  final List<BowlerStats> bowlers;
  final String? currentBowlerId;
  final String? lastOverBowlerId; // Can't bowl consecutive overs

  const ChangeBowlerDialog({
    super.key,
    required this.bowlers,
    this.currentBowlerId,
    this.lastOverBowlerId,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out the bowler who just finished the over
    final availableBowlers = bowlers.where((b) => b.playerId != lastOverBowlerId).toList();

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
                color: Colors.red.shade400,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.sports_baseball, color: Colors.white, size: 32.sp),
                  SizedBox(height: 8.h),
                  Text(
                    'Select Next Bowler',
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
                itemCount: availableBowlers.length,
                itemBuilder: (context, index) {
                  final bowler = availableBowlers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text(
                        bowler.playerName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      bowler.playerName,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${bowler.oversDisplay}-${bowler.maidens}-${bowler.runs}-${bowler.wickets} | Eco: ${bowler.economy.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
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

/// Dialog for innings change
class InningsChangeDialog extends StatelessWidget {
  final String team1Name;
  final String team2Name;
  final int team1Score;
  final int team1Wickets;
  final double team1Overs;
  final bool isFirstInningsComplete;

  const InningsChangeDialog({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.team1Score,
    required this.team1Wickets,
    required this.team1Overs,
    this.isFirstInningsComplete = true,
  });

  @override
  Widget build(BuildContext context) {
    final target = team1Score + 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 48.sp, color: AppTheme.primaryOrange),
            SizedBox(height: 16.h),
            Text(
              'End of Innings',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24.h),

            // First innings summary
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Text(
                    team1Name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '$team1Score/$team1Wickets (${team1Overs.toStringAsFixed(1)} Overs)',
                    style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),
            Icon(Icons.arrow_downward, color: Colors.grey),
            SizedBox(height: 16.h),

            // Target info
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.primaryOrange),
              ),
              child: Column(
                children: [
                  Text(
                    team2Name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Target: $target',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: const Text('Start 2nd Innings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
