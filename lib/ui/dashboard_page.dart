// lib/ui/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart'; // Import for background task registration
import '../telemetry_sync_engine.dart'; // Adjust path if needed

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _rawResearchId = "";
  String _displayResearchId = "Loading...";
  String _totalEvents = "0";
  String _validatedSessions = "0";
  bool _isCollectorActive = false;

  // Unified communication channel to the native Android telemetry engine
  static const platform = MethodChannel('com.neurotrace_v2.telemetry');

  @override
  void initState() {
    super.initState();
    _loadResearchId();
    _autoStartService();
    _refreshTelemetry();
    _ensureBackgroundSyncRegistered(); // Locks in the sync schedule immediately
  }

  /// 🟢 PRODUCTION BACKGROUND SYNC REGISTRATION
  void _ensureBackgroundSyncRegistered() {
    Workmanager().registerPeriodicTask(
      "neurotrace-periodic-sync", // Unique task name
      "syncTelemetryData",        // Task label (must match task in callbackDispatcher)
      frequency: const Duration(hours: 2), // Minimum allowed by Android is 15 minutes
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run if internet is available
      ),
      // 'keep' ensures we don't restart the timer every time the dashboard is opened
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    debugPrint("🟢 [WorkManager] Registered Periodic Task: neurotrace-periodic-sync");
  }

  /// Loads and safely formats the participant UUID for the dashboard UI
  Future<void> _loadResearchId() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString('research_id') ?? "Unknown";
    setState(() {
      _rawResearchId = uuid; // Store raw ID for the Sync Engine
      if (uuid == "Unknown") {
        _displayResearchId = uuid;
      } else {
        // Keeping secure truncation logic (NT-XXXX) for display purposes
        _displayResearchId = "NT-${uuid.substring(0, 8).toUpperCase()}";
      }
    });
  }

  /// Automatically requests the native side to spin up the CollectionService
  Future<void> _autoStartService() async {
    try {
      await platform.invokeMethod('startService');
      setState(() {
        _isCollectorActive = true;
      });
      debugPrint("NeuroTrace: Background service auto-started successfully.");
    } on PlatformException catch (e) {
      debugPrint("NeuroTrace: Failed to auto-start service - ${e.message}");
      setState(() {
        _isCollectorActive = false;
      });
    }
  }

  /// Silently pulls exact database row counts from the local SQLite instance
  Future<void> _refreshTelemetry() async {
    try {
      final Map<dynamic, dynamic>? stats = await platform.invokeMethod('getOperationalStats');

      if (mounted && stats != null) {
        setState(() {
          _totalEvents = (stats['total_events'] ?? 0).toString();
          _validatedSessions = (stats['validated_sessions'] ?? 0).toString();
          if (stats.containsKey('is_service_running')) {
            _isCollectorActive = stats['is_service_running'];
          }
        });
      }
    } on PlatformException catch (e) {
      debugPrint("NeuroTrace: Failed to fetch telemetry - ${e.message}");
      if (mounted) {
        setState(() {
          _totalEvents = "Error";
          _validatedSessions = "Error";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Research Terminal"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Participant ID Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.badge, color: Color(0xFF7C4DFF), size: 32),
                title: const Text("Participant ID", style: TextStyle(fontSize: 14, color: Colors.grey)),
                subtitle: Text(
                    _displayResearchId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Telemetry Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildStatusCard(
                    "Collection",
                    _isCollectorActive ? "Active" : "Paused",
                    _isCollectorActive ? Icons.play_circle_fill : Icons.pause_circle_filled,
                    _isCollectorActive ? Colors.green : Colors.orange
                ),
                _buildStatusCard("Raw Events", _totalEvents, Icons.memory, Colors.blue),
                _buildStatusCard("Validated Apps", _validatedSessions, Icons.fact_check, Colors.teal),
                _buildStatusCard("Firebase Sync", "Active", Icons.cloud_done, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),

            // Refresh Button Only
            ElevatedButton.icon(
              onPressed: _refreshTelemetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Stats"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1E1E24),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            // Footer Message
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.health_and_safety, size: 56, color: Colors.grey),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        "Thank you for contributing to digital wellbeing research. Your data is collected anonymously and stored securely.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Force Sync Button strictly contained inside the Dashboard
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_rawResearchId.isNotEmpty && _rawResearchId != "Unknown") {
            debugPrint("🔄 FORCE SYNC CLICKED: Initializing Engine...");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Initiating secure cloud sync..."), duration: Duration(seconds: 2)),
            );
            final syncEngine = TelemetrySyncEngine();
            await syncEngine.syncPendingData(_rawResearchId);
          }
        },
        icon: const Icon(Icons.cloud_upload),
        label: const Text("Force Sync"),
        backgroundColor: Colors.tealAccent.shade400,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}