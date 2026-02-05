import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/image_service.dart';
import '../services/settings_service.dart';

class ImageManagerView extends StatefulWidget {
  const ImageManagerView({super.key});

  @override
  State<ImageManagerView> createState() => _ImageManagerViewState();
}

class _ImageManagerViewState extends State<ImageManagerView> {
  String? _selectedImagePath;
  String _imageInfo = '';
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController(text: '20G');
  String _selectedFormat = 'qcow2';
  final List<String> _formats = ['qcow2', 'raw', 'vmdk', 'vdi', 'qed'];

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImagePath = result.files.single.path;
      });
      _refreshInfo();
    }
  }

  Future<void> _refreshInfo() async {
    if (_selectedImagePath == null) return;
    final settings = context.read<Settings>();
    final imageService = ImageService(settings.qemuImgPath);
    final info = await imageService.getInfo(_selectedImagePath!);
    setState(() {
      _imageInfo = info;
    });
  }

  Future<void> _createImage() async {
    final settings = context.read<Settings>();
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || _nameController.text.isEmpty) return;

    final path = p.join(dir, _nameController.text + (p.extension(_nameController.text).isEmpty ? '.$_selectedFormat' : ''));
    final imageService = ImageService(settings.qemuImgPath);

    final result = await imageService.createImg(path, _sizeController.text, format: _selectedFormat);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
      setState(() {
        _selectedImagePath = path;
      });
      _refreshInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Image Manager'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage Existing Image', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(_selectedImagePath ?? 'No image selected')),
                ElevatedButton(onPressed: _pickImage, child: const Text('Select Image')),
              ],
            ),
            if (_imageInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Image Info:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                width: double.infinity,
                child: Text(
                  _imageInfo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const Divider(height: 48),
            Text('Create New Image', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Filename (without extension)', hintText: 'my_disk'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sizeController,
                    decoration: const InputDecoration(labelText: 'Size (e.g. 20G, 500M)', hintText: '20G'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFormat,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: const [
                      DropdownMenuItem(value: 'qcow2', child: Text('qcow2 (Recommended)')),
                      DropdownMenuItem(value: 'raw', child: Text('raw (Performance)')),
                      DropdownMenuItem(value: 'vmdk', child: Text('vmdk (VMware)')),
                      DropdownMenuItem(value: 'vdi', child: Text('vdi (VirtualBox)')),
                      DropdownMenuItem(value: 'qed', child: Text('qed (Enhanced)')),
                    ],
                    onChanged: (v) => setState(() => _selectedFormat = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _createImage, child: const Text('Create & Select')),
          ],
        ),
      ),
    );
  }
}
