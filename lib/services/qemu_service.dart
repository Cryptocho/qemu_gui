import 'dart:io';
import '../models/vm_config.dart';

class QemuService {
  Future<String> getQemuVersion(String path) async {
    try {
      final result = await Process.run(path, ['-version']);
      if (result.exitCode == 0) {
        return result.stdout.toString().split('''
''').first;
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> getQemuImgVersion(String path) async {
    try {
      final result = await Process.run(path, ['--version']);
      if (result.exitCode == 0) {
        return result.stdout.toString().split('''
''').first;
      }
      return 'Error: ${result.stderr}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> isKvmAvailable() async {
    if (!Platform.isLinux) return false;
    return await File('/dev/kvm').exists();
  }

  List<String> buildArgs(VMConfig vm, {bool headless = false}) {
    final args = <String>[];
    args.addAll(['-machine', vm.machine]);
    if (vm.enableKvm) args.add('-enable-kvm');
    args.addAll(['-m', '${vm.memoryMB}M']);
    args.addAll(['-smp', vm.cores.toString()]);
    args.addAll(['-cpu', vm.cpuModel]);
    args.addAll(['-vga', vm.vga]);
    args.addAll(['-display', headless ? 'none' : vm.display]);
    args.addAll(['-boot', 'order=${vm.bootOrder}']);

    if (vm.useUsbTablet) {
      args.addAll(['-usb', '-device', 'usb-tablet']);
    }

    for (final disk in vm.disks) {
      args.addAll(['-drive', 'file=${disk.path},format=${disk.format}']);
    }

    if (vm.isoPath != null) {
      args.addAll(['-cdrom', vm.isoPath!]);
    }

    // Network
    String netArgs = 'user,id=${vm.netConfig.id}';
    for (final pf in vm.netConfig.portForwards) {
      netArgs += ',$pf';
    }
    args.addAll(['-netdev', netArgs]);
    args.addAll(['-device', 'virtio-net-pci,netdev=${vm.netConfig.id}']);

    return args;
  }

  String buildCommandString(String qemuPath, VMConfig vm, {bool headless = false}) {
    final args = buildArgs(vm, headless: headless);
    return '$qemuPath ${args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ')}';
  }

  Future<Process> startVM(String qemuPath, VMConfig vm, {bool headless = false}) async {
    final args = buildArgs(vm, headless: headless);
    return await Process.start(qemuPath, args);
  }
}
