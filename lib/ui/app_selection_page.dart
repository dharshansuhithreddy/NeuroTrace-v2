
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'purpose_selection_page.dart';

class AppSelectionPage extends StatefulWidget {
const AppSelectionPage({super.key});

@override
State<AppSelectionPage> createState() => _AppSelectionPageState();
}

class _AppSelectionPageState extends State<AppSelectionPage> {
static const MethodChannel _channel =
MethodChannel('com.neurotrace_v2.telemetry');

List<Map<String, String>> _applications = [];
final Set<String> _selectedPackages = {};

bool _isLoading = true;
String? _error;

@override
void initState() {
super.initState();
_loadApplications();
}

Future<void> _loadApplications() async {
try {
final List<dynamic>? result =
await _channel.invokeMethod<List<dynamic>>(
'getInstalledApplications',
);

final apps = (result ?? []).map((item) {
final app = Map<String, dynamic>.from(item as Map);

return {
'appName': app['appName']?.toString() ?? 'Unknown App',
'packageName': app['packageName']?.toString() ?? '',
};
}).where((app) => app['packageName']!.isNotEmpty).toList();

if (!mounted) return;

setState(() {
_applications = apps;
_isLoading = false;
});
} on PlatformException catch (e) {
if (!mounted) return;

setState(() {
_error = e.message ?? 'Unable to retrieve applications.';
_isLoading = false;
});
} catch (e) {
if (!mounted) return;

setState(() {
_error = 'Something went wrong: $e';
_isLoading = false;
});
}
}

void _continue() {
if (_selectedPackages.length < 2) return;

final selectedApps = _applications
    .where((app) =>
_selectedPackages.contains(app['packageName']))
    .toList();

Navigator.push(
context,
MaterialPageRoute(
builder: (context) => PurposeSelectionPage(
selectedApps: selectedApps,
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Application Selection'),
),
body: _isLoading
? const Center(child: CircularProgressIndicator())
    : _error != null
? Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text(_error!),
const SizedBox(height: 16),
ElevatedButton(
onPressed: () {
setState(() {
_isLoading = true;
_error = null;
});
_loadApplications();
},
child: const Text('Retry'),
),
],
),
),
)
    : Column(
children: [
Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Select the applications you use regularly.',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
const Text(
'Choose at least 2 applications. '
'You can select more if needed.',
),
const SizedBox(height: 12),
Text(
'${_selectedPackages.length} applications selected',
style: const TextStyle(
fontWeight: FontWeight.w600,
),
),
],
),
),
const Divider(height: 1),
Expanded(
child: _applications.isEmpty
? const Center(
child: Text(
'No launchable applications found.',
),
)
    : ListView.builder(
itemCount: _applications.length,
itemBuilder: (context, index) {
final app = _applications[index];
final packageName =
app['packageName']!;
final appName = app['appName']!;

return CheckboxListTile(
value: _selectedPackages
    .contains(packageName),
title: Text(appName),
subtitle: Text(
packageName,
style: const TextStyle(fontSize: 11),
),
controlAffinity:
ListTileControlAffinity.leading,
onChanged: (selected) {
setState(() {
if (selected == true) {
_selectedPackages.add(packageName);
} else {
_selectedPackages.remove(packageName);
}
});
},
);
},
),
),
Padding(
padding: const EdgeInsets.all(16),
child: SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: _selectedPackages.length >= 2
? _continue
    : null,
child: const Text('Continue'),
),
),
),
],
),
);
}
}
