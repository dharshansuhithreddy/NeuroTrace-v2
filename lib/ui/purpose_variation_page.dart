
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'permissions_page.dart';

class PurposeVariationPage extends StatefulWidget {
final Map<String, dynamic> frequencyResults;

const PurposeVariationPage({
super.key,
required this.frequencyResults,
});

@override
State<PurposeVariationPage> createState() =>
_PurposeVariationPageState();
}

class _PurposeVariationPageState
extends State<PurposeVariationPage> {
String? _selectedVariation;
bool _isSaving = false;

final List<Map<String, String>> _options = [
{
'value': 'usually_same',
'label': 'Usually remains the same',
'description':
'I generally use applications for the same purposes.',
},
{
'value': 'changes_by_day',
'label': 'Changes depending on the day',
'description':
'My usage purposes may differ from day to day.',
},
{
'value': 'changes_by_situation',
'label': 'Changes depending on the situation',
'description':
'My purpose changes based on my needs or situation.',
},
{
'value': 'not_sure',
'label': 'Not sure',
'description':
'I cannot identify a consistent pattern.',
},
];

Future<void> _continue() async {
if (_selectedVariation == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Please select an option to continue.'),
),
);
return;
}

if (_isSaving) return;

setState(() {
_isSaving = true;
});

try {
// Retrieve the existing participant ID.
final prefs = await SharedPreferences.getInstance();

final participantId = prefs.getString('research_id');

if (participantId == null || participantId.isEmpty) {
throw Exception('Participant ID not found.');
}

// Convert application results into a structured list.
final List<Map<String, dynamic>> applications = [];

widget.frequencyResults.forEach((packageName, appData) {
if (appData is! Map) return;

final rawPurposes = appData['purposes'] as List? ?? [];

final purposes = rawPurposes.map((purpose) {
final purposeData =
Map<String, dynamic>.from(purpose as Map);

return {
'purpose': purposeData['purpose'],
'frequency': purposeData['frequency'],
};
}).toList();

applications.add({
'package_name': packageName,
'app_name': appData['appName']?.toString() ?? 'Unknown App',
'purposes': purposes,
});
});

// Prepare the questionnaire document.
final questionnaireData = {
'applications': applications,
'purpose_variation': _selectedVariation,
'questionnaire_version': '1.0',
'survey_completed': true,
'completed_at': FieldValue.serverTimestamp(),
};

// Save into the existing participant document.
await FirebaseFirestore.instance
    .collection('research_participants')
    .doc(participantId)
    .set(
{
'onboarding_survey': questionnaireData,
},
SetOptions(merge: true),
);

debugPrint('Questionnaire successfully saved to Firestore.');

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Questionnaire saved successfully!'),
),
);

// Continue only after the Firebase save succeeds.
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (context) => const PermissionsPage(),
),
);
} catch (e) {
debugPrint('Questionnaire Firebase save error: $e');

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Unable to save questionnaire: $e'),
duration: const Duration(seconds: 5),
),
);
} finally {
if (mounted) {
setState(() {
_isSaving = false;
});
}
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Purpose Variation'),
),
body: Column(
children: [
const Padding(
padding: EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Purpose Variation',
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
),
),
SizedBox(height: 12),
Text(
'Does your purpose for using an application '
'change depending on your needs or situation?',
style: TextStyle(fontSize: 17),
),
SizedBox(height: 8),
Text(
'Choose the option that best describes your '
'general usage pattern.',
style: TextStyle(color: Colors.grey),
),
],
),
),
Expanded(
child: ListView.builder(
padding: const EdgeInsets.symmetric(horizontal: 16),
itemCount: _options.length,
itemBuilder: (context, index) {
final option = _options[index];
final isSelected =
_selectedVariation == option['value'];

return Card(
margin: const EdgeInsets.only(bottom: 12),
child: RadioListTile<String>(
value: option['value']!,
groupValue: _selectedVariation,
onChanged: _isSaving
? null
    : (value) {
setState(() {
_selectedVariation = value;
});
},
title: Text(
option['label']!,
style: const TextStyle(
fontWeight: FontWeight.w600,
),
),
subtitle: Text(option['description']!),
selected: isSelected,
controlAffinity:
ListTileControlAffinity.leading,
),
);
},
),
),
Padding(
padding: const EdgeInsets.all(16),
child: SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: _isSaving ? null : _continue,
child: _isSaving
? const SizedBox(
height: 22,
width: 22,
child: CircularProgressIndicator(
strokeWidth: 2,
),
)
    : const Text('Continue'),
),
),
),
],
),
);
}
}
