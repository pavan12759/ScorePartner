import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/firebase_data_service.dart';
import '../../../core/theme/app_theme.dart';

class GoLiveScreen extends StatefulWidget {
  final String? preselectedMatchId;

  const GoLiveScreen({super.key, this.preselectedMatchId});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMatchId;
  MatchModel? _selectedMatch;
  bool _isLoading = false;
  bool _isSaving = false;
  List<MatchModel> _liveMatches = [];

  final _youtubeUrlController = TextEditingController();
  final _channelNameController = TextEditingController();
  String _selectedTheme = 'classic';
  bool _overlayEnabled = true;

  final Map<String, String> _themes = {
    'classic': 'ScorePartner Classic',
    'stadium-night': 'Stadium Night',
    'glass-broadcast': 'Glass Broadcast',
    'cricket-green': 'Cricket Green',
  };

  @override
  void initState() {
    super.initState();
    _selectedMatchId = widget.preselectedMatchId;
    _loadMatches();
  }

  @override
  void dispose() {
    _youtubeUrlController.dispose();
    _channelNameController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }
      final allMatches = await FirebaseDataService.instance.getUserMatches(uid);
      final matches = allMatches.where((m) => m.status == 'live' || m.status == 'in-progress').toList();
      
      setState(() {
        _liveMatches = matches;
        _isLoading = false;
      });

      if (_selectedMatchId != null) {
        final match = _liveMatches.firstWhere((m) => m.id == _selectedMatchId);
        _onMatchSelected(match);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onMatchSelected(MatchModel match) {
    setState(() {
      _selectedMatchId = match.id;
      _selectedMatch = match;
      _youtubeUrlController.text = match.youtubeLiveUrl ?? '';
      _channelNameController.text = match.youtubeChannelName ?? '';
      _selectedTheme = match.overlayTheme ?? 'classic';
      _overlayEnabled = match.overlayEnabled;
    });
  }

  Future<void> _saveBroadcastSettings() async {
    if (!_formKey.currentState!.validate() || _selectedMatchId == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseDataService.instance.updateMatch(_selectedMatchId!, {
        'youtubeLiveUrl': _youtubeUrlController.text.trim(),
        'youtubeChannelName': _channelNameController.text.trim(),
        'overlayTheme': _selectedTheme,
        'overlayEnabled': _overlayEnabled,
        'isBroadcasting': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast settings saved! Viewers can now watch live.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _stopBroadcast() async {
    if (_selectedMatchId == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseDataService.instance.updateMatch(_selectedMatchId!, {
        'isBroadcasting': false,
        'youtubeLiveUrl': null,
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _copyOverlayUrl() {
    if (_selectedMatchId == null) return;
    // Replace this with the actual production domain later
    final url = 'https://scorepartner.in/live/$_selectedMatchId/overlay?theme=$_selectedTheme';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OBS Overlay URL copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Broadcast Setup'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Match Selection
                    Text('Select Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      value: _selectedMatchId,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _liveMatches.map((m) {
                        return DropdownMenuItem(
                          value: m.id,
                          child: Text('${m.team1Name} vs ${m.team2Name}'),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          final match = _liveMatches.firstWhere((m) => m.id == id);
                          _onMatchSelected(match);
                        }
                      },
                      validator: (val) => val == null ? 'Please select a match' : null,
                    ),
                    SizedBox(height: 24.h),

                    // YouTube Settings
                    Text('YouTube Live URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _youtubeUrlController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'https://youtube.com/live/...',
                        prefixIcon: Icon(Icons.link, color: Colors.red),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'URL is required';
                        if (!val.contains('youtube.com') && !val.contains('youtu.be')) {
                          return 'Must be a valid YouTube URL';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    Text('YouTube Channel Name (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: _channelNameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g. ScorePartner Sports',
                        prefixIcon: Icon(Icons.tv),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Overlay Settings
                    Text('OBS Overlay Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      value: _selectedTheme,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _themes.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTheme = val);
                      },
                    ),
                    SizedBox(height: 16.h),

                    SwitchListTile(
                      title: const Text('Enable Overlay Engine'),
                      subtitle: const Text('Allow the web overlay to receive real-time score updates'),
                      value: _overlayEnabled,
                      onChanged: (val) => setState(() => _overlayEnabled = val),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryOrange,
                    ),
                    SizedBox(height: 24.h),

                    // OBS Setup Instructions
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade800),
                              SizedBox(width: 8.w),
                              Text('OBS Studio Setup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          const Text('1. Copy the Overlay URL below.'),
                          const Text('2. In OBS, add a new "Browser" source.'),
                          const Text('3. Paste the URL. Set Width to 1920 and Height to 1080.'),
                          const Text('4. Check "Transparent Background".'),
                          SizedBox(height: 12.h),
                          ElevatedButton.icon(
                            onPressed: _selectedMatchId == null ? null : _copyOverlayUrl,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy OBS Overlay URL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveBroadcastSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SAVE & ENABLE BROADCAST', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    if (_selectedMatch?.isBroadcasting == true)
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _stopBroadcast,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          child: const Text('STOP BROADCAST', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
