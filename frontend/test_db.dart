import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("==== STARTING DB CHECK ====");
  try {
    final matches = await FirebaseFirestore.instance.collection('matches').limit(5).get();
    debugPrint("Total matches pulled: \${matches.docs.length}");
    for (var doc in matches.docs) {
      final data = doc.data();
      debugPrint("Match ID: \${doc.id}");
      debugPrint("Status: \${data['status']}");
      debugPrint("Player IDs exist? \${data.containsKey('playerIds')}");
      if (data.containsKey('playerIds')) {
        debugPrint("Player IDs len: \${(data['playerIds'] as List).length}");
      }
    }
  } catch (e) {
    debugPrint("Error: \$e");
  }
}
