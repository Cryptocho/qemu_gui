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
  int _currentStep = 0;
  late TextEditingController _nameController;
  late TextEditingController _ramController;
  late TextEditingController _coresController;
  late String _machine;
  late bool _enableKvm;
  String? _diskPath;
  String? _isoPath;
  late List<PortForward> _portForwards;

  @override
  void initState() {
    super.initState();
    final vm = widget.existingVM;
    _nameController = TextEditingController(text: vm?.name ?? '');
    _ramController = TextEditingController(text: vm?.memoryMB.toString() ?? '4096');
    _coresController = TextEditingController(text: vm?.cores.toString() ?? '4');
    _machine = vm?.machine ?? 'q35';
    _enableKvm = vm?.enableKvm ?? true;
    _diskPath = vm?.disks.isNotEmpty == true ? vm?.disks.first.path : null;
    _isoPath = vm?.isoPath;
    _portForwards = vm != null ? List.from(vm.netConfig.portForwards) : [];
  }
  final _hostPortController = TextEditingController();
  final _guestPortController = TextEditingController();
  NetProtocol _selectedProtocol = NetProtocol.tcp;

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
    final vm = VMConfig(
      id: widget.existingVM?.id ?? const Uuid().v4(),
      name: _nameController.text,
      machine: _machine,
      enableKvm: _enableKvm,
      memoryMB: int.tryParse(_ramController.text) ?? 4096,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New VM')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _saveVM();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          } else {
            Navigator.pop(context);
          }
        },
        steps: [
          Step(
            title: const Text('Basics'),
            isActive: _currentStep >= 0,
            content: Column(
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'VM Name')),
                TextField(controller: _ramController, decoration: const InputDecoration(labelText: 'Memory (MB)')),
                TextField(controller: _coresController, decoration: const InputDecoration(labelText: 'CPU Cores')),
                DropdownButtonFormField<String>(
                  value: _machine,
                  items: const [
                    DropdownMenuItem(value: 'q35', child: Text('q35')),
                    DropdownMenuItem(value: 'pc', child: Text('pc')),
                  ],
                  onChanged: (v) => setState(() => _machine = v!),
                  decoration: const InputDecoration(labelText: 'Machine Type'),
                ),
                SwitchListTile(
                  title: const Text('Enable KVM'),
                  value: _enableKvm,
                  onChanged: (v) => setState(() => _enableKvm = v),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Storage'),
            isActive: _currentStep >= 1,
            content: Column(
              children: [
                ListTile(
                  title: Text(_diskPath ?? 'No primary disk selected'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) setState(() => _diskPath = result.files.single.path);
                    },
                    child: const Text('Select Disk'),
                  ),
                ),
                ListTile(
                  title: Text(_isoPath ?? 'No ISO selected (optional)'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null) setState(() => _isoPath = result.files.single.path);
                    },
                    child: const Text('Select ISO'),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Network (Port Mapping)'),
            isActive: _currentStep >= 2,
            content: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _hostPortController, decoration: const InputDecoration(labelText: 'Host Port'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _guestPortController, decoration: const InputDecoration(labelText: 'Guest Port'))),
                    DropdownButton<NetProtocol>(
                      value: _selectedProtocol,
                      onChanged: (v) => setState(() => _selectedProtocol = v!),
                      items: NetProtocol.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                    ),
                    IconButton(icon: const Icon(Icons.add), onPressed: _addPortForward),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _portForwards.length,
                  itemBuilder: (context, index) {
                    final pf = _portForwards[index];
                    return ListTile(
                      title: Text(pf.toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _portForwards.removeAt(index)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
