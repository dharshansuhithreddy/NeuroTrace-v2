import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class RawCollector {
  static const MethodChannel _channel = MethodChannel('com.neurotrace/raw_events');

  static void setupMethodChannel() {
    _channel.setMethodCallHandler((MethodCall call) async {
      // ARCHITECTURE UPDATE:
      // The Native Kotlin layer (CollectionService.kt) now handles all SQLite database insertions directly.
      // This Flutter channel remains open purely for optional real-time debugging in the console.
      // No data is written to the database from this file to prevent duplicate records.

      if (call.method == "storeRawUsageEvent") {
        debugPrint("📡 [NATIVE BINDING] Raw Usage Event collected and stored natively.");
      } else if (call.method == "storeUsageStats") {
        debugPrint("📡 [NATIVE BINDING] Raw Usage Stats collected and stored natively.");
      }
    });
  }
}