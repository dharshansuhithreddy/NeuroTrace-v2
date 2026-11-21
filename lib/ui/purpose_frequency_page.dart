
import 'package:flutter/material.dart';

import 'purpose_variation_page.dart';

class PurposeFrequencyPage extends StatefulWidget {
final List<Map<String, String>> selectedApps;
final Map<String, dynamic> selectedPurposes;

const PurposeFrequencyPage({
super.key,
required this.selectedApps,
required this.selectedPurposes,
});

@override
State<PurposeFrequencyPage> createState() =>
_PurposeFrequencyPageState();
}

class _PurposeFrequencyPageState
extends State<PurposeFrequencyPage> {
final Map<String, Map<String, String>> _frequencies = {};

final List<String> _frequencyOptions = [
'Often',
'Sometimes',
'Rarely',
];

@override
void initState() {
super.initState();

for (final app in widget.selectedApps) {
final packageName = app['packageName']!;

_frequencies[packageName] = {};

final appData = widget.selectedPurposes[packageName];

if (appData is Map) {
final purposes = appData['purposes'] as List? ?? [];

for (final purpose in purposes) {
_frequencies[packageName]![purpose.toString()] = '';
}
}
}
}

void _continue() {
final incompleteCount = _frequencies.values.fold<int>(
0,
(count, appFrequencies) =>
count +
appFrequencies.values
    .where((frequency) => frequency.isEmpty)
    .length,
);

if (incompleteCount > 0) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Please select frequency for all purposes. '
'$incompleteCount remaining.',
),
),
);
return;
}

final result = <String, dynamic>{};

for (final app in widget.selectedApps) {
final packageName = app['packageName']!;

result[packageName] = {
'appName': app['appName'],
'purposes': _frequencies[packageName]!.entries.map((entry) {
return {
'purpose': entry.key,
'frequency': entry.value,
};
}).toList(),
};
}

Navigator.push(
context,
MaterialPageRoute(
builder: (context) => PurposeVariationPage(
frequencyResults: result,
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Purpose Frequency'),
),
body: Column(
children: [
const Padding(
padding: EdgeInsets.all(16),
child: Text(
'How frequently do you use each application '
'for the selected purposes?',
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
final packageName = app['packageName']!;
final appName = app['appName']!;

final purposes =
_frequencies[packageName]!.keys.toList();

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
'${_frequencies[packageName]!.values.where((v) => v.isNotEmpty).length}'
' of ${purposes.length} completed',
),
children: purposes.map((purpose) {
return Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
purpose,
style: const TextStyle(
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),
Wrap(
spacing: 8,
children: _frequencyOptions.map((frequency) {
return ChoiceChip(
label: Text(frequency),
selected:
_frequencies[packageName]![purpose] ==
frequency,
onSelected: (selected) {
setState(() {
_frequencies[packageName]![purpose] =
selected ? frequency : '';
});
},
);
}).toList(),
),
],
),
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
