import 'package:flutter/material.dart';
import 'permissions_page.dart';

class DemographicsPage extends StatefulWidget {
  const DemographicsPage({super.key});

  @override
  State<DemographicsPage> createState() => _DemographicsPageState();
}

class _DemographicsPageState extends State<DemographicsPage> {
  String? _selectedGender;
  String? _selectedAge;

  bool get _isComplete => _selectedGender != null && _selectedAge != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Demographic Info")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("To help us with our research, please provide your demographic details.",
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),

            // Age Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Age Range", border: OutlineInputBorder()),
              items: ["18-24", "25-34", "35-44", "45+"].map((age) => DropdownMenuItem(value: age, child: Text(age))).toList(),
              onChanged: (val) => setState(() => _selectedAge = val),
            ),
            const SizedBox(height: 20),

            // Gender Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
              items: ["Male", "Female", "Non-binary", "Prefer not to say"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => setState(() => _selectedGender = val),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isComplete
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsPage()))
                    : null,
                child: const Text("Continue to Permissions"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}