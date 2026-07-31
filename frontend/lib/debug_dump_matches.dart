import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> dumpMatchData() async {
  try {
    debugPrint('🔍 DUMPING MATCH DATA...');
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('matches').limit(5).get();
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      debugPrint('--- Match: ${doc.id} (${data['matchName']}) ---');
      debugPrint('Status: ${data['status']}');
      debugPrint('PlayerIds: ${data['playerIds']}');
      
      final team1 = data['team1Score'] ?? {};
      final batters = team1['batters'] as List? ?? [];
      for (var b in batters) {
        debugPrint('  Batter: ${b['playerName']} (ID: ${b['playerId']})');
      }
      
      final bowlers = team1['bowlers'] as List? ?? [];
      for (var b in bowlers) {
        debugPrint('  Bowler: ${b['playerName']} (ID: ${b['playerId']})');
      }
    }
    debugPrint('🏁 DUMP COMPLETE');
  } catch (e) {
    debugPrint('❌ DUMP ERROR: $e');
  }
}
