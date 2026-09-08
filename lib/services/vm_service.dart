import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vm_config.dart';
import 'monitor_service.dart';
import 'qemu_service.dart';

class VMService extends ChangeNotifier {
  static const _key = 'vms';
  List<VMConfig> _vms = [];
  final Map<String, Process> _runningProcesses = {};
  final Map<String, List<String>> _logs = {};
  final MonitorService? _monitor;

  VMService({MonitorService? monitorService}) : _monitor = monitorService;

  List<VMConfig> get vms => _vms;

  bool isVMRunning(String id) => _runningProcesses.containsKey(id);

  List<String> getLogs(String vmId) => _logs[vmId] ?? [];

  void clearLogs(String vmId) {
    _logs[vmId] = [];
    notifyListeners();
  }

  void _addLog(String vmId, String line) {
    _logs[vmId] ??= [];
    _logs[vmId]!.add('[${DateTime.now().toIso8601String()}] $line');
    if (_logs[vmId]!.length > 1000) {
      _logs[vmId]!.removeAt(0);
    }
    notifyListeners();
  }

  Future<void> loadVMs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      try {
        final List list = jsonDecode(data);
        _vms = list.map((e) => VMConfig.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        _vms = [];
      }
    }
  }

  Future<void> saveVMs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_vms.map((e) => e.toJson()).toList()));
  }

  Future<void> addVM(VMConfig vm) async {
    _vms.add(vm);
    await saveVMs();
    notifyListeners();
  }

  /// Stores a new configuration for an existing VM (matched by id) without
  /// touching a running process, so edits to a running VM take effect on its
  /// next start rather than killing it. If no VM with that id exists, it is
  /// added.
  Future<void> updateVM(VMConfig vm) async {
    final index = _vms.indexWhere((element) => element.id == vm.id);
    if (index == -1) {
      _vms.add(vm);
    } else {
      _vms[index] = vm;
    }
    await saveVMs();
    notifyListeners();
  }

  Future<void> removeVM(String id) async {
    stopVM(id);
    _vms.removeWhere((element) => element.id == id);
    await saveVMs();
    notifyListeners();
  }

  void registerProcess(String vmId, Process process, {String? command}) {
    _runningProcesses[vmId] = process;
    _monitor?.attach(vmId, process.pid, QemuService.qmpSocketPath(vmId));
    if (command != null) {
      _addLog(vmId, 'Starting VM with command: $command');
    }
    notifyListeners();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) _addLog(vmId, 'STDOUT: $line');
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) _addLog(vmId, 'STDERR: $line');
    });

    process.exitCode.then((code) {
      _addLog(vmId, 'Process exited with code $code');
      _runningProcesses.remove(vmId);
      _monitor?.detach(vmId);
      notifyListeners();
    });
  }

  void stopVM(String vmId) {
    _runningProcesses[vmId]?.kill();
    _runningProcesses.remove(vmId);
    _monitor?.detach(vmId);
    notifyListeners();
  }
}
