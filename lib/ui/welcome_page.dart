import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'consent_page.dart';

class WelcomePage extends StatefulWidget {
  final String participantId;

  const WelcomePage({super.key, required this.participantId});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _ageController = TextEditingController();
  String? _selectedGender;
  bool _isSaving = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

  Future<void> _saveAndContinue() async {
    // 1. Validate Input
    if (_ageController.text.isEmpty || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide your age and gender to continue.")),
      );
      return;
    }

    final int? age = int.tryParse(_ageController.text);
    if (age == null || age <= 0 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid age number.")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // 2. Save explicitly to Firestore parent document
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('research_participants').doc(widget.participantId);

    try {
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists || docSnapshot.data() == null || !docSnapshot.data()!.containsKey('joinedAt')) {
        await docRef.set({
          'age': age,
          'gender': _selectedGender,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ NEUROTRACE: Parent profile initialized successfully during onboarding.');
      } else {
        await docRef.set({
          'age': age,
          'gender': _selectedGender,
        }, SetOptions(merge: true));
      }

      // 3. Success! Move to Consent Page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ConsentPage()),
        );
      }
    } catch (e) {
      debugPrint('❌ NEUROTRACE DEMOGRAPHIC ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ---> THE NEW CUSTOM LOGO IS RIGHT HERE <---
            Image.asset('assets/images/app_icon.png', height: 80),

            const SizedBox(height: 24),
            const Text(
                "NeuroTrace",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )
            ),
            const SizedBox(height: 8),
            const Text(
              "A Research Platform for Understanding Digital Habits",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Demographics Setup Form
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Participant Setup",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7C4DFF))
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Age",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF121214),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: const Color(0xFF1E1E24),
                    decoration: InputDecoration(
                      labelText: "Gender",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF121214),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: _genderOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      setState(() {
                        _selectedGender = newVal;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Continue to Consent", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}