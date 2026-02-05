import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/vm_config.dart';
import '../models/disk_image.dart';
import '../models/net_config.dart';
import '../services/vm_service.dart';

class VMWizardView extends StatefulWidget {
  final VMConfig? existingVM;
  const VMWizardView({super.key, this.existingVM});

  @override
  State<VMWizardView> createState() => _VMWizardViewState();
}

class _VMWizardViewState extends State<VMWizardView> {
  late TextEditingController _nameController;
  late TextEditingController _ramController;
  late TextEditingController _coresController;
  late String _machine;
  late bool _enableKvm;
  String? _diskPath;
  String? _isoPath;
  late List<PortForward> _portForwards;

  final _hostPortController = TextEditingController();
  final _guestPortController = TextEditingController();
  NetProtocol _selectedProtocol = NetProtocol.tcp;

  @override
  void initState() {
    super.initState();
    final vm = widget.existingVM;
    _nameController = TextEditingController(text: vm?.name ?? '');
    _ramController = TextEditingController(
      text: vm != null ? (vm.memoryMB / 1024).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : '4',
    );
    _coresController = TextEditingController(text: vm?.cores.toString() ?? '4');
    _machine = vm?.machine ?? 'q35';
    _enableKvm = vm?.enableKvm ?? true;
    _diskPath = vm?.disks.isNotEmpty == true ? vm?.disks.first.path : null;
    _isoPath = vm?.isoPath;
    _portForwards = vm != null ? List.from(vm.netConfig.portForwards) : [];
  }

  void _addPortForward() {
    final hp = int.tryParse(_hostPortController.text);
    final gp = int.tryParse(_guestPortController.text);
    if (hp != null && gp != null) {
      setState(() {
        _portForwards.add(PortForward(protocol: _selectedProtocol, hostPort: hp, guestPort: gp));
        _hostPortController.clear();
        _guestPortController.clear();
      });
    }
  }

  Future<void> _saveVM() async {
    final ramGB = double.tryParse(_ramController.text) ?? 4.0;
    final vm = VMConfig(
      id: widget.existingVM?.id ?? const Uuid().v4(),
      name: _nameController.text,
      machine: _machine,
      enableKvm: _enableKvm,
      memoryMB: (ramGB * 1024).toInt(),
      cores: int.tryParse(_coresController.text) ?? 4,
      disks: _diskPath != null ? [DiskImage(path: _diskPath!)] : [],
      isoPath: _isoPath,
      netConfig: NetConfig(id: 'n0', portForwards: _portForwards),
    );

    if (widget.existingVM != null) {
      await context.read<VMService>().removeVM(widget.existingVM!.id);
    }
    await context.read<VMService>().addVM(vm);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.3))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(widget.existingVM == null ? 'Create New VM' : 'Edit VM'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Basics'),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'VM Name')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _ramController, decoration: const InputDecoration(labelText: 'Memory (GB)'))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _coresController, decoration: const InputDecoration(labelText: 'CPU Cores'))),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _machine,
              items: const [
                DropdownMenuItem(value: 'q35', child: Text('q35 (Modern, PCIe, recommended)')),
                DropdownMenuItem(value: 'pc', child: Text('pc (Legacy i440FX, compatibility)')),
              ],
              onChanged: (v) => setState(() => _machine = v!),
              decoration: const InputDecoration(labelText: 'Machine Type'),
            ),
            SwitchListTile(
              title: const Text('Enable KVM', style: TextStyle(fontSize: 14)),
              value: _enableKvm,
              onChanged: (v) => setState(() => _enableKvm = v),
              contentPadding: EdgeInsets.zero,
            ),
            _buildSectionHeader('Storage'),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ListTile(
                dense: true,
                title: Text(_diskPath ?? 'No primary disk selected', style: const TextStyle(fontSize: 13)),
                subtitle: const Text('Select an existing .qcow2 or .img file', style: TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles();
                        if (result != null) setState(() => _diskPath = result.files.single.path);
                      },
                      child: const Text('Select', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                      onPressed: () => Navigator.pushNamed(context, '/images'),
                      child: const Text('Create New', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ListTile(
                dense: true,
                title: Text(_isoPath ?? 'No ISO selected (optional)', style: const TextStyle(fontSize: 13)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles();
                    if (result != null) setState(() => _isoPath = result.files.single.path);
                  },
                  child: const Text('Select ISO', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
            _buildSectionHeader('Network (Port Mapping)'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Note: Avoid using privileged ports (1-1024) for the host.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _hostPortController, decoration: const InputDecoration(labelText: 'Host Port'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _guestPortController, decoration: const InputDecoration(labelText: 'Guest Port'))),
                const SizedBox(width: 8),
                DropdownButton<NetProtocol>(
                  value: _selectedProtocol,
                  onChanged: (v) => setState(() => _selectedProtocol = v!),
                  items: NetProtocol.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                ),
                IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _addPortForward),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _portForwards.length,
              itemBuilder: (context, index) {
                final pf = _portForwards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(pf.toString(), style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _portForwards.removeAt(index)),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveVM,
                child: const Text('Save Virtual Machine'),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
