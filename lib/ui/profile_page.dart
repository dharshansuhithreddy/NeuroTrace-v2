import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _participantId = "Loading ID...";
  final _ageController = TextEditingController();
  String? _selectedGender;
  bool _isSaving = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _loadParticipantId();
  }

  /// Automatically retrieves the exact dynamic UUID used by the background collectors
  Future<void> _loadParticipantId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('research_id') ?? 'No ID Found';
    setState(() {
      _participantId = id;
    });
  }

  /// Writes demographic fields to the parent document once without overwriting telemetry subcollections
  Future<void> _saveDemographicsToFirestore() async {
    if (_ageController.text.isEmpty || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill out both Age and Gender before saving.")),
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

    final db = FirebaseFirestore.instance;
    final docRef = db.collection('research_participants').doc(_participantId);

    try {
      // Step 1: Check if the document already contains a registration timestamp
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists || docSnapshot.data() == null || !docSnapshot.data()!.containsKey('joinedAt')) {
        // Step 2: First time upload - register demographic data with an immutable joinedAt time
        await docRef.set({
          'age': age,
          'gender': _selectedGender,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ NEUROTRACE: Parent profile initialized successfully.');
      } else {
        // Step 3: Profile exists - merge only modified fields, protecting joinedAt and telemetry folders
        await docRef.set({
          'age': age,
          'gender': _selectedGender,
        }, SetOptions(merge: true));
        debugPrint('✅ NEUROTRACE: Parent profile demographic fields merged safely.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demographic profile synced successfully!")),
        );
      }
    } catch (e) {
      debugPrint('❌ NEUROTRACE DEMOGRAPHIC ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync failed: $e")),
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
      appBar: AppBar(
        title: const Text("Research Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF7C4DFF),
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text("Participant ID", style: TextStyle(color: Colors.grey)),
            Text(
              _participantId,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Input Fields Row/Column Block
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Demographics Configuration", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF7C4DFF))),
                  const SizedBox(height: 16),

                  // Age input field
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Enter Age",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF121214),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender Dropdown field - Fixed Deprecation Warning
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    dropdownColor: const Color(0xFF1E1E24),
                    decoration: InputDecoration(
                      labelText: "Select Gender",
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
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveDemographicsToFirestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Update Demographics", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildStatCard("Data Sync Status", "Active Telemetry Pipeline"),
            const SizedBox(height: 40),

            TextButton(
              onPressed: () {
                // Logic to stop research/uninstall
              },
              child: const Text("Leave Research Study", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end, // Fixed Layout Warning
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C4DFF)),
            ),
          ),
        ],
      ),
    );
  }
}