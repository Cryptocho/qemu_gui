import 'package:flutter_test/flutter_test.dart';
import 'package:qemu_gui/models/net_config.dart';
import 'package:qemu_gui/models/shared_folder.dart';
import 'package:qemu_gui/models/vm_config.dart';

void main() {
  test('json roundtrip preserves edid resolution settings', () {
    final vm = VMConfig(
      id: 'vm1',
      name: 't',
      netConfig: NetConfig(id: 'n0'),
      enableEdid: true,
      xres: 2560,
      yres: 1440,
      sharedFolders: [SharedFolder(path: '/a/b', mountTag: 'b')],
    );
    final restored = VMConfig.fromJson(vm.toJson());
    expect(restored.enableEdid, true);
    expect(restored.xres, 2560);
    expect(restored.yres, 1440);
    expect(restored.sharedFolders.length, 1);
    expect(restored.sharedFolders.first.mountTag, 'b');
  });

  test('legacy json without new keys decodes with defaults', () {
    // Simulates a blob written before sharedFolders/edid existed (old toJson
    // always emitted the keys below). Guards against VMService.loadVMs()
    // silently wiping the VM list when decode throws on old blobs.
    final vm = VMConfig.fromJson({
      'id': 'vm1',
      'name': 'old',
      'machine': 'q35',
      'enableKvm': true,
      'memoryMB': 4096,
      'cores': 4,
      'vga': 'virtio',
      'display': 'gtk',
      'bootOrder': 'dc',
      'disks': [],
      'netConfig': {'id': 'n0'},
      'useUsbTablet': true,
    });
    expect(vm.enableEdid, false);
    expect(vm.xres, 1920);
    expect(vm.yres, 1080);
    expect(vm.sharedFolders, isEmpty);
  });
}
