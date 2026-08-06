import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class BackgroundService {
  // Method Channel to communicate with the Android Foreground Service
  static const MethodChannel _channel = MethodChannel('com.neurotrace/background_service');

  // Start the native Foreground Service
  static Future<void> startService() async {
    try {
      await _channel.invokeMethod('startService');
      debugPrint("Background service started successfully.");
    } on PlatformException catch (e) {
      // Replaced 'print' with 'debugPrint' to fix avoid_print warning
      debugPrint("Failed to start background service: '${e.message}'.");
    }
  }

  // Stop the collection service
  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopService');
      debugPrint("Background service stopped.");
    } on PlatformException catch (e) {
      debugPrint("Failed to stop background service: '${e.message}'.");
    }
  }
}