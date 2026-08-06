import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _acknowledged = false;

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!context.mounted) return;

    // Remove all previous routes and go to Dashboard
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Required Permissions")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.analytics, color: Color(0xFF7C4DFF)),
              title: Text("Usage Access"),
              subtitle: Text("Collects app usage duration and sessions."),
            ),
            const ListTile(
              leading: Icon(Icons.notifications, color: Color(0xFF7C4DFF)),
              title: Text("Notifications"),
              subtitle: Text("Ensures the collection service stays active."),
            ),
            const ListTile(
              leading: Icon(Icons.battery_saver, color: Color(0xFF7C4DFF)),
              title: Text("Battery Optimization"),
              subtitle: Text("Prevents Android from stopping collection."),
            ),
            const ListTile(
              leading: Icon(Icons.apps, color: Color(0xFF7C4DFF)),
              title: Text("Background Execution"),
              subtitle: Text("Allows continuous research data collection."),
            ),
            const Spacer(),

            // Mandatory Acknowledgement Checkbox
            CheckboxListTile(
              value: _acknowledged,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                "I understand that these permissions are mandatory for NeuroTrace to function and collect research data.",
                style: TextStyle(fontSize: 14),
              ),
              onChanged: (val) {
                setState(() {
                  _acknowledged = val ?? false;
                });
              },
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Button is disabled (null) if checkbox is not checked
                onPressed: _acknowledged ? () => _completeOnboarding(context) : null,
                child: const Text("Grant Permissions & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}