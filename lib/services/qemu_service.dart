import 'dart:io';

import 'package:path/path.dart' as p;

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

  /// QEMU device names for -vga shorthand values. The -vga shorthand takes no
  /// properties, so custom EDID resolution needs the explicit -device form.
  /// Values not listed here fall back to plain -vga (no custom resolution).
  static const _vgaDevices = {
    'virtio': 'virtio-vga',
    'std': 'VGA',
    'cirrus': 'cirrus-vga',
    'qxl': 'qxl-vga',
    'vmware': 'vmware-svga',
  };

  /// Directory holding one QMP unix socket per VM, under XDG_RUNTIME_DIR
  /// (falls back to the system temp dir).
  static Directory qmpSocketDir() {
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
    final base = runtimeDir == null || runtimeDir.isEmpty
        ? Directory.systemTemp.path
        : runtimeDir;
    return Directory(p.join(base, 'qemu_gui'));
  }

  static String qmpSocketPath(String vmId) =>
      p.join(qmpSocketDir().path, '$vmId.qmp.sock');

  List<String> buildArgs(VMConfig vm, {bool headless = false}) {
    final args = <String>[];
    args.addAll(['-machine', vm.machine]);
    if (vm.enableKvm) args.add('-enable-kvm');
    args.addAll(['-m', '${vm.memoryMB}M']);
    args.addAll(['-smp', vm.cores.toString()]);
    args.addAll(['-cpu', vm.cpuModel]);
    final vgaDevice = vm.enableEdid && vm.xres > 0 && vm.yres > 0 ? _vgaDevices[vm.vga] : null;
    if (vgaDevice != null) {
      args.addAll(['-device', '$vgaDevice,edid=on,xres=${vm.xres},yres=${vm.yres}']);
    } else {
      args.addAll(['-vga', vm.vga]);
    }
    args.addAll(['-display', headless ? 'none' : vm.display]);
    args.addAll(['-boot', 'order=${vm.bootOrder}']);

    if (vm.useUsbTablet) {
      args.addAll(['-usb', '-device', 'usb-tablet']);
    }

    for (final disk in vm.disks) {
      args.addAll(['-drive', 'file=${disk.path},format=${disk.format}']);
    }

    // Shared folders (9p virtfs)
    for (final folder in vm.sharedFolders) {
      final ro = folder.readOnly ? ',readonly=on' : '';
      args.addAll([
        '-virtfs',
        'local,path=${folder.path},mount_tag=${folder.mountTag},security_model=mapped-xattr$ro',
      ]);
    }

    if (vm.isoPath != null) {
      args.addAll(['-cdrom', vm.isoPath!]);
    }

    // Network
    String netArgs = 'user,id=${vm.netConfig.id}';
    for (final pf in vm.netConfig.portForwards) {
      netArgs += ',$pf';
    }
    for (final gf in vm.netConfig.guestForwards) {
      netArgs += ',$gf';
    }
    args.addAll(['-netdev', netArgs]);
    args.addAll(['-device', 'virtio-net-pci,netdev=${vm.netConfig.id}']);

    // QMP monitor socket so the app can poll performance stats. server=on
    // keeps the socket alive across GUI reconnects; wait=off so startup never
    // blocks on a client. The path is derived from the VM id, so starting the
    // same VM twice would collide on the socket and the process map — a
    // pre-existing single-instance-per-VM assumption of VMService.
    args.addAll(['-qmp', 'unix:${qmpSocketPath(vm.id)},server=on,wait=off']);

    // Explicit balloon device for query-balloon: the implicit default balloon
    // is never activated (QMP reports DeviceNotActive without it). Skip on
    // machines without a PCI bus (isapc fails to start with this device).
    if (vm.machine == 'pc' || vm.machine == 'q35') {
      args.addAll(['-device', 'virtio-balloon']);
    }

    return args;
  }

  String buildCommandString(String qemuPath, VMConfig vm, {bool headless = false}) {
    final args = buildArgs(vm, headless: headless);
    return '$qemuPath ${args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ')}';
  }

  Future<Process> startVM(String qemuPath, VMConfig vm, {bool headless = false}) async {
    // QEMU's unix-socket QMP server fails to bind if a stale socket file from
    // a previous run is still on disk, so remove it up front.
    final sockDir = qmpSocketDir();
    await sockDir.create(recursive: true);
    final sockFile = File(qmpSocketPath(vm.id));
    if (await sockFile.exists()) {
      try {
        await sockFile.delete();
      } catch (_) {
        // QEMU will surface the bind error in the VM log.
      }
    }
    final args = buildArgs(vm, headless: headless);
    return await Process.start(qemuPath, args);
  }
}
