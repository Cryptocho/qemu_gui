import 'disk_image.dart';
import 'net_config.dart';

class VMConfig {
  final String id;
  final String name;
  final String machine; // q35, pc
  final bool enableKvm;
  final int memoryMB;
  final int cores;
  final String cpuModel; // host, max
  final String vga; // virtio, std
  final String display; // gtk, sdl, none
  final String bootOrder; // dc, cd
  final String? isoPath;
  final List<DiskImage> disks;
  final NetConfig netConfig;
  final bool useUsbTablet;

  VMConfig({
    required this.id,
    required this.name,
    this.machine = 'q35',
    this.enableKvm = true,
    this.memoryMB = 4096,
    this.cores = 4,
    this.cpuModel = 'host',
    this.vga = 'virtio',
    this.display = 'gtk',
    this.bootOrder = 'dc',
    this.isoPath,
    this.disks = const [],
    required this.netConfig,
    this.useUsbTablet = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'machine': machine,
        'enableKvm': enableKvm,
        'memoryMB': memoryMB,
        'cores': cores,
        'cpuModel': cpuModel,
        'vga': vga,
        'display': display,
        'bootOrder': bootOrder,
        'isoPath': isoPath,
        'disks': disks.map((e) => e.toJson()).toList(),
        'netConfig': netConfig.toJson(),
        'useUsbTablet': useUsbTablet,
      };

  factory VMConfig.fromJson(Map<String, dynamic> json) => VMConfig(
        id: json['id'],
        name: json['name'],
        machine: json['machine'] ?? 'q35',
        enableKvm: json['enableKvm'] ?? true,
        memoryMB: json['memoryMB'] ?? 4096,
        cores: json['cores'] ?? 4,
        cpuModel: json['cpuModel'] ?? 'host',
        vga: json['vga'] ?? 'virtio',
        display: json['display'] ?? 'gtk',
        bootOrder: json['bootOrder'] ?? 'dc',
        isoPath: json['isoPath'],
        disks: (json['disks'] as List)
            .map((e) => DiskImage.fromJson(e))
            .toList(),
        netConfig: NetConfig.fromJson(json['netConfig']),
        useUsbTablet: json['useUsbTablet'] ?? true,
      );
}
