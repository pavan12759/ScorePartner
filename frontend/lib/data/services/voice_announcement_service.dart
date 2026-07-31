import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Supported languages for AI voice commentary
enum CommentaryLanguage {
  english('en-IN', 'English'),
  telugu('te-IN', 'తెలుగు'),
  hindi('hi-IN', 'हिंदी'),
  tamil('ta-IN', 'தமிழ்'),
  malayalam('ml-IN', 'മലയാളം');

  const CommentaryLanguage(this.code, this.displayName);
  final String code;
  final String displayName;
}

/// Service for AI voice announcements during cricket matches.
/// Supports English, Telugu, Hindi, Tamil, and Malayalam.
class VoiceAnnouncementService {
  static final VoiceAnnouncementService _instance = VoiceAnnouncementService._internal();
  factory VoiceAnnouncementService() => _instance;
  VoiceAnnouncementService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isEnabled = true;
  CommentaryLanguage _currentLanguage = CommentaryLanguage.english;
  final Random _random = Random();

  // ═══════════════════════════════════════════════════════════════
  // COMMENTARY PHRASES
  // ═══════════════════════════════════════════════════════════════

  /// SIX (6 RUNS) phrases
  static const Map<CommentaryLanguage, List<String>> _sixPhrases = {
    CommentaryLanguage.english: [
      "What a six by the batsman! Massive hit!",
      "Sixerrrr! That's out of the park!",
    ],
    CommentaryLanguage.telugu: [
      "అయ్యో! సిక్సర్ రా బాబు! అదిరిపోయింది!",
      "సిక్సర్! స్టేడియం దద్దరిల్లింది!"
    ],
    CommentaryLanguage.hindi: [
      "छक्का! क्या शानदार शॉट!",
      "बॉल गई स्टेडियम के बाहर!",
    ],
    CommentaryLanguage.tamil: [
      "சிக்ஸர்! அசத்தலான அடிப்பு!",
      "பந்து மைதானத்துக்கு வெளியே!",
    ],
    CommentaryLanguage.malayalam: [
      "സിക്സർ! അതിശയകരമായ ഷോട്ട്!",
      "പന്ത് സ്റ്റേഡിയത്തിന് പുറത്തേക്ക്!"
    ],
  };

  /// FOUR (4 RUNS) phrases
  static const Map<CommentaryLanguage, List<String>> _fourPhrases = {
    CommentaryLanguage.english: [
      "Four! Beautiful timing!",
      "Cracking shot to the boundary!",
    ],
    CommentaryLanguage.telugu: [
      "ఫోర్! అద్భుతమైన షాట్!",
      "బౌండరీ దాకా వెళ్లింది!",
    ],
    CommentaryLanguage.hindi: [
      "चौका! शानदार टाइमिंग!",
      "बाउंड्री के पार!",
    ],
    CommentaryLanguage.tamil: [
      "போர்! அருமையான ஷாட்!",
      "பவுண்டரி!",
    ],
    CommentaryLanguage.malayalam: [
      "ഫോർ! മനോഹരമായ ഷോട്ട്!",
      "ബൗണ്ടറി നേടി!",
    ],
  };

  /// WICKET phrases
  static const Map<CommentaryLanguage, List<String>> _wicketPhrases = {
    CommentaryLanguage.english: [
      "Wicket! He is gone!",
      "That's a big breakthrough!",

    ],
    CommentaryLanguage.telugu: [
      "వికెట్! ఆట అయిపోయింది!",
      "ముఖ్యమైన వికెట్ పడింది!",
    ],
    CommentaryLanguage.hindi: [
      "विकेट! बल्लेबाज़ आउट!",
      "बड़ा झटका!",
    ],
    CommentaryLanguage.tamil: [
      "விக்கெட்! அவுட்!",
      "முக்கிய விக்கெட்!",
    ],
    CommentaryLanguage.malayalam: [
      "വിക്കറ്റ്! പുറത്തായി!",
      "വലിയ ബ്രേക്ക് ത്രൂ!",
    ],
  };

  /// NO BALL phrases
  static const Map<CommentaryLanguage, List<String>> _noBallPhrases = {
    CommentaryLanguage.english: [
      "No ball! Free hit coming!",
      "No ball! Extra run!",
    ],
    CommentaryLanguage.telugu: [
      "నో బాల్! ఫ్రీ హిట్!",
    ],
    CommentaryLanguage.hindi: [
      "नो बॉल! फ्री हिट!",
    ],
    CommentaryLanguage.tamil: [
      "நோ பால்! ஃப்ரீ ஹிட்!",
    ],
    CommentaryLanguage.malayalam: [
      "നോ ബോൾ! ഫ്രീ ഹിറ്റ്!",
    ],
  };

