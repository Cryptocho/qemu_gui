import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/qemu_service.dart';
import '../main.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _qemuPathController;
  late TextEditingController _qemuImgPathController;
  String _qemuVersion = 'Unknown';
  String _qemuImgVersion = 'Unknown';
  bool _kvmAvailable = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<Settings>();
    _qemuPathController = TextEditingController(text: settings.qemuSystemPath);
    _qemuImgPathController = TextEditingController(text: settings.qemuImgPath);
    _checkVersions();
  }

  Future<void> _checkVersions() async {
    final qemuService = context.read<QemuService>();
    final qv = await qemuService.getQemuVersion(_qemuPathController.text);
    final qiv = await qemuService.getQemuImgVersion(_qemuImgPathController.text);
    final kvm = await qemuService.isKvmAvailable();
    if (mounted) {
      setState(() {
        _qemuVersion = qv;
        _qemuImgVersion = qiv;
        _kvmAvailable = kvm;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _qemuPathController,
            decoration: const InputDecoration(labelText: 'QEMU System Path'),
          ),
          const SizedBox(height: 8),
          Text(
            'Version: $_qemuVersion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qemuImgPathController,
            decoration: const InputDecoration(labelText: 'QEMU Img Path'),
          ),
          const SizedBox(height: 8),
          Text(
            'Version: $_qemuImgVersion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('KVM Available'),
            value: _kvmAvailable,
            onChanged: null,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              final settings = context.read<Settings>();
              settings.qemuSystemPath = _qemuPathController.text;
              settings.qemuImgPath = _qemuImgPathController.text;
              await context.read<SettingsService>().saveSettings(settings);
              if (mounted) {
                SettingsWrapper.of(context).update(settings);
                _checkVersions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved')),
                );
              }
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
