import 'package:flutter/material.dart';
import 'app_selection_page.dart';

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
                      "1. Collected: App usage information, screen events, "
                      "session duration, and selected application names "
                      "and package identifiers.\n\n"
                      "2. Questionnaire: You will be asked about the purposes "
                      "for which you use selected applications, how frequently "
                      "you use them for those purposes, and whether your usage "
                      "purposes change depending on your situation.\n\n"
                      "3. NOT Collected: Passwords, private messages, photos, "
                      "or banking information.\n\n"
                      "Your data is collected only for research purposes. "
                      "A pseudonymous Research ID (UUID) is used to associate "
                      "your research data. You may stop participating at any time.\n\n"
                      "Your questionnaire responses will be stored alongside "
                      "your existing research participant record.",
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            CheckboxListTile(
              value: _agreed,
              title: const Text(
                "I have read and agree to the Privacy Policy and Research Consent.",
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) {
                setState(() {
                  _agreed = val ?? false;
                });
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _agreed
                    ? () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const AppSelectionPage(),
                    ),
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