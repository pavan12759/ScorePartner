
const fs = require('fs');
let code = fs.readFileSync('lib/data/services/firebase_data_service.dart', 'utf8');

const highlightMethods = 

  // ==================== MATCH HIGHLIGHTS ====================

  /// Saves a generated match highlight image to Firestore (as a base64 string)
  /// and updates the MatchModel's highlights list
  Future<bool> saveMatchHighlight({
    required String matchId,
    required MatchHighlight highlight,
    required Uint8List imageBytes,
  }) async {
    try {
      debugPrint('?? Match Highlight upload starting — raw size: \ bytes');

      // Convert to base64 data URL
      final base64Image = base64Encode(imageBytes);
      final dataUrl = 'data:image/png;base64,\';
      
      // The highlight object must have the imageUrl set to the dataUrl
      final finalHighlight = MatchHighlight(
        id: highlight.id,
        imageUrl: dataUrl,
        type: highlight.type,
        title: highlight.title,
        description: highlight.description,
        playerId: highlight.playerId,
        playerName: highlight.playerName,
        createdAt: highlight.createdAt,
      );

      await _db.collection(matchesCollection).doc(matchId).update({
        'highlights': FieldValue.arrayUnion([finalHighlight.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('? Match highlight saved successfully!');
      return true;
    } catch (e) {
      debugPrint('? Error saving match highlight: \');
      return false;
    }
  }
;

const lastBracePos = code.lastIndexOf('}');
if (lastBracePos !== -1) {
    let newCode = code.substring(0, lastBracePos) + highlightMethods + '\n}\n';
    fs.writeFileSync('lib/data/services/firebase_data_service.dart', newCode);
    console.log('Injected saveMatchHighlight successfully.');
} else {
    console.log('Failed to find closing brace');
}

