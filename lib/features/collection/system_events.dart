import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SystemEventCollector {
  static const MethodChannel _channel = MethodChannel('com.neurotrace/system_events');

  static void setupMethodChannel() {
    _channel.setMethodCallHandler((MethodCall call) async {
      // ARCHITECTURE UPDATE:
      // System broadcasts are now saved directly to SQLite by the native EventReceiver.kt.
      // This receiver just acts as a debug monitor so you can see events in your Flutter terminal.
      // No data is written to the database from this file.

      if (call.method == "storeSystemEvent") {
        final Map<String, dynamic> args = Map<String, dynamic>.from(call.arguments);
        debugPrint("⚡ [SYSTEM EVENT] Broadcast intercepted and stored natively: ${args['eventType']}");
      }
    });
  }
}