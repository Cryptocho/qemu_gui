import 'package:flutter_test/flutter_test.dart';
import 'package:qemu_gui/models/disk_image.dart';
import 'package:qemu_gui/models/net_config.dart';
import 'package:qemu_gui/models/shared_folder.dart';
import 'package:qemu_gui/models/vm_config.dart';
import 'package:qemu_gui/services/qemu_service.dart';

VMConfig _vm({
  List<SharedFolder> sharedFolders = const [],
  String? isoPath,
  bool enableEdid = false,
  int xres = 1920,
  int yres = 1080,
  String vga = 'virtio',
}) {
  return VMConfig(
    id: 'vm1',
    name: 't',
    isoPath: isoPath,
    vga: vga,
    disks: isoPath == null
        ? []
        : [DiskImage(path: '/vms/test.qcow2')],
    netConfig: NetConfig(id: 'n0'),
    sharedFolders: sharedFolders,
    enableEdid: enableEdid,
    xres: xres,
    yres: yres,
  );
}

void main() {
  final qemu = QemuService();

  test('no shared folders emits no -virtfs args', () {
    final args = qemu.buildArgs(_vm());
    expect(args, isNot(contains('-virtfs')));
  });

  test('emits readonly=on only for read-only folders', () {
    final args = qemu.buildArgs(_vm(sharedFolders: [
      SharedFolder(path: '/home/u/My Docs', mountTag: 'My_Docs'),
      SharedFolder(path: '/home/u/iso', mountTag: 'iso', readOnly: true),
    ]));
    expect(
      args,
      containsAllInOrder(<String>[
        '-virtfs',
        'local,path=/home/u/My Docs,mount_tag=My_Docs,security_model=mapped-xattr',
        '-virtfs',
        'local,path=/home/u/iso,mount_tag=iso,security_model=mapped-xattr,readonly=on',
      ]),
    );
  });

  test('shared folder args sit between disks and cdrom', () {
    final args = qemu.buildArgs(_vm(
      isoPath: '/iso/linux.iso',
      sharedFolders: [
        SharedFolder(path: '/home/u/docs', mountTag: 'docs'),
      ],
    ));
    expect(args.indexOf('-virtfs'), greaterThan(args.lastIndexOf('-drive')));
    expect(args.indexOf('-virtfs'), lessThan(args.indexOf('-cdrom')));
  });

  test('edid disabled keeps the -vga shorthand', () {
    final args = qemu.buildArgs(_vm());
    expect(args, containsAllInOrder(['-vga', 'virtio']));
    expect(args, isNot(contains('virtio-vga,edid=on,xres=1920,yres=1080')));
  });

  test('edid enabled emits explicit -device with resolution', () {
    final args = qemu.buildArgs(_vm(enableEdid: true));
    expect(args, containsAllInOrder(['-device', 'virtio-vga,edid=on,xres=1920,yres=1080']));
    expect(args, isNot(contains('-vga')));
  });

  test('edid maps std vga to the VGA device', () {
    final args = qemu.buildArgs(_vm(enableEdid: true, vga: 'std', xres: 2560, yres: 1440));
    expect(args, contains('VGA,edid=on,xres=2560,yres=1440'));
  });

  test('edid falls back to -vga for unknown vga values', () {
    final args = qemu.buildArgs(_vm(enableEdid: true, vga: 'foo'));
    expect(args, containsAllInOrder(['-vga', 'foo']));
  });

  test('edid falls back to -vga when resolution is invalid', () {
    final args = qemu.buildArgs(_vm(enableEdid: true, xres: 0));
    expect(args, containsAllInOrder(['-vga', 'virtio']));
  });

  test('adds QMP socket and explicit balloon device for q35', () {
    final args = qemu.buildArgs(_vm());
    expect(
      args,
      containsAllInOrder([
        '-qmp',
        'unix:${QemuService.qmpSocketPath('vm1')},server=on,wait=off',
      ]),
    );
    expect(args, containsAllInOrder(['-device', 'virtio-balloon']));
  });

  test('skips balloon on machines without a PCI bus', () {
    final vm = VMConfig(
      id: 'vm1',
      name: 't',
      machine: 'isapc',
      netConfig: NetConfig(id: 'n0'),
    );
    final args = qemu.buildArgs(vm);
    expect(args, isNot(contains('virtio-balloon')));
    expect(
      args,
      containsAllInOrder([
        '-qmp',
        'unix:${QemuService.qmpSocketPath('vm1')},server=on,wait=off',
      ]),
    );
  });
}
