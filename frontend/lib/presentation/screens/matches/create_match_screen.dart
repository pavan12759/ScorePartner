import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/match_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../matches/live_scoring_screen.dart';
import '../../widgets/qr_scanner_screen.dart';
import '../../widgets/places_autocomplete_field.dart';

class CreateMatchScreen extends StatefulWidget {
  final TournamentModel? tournament;
  final List<TeamModel>? tournamentTeams;

  const CreateMatchScreen({
    super.key, 
    this.tournament,
    this.tournamentTeams,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _team1NameController = TextEditingController();
  final _team2NameController = TextEditingController();
  final _team1SptIdController = TextEditingController();
  final _team2SptIdController = TextEditingController();
  final _venueController = TextEditingController();
  final _oversController = TextEditingController(text: '10');
  final _powerPlayController = TextEditingController(text: '6');

  bool _isLoading = false;
  bool _isLookingUpTeam1 = false;
  bool _isLookingUpTeam2 = false;
  String _matchType = 'Tennis Ball';
  final List<String> _matchTypes = ['Tennis Ball', 'Leather Ball'];

  // Match Format (T20, ODI, Test)
  String _matchFormat = 'T20';
  final List<String> _matchFormats = ['T20', 'ODI', 'Test', 'Custom'];

  // Geo-coordinates
  double? _venueLatitude;
  double? _venueLongitude;

  // Stores full team data
  TeamModel? _team1Data;
  TeamModel? _team2Data;

  String? _team1CaptainId;
  String? _team1VCId;
  String? _team2CaptainId;
  String? _team2VCId;
  String? _team1KeeperId;
  String? _team2KeeperId;

  // Manual team selection from dropdown (for tournaments)
  String? _selectedTeam1Id;
  String? _selectedTeam2Id;

  // Match Stage Selection
  String _selectedStage = 'League Match';
  final List<String> _stages = [
    'League Match',
    'Group Stage',
    'Knockout',
    'Round of 16',
    'Quarter Final',
    'Semi Final',
    'Final',
    'Qualifier 1',
    'Eliminator',
    'Qualifier 2',
    'Third Place',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tournament != null) {
      _venueController.text = widget.tournament!.location;
      _oversController.text = widget.tournament!.overs.toString();
      _matchType = widget.tournament!.ballType == 'leather' ? 'Leather Ball' : 'Tennis Ball';
      _matchFormat = widget.tournament!.matchFormat;
    }
  }

  void _onFormatChanged(String format) {
    setState(() {
      _matchFormat = format;
      if (format != 'Custom') {
        final defaults = MatchModel.getFormatDefaults(format);
        _oversController.text = (defaults['overs'] as int).toString();
      }
    });
  }

  @override
  void dispose() {
    _team1NameController.dispose();
    _team2NameController.dispose();
    _team1SptIdController.dispose();
    _team2SptIdController.dispose();
    _venueController.dispose();
    _oversController.dispose();
    _powerPlayController.dispose();
    super.dispose();
  }

  Future<void> _lookupTeam(int teamNumber) async {
    final controller = teamNumber == 1 ? _team1SptIdController : _team2SptIdController;
    final sptId = controller.text.trim().toUpperCase();
    if (sptId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an SPT ID to search')),
      );
      return;
    }

    setState(() {
      if (teamNumber == 1) _isLookingUpTeam1 = true;
      else _isLookingUpTeam2 = true;
    });

    try {
      final teamData = await FirebaseDataService.instance.getTeamBySptId(sptId);
      _handleTeamFound(teamNumber, teamData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (teamNumber == 1) _isLookingUpTeam1 = false;
          else _isLookingUpTeam2 = false;
        });
      }
    }
  }

  void _onTournamentTeamSelected(int teamNumber, String? teamId) {
    if (teamId == null) return;
    
    final teamData = widget.tournamentTeams?.firstWhere((t) => t.id == teamId);
    if (teamData != null) {
      setState(() {
        if (teamNumber == 1) _selectedTeam1Id = teamId;
        else _selectedTeam2Id = teamId;
      });
      _handleTeamFound(teamNumber, teamData);
    }
  }

  void _handleTeamFound(int teamNumber, TeamModel? teamData) {
    if (teamData != null) {
      setState(() {
        if (teamNumber == 1) {
          _team1Data = teamData;
          _team1NameController.text = teamData.name;
          _team1SptIdController.text = teamData.spTId; 
          _team1CaptainId = teamData.players.firstWhere((p) => p.isCaptain, orElse: () => teamData.players.first).userId;
          _team1VCId = teamData.players.where((p) => p.isViceCaptain).firstOrNull?.userId;
        } else {
          _team2Data = teamData;
          _team2NameController.text = teamData.name;
          _team2SptIdController.text = teamData.spTId;
          _team2CaptainId = teamData.players.firstWhere((p) => p.isCaptain, orElse: () => teamData.players.first).userId;
          _team2VCId = teamData.players.where((p) => p.isViceCaptain).firstOrNull?.userId;
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team not found'), backgroundColor: Colors.orange),
      );
    }
  }

  void _createMatch() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation for tournament teams
    if (widget.tournament != null) {
      if (_team1Data == null || _team2Data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both teams from the dropdown')),
        );
        return;
      }
      if (_team1Data!.id == _team2Data!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select different teams')),
        );
        return;
      }
    } else {
       // Manual Match - Strict check for team data
       if (_team1Data == null || _team2Data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid team data. Please search again using SPT ID.')),
        );
        return;
      }
    }

    // Toss Selection Dialog
    String? tossWinner;
    String? tossDecision;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Toss'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Who won the toss?'),
              SizedBox(height: 16.h),
              Row(
                children: [
                   Expanded(
                    child: ChoiceChip(
                      label: Text(_team1NameController.text.isNotEmpty ? _team1NameController.text : 'Team 1'),
                      selected: tossWinner == 'team1',
                      onSelected: (val) => setDialogState(() => tossWinner = 'team1'),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(_team2NameController.text.isNotEmpty ? _team2NameController.text : 'Team 2'),
                      selected: tossWinner == 'team2',
                      onSelected: (val) => setDialogState(() => tossWinner = 'team2'),
                    ),
                  ),
                ],
              ),
              if (tossWinner != null) ...[
                SizedBox(height: 24.h),
                Text('${tossWinner == 'team1' ? _team1NameController.text : _team2NameController.text} elected to:'),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Bat'),
                        selected: tossDecision == 'bat',
                        onSelected: (val) => setDialogState(() => tossDecision = 'bat'),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Bowl'),
                        selected: tossDecision == 'bowl',
                        onSelected: (val) => setDialogState(() => tossDecision = 'bowl'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (tossWinner != null && tossDecision != null)
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Start Match'),
            ),
          ],
        ),
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;

      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;

        if (user == null) throw Exception('User not logged in');

        // Determine batting/bowling team
        String battingTeam;
        String bowlingTeam;

        if (tossWinner == 'team1') {
          if (tossDecision == 'bat') {
            battingTeam = 'team1';
            bowlingTeam = 'team2';
          } else {
            battingTeam = 'team2';
            bowlingTeam = 'team1';
          }
        } else {
          if (tossDecision == 'bat') {
            battingTeam = 'team2';
            bowlingTeam = 'team1';
          } else {
            battingTeam = 'team1';
            bowlingTeam = 'team2';
          }
        }

        List<BatterStats> team1Batters = [];
        List<BowlerStats> team1Bowlers = [];
        List<BatterStats> team2Batters = [];
        List<BowlerStats> team2Bowlers = [];
        
        // Helper to resolve player IDs proactively
        Future<List<String>> _resolveAll(List<TeamPlayer> players) async {
          return Future.wait(players.map((p) async {
            if (p.userId.isNotEmpty) return p.userId;
            final resolved = await FirebaseDataService.instance.resolveTemporaryPlayer('', p.name);
            return resolved?.uid ?? 'p_${p.name.replaceAll(' ', '_')}';
          }));
        }

        final t1ResolvedIds = await _resolveAll(_team1Data?.players ?? []);
        final t2ResolvedIds = await _resolveAll(_team2Data?.players ?? []);

        if (_team1Data != null) {
          for (int i = 0; i < _team1Data!.players.length; i++) {
            final player = _team1Data!.players[i];
            final resolvedId = t1ResolvedIds[i];
            team1Batters.add(BatterStats(playerId: resolvedId, playerName: player.name));
            team1Bowlers.add(BowlerStats(playerId: resolvedId, playerName: player.name));
          }
        }
        
        if (_team2Data != null) {
          for (int i = 0; i < _team2Data!.players.length; i++) {
            final player = _team2Data!.players[i];
            final resolvedId = t2ResolvedIds[i];
            team2Batters.add(BatterStats(playerId: resolvedId, playerName: player.name));
            team2Bowlers.add(BowlerStats(playerId: resolvedId, playerName: player.name));
          }
        }

        final match = MatchModel(
          id: '',
          matchName: '${_team1NameController.text} vs ${_team2NameController.text}',
          tournamentId: widget.tournament?.id,
          tournamentName: widget.tournament?.name,
          team1Id: _team1Data?.id ?? 't1',
          team2Id: _team2Data?.id ?? 't2',
          team1Name: _team1NameController.text.trim(),
          team2Name: _team2NameController.text.trim(),
          ground: _venueController.text.trim(),
          location: '',
          latitude: _venueLatitude,
          longitude: _venueLongitude,
          matchType: _matchType,
          oversPerSide: int.tryParse(_oversController.text) ?? 20,
          matchFormat: _matchFormat,
          powerplayConfig: _matchFormat == 'Custom'
              ? _buildCustomPowerplay()
              : (MatchModel.getFormatDefaults(_matchFormat)['powerplay'] as List<PowerplayPhase>),
          scheduledDate: DateTime.now(),
          status: 'live',
          currentInnings: 1,
          currentBattingTeam: battingTeam,
          bowlingTeam: bowlingTeam,
          currentOver: 0,
          currentBall: 0,
          team1Score: TeamScore(runs: 0, wickets: 0, overs: 0, batters: team1Batters, bowlers: team1Bowlers),
          team2Score: TeamScore(runs: 0, wickets: 0, overs: 0, batters: team2Batters, bowlers: team2Bowlers),
          ballByBall: [],
          createdBy: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tossWinnerId: tossWinner == 'team1' ? (_team1Data?.id ?? 't1') : (_team2Data?.id ?? 't2'),
          tossDecision: tossDecision,
          team1CaptainId: _team1CaptainId,
          team2CaptainId: _team2CaptainId,
          team1VCId: _team1VCId,
          team2VCId: _team2VCId,
          team1KeeperId: _team1KeeperId,
          team2KeeperId: _team2KeeperId,
          playerIds: {
            ...team1Batters.map((p) => p.playerId),
            ...team2Batters.map((p) => p.playerId),
          }.toList(),
        );

        // Save to Firebase
        final createdMatch = await FirebaseDataService.instance.createMatch(match, user.uid);

        if (createdMatch == null) {
          throw Exception('Failed to create match');
        }

        // If tournament match, add fixture to tournament
        if (widget.tournament != null) {
          final fixture = TournamentFixture(
            id: 'fix_${DateTime.now().millisecondsSinceEpoch}',
            team1Id: match.team1Id,
            team1Name: match.team1Name,
            team2Id: match.team2Id,
            team2Name: match.team2Name,
            round: _selectedStage, // Use selected stage
            roundNumber: 1,
            matchId: createdMatch.id,
            status: 'live',
            scheduledDate: DateTime.now(),
          );
          
          await FirebaseDataService.instance.addFixtureToTournament(widget.tournament!.id, fixture);
        }

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LiveScoringScreen(matchId: createdMatch.id)),
        );
      } catch (e, stack) {
        debugPrint('Error: $e, $stack');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create match: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  List<PowerplayPhase> _buildCustomPowerplay() {
    final ppOvers = int.tryParse(_powerPlayController.text) ?? 0;
    final totalOvers = int.tryParse(_oversController.text) ?? 20;
    if (ppOvers <= 0) return [];
    
    final phases = <PowerplayPhase>[
      PowerplayPhase(name: 'Powerplay', startOver: 1, endOver: ppOvers, maxFieldersOutside: 2),
    ];
    if (ppOvers < totalOvers) {
      phases.add(PowerplayPhase(name: 'Middle/Death Overs', startOver: ppOvers + 1, endOver: totalOvers, maxFieldersOutside: 5));
    }
    return phases;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tournament != null ? 'New Tournament Match' : 'New Match')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tournament != null 
                  ? 'Select Teams for ${widget.tournament!.name}'
                  : 'Select Teams', 
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)
              ),
              SizedBox(height: 12.h),
              
              _buildTeamInput(1),

              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0.h),
                child: Center(
                  child: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

              _buildTeamInput(2),

              SizedBox(height: 24.h),
              Text('Match Details', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),

              // Match Format Selector
              Text('Match Format', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
              SizedBox(height: 8.h),
              Row(
                children: _matchFormats.map((format) {
                  final isSelected = _matchFormat == format;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: format != 'Custom' ? 4 : 0),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(format, style: TextStyle(fontSize: 12.sp, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: format == 'T20'
                            ? Colors.green
                            : format == 'ODI'
                                ? Colors.blue
                                : format == 'Test'
                                    ? Colors.red
                                    : Colors.orange,
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey[300]!)),
                        onSelected: (_) => _onFormatChanged(format),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 4.h),
              Text(
                _matchFormat == 'T20'
                    ? '20 overs • PP: Ov 1-6 (2 out), Ov 7-20 (5 out)'
                    : _matchFormat == 'ODI'
                        ? '50 overs • PP1: 1-10, PP2: 11-40, PP3: 41-50'
                        : _matchFormat == 'Test'
                            ? 'Unlimited overs • 4 innings • New ball every 80 ov'
                            : 'Custom overs • Set powerplay below',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16.h),

              if (widget.tournament != null) ...[
                DropdownButtonFormField<String>(
                  value: _selectedStage,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Match Stage',
                    prefixIcon: Icon(Icons.emoji_events_outlined),
                  ),
                  items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _selectedStage = val!),
                ),
                SizedBox(height: 16.h),
              ],

              PlacesAutocompleteField(
                label: 'Venue / Ground',
                hint: 'Search ground name...',
                controller: _venueController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onPlaceSelected: (name, address, lat, lng) {
                  setState(() {
                    _venueLatitude = lat;
                    _venueLongitude = lng;
                  });
                },
              ),
              SizedBox(height: 16.h),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _matchType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ball Type'),
                      items: _matchTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _matchType = val!),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: TextFormField(
                      controller: _oversController,
                      keyboardType: TextInputType.number,
                      enabled: _matchFormat == 'Custom',
                      decoration: InputDecoration(
                        labelText: 'Overs',
                        prefixIcon: Icon(Icons.timer),
                        fillColor: _matchFormat == 'Custom' ? null : Colors.grey[100],
                        filled: _matchFormat != 'Custom',
                      ),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              // Powerplay Overs — only for Custom format
              if (_matchFormat == 'Custom') ...[
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _powerPlayController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Powerplay Overs',
                    prefixIcon: Icon(Icons.flash_on, color: Colors.amber),
                    hintText: 'e.g. 6',
                    helperText: 'Field restrictions apply during powerplay',
                    helperStyle: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return null;
                    final pp = int.tryParse(val);
                    if (pp == null || pp < 0) return 'Invalid';
                    final totalOvers = int.tryParse(_oversController.text) ?? 20;
                    if (pp > totalOvers) return 'Cannot exceed total overs';
                    return null;
                  },
                ),
              ],

              SizedBox(height: 48.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMatch,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16.h)),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Start Match', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInput(int teamNumber) {
    if (widget.tournament != null && widget.tournamentTeams != null) {
      // Dropdown for tournament matches
      return Card(
        elevation: 0,
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Team $teamNumber', style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                value: teamNumber == 1 ? _selectedTeam1Id : _selectedTeam2Id,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.groups),
                ),
                hint: const Text('Select Team'),
                items: widget.tournamentTeams!.map((team) => DropdownMenuItem(
                  value: team.id,
                  child: Text(team.name),
                )).toList(),
                onChanged: (val) => _onTournamentTeamSelected(teamNumber, val),
              ),
              if ((teamNumber == 1 ? _team1Data : _team2Data) != null) ...[
                SizedBox(height: 16.h),
                _buildTeamPlayersDetails(teamNumber),
              ],
            ],
          ),
        ),
      );
    }

    // Existing manual/SPT lookup UI
    final sptIdController = teamNumber == 1 ? _team1SptIdController : _team2SptIdController;
    final nameController = teamNumber == 1 ? _team1NameController : _team2NameController;
    final isLookingUp = teamNumber == 1 ? _isLookingUpTeam1 : _isLookingUpTeam2;
    final teamData = teamNumber == 1 ? _team1Data : _team2Data;

    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sptIdController,
                    decoration: InputDecoration(
                      hintText: 'Search SPT ID (Required)', // Updated hint
                      labelText: 'SPT ID',
                      prefixIcon: Icon(Icons.search, size: 20.sp),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.r),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan Team QR',
                  onPressed: isLookingUp ? null : () async {
                    final scannedCode = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                    );
                    
                    if (scannedCode != null && mounted) {
                      sptIdController.text = scannedCode;
                      _lookupTeam(teamNumber);
                    }
                  },
                ),
                SizedBox(width: 4.w),
                IconButton(
                  onPressed: isLookingUp ? null : () => _lookupTeam(teamNumber),
                  icon: isLookingUp
                      ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.arrow_forward_ios, size: 16.sp),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            TextFormField(
              controller: nameController,
              readOnly: true, // Make read-only
              decoration: InputDecoration(
                labelText: 'Team Name',
                hintText: 'Search via SPT ID',
                prefixIcon: Icon(Icons.group),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            
            if (teamData != null) ...[
              SizedBox(height: 16.h),
              _buildTeamPlayersDetails(teamNumber),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamPlayersDetails(int teamNumber) {
    final teamData = teamNumber == 1 ? _team1Data : _team2Data;
    if (teamData == null) return SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPlayerDropdown(
                label: 'Captain',
                players: teamData.players,
                value: teamNumber == 1 ? _team1CaptainId : _team2CaptainId,
                onChanged: (val) => setState(() {
                  if (teamNumber == 1) _team1CaptainId = val;
                  else _team2CaptainId = val;
                }),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildPlayerDropdown(
                label: 'Vice Captain',
                players: teamData.players,
                value: teamNumber == 1 ? _team1VCId : _team2VCId,
                onChanged: (val) => setState(() {
                  if (teamNumber == 1) _team1VCId = val;
                  else _team2VCId = val;
                }),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _buildPlayerDropdown(
          label: 'Wicket Keeper',
          players: teamData.players,
          value: teamNumber == 1 ? _team1KeeperId : _team2KeeperId,
          onChanged: (val) => setState(() {
            if (teamNumber == 1) _team1KeeperId = val;
            else _team2KeeperId = val;
          }),
        ),
      ],
    );
  }

  Widget _buildPlayerDropdown({
    required String label,
    required List<TeamPlayer> players,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: players.any((p) => p.userId == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      items: players.map((p) => DropdownMenuItem(
        value: p.userId,
        child: Text(p.name, style: TextStyle(fontSize: 13.sp), overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: onChanged,
    );
  }
}
