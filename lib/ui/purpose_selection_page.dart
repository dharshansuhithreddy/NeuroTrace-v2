
import 'package:flutter/material.dart';

import 'purpose_frequency_page.dart';

class PurposeSelectionPage extends StatefulWidget {
final List<Map<String, String>> selectedApps;

const PurposeSelectionPage({
super.key,
required this.selectedApps,
});

@override
State<PurposeSelectionPage> createState() =>
_PurposeSelectionPageState();
}

class _PurposeSelectionPageState extends State<PurposeSelectionPage> {
final List<String> _purposes = [
'Learning and Education',
'Work and Productivity',
'Communication',
'Social Networking',
'Entertainment',
'Gaming',
'News and Information',
'Shopping and Financial Services',
'Health and Fitness',
'Navigation and Travel',
'Content Creation',
'Other',
];

final Map<String, Set<String>> _selectedPurposes = {};

@override
void initState() {
super.initState();

for (final app in widget.selectedApps) {
_selectedPurposes[app['packageName']!] = {};
}
}

void _continue() {
final incompleteApps = widget.selectedApps.where((app) {
final packageName = app['packageName']!;
return _selectedPurposes[packageName]!.isEmpty;
}).toList();

if (incompleteApps.isNotEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Please select at least one purpose for '
'${incompleteApps.length} remaining application(s).',
),
),
);
return;
}

final Map<String, dynamic> result = {};

for (final app in widget.selectedApps) {
final packageName = app['packageName']!;

result[packageName] = {
'appName': app['appName'],
'purposes': _selectedPurposes[packageName]!.toList(),
};
}

Navigator.push(
context,
MaterialPageRoute(
builder: (context) => PurposeFrequencyPage(
selectedApps: widget.selectedApps,
selectedPurposes: result,
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Application Purposes'),
),
body: Column(
children: [
const Padding(
padding: EdgeInsets.all(16),
child: Text(
'Why do you use each application?\n'
'Select all purposes that apply to you.',
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.w600,
),
),
),
Expanded(
child: ListView.builder(
padding: const EdgeInsets.symmetric(horizontal: 12),
itemCount: widget.selectedApps.length,
itemBuilder: (context, index) {
final app = widget.selectedApps[index];
final appName = app['appName']!;
final packageName = app['packageName']!;

return Card(
margin: const EdgeInsets.only(bottom: 12),
child: ExpansionTile(
initiallyExpanded: true,
title: Text(
appName,
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
subtitle: Text(
'${_selectedPurposes[packageName]!.length} purposes selected',
),
children: _purposes.map((purpose) {
return CheckboxListTile(
dense: true,
title: Text(purpose),
value: _selectedPurposes[packageName]!
    .contains(purpose),
onChanged: (selected) {
setState(() {
if (selected == true) {
_selectedPurposes[packageName]!
    .add(purpose);
} else {
_selectedPurposes[packageName]!
    .remove(purpose);
}
});
},
);
}).toList(),
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
onPressed: _continue,
child: const Text('Continue'),
),
),
),
],
),
);
}
}
