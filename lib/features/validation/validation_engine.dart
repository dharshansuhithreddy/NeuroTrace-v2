import 'package:flutter/foundation.dart';
import '../../core/database/sqlite_helper.dart';

class ValidationEngine {
  static const List<String> _blacklistedKeywords = [
    'systemui', 'launcher', 'wallpaper', 'keyboard', 'inputmethod', 'nexuslauncher', 'trebuchet', 'neurotrace'
  ];

  static Future<void> processRawEvents() async {
    final db = await SQLiteHelper.instance.database;
    final List<Map<String, dynamic>> rawEvents = await db.query(
      'raw_usage_events',
      orderBy: 'timestamp ASC',
    );

    debugPrint("ValidationEngine: Processing ${rawEvents.length} events.");

    // Map to keep track of the last seen 'foreground' event for each package
    Map<String, Map<String, dynamic>> openSessions = {};

    for (var event in rawEvents) {
      String packageName = event['package_name'] as String;
      int eventType = event['event_type'] as int; // Assuming 1 = Foreground, 2 = Background
      int timestamp = event['timestamp'] as int;

      if (!passesPackageFilter(packageName)) continue;

      if (eventType == 1) { // Foreground start
        openSessions[packageName] = event;
      } else if (eventType == 2 && openSessions.containsKey(packageName)) { // Background end
        final startEvent = openSessions.remove(packageName)!;

        // Calculate duration and insert into validated_sessions
        int duration = timestamp - (startEvent['timestamp'] as int);

        await db.insert('validated_sessions', {
          'research_id': 'ANON-UUID-001', // TODO: Fetch from SharedPreferences
          'package_name': packageName,
          'start_time': startEvent['timestamp'],
          'end_time': timestamp,
          'duration': duration,
          'sync_status': 0
        });
        debugPrint("ValidationEngine: Validated session for $packageName: ${duration}ms");
      }
    }
  }

  static bool passesPackageFilter(String packageName) {
    final lowerCase = packageName.toLowerCase();
    return !_blacklistedKeywords.any((keyword) => lowerCase.contains(keyword));
  }
}