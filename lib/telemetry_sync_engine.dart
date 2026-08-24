import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'core/database/sqlite_helper.dart';

class TelemetrySyncEngine {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncPendingData(String participantId) async {
    debugPrint("🛠️ [SYNC_ENGINE] 1. Starting RAW SQLite background sync for: $participantId");

    try {
      final db = await SQLiteHelper.instance.database;
      debugPrint("🛠️ [SYNC_ENGINE] 2. SQLite Database instance acquired.");

      // Swapped to new Raw Telemetry schemas
      final List<String> tables = [
        'raw_usage_events',
        'raw_usage_stats',
        'raw_system_events',
      ];

      List<Map<String, dynamic>> allPendingEvents = [];
      Map<String, List<int>> pendingIdsByTable = {};

      for (String table in tables) {
        debugPrint("🛠️ [SYNC_ENGINE] 3. Scanning table: $table for unsynced records...");
        final List<Map<String, dynamic>> rows = await db.query(
          table,
          where: 'sync_status != ?',
          whereArgs: [1],
          limit: 300, // Slightly increased limit for higher data volume
        );

        if (rows.isNotEmpty) {
          List<int> ids = [];
          for (var row in rows) {
            Map<String, dynamic> cleanRow = Map<String, dynamic>.from(row);
            cleanRow['source_table'] = table;
            ids.add(cleanRow['id'] as int);
            allPendingEvents.add(cleanRow);
          }
          pendingIdsByTable[table] = ids;
          debugPrint("🛠️ [SYNC_ENGINE] 3a. Found ${ids.length} pending events in $table.");
        }
      }

      if (allPendingEvents.isEmpty) {
        debugPrint("✅ [SYNC_ENGINE] 4. SQLite database is completely synced. No pending data.");
        return;
      }

      debugPrint("🛠️ [SYNC_ENGINE] 4. Compiling Firestore Payload with ${allPendingEvents.length} total events.");
      String batchUuid = "batch_${DateTime.now().millisecondsSinceEpoch}";
      final Map<String, dynamic> firestorePayload = {
        'uploaded_at': FieldValue.serverTimestamp(),
        'batch_id': batchUuid,
        'participant_id': participantId,
        'event_count': allPendingEvents.length,
        'events': allPendingEvents,
      };

      debugPrint("🛠️ [SYNC_ENGINE] 5. Initiating Cloud Firestore Network Upload...");
      await _firestore
          .collection('research_participants')
          .doc(participantId)
          .collection('telemetry_batches')
          .doc(batchUuid)
          .set(firestorePayload);

      debugPrint("✅ [SYNC_ENGINE] 6. Firebase network upload successful!");

      debugPrint("🛠️ [SYNC_ENGINE] 7. Opening SQLite Transaction to update sync_status...");
      await db.transaction((txn) async {
        for (var entry in pendingIdsByTable.entries) {
          String tableName = entry.key;
          List<int> ids = entry.value;

          if (ids.isNotEmpty) {
            String idPlaceholders = ids.map((_) => '?').join(',');
            await txn.rawUpdate(
              'UPDATE $tableName SET sync_status = 1 WHERE id IN ($idPlaceholders)',
              ids,
            );
          }
        }
      });

      debugPrint("✅ [SYNC_ENGINE] 8. Local sync_status update complete. Cycle finished.");

    } catch (e) {
      debugPrint("❌ [SYNC_ENGINE] FATAL ERROR IN SYNC PIPELINE: $e");

      try {
        final db = await SQLiteHelper.instance.database;
        final int now = DateTime.now().millisecondsSinceEpoch;
        final List<String> tables = ['raw_usage_events', 'raw_usage_stats', 'raw_system_events'];

        for (String table in tables) {
          await db.rawUpdate(
            'UPDATE $table SET sync_status = 2, retry_count = retry_count + 1, last_sync_attempt = ? WHERE sync_status = 0',
            [now],
          );
        }
        debugPrint("⚠️ [SYNC_ENGINE] Records marked as FAILED (status=2) for future retry.");
      } catch (dbError) {
        debugPrint("🚨 [SYNC_ENGINE] CRITICAL DB ERROR DURING FAILURE RECOVERY: $dbError");
      }

      // Rethrow to ensure WorkManager catches it and marks the background job as failed
      rethrow;
    }
  }
}