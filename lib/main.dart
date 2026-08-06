// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';

import 'core/database/sqlite_helper.dart';
import 'core/theme.dart';
import 'features/collection/raw_collector.dart';
import 'ui/welcome_page.dart';
import 'ui/dashboard_page.dart';
import 'telemetry_sync_engine.dart';

/// ⚡ HEADLESS BACKGROUND WORKER ⚡
/// This must remain a top-level function. It wakes up independently of the app UI.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("==========================================");
    debugPrint("🟢 [WorkManager] Worker Started: Task = $task");

    try {
      // 1. Re-initialize Flutter Engine
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint("🟢 [WorkManager] Flutter Engine Bound");

      // 2. Re-initialize Firebase for this isolated background thread
      await Firebase.initializeApp();
      debugPrint("🟢 [WorkManager] Firebase Initialized Background Instance");

      // 3. Fetch the ID securely
      final prefs = await SharedPreferences.getInstance();
      final participantId = prefs.getString('research_id') ?? '';

      if (participantId.isEmpty) {
        debugPrint("🔴 [WorkManager] Participant ID missing. Aborting Task.");
        return Future.value(false);
      }
      debugPrint("🟢 [WorkManager] Participant ID found: $participantId");

      // 4. Match the exact task name registered in dashboard_page.dart
      if (task == "syncTelemetryData") {
        debugPrint("🟢 [WorkManager] Sync Started for $participantId. Fetching pending records...");
        final syncEngine = TelemetrySyncEngine();
        await syncEngine.syncPendingData(participantId);
        debugPrint("🟢 [WorkManager] Sync Finished Successfully.");
      } else {
        debugPrint("🟡 [WorkManager] Unknown task name received: $task");
      }

      debugPrint("🟢 [WorkManager] Worker Finished. Returning to sleep.");
      debugPrint("==========================================");
      return Future.value(true);

    } catch (e, stackTrace) {
      debugPrint("🔴 [WorkManager] Worker Failed Exception: $e");
      debugPrint("🔴 [WorkManager] StackTrace: $stackTrace");
      debugPrint("==========================================");
      return Future.value(false);
    }
  });
}

void main() async {
  // 1. Ensure Flutter engine bindings are completely ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. INITIALIZE WORKMANAGER FIRST
  // Isolated in its own try/catch so it never gets skipped if DB/Firebase fails
  try {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // SET TO TRUE TO SEE WORKMANAGER NOTIFICATIONS
    );
    debugPrint("NeuroTrace: Workmanager initialized successfully.");
  } catch (e) {
    debugPrint("NeuroTrace: CRITICAL - Workmanager initialization failed: $e");
  }

  // 3. Initialize Firebase & Database
  try {
    await Firebase.initializeApp();
    debugPrint("NeuroTrace_Firebase: Initialization Successful.");

    // Disable offline persistence to force real-time network errors during debug
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    debugPrint("NeuroTrace_Firebase: Offline cache disabled for debugging.");

    await SQLiteHelper.instance.database;
    RawCollector.setupMethodChannel();
  } catch (e) {
    debugPrint("NeuroTrace: Warning during core dependencies init: $e");
  }

  // 4. Identity & Onboarding Status Configuration
  final prefs = await SharedPreferences.getInstance();
  String participantId = prefs.getString('research_id') ?? '';

  if (participantId.isEmpty) {
    participantId = const Uuid().v4();
    await prefs.setString('research_id', participantId);
    debugPrint("Initialized new Research Participant ID: $participantId");
  } else {
    debugPrint("Loaded existing Research Participant ID: $participantId");
  }

  // Evaluate platform onboarding completion status
  final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  // NOTE: Registration of the periodic task is now correctly handled inside DashboardPage.
  runApp(NeuroTraceApp(
    isCompleted: onboardingCompleted,
    participantId: participantId,
  ));
}

class NeuroTraceApp extends StatelessWidget {
  final bool isCompleted;
  final String participantId;

  const NeuroTraceApp({
    super.key,
    required this.isCompleted,
    required this.participantId,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NeuroTrace V2',
      theme: NeuroTheme.darkTheme,
      home: isCompleted ? const DashboardPage() : WelcomePage(participantId: participantId),
    );
  }
}