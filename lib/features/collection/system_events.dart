import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import '../../core/database/sqlite_helper.dart';

class SystemEventCollector {
  // A dedicated Method Channel for system-level broadcasts.
  // ignore: unused_field
  static const MethodChannel _channel = MethodChannel('com.neurotrace/system_events');

  // Called from native Android BroadcastReceivers (e.g., ACTION_SCREEN_ON)
  static Future<void> storeSystemEvent(String eventType, {int? value}) async {
    try {
      final db = await SQLiteHelper.instance.database;

      // Precise immutable timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await db.insert('raw_system_events', {
        'timestamp': timestamp,
        'event_type': eventType,
        'value': value ?? 0, // 0 if no specific value is passed
      });

      debugPrint("Logged system event: $eventType (Value: ${value ?? 0})");
    } catch (e) {
      debugPrint("Error logging system event: $e");
    }
  }
}