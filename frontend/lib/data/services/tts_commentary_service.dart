import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/match_model.dart';

/// AI-powered Text-to-Speech commentary service for live cricket matches.
/// Generates rich, dynamic cricket commentary and speaks it aloud.
class TtsCommentaryService {
  // Singleton
  static TtsCommentaryService? _instance;
  static TtsCommentaryService get instance =>
      _instance ??= TtsCommentaryService._();
  TtsCommentaryService._();

  final FlutterTts _tts = FlutterTts();
  bool _isEnabled = false;
  bool _isInitialized = false;
  final Random _random = Random();

  bool get isEnabled => _isEnabled;

  /// Initialize TTS engine with cricket-friendly settings
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.1);
      await _tts.setVolume(1.0);
      _isInitialized = true;
      debugPrint('🔊 TTS Commentary Service initialized');
    } catch (e) {
      debugPrint('❌ TTS init error: $e');
    }
  }

  /// Toggle commentary on/off
  Future<bool> toggle() async {
    if (!_isInitialized) await init();
    _isEnabled = !_isEnabled;
    if (!_isEnabled) {
      await stop();
    }
    debugPrint('🔊 TTS Commentary ${_isEnabled ? "ON" : "OFF"}');
    return _isEnabled;
  }

  /// Enable commentary
  Future<void> enable() async {
    if (!_isInitialized) await init();
    _isEnabled = true;
  }

  /// Disable commentary
  Future<void> disable() async {
    _isEnabled = false;
    await stop();
  }

  /// Stop current speech
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('❌ TTS stop error: $e');
    }
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    try {
      await _tts.stop(); // Stop any ongoing speech
      await _tts.speak(text);
    } catch (e) {
      debugPrint('❌ TTS speak error: $e');
    }
  }

  /// Generate and speak AI commentary for a ball event
  Future<void> commentOnBall(BallEvent event, {String? batsmanName, String? bowlerName}) async {
    if (!_isEnabled) return;
    final commentary = generateCommentary(event, batsmanName: batsmanName, bowlerName: bowlerName);
    await speak(commentary);
  }

  /// Generate rich AI-style commentary from a ball event
  String generateCommentary(BallEvent event, {String? batsmanName, String? bowlerName}) {
    final batsman = batsmanName ?? 'Batsman';
    final bowler = bowlerName ?? 'Bowler';
    
    // Format: [Over].[Ball] [Bowler] to [Batsman], [Event Summary]. [Exciting Line]
    // overNumber assumed to be 0-indexed (0.1, 0.2, etc.)
    final String prefix = '${event.overNumber}.${event.ballNumber} $bowler to $batsman, ';
    
    String eventSummary = '';
    String excitingLine = '';

    // Wicket
    if (event.wicket != null) {
      eventSummary = 'Wicket';
      excitingLine = _pickRandom([
        'OUT! Clean bowled! Danda ukhad diya!',
        'Gone! In the air... and taken! He has to walk back!',
        'Wicket! Aree baap re, what a delivery!',
        'Run out! Total confusion and he is gone!',
        'Edged and gone! Keeper makes no mistake!',
        'That\'s the end of him! Bowler is absolutely pumped!',
        'Cleaned him up! The stumps tell the story!',
        'Oh no! A disaster for the batting team!',
        'Caught! He failed to get the distance!',
        'Up goes the finger! Umpire says OUT!',
      ]);
    }
    // Six
    else if (event.runs == 6 && event.extraType == null) {
      eventSummary = 'Six runs';
      excitingLine = _pickRandom([
        'That is huge! Gone out of the park!',
        'Aree wah! What a connection! Massive six!',
        'Maximum! Sends this one into orbit!',
        'Boom! Sweet sound off the bat!',
        'Gagon chumbi chakka! That ball is not coming back!',
        'Stand and deliver! Pure power!',
        'Monster hit! Crowd is loving this!',
        'Dispatched! Punished over square leg!',
        'High and handsome! Dealing in boundaries!',
        'Oh my goodness! Smashed onto the roof!',
      ]);
    }
    // Four
    else if (event.runs == 4 && event.extraType == null) {
      eventSummary = 'Four runs';
      excitingLine = _pickRandom([
        'Cracking shot through the covers! Classy!',
        'Rocket! Raced to the fence like a bullet!',
        'Gap dhunda aur char run! Smashing shot!',
        'Beautiful timing! Just a push and it\'s four!',
        'Slapped through point! No chance for the fielder!',
        'Swept away for four! Played very smartly!',
        'Straight down the ground! One bounce over the rope!',
        'Misfield and four! Bowler won\'t be happy!',
        'Cut away elegantly past backward point!',
        'Full toss and punished!',
      ]);
    }
    // Wide
    else if (event.extraType == 'wide') {
      eventSummary = 'Wide ball';
      excitingLine = _pickRandom([
        'Way outside off stump, umpire stretches his arms.',
        'Too short and too high! Wide called.',
        'Direction radar is off! Extra run.',
        'Poor line. That one is a wide.',
        'Slips down the leg side, easy wide.',
      ]);
    }
    // No ball
    else if (event.extraType == 'no-ball') {
      eventSummary = 'No ball';
      excitingLine = _pickRandom([
        'Overstepping the line! Free hit coming up!',
        'Siren blowing! Bowler crossed the line!',
        'That\'s a crime in cricket! No ball!',
        'Dangerous bowling, No ball called!',
        'Huge no ball. Free hit loading!',
      ]);
    }
    // Dot ball
    else if (event.runs == 0 && event.extraType == null) {
      eventSummary = 'Dot ball';
      excitingLine = _pickRandom([
        'Good tight bowling!',
        'Straight to the fielder. No run.',
        'Beaten! Lovely delivery outside off!',
        'Swing and a miss! Completely deceived!',
        'Solid defense. Respecting the good ball.',
        'Bouncer! Ducks under it nicely.',
        'Golden dot ball! Pressure building!',
        'Hit hard to the fielder! No single there.',
        'Beauty! Zooms past the edge!',
        'No run. Asking tough questions!',
      ]);
    }
    // Singles/Doubles/Triples
    else {
      eventSummary = '${event.runs} run${event.runs != 1 ? "s" : ""}';
      if (event.runs == 1) {
        excitingLine = _pickRandom([
          'Quick single! Chalo chalo, good running!',
          'Tapped for a single.',
          'Direct hit missed! Cheeky single!',
          'Pushed to long-on for one.',
          'Edged but safe! Single taken.',
          'Rotating the strike nicely.',
          'Drop and run! Excellent call.',
        ]);
      } else if (event.runs == 2) {
        excitingLine = _pickRandom([
          'Brilliant placement in the gap!',
          'Running hard! Converting one into two!',
          'Great fielding saves two runs!',
          'Whipped away for a couple.',
          'Dangerous running but they make it!',
        ]);
      } else if (event.runs == 3) {
        excitingLine = _pickRandom([
          'Superb athleticism! Three runs!',
          'Stopped inside the rope! They run three!',
          'Poor fielding allows the third!',
        ]);
      } else {
        excitingLine = 'Good running between the wickets.';
      }
    }
    
    // Combine for final output
    return '$prefix$eventSummary. $excitingLine';
  }

  /// Announce the score summary
  Future<void> announceScore({
    required String teamName,
    required int runs,
    required int wickets,
    required double overs,
  }) async {
    if (!_isEnabled) return;
    final text = '$teamName are $runs for $wickets after ${overs.toStringAsFixed(1)} overs.';
    await speak(text);
  }

  /// Announce innings change
  Future<void> announceInningsChange({
    required String battingTeamName,
    required int target,
  }) async {
    if (!_isEnabled) return;
    final text = 'End of innings! $battingTeamName need $target runs to win!';
    await speak(text);
  }

  String _pickRandom(List<String> options) {
    return options[_random.nextInt(options.length)];
  }

  /// Dispose the TTS engine
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
    _instance = null;
  }
}
