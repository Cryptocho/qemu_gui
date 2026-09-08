import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/vm_config.dart';
import '../models/disk_image.dart';
import '../models/net_config.dart';
import '../models/shared_folder.dart';
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
  late bool _enableEdid;
  late TextEditingController _xresController;
  late TextEditingController _yresController;
  String? _diskPath;
  String? _isoPath;
  late List<PortForward> _portForwards;
  late List<GuestForward> _guestForwards;
  late List<SharedFolder> _sharedFolders;

  final _hostPortController = TextEditingController();
  final _guestPortController = TextEditingController();
  NetProtocol _selectedProtocol = NetProtocol.tcp;

  final _gfGuestIpController = TextEditingController(text: '10.0.2.100');
  final _gfGuestPortController = TextEditingController();
  final _gfHostIpController = TextEditingController(text: '127.0.0.1');
  final _gfHostPortController = TextEditingController();

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
    _enableEdid = vm?.enableEdid ?? false;
    _xresController = TextEditingController(text: (vm?.xres ?? 1920).toString());
    _yresController = TextEditingController(text: (vm?.yres ?? 1080).toString());
    _diskPath = vm?.disks.isNotEmpty == true ? vm?.disks.first.path : null;
    _isoPath = vm?.isoPath;
    _portForwards = vm != null ? List.from(vm.netConfig.portForwards) : [];
    _guestForwards = vm != null ? List.from(vm.netConfig.guestForwards) : [];
    _sharedFolders = vm != null ? List.from(vm.sharedFolders) : [];
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

  void _addGuestForward() {
    final gp = int.tryParse(_gfGuestPortController.text);
    final hp = int.tryParse(_gfHostPortController.text);
    final gIp = _gfGuestIpController.text;
    final hIp = _gfHostIpController.text;

    if (gp != null && hp != null && gIp.isNotEmpty && hIp.isNotEmpty) {
      setState(() {
        _guestForwards.add(GuestForward(
          guestIp: gIp,
          guestPort: gp,
          hostIp: hIp,
          hostPort: hp,
        ));
        _gfGuestPortController.clear();
        _gfHostPortController.clear();
      });
    }
  }

  Future<void> _addSharedFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    if (dir.contains(',')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Folders with commas in the path are not supported (QEMU limitation).'),
        ));
      }
      return;
    }
    setState(() {
      _sharedFolders.add(SharedFolder(
        path: dir,
        mountTag: SharedFolder.generateMountTag(
            dir, _sharedFolders.map((f) => f.mountTag).toList()),
      ));
    });
  }

  /// Returns an error message, or null if the tag is valid and unique
  /// among the other entries.
  String? _validateMountTag(String value, {required int excludeIndex}) {
    final v = value.trim();
    if (v.isEmpty) return 'mount_tag cannot be empty';
    if (!SharedFolder.isValidMountTag(v)) {
      return 'Must start with a letter; only letters, digits, . _ - allowed';
    }
    final taken = _sharedFolders.asMap().entries
        .where((e) => e.key != excludeIndex)
        .any((e) => e.value.mountTag == v);
    if (taken) return 'This tag is already used by another folder';
    return null;
  }

  Future<void> _editMountTag(int index) async {
    final folder = _sharedFolders[index];
    final controller = TextEditingController(text: folder.mountTag);
    final tag = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void save() {
              final error = _validateMountTag(controller.text, excludeIndex: index);
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.pop(dialogContext, controller.text.trim());
            }

            return AlertDialog(
              title: const Text('Edit mount_tag'),
              content: TextField(
                controller: controller,
                autofocus: true,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(
                  labelText: 'mount_tag',
                  helperText: 'Letters, digits, . _ -; must start with a letter',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: save,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (tag != null && mounted) {
      setState(() {
        _sharedFolders[index] = SharedFolder(
          path: folder.path,
          mountTag: tag,
          readOnly: folder.readOnly,
        );
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
      netConfig: NetConfig(
        id: 'n0',
        portForwards: _portForwards,
        guestForwards: _guestForwards,
      ),
      sharedFolders: _sharedFolders,
      enableEdid: _enableEdid,
      xres: int.tryParse(_xresController.text) ?? 1920,
      yres: int.tryParse(_yresController.text) ?? 1080,
    );

    final vmService = context.read<VMService>();
    if (widget.existingVM != null) {
      await vmService.updateVM(vm);
      // The VM may still be running; the edited configuration only takes
      // effect on its next start, so do not stop it here.
      if (vmService.isVMRunning(vm.id) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('VM is running — the new configuration will take effect on the next start.'),
        ));
      }
    } else {
      await vmService.addVM(vm);
    }
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
            SwitchListTile(
              title: const Text('Custom resolution (EDID)', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Advertise a preferred screen size to the guest', style: TextStyle(fontSize: 11)),
              value: _enableEdid,
              onChanged: (v) => setState(() => _enableEdid = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_enableEdid)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _xresController, decoration: const InputDecoration(labelText: 'Width (xres)'))),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(controller: _yresController, decoration: const InputDecoration(labelText: 'Height (yres)'))),
                  ],
                ),
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles();
                        if (result != null) setState(() => _isoPath = result.files.single.path);
                      },
                      child: const Text('Select ISO', style: TextStyle(fontSize: 12)),
                    ),
                    if (_isoPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _isoPath = null),
                        tooltip: 'Remove ISO',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildSectionHeader('Shared Folders'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Host directories shared with the guest via 9p (virtfs). '
                'Tap a folder to edit its mount_tag. '
                'Paths containing commas are not supported. '
                'Mount in the guest: mount -t 9p -o trans=virtio,version=9p2000.L <mount_tag> /mnt/share',
                style: TextStyle(fontSize: 11),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                  onPressed: _addSharedFolder,
                  child: const Text('Add Folder…', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sharedFolders.length,
              itemBuilder: (context, index) {
                final folder = _sharedFolders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: ListTile(
                      dense: true,
                      onTap: () => _editMountTag(index),
                      title: Text(folder.path, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('mount_tag: ${folder.mountTag}', style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Read-only', style: TextStyle(fontSize: 11)),
                          Switch(
                            value: folder.readOnly,
                            onChanged: (v) => setState(() {
                              _sharedFolders[index] = SharedFolder(
                                path: folder.path,
                                mountTag: folder.mountTag,
                                readOnly: v,
                              );
                            }),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.delete),
                            onPressed: () => setState(() => _sharedFolders.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
            _buildSectionHeader('Guest Forwarding (Guest -> Host)'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Forward guest connections to host services.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _gfGuestIpController, decoration: const InputDecoration(labelText: 'Guest IP'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _gfGuestPortController, decoration: const InputDecoration(labelText: 'Port'))),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _gfHostIpController, decoration: const InputDecoration(labelText: 'Host IP'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _gfHostPortController, decoration: const InputDecoration(labelText: 'Port'))),
                IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _addGuestForward),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _guestForwards.length,
              itemBuilder: (context, index) {
                final gf = _guestForwards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(gf.toString(), style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _guestForwards.removeAt(index)),
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
