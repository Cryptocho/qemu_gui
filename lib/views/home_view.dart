import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vm_service.dart';
import '../models/vm_config.dart';
import '../services/qemu_service.dart';
import '../services/settings_service.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final vmService = context.watch<VMService>();

    return Scaffold(
      appBar: AppBar(
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
          : ListView.builder(
              itemCount: vmService.vms.length,
              itemBuilder: (context, index) {
                final vm = vmService.vms[index];
                return ListTile(
                  title: Text(vm.name),
                  subtitle: Text('${vm.machine} - ${vm.memoryMB}MB RAM'),
                  onTap: () => Navigator.pushNamed(context, '/wizard', arguments: vm),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () async {
                          final qemuService = context.read<QemuService>();
                          final settings = context.read<Settings>();
                          try {
                            final process = await qemuService.startVM(settings.qemuSystemPath, vm);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Starting ${vm.name}...')),
                              );
                            }
                            // In a real app, we would track this process
                            process.exitCode.then((code) {
                              print('VM ${vm.name} exited with code $code');
                            });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => vmService.removeVM(vm.id),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/wizard'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
