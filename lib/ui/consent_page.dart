import 'package:flutter/material.dart';
import 'permissions_page.dart'; // 1. Changed import to the next actual step

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Research Consent"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  "Detailed Privacy Policy:\n\n"
                      "1. Collected: App usage, screen events, session duration.\n"
                      "2. NOT Collected: Passwords, messages, photos, bank info.\n\n"
                      "Your data is collected only for research purposes. "
                      "Anonymized Research ID (UUID) is used. No personally "
                      "identifiable information is stored. You may stop "
                      "participating at any time by uninstalling.",
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            CheckboxListTile(
              value: _agreed,
              title: const Text("I have read and agree to the Privacy Policy and Research Consent."),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => _agreed = val ?? false),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _agreed
                    ? () {
                  // 2. Rerouted directly to PermissionsPage (or DashboardPage)
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const PermissionsPage()),
                  );
                }
                    : null,
                child: const Text("Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}