import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/sqlite_helper.dart';

class RawCollector {
  static const MethodChannel _channel = MethodChannel('com.neurotrace/raw_events');

  static void setupMethodChannel() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == "storeRawEvent") {
        final Map args = Map<String, dynamic>.from(call.arguments);
        final packageName = args['packageName'] as String;
        final eventType = args['eventType'] as int;

        await storeSystemEvent(packageName, eventType);
      }
    });
  }

  /// Specialized method for System Events (Phase 1)
  static Future<void> storeSystemEvent(String eventName, int eventType) async {
    try {
      final db = await SQLiteHelper.instance.database;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await db.insert('raw_system_events', {
        'timestamp': timestamp,
        'event_type': eventName, // Stores 'system_event'
        'value': eventType,      // Stores the code (1, 2, or 3)
      });

      debugPrint("Logged system event: $eventName (Value: $eventType)");
    } catch (e) {
      debugPrint("Error logging system event: $e");
    }
  }
}