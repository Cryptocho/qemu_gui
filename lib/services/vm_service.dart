import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vm_config.dart';

class VMService extends ChangeNotifier {
  static const _key = 'vms';
  List<VMConfig> _vms = [];

  List<VMConfig> get vms => _vms;

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
    _vms.removeWhere((element) => element.id == id);
    await saveVMs();
    notifyListeners();
  }
}
