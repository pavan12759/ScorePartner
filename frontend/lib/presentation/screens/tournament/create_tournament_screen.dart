import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_model.dart';
import '../../widgets/qr_scanner_screen.dart';
import '../../widgets/places_autocomplete_field.dart';

/// Create Tournament Screen - Multi-step wizard
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxTeamsController = TextEditingController(text: '8');
  final _oversController = TextEditingController(text: '10');
  final _entryFeeController = TextEditingController(text: '0');
  final _prizePoolController = TextEditingController(text: '0');
  final _sptIdController = TextEditingController();
  final _powerPlayController = TextEditingController(text: '6'); // CricHeroes-like power play overs

  // Geo-coordinates
  double? _tournamentLatitude;
  double? _tournamentLongitude;

  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 14));
  String _format = 'knockout';
  String _matchFormat = 'T20'; // Match format (T20, ODI, Test)
  String _ballType = 'tennis';
  String _category = 'open'; // CricHeroes-like category
  bool _isLoading = false;
  bool _isSearching = false;

  final List<String> _formats = ['knockout', 'league', 'group'];
  final List<String> _matchFormats = ['T20', 'ODI', 'Test'];
  final List<String> _ballTypes = ['tennis', 'leather'];
  final List<String> _categories = ['open', 'corporate', 'box_cricket', 'series', 'community'];
  
  // Multi-step wizard state
  int _currentStep = 0;
  final List<TeamModel> _addedTeams = [];
  List<TournamentFixture> _generatedFixtures = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _maxTeamsController.dispose();
    _oversController.dispose();
    _entryFeeController.dispose();
    _prizePoolController.dispose();
    _sptIdController.dispose();
    _powerPlayController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _onMatchFormatChanged(String? format) {
    if (format != null) {
      setState(() {
        _matchFormat = format;
        final defaults = MatchModel.getFormatDefaults(format);
        _oversController.text = (defaults['overs'] as int).toString();
        // Also update powerplay if needed, but simplistic for now
      });
    }
  }

  Future<void> _searchTeamBySptId() async {
    final sptId = _sptIdController.text.trim().toUpperCase();
    if (sptId.isEmpty) return;

    // Check if already added
    if (_addedTeams.any((t) => t.spTId == sptId || t.id == sptId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team already added'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final team = await FirebaseDataService.instance.getTeamBySptId(sptId);
      if (team != null) {
        setState(() {
          _addedTeams.add(team);
          _sptIdController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: ${team.name}'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team not found with this SPT ID'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _removeTeam(TeamModel team) {
    setState(() {
      _addedTeams.remove(team);
    });
  }

  void _generateFixtures() {
    if (_addedTeams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 teams'), backgroundColor: Colors.orange),
      );
      return;
    }

    List<TournamentFixture> fixtures = [];

    switch (_format) {
      case 'knockout':
        fixtures = _generateKnockoutFixtures();
        break;
      case 'league':
        fixtures = _generateLeagueFixtures();
        break;
      case 'group':
        fixtures = _generateGroupFixtures();
        break;
    }

    setState(() {
      _generatedFixtures = fixtures;
      _currentStep = 2;
    });
  }

  List<TournamentFixture> _generateKnockoutFixtures() {
    List<TournamentFixture> fixtures = [];
    List<TeamModel> teams = List.from(_addedTeams);
    
    // Calculate number of rounds needed
    int roundNumber = 1;
    int fixtureId = 0;
    
    // First round - pair teams
    List<TeamModel> currentRound = teams;
    
    while (currentRound.length > 1) {
      String roundName;
      if (currentRound.length == 2) {
        roundName = 'Final';
      } else if (currentRound.length <= 4) {
        roundName = 'Semi-Final';
      } else if (currentRound.length <= 8) {
        roundName = 'Quarter-Final';
      } else {
        roundName = 'Round $roundNumber';
      }

      List<TeamModel> nextRound = [];
      
      for (int i = 0; i < currentRound.length; i += 2) {
        if (i + 1 < currentRound.length) {
          fixtures.add(TournamentFixture(
            id: 'fixture_${fixtureId++}',
            team1Id: currentRound[i].id,
            team1Name: currentRound[i].name,
            team2Id: currentRound[i + 1].id,
            team2Name: currentRound[i + 1].name,
            round: currentRound.length == 2 ? roundName : '$roundName ${(i ~/ 2) + 1}',
            roundNumber: roundNumber,
          ));
          // Placeholder for winner - first team as placeholder
          nextRound.add(currentRound[i]);
        } else {
          // Odd team gets bye
          nextRound.add(currentRound[i]);
        }
      }
      
      currentRound = nextRound;
      roundNumber++;
      
      // For preview, only show first round matches
      if (roundNumber > 1 && currentRound.length > 1) break;
    }

    return fixtures;
  }

  List<TournamentFixture> _generateLeagueFixtures() {
    List<TournamentFixture> fixtures = [];
    int fixtureId = 0;
    int roundNumber = 1;

    // Round-robin: each team plays every other team once
    for (int i = 0; i < _addedTeams.length; i++) {
      for (int j = i + 1; j < _addedTeams.length; j++) {
        fixtures.add(TournamentFixture(
          id: 'fixture_${fixtureId++}',
          team1Id: _addedTeams[i].id,
          team1Name: _addedTeams[i].name,
          team2Id: _addedTeams[j].id,
          team2Name: _addedTeams[j].name,
          round: 'Match ${fixtureId}',
          roundNumber: roundNumber,
        ));
      }
    }

    return fixtures;
  }

  List<TournamentFixture> _generateGroupFixtures() {
    List<TournamentFixture> fixtures = [];
    int fixtureId = 0;

    // Divide teams into groups (2 groups for 4+ teams)
    int numGroups = (_addedTeams.length >= 4) ? 2 : 1;
    int teamsPerGroup = (_addedTeams.length / numGroups).ceil();
    
    List<List<TeamModel>> groups = [];
    for (int g = 0; g < numGroups; g++) {
      int start = g * teamsPerGroup;
      int end = (start + teamsPerGroup).clamp(0, _addedTeams.length);
      if (start < _addedTeams.length) {
        groups.add(_addedTeams.sublist(start, end));
      }
    }

    // Generate group stage matches
    for (int g = 0; g < groups.length; g++) {
      String groupName = 'Group ${String.fromCharCode(65 + g)}'; // A, B, C...
      List<TeamModel> groupTeams = groups[g];
      
      for (int i = 0; i < groupTeams.length; i++) {
        for (int j = i + 1; j < groupTeams.length; j++) {
          fixtures.add(TournamentFixture(
            id: 'fixture_${fixtureId++}',
            team1Id: groupTeams[i].id,
            team1Name: groupTeams[i].name,
            team2Id: groupTeams[j].id,
            team2Name: groupTeams[j].name,
            round: groupName,
            roundNumber: 1,
            groupName: groupName,
          ));
        }
      }
    }

    // Add placeholder knockout matches (Semi-finals, Final)
    if (numGroups >= 2) {
      fixtures.add(TournamentFixture(
        id: 'fixture_${fixtureId++}',
        team1Id: 'TBD',
        team1Name: 'Winner Group A',
        team2Id: 'TBD',
        team2Name: 'Runner-up Group B',
        round: 'Semi-Final 1',
        roundNumber: 2,
      ));
      fixtures.add(TournamentFixture(
        id: 'fixture_${fixtureId++}',
        team1Id: 'TBD',
        team1Name: 'Winner Group B',
        team2Id: 'TBD',
        team2Name: 'Runner-up Group A',
        round: 'Semi-Final 2',
        roundNumber: 2,
      ));
      fixtures.add(TournamentFixture(
        id: 'fixture_${fixtureId++}',
        team1Id: 'TBD',
        team1Name: 'Winner SF1',
        team2Id: 'TBD',
        team2Name: 'Winner SF2',
        round: 'Final',
        roundNumber: 3,
      ));
    }

    return fixtures;
  }

  void _moveFixture(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final fixture = _generatedFixtures.removeAt(oldIndex);
      _generatedFixtures.insert(newIndex, fixture);
    });
  }

  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not logged in');
      }

      debugPrint('📋 Creating tournament with ${_addedTeams.length} teams and ${_generatedFixtures.length} fixtures');

      final tournament = TournamentModel(
        id: 'tournament_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        organizerId: user.uid,
        organizerName: user.name,
        location: _locationController.text.trim(),
        latitude: _tournamentLatitude,
        longitude: _tournamentLongitude,
        startDate: _startDate,
        endDate: _endDate,
        maxTeams: int.tryParse(_maxTeamsController.text) ?? 8,
        registeredTeamIds: _addedTeams.map((t) => t.id).toList(),
        status: 'upcoming',
        format: _format,
        matchFormat: _matchFormat,
        overs: int.tryParse(_oversController.text) ?? 10,
        ballType: _ballType,
        entryFee: double.tryParse(_entryFeeController.text) ?? 0,
        prizePool: double.tryParse(_prizePoolController.text) ?? 0,
        winnerId: '',
        runnerUpId: '',
        fixtures: _generatedFixtures,
        // CricHeroes-like fields
        category: _category,
        powerPlayOvers: int.tryParse(_powerPlayController.text) ?? 6,
        pointsTable: _generateInitialPointsTable(),
      );

      debugPrint('📋 Tournament data to save: ${tournament.toMap()}');

      final createdTournament = await FirebaseDataService.instance.createTournament(tournament, user.uid);
      
      if (createdTournament == null) {
        throw Exception('Failed to create tournament - service returned null');
      }
      
      debugPrint('✅ Tournament created in Firebase - ${tournament.name}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tournament created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating tournament: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step indicator
            _buildStepIndicator(),
            
            // Step content
            Expanded(
              child: _currentStep == 0
                  ? _buildStep1Details()
                  : _currentStep == 1
                      ? _buildStep2Teams()
                      : _buildStep3Fixtures(),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Tournament Details';
      case 1: return 'Add Teams';
      case 2: return 'Review Fixtures';
      default: return 'Create Tournament';
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepDot(0, 'Details'),
          _buildStepLine(0),
          _buildStepDot(1, 'Teams'),
          _buildStepLine(1),
          _buildStepDot(2, 'Fixtures'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    bool isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryOrange : Colors.grey[300],
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? Icon(Icons.check, color: Colors.white, size: 18.sp)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isActive ? AppTheme.primaryOrange : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    bool isActive = _currentStep > afterStep;
    return Container(
      width: 50.w,
      height: 3.h,
      margin: EdgeInsets.only(bottom: 20.h),
      color: isActive ? AppTheme.primaryOrange : Colors.grey[300],
    );
  }

  Widget _buildStep1Details() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Tournament Info'),
          SizedBox(height: 12.h),
          _buildTextField(
            controller: _nameController,
            label: 'Tournament Name',
            icon: Icons.emoji_events,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          SizedBox(height: 12.h),
          _buildTextField(
            controller: _descController,
            label: 'Description',
            icon: Icons.description,
            maxLines: 3,
          ),
          SizedBox(height: 12.h),
          PlacesAutocompleteField(
            label: 'Location',
            hint: 'Search city or ground...',
            controller: _locationController,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            onPlaceSelected: (name, address, lat, lng) {
              setState(() {
                _tournamentLatitude = lat;
                _tournamentLongitude = lng;
              });
            },
          ),
          
          // CricHeroes-like Tournament Category
          SizedBox(height: 12.h),
          _buildDropdown(
            'Category',
            _category,
            _categories,
            (v) => setState(() => _category = v!),
          ),

          SizedBox(height: 24.h),
          _buildSectionTitle('Schedule'),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker('Start Date', _startDate, () => _selectDate(true)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildDatePicker('End Date', _endDate, () => _selectDate(false)),
              ),
            ],
          ),

          SizedBox(height: 24.h),
          _buildSectionTitle('Match Settings'),
          SizedBox(height: 12.h),
          // Tournament Format
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  'Tournament Format',
                  _format,
                  _formats,
                  (v) => setState(() => _format = v!),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Match Format and Ball Type
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  'Match Format',
                  _matchFormat,
                  _matchFormats,
                  _onMatchFormatChanged,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildDropdown(
                  'Ball Type',
                  _ballType,
                  _ballTypes,
                  (v) => setState(() => _ballType = v!),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Overs and Max Teams
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _oversController,
                  label: 'Overs',
                  icon: Icons.timer,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildTextField(
                  controller: _maxTeamsController,
                  label: 'Max Teams',
                  icon: Icons.groups,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          
          // CricHeroes-like Power Play Configuration
          SizedBox(height: 12.h),
          _buildPowerPlaySection(),

          SizedBox(height: 24.h),
          _buildSectionTitle('Fees & Prizes'),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _entryFeeController,
                  label: 'Entry Fee (₹)',
                  icon: Icons.payments,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildTextField(
                  controller: _prizePoolController,
                  label: 'Prize Pool (₹)',
                  icon: Icons.monetization_on,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Teams() {
    return Column(
      children: [
        // Search by SPT ID
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sptIdController,
                  decoration: InputDecoration(
                    labelText: 'Enter Team SPT ID',
                    hintText: 'e.g. SPT12345678',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _searchTeamBySptId(),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                icon: Icon(Icons.qr_code_scanner),
                tooltip: 'Scan Team QR',
                onPressed: _isSearching ? null : () async {
                  final scannedCode = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                  
                  if (scannedCode != null && mounted) {
                    _sptIdController.text = scannedCode;
                    _searchTeamBySptId();
                  }
                },
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchTeamBySptId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isSearching
                    ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Teams count
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Added Teams: ${_addedTeams.length}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              Text(
                'Max: ${_maxTeamsController.text}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),

        // Added teams list
        Expanded(
          child: _addedTeams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_outlined, size: 64.sp, color: Colors.grey[300]),
                      SizedBox(height: 16.h),
                      Text('No teams added yet', style: TextStyle(color: Colors.grey[500], fontSize: 16.sp)),
                      SizedBox(height: 8.h),
                      Text('Enter SPT ID to add teams', style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _addedTeams.length,
                  itemBuilder: (context, index) {
                    final team = _addedTeams[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                          child: Text(
                            team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                            style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(team.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Captain: ${team.captainName} • ${team.players.length} players'),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeTeam(team),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStep3Fixtures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fixtures',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
                  ),
                  Text(
                    '${_format.toUpperCase()} format • ${_generatedFixtures.isEmpty ? "No matches yet" : "${_generatedFixtures.length} matches"}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              if (_generatedFixtures.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                     // Clear fixtures logic
                     setState(() {
                       _generatedFixtures.clear();
                     });
                  },
                  icon: Icon(Icons.clear_all, color: Colors.red),
                  label: const Text('Clear', style: TextStyle(color: Colors.red)),
                )
            ],
          ),
        ),
        
        if (_generatedFixtures.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sports_cricket, size: 48.sp, color: Colors.blue),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'No Fixtures Generated',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'You can create the tournament now effectively skipping fixture generation. Matches can be added manually later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 32.h),
                     OutlinedButton.icon(
                      onPressed: _generateFixtures,
                      icon: Icon(Icons.auto_awesome),
                      label: const Text('Auto-Generate Fixtures'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                        side: BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              'Drag to reorder matches',
              style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
            ),
          ),
          SizedBox(height: 8.h),

          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _generatedFixtures.length,
              onReorder: _moveFixture,
              itemBuilder: (context, index) {
                final fixture = _generatedFixtures[index];
                return Card(
                  key: ValueKey(fixture.id),
                  margin: EdgeInsets.only(bottom: 8.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  child: ListTile(
                    leading: Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: fixture.groupName != null 
                            ? Colors.blue.withOpacity(0.1) 
                            : AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: fixture.groupName != null ? Colors.blue : AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      '${fixture.team1Name} vs ${fixture.team2Name}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                    ),
                    subtitle: Text(
                      fixture.round,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
                    ),
                    trailing: Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  side: BorderSide(color: AppTheme.primaryOrange),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _getNextAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _getNextButtonText(),
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0: return 'Next: Add Teams';
      case 1: return 'Next: Fixtures'; // Changed from 'Generate Fixtures'
      case 2: return 'Create Tournament';
      default: return 'Next';
    }
  }

  VoidCallback? _getNextAction() {
    switch (_currentStep) {
      case 0:
        return () {
          if (_formKey.currentState!.validate()) {
            setState(() => _currentStep = 1);
          }
        };
      case 1:
        // Simply move to next step without generating fixtures automatically
        return () {
             setState(() => _currentStep = 2);
        };
      case 2:
        return _createTournament;
      default:
        return null;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryOrange,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        child: Text(
          '${date.day}/${date.month}/${date.year}',
          style: TextStyle(fontSize: 16.sp),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
      onChanged: onChanged,
    );
  }

  /// CricHeroes-like Power Play Configuration Section
  Widget _buildPowerPlaySection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: AppTheme.primaryOrange, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Power Play Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _powerPlayController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Power Play Overs',
                    hintText: 'e.g. 6 for T20',
                    prefixIcon: Icon(Icons.sports_cricket),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Only 2 fielders allowed outside 30-yard circle during power play',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  /// Generate initial points table for league/group tournaments
  List<TeamPoints> _generateInitialPointsTable() {
    if (_format == 'knockout') return [];
    
    return _addedTeams.map((team) => TeamPoints(
      teamId: team.id,
      teamName: team.name,
    )).toList();
  }
}
