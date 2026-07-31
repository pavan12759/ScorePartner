import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_model.dart';

/// Player Selection Screen - Select Playing 11 for a team
class PlayerSelectionScreen extends StatefulWidget {
  final String teamName;
  final List<String> existingPlayers;
  final Function(List<BatterStats>) onPlayersSelected;

  const PlayerSelectionScreen({
    super.key,
    required this.teamName,
    this.existingPlayers = const [],
    required this.onPlayersSelected,
  });

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  final List<TextEditingController> _controllers = [];
  final List<BatterStats> _players = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Start with 2 players (opening pair), can add up to 11
    _addPlayer();
    _addPlayer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_controllers.length < 11) {
      setState(() {
        _controllers.add(TextEditingController());
      });
    }
  }

  void _removePlayer(int index) {
    if (_controllers.length > 2) {
      setState(() {
        _controllers[index].dispose();
        _controllers.removeAt(index);
      });
    }
  }

  void _submitPlayers() {
    if (_formKey.currentState!.validate()) {
      final players = <BatterStats>[];
      for (int i = 0; i < _controllers.length; i++) {
        final name = _controllers[i].text.trim();
        if (name.isNotEmpty) {
          players.add(BatterStats(
            playerId: 'player_${DateTime.now().millisecondsSinceEpoch}_$i',
            playerName: name,
            isPlaying: i < 2, // First 2 are opening batsmen
            isOnStrike: i == 0, // First batter on strike
          ));
        }
      }
      widget.onPlayersSelected(players);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.teamName} Playing XI'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _controllers.length >= 2 ? _submitPlayers : null,
            icon: Icon(Icons.check, color: Colors.white),
            label: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Info Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              color: Colors.amber.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Add at least 2 players. First 2 will be opening batsmen.',
                      style: TextStyle(color: Colors.amber[900], fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),

            // Player Count
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Players: ${_controllers.length}/11',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                  if (_controllers.length < 11)
                    TextButton.icon(
                      onPressed: _addPlayer,
                      icon: Icon(Icons.add),
                      label: const Text('Add Player'),
                    ),
                ],
              ),
            ),

            // Player List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index < 2 ? AppTheme.primaryOrange : Colors.grey[300],
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index < 2 ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: TextFormField(
                        controller: _controllers[index],
                        decoration: InputDecoration(
                          hintText: index < 2 ? 'Opening Batsman ${index + 1}' : 'Player ${index + 1} Name',
                          border: InputBorder.none,
                        ),
                        validator: (val) {
                          if (index < 2 && (val == null || val.isEmpty)) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                      trailing: _controllers.length > 2
                          ? IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () => _removePlayer(index),
                            )
                          : null,
                      subtitle: index < 2
                          ? Text(
                              index == 0 ? '🏏 On Strike' : '🏃 Non-Striker',
                              style: TextStyle(fontSize: 12.sp, color: Colors.green),
                            )
                          : null,
                    ),
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
