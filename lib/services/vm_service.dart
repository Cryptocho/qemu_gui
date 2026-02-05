import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vm_config.dart';

class VMService extends ChangeNotifier {
  static const _key = 'vms';
  List<VMConfig> _vms = [];
  final Map<String, Process> _runningProcesses = {};
  final Map<String, List<String>> _logs = {};

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

  Future<void> removeVM(String id) async {
    stopVM(id);
    _vms.removeWhere((element) => element.id == id);
    await saveVMs();
    notifyListeners();
  }

  void registerProcess(String vmId, Process process, {String? command}) {
    _runningProcesses[vmId] = process;
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
      notifyListeners();
    });
  }

  void stopVM(String vmId) {
    _runningProcesses[vmId]?.kill();
    _runningProcesses.remove(vmId);
    notifyListeners();
  }
}
