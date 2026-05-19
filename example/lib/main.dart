import 'dart:convert';

import 'package:companion_device_manager/companion_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CompanionDeviceManagerExampleApp());
}

@pragma('vm:entry-point')
Future<void> companionDeviceWakeCallback() async {
  debugPrint('[CDM] Companion device background callback invoked.');
}

class CompanionDeviceManagerExampleApp extends StatelessWidget {
  const CompanionDeviceManagerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companion Device Manager Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const CompanionDeviceManagerHomePage(),
    );
  }
}

class CompanionDeviceManagerHomePage extends StatefulWidget {
  const CompanionDeviceManagerHomePage({super.key});

  @override
  State<CompanionDeviceManagerHomePage> createState() =>
      _CompanionDeviceManagerHomePageState();
}

class _CompanionDeviceManagerHomePageState extends State<CompanionDeviceManagerHomePage> {
  final CompanionDeviceManager _manager = CompanionDeviceManager();
  final TextEditingController _addressController =
      TextEditingController(text: '00:11:22:33:44:55');

  bool _available = false;
  bool _callbackRegistered = false;
  bool _busy = false;
  String _status = 'Ready';
  String? _lastEventJson;
  List<CompanionDeviceAssociation> _associations = <CompanionDeviceAssociation>[];

  @override
  void initState() {
    super.initState();
    _refreshAvailability();
    _refreshAssociations();
    _refreshLastEvent();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _refreshAvailability() async {
    setState(() => _busy = true);
    try {
      final available = await _manager.isAvailable();
      if (!mounted) return;
      setState(() {
        _available = available;
        _status = available
            ? 'Companion Device Manager is available on this Android device.'
            : 'Companion Device Manager is not available on this Android device.';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Availability check failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshAssociations() async {
    setState(() => _busy = true);
    try {
      final associations = await _manager.getAssociations();
      if (!mounted) return;
      setState(() => _associations = associations);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Unable to load associations: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshLastEvent() async {
    try {
      final event = await _manager.getLastBackgroundEvent();
      if (!mounted) return;
      setState(() => _lastEventJson = event == null ? null : const JsonEncoder.withIndent('  ').convert(event.toMap()));
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Unable to load the last event: ${error.message}');
    }
  }

  Future<void> _registerCallback() async {
    setState(() => _busy = true);
    try {
      await _manager.registerBackgroundCallback(companionDeviceWakeCallback);
      if (!mounted) return;
      setState(() {
        _callbackRegistered = true;
        _status = 'Background wake callback registered.';
      });
      _showSnackBar('Background callback registered.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message.toString());
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Unable to register callback: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearCallback() async {
    setState(() => _busy = true);
    try {
      await _manager.clearBackgroundCallback();
      if (!mounted) return;
      setState(() {
        _callbackRegistered = false;
        _status = 'Background callback cleared.';
      });
      _showSnackBar('Background callback cleared.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Unable to clear callback: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _associate() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _status = 'Please enter a Bluetooth MAC address.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Launching the Android companion device chooser...';
    });

    try {
      final association = await _manager.associate(
        CompanionDeviceAssociationRequest(
          displayName: 'Companion Device Manager Example',
          filters: <CompanionDeviceFilter>[
            CompanionDeviceFilter.bluetooth(address: address),
          ],
          singleDevice: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _status = 'Association completed for ${association.macAddress ?? 'unknown device'}.';
      });
      await _refreshAssociations();
      await _refreshLastEvent();
      _showSnackBar('Association completed.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Association failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disassociate(CompanionDeviceAssociation association) async {
    setState(() => _busy = true);
    try {
      await _manager.disassociate(association);
      if (!mounted) return;
      setState(() => _status = 'Association removed for ${association.macAddress ?? 'unknown device'}');
      await _refreshAssociations();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Unable to remove association: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companion Device Manager'),
        actions: [
          IconButton(
            onPressed: _busy
                ? null
                : () async {
                    await _refreshAvailability();
                    await _refreshAssociations();
                    await _refreshLastEvent();
                  },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _InfoCard(
            title: 'Status',
            child: Text(_status),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Runtime availability',
            child: Text(_available ? 'Available' : 'Not available'),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Background callback',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_callbackRegistered ? 'Registered' : 'Not registered'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _registerCallback,
                      child: const Text('Register callback'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _clearCallback,
                      child: const Text('Clear callback'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _refreshLastEvent,
                      child: const Text('Reload last event'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Association setup',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Bluetooth MAC address',
                    helperText: 'Use a real companion device address when testing.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _associate,
                  child: const Text('Start association'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Current associations',
            child: _associations.isEmpty
                ? const Text('No associations found yet.')
                : Column(
                    children: _associations
                        .map(
                          (association) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(association.displayName ?? association.macAddress ?? 'Unknown device'),
                            subtitle: Text(
                              'MAC: ${association.macAddress ?? 'n/a'}\n'
                              'Association ID: ${association.associationId?.toString() ?? 'n/a'}',
                            ),
                            isThreeLine: true,
                            trailing: TextButton(
                              onPressed: _busy ? null : () => _disassociate(association),
                              child: const Text('Remove'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Last background event',
            child: SelectableText(
              _lastEventJson ?? 'No background event captured yet.',
            ),
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Notes',
            child: Text(
              'The background callback must be a top-level or static function marked with @pragma(\'vm:entry-point\').\n'
              'Android pairing also depends on the device type, user consent, and any required Bluetooth permissions.',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