  /// WIDE BALL phrases
  static const Map<CommentaryLanguage, List<String>> _widePhrases = {
    CommentaryLanguage.english: [
      "Wide ball!",
      "That's a wide! Extra run!",
    ],
    CommentaryLanguage.telugu: [
      "వైడ్ బాల్!",
    ],
    CommentaryLanguage.hindi: [
      "वाइड बॉल!",
    ],
    CommentaryLanguage.tamil: [
      "வைடு பால்!",
    ],
    CommentaryLanguage.malayalam: [
      "വൈഡ് ബോൾ!",
    ],
  };

  /// FIFTY (50 RUNS) phrases
  static const Map<CommentaryLanguage, List<String>> _fiftyPhrases = {
    CommentaryLanguage.english: [
      "Fifty! What an innings!",
      "Half century! Brilliant batting!",
    ],
    CommentaryLanguage.telugu: [
      "ఫిఫ్టీ! అదిరిపోయిన ఇన్నింగ్స్!",
    ],
    CommentaryLanguage.hindi: [
      "अर्धशतक! शानदार पारी!",
    ],
    CommentaryLanguage.tamil: [
      "அரை சதம்! அருமை!",
    ],
    CommentaryLanguage.malayalam: [
      "അർധശതകം! മികച്ച ഇന്നിംഗ്സ്!",
    ],
  };

  /// CENTURY (100 RUNS) phrases
  static const Map<CommentaryLanguage, List<String>> _centuryPhrases = {
    CommentaryLanguage.english: [
      "Century! What an incredible innings!",
      "Hundred runs! Magnificent batting!",
    ],
    CommentaryLanguage.telugu: [
      "సెంచరీ! అద్భుతమైన ఇన్నింగ్స్!",
    ],
    CommentaryLanguage.hindi: [
      "शतक! शानदार शतक!",
    ],
    CommentaryLanguage.tamil: [
      "சதம்! அற்புதமான ஆட்டம்!",
    ],
    CommentaryLanguage.malayalam: [
      "ശതകം! അതിശയകരമായ ഇന്നിംഗ്സ്!",
    ],
  };

  /// MATCH WON phrases
  static const Map<CommentaryLanguage, List<String>> _matchWonPhrases = {
    CommentaryLanguage.english: [
      "What a victory! Brilliant performance!",
      "They've won the match!",
      "Match over! Champions!",
    ],
    CommentaryLanguage.telugu: [
      "అద్భుతమైన విజయం! మ్యాచ్ గెలిచారు!",
      "చారిత్రక విజయం!",
    ],
    CommentaryLanguage.hindi: [
      "शानदार जीत! मैच जीत लिया!",
      "क्या मुकाबला था!",
    ],
    CommentaryLanguage.tamil: [
      "அற்புதமான வெற்றி!",
      "முடிவில் வெற்றி பெற்றனர்!",
    ],
    CommentaryLanguage.malayalam: [
      "അദ്ഭുതമായ വിജയം!",
      "മത്സരം ജയിച്ചു!",
    ],
  };

  /// HAT-TRICK phrases
  static const Map<CommentaryLanguage, List<String>> _hatTrickPhrases = {
    CommentaryLanguage.english: [
      "Hat-trick! Three wickets in three balls!",
      "Unbelievable! Hat-trick!",
    ],
    CommentaryLanguage.telugu: [
      "హ్యాట్రిక్! మూడు బంతుల్లో మూడు వికెట్లు!",
    ],
    CommentaryLanguage.hindi: [
      "हैट-ट्रिक! तीन गेंदों में तीन विकेट!",
    ],
    CommentaryLanguage.tamil: [
      "ஹாட்ரிக்! மூன்று பந்துகளில் மூன்று விக்கெட்!",
    ],
    CommentaryLanguage.malayalam: [
      "ഹാട്രിക്! മൂന്ന് പന്തുകളിൽ മൂന്ന് വിക്കറ്റ്!",
    ],
  };

  // ═══════════════════════════════════════════════════════════════
  // SERVICE METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _flutterTts = FlutterTts();
      
      // Configure TTS settings - Fast, Clear & Male Voice for cricket commentary!
      await _flutterTts!.setLanguage(_currentLanguage.code);
      await _flutterTts!.setSpeechRate(0.85);  // Fast and clear
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(0.9);  // Lower pitch for male voice
      
      // Try to set male voice if available
      await _setMaleVoice();
      
