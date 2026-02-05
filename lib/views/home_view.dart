import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../services/vm_service.dart';
import '../models/vm_config.dart';
import '../services/qemu_service.dart';
import '../services/settings_service.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  void _showLogs(BuildContext context, VMConfig vm, VMService vmService) {
    final scrollController = ScrollController();
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: vmService,
        child: Consumer<VMService>(
          builder: (context, svc, _) {
            final logs = svc.getLogs(vm.id);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                scrollController.jumpTo(scrollController.position.maxScrollExtent);
              }
            });
            return AlertDialog(
              title: Row(
                children: [
                  Text('Logs: ${vm.name}', style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy all logs',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: logs.join('''
''')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logs copied to clipboard'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: 700,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: logs.length,
                          itemBuilder: (context, index) => SelectableText(
                            logs[index],
                            style: const TextStyle(
                              color: Color(0xFFD4D4D4),
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => svc.clearLogs(vm.id),
                  child: const Text('Clear Logs'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, VMConfig vm, VMService vmService) async {
    bool deleteImages = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Delete VM: ${vm.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to remove this VM configuration?'),
              if (vm.disks.isNotEmpty) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Delete associated disk images'),
                  subtitle: Text(vm.disks.map((d) => p.basename(d.path)).join(', ')),
                  value: deleteImages,
                  onChanged: (val) => setState(() => deleteImages = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (deleteImages) {
        for (final disk in vm.disks) {
          try {
            final file = File(disk.path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete image ${disk.path}: $e')),
              );
            }
          }
        }
      }
      await vmService.removeVM(vm.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vmService = context.watch<VMService>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('QEMU GUI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Image Manager',
            onPressed: () => Navigator.pushNamed(context, '/images'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: vmService.vms.isEmpty
          ? const Center(child: Text('No VMs found. Create one!'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Virtual Machines',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Divider(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: vmService.vms.length,
                    itemBuilder: (context, index) {
                      final vm = vmService.vms[index];
                      final isRunning = vmService.isVMRunning(vm.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => Navigator.pushNamed(context, '/wizard', arguments: vm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: isRunning ? Colors.green : Colors.grey,
                              size: 6,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    vm.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${vm.machine} - ${vm.memoryMB}MB RAM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 22,
                              icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                              color: isRunning ? Colors.red : null,
                              onPressed: () async {
                                if (isRunning) {
                                  vmService.stopVM(vm.id);
                                  return;
                                }
                                final qemuService = context.read<QemuService>();
                                final settings = context.read<Settings>();
                                try {
                                  final cmd = qemuService.buildCommandString(settings.qemuSystemPath, vm);
                                  final process = await qemuService.startVM(settings.qemuSystemPath, vm);
                                  vmService.registerProcess(vm.id, process, command: cmd);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Starting ${vm.name}...')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                            if (!isRunning) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 22,
                                icon: const Icon(Icons.visibility_off),
                                tooltip: 'Start Headless',
                                onPressed: () async {
                                  final qemuService = context.read<QemuService>();
                                  final settings = context.read<Settings>();
                                  try {
                                    final cmd = qemuService.buildCommandString(settings.qemuSystemPath, vm, headless: true);
                                    final process = await qemuService.startVM(settings.qemuSystemPath, vm, headless: true);
                                    vmService.registerProcess(vm.id, process, command: cmd);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Starting ${vm.name} (headless)...')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 18,
                              icon: const Icon(Icons.receipt_long),
                              tooltip: 'Logs',
                              onPressed: () => _showLogs(context, vm, vmService),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 22,
                              icon: const Icon(Icons.delete),
                              onPressed: () => _showDeleteConfirmation(context, vm, vmService),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => Navigator.pushNamed(context, '/wizard'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