      _isInitialized = true;
      debugPrint('Voice announcement service initialized with ${_currentLanguage.displayName} (Male Voice)');
    } catch (e) {
      debugPrint('Failed to initialize TTS: $e');
      _isInitialized = false;
    }
  }

  /// Try to set a male voice for the current language
  Future<void> _setMaleVoice() async {
    if (_flutterTts == null) return;
    
    try {
      // Get available voices
      List<dynamic> voices = await _flutterTts!.getVoices;
      
      // Find a male voice for the current language
      for (var voice in voices) {
        if (voice is Map) {
          String? voiceName = voice['name']?.toString().toLowerCase() ?? '';
          String? locale = voice['locale']?.toString() ?? '';
          
          // Check if voice matches current language and is male
          if (locale.contains(_currentLanguage.code.split('-')[0]) ||
              locale.contains(_currentLanguage.code)) {
            // Look for male voice indicators
            if (voiceName.contains('male') || 
                voiceName.contains('man') ||
                voiceName.contains('guy') ||
                !voiceName.contains('female') && !voiceName.contains('woman')) {
              await _flutterTts!.setVoice({"name": voice['name'], "locale": locale});
              debugPrint('Set male voice: ${voice['name']}');
              return;
            }
          }
        }
      }
      debugPrint('Using default voice with male pitch');
    } catch (e) {
      debugPrint('Could not set male voice: $e');
    }
  }

  /// Set the commentary language
  Future<void> setLanguage(CommentaryLanguage language) async {
    _currentLanguage = language;
    if (_flutterTts != null && _isInitialized) {
      await _flutterTts!.setLanguage(language.code);
      await _flutterTts!.setPitch(0.9);  // Keep male pitch
      await _setMaleVoice();  // Re-apply male voice for new language
    }
    debugPrint('Commentary language changed to: ${language.displayName} (Male Voice)');
  }

  CommentaryLanguage get currentLanguage => _currentLanguage;

  /// Enable or disable voice announcements
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  bool get isEnabled => _isEnabled;

  /// Get a random phrase from the list
  String _getRandomPhrase(Map<CommentaryLanguage, List<String>> phrases) {
    final languagePhrases = phrases[_currentLanguage] ?? phrases[CommentaryLanguage.english]!;
    return languagePhrases[_random.nextInt(languagePhrases.length)];
  }

  /// Speak the given text
  Future<void> _speak(String text) async {
    if (!_isEnabled || !_isInitialized || _flutterTts == null) return;
    
    try {
      await _flutterTts!.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EVENT ANNOUNCEMENTS
  // ═══════════════════════════════════════════════════════════════

  /// Announce a SIX
  Future<void> announceSix([String? batsmanName]) async {
    final phrase = _getRandomPhrase(_sixPhrases);
    if (batsmanName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase by $batsmanName!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce a FOUR
  Future<void> announceFour([String? batsmanName]) async {
    final phrase = _getRandomPhrase(_fourPhrases);
    if (batsmanName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase by $batsmanName!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce a WICKET
  Future<void> announceWicket([String? batsmanName, String? bowlerName]) async {
    final phrase = _getRandomPhrase(_wicketPhrases);
    if (batsmanName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase $batsmanName is out!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce NO BALL
  Future<void> announceNoBall() async {
    final phrase = _getRandomPhrase(_noBallPhrases);
    await _speak(phrase);
  }

  /// Announce WIDE BALL
  Future<void> announceWide() async {
    final phrase = _getRandomPhrase(_widePhrases);
    await _speak(phrase);
  }

  /// Announce FIFTY (50 runs)
  Future<void> announceFifty([String? batsmanName]) async {
    final phrase = _getRandomPhrase(_fiftyPhrases);
    if (batsmanName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase by $batsmanName!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce CENTURY (100 runs)
  Future<void> announceCentury([String? batsmanName]) async {
    final phrase = _getRandomPhrase(_centuryPhrases);
    if (batsmanName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase by $batsmanName!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce MATCH WON
  Future<void> announceMatchWon([String? teamName]) async {
    final phrase = _getRandomPhrase(_matchWonPhrases);
    if (teamName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase $teamName wins!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce HAT-TRICK
  Future<void> announceHatTrick([String? bowlerName]) async {
    final phrase = _getRandomPhrase(_hatTrickPhrases);
    if (bowlerName != null && _currentLanguage == CommentaryLanguage.english) {
      await _speak("$phrase by $bowlerName!");
    } else {
      await _speak(phrase);
    }
  }

  /// Announce new over
  Future<void> announceNewOver(int overNumber, [String? bowlerName]) async {
    if (_currentLanguage == CommentaryLanguage.english) {
      final text = bowlerName != null 
          ? "Over $overNumber. $bowlerName to bowl."
          : "Over $overNumber starting.";
      await _speak(text);
    }
  }

  /// Announce runs needed
  Future<void> announceRunsNeeded(int runs, int balls) async {
    if (_currentLanguage == CommentaryLanguage.english) {
      await _speak("$runs runs needed from $balls balls!");
    }
  }

  /// Custom announcement
  Future<void> customAnnouncement(String text) async {
    await _speak(text);
  }

  /// Stop any ongoing speech
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  /// Dispose the TTS engine
  Future<void> dispose() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _isInitialized = false;
    }
  }

  /// Get list of available languages
  List<CommentaryLanguage> get availableLanguages => CommentaryLanguage.values;
}
