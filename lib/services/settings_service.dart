import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  String qemuSystemPath;
  String qemuImgPath;
  String vmsPath;

  Settings({
    this.qemuSystemPath = 'qemu-system-x86_64',
    this.qemuImgPath = 'qemu-img',
    this.vmsPath = '',
  });

  Map<String, dynamic> toJson() => {
        'qemuSystemPath': qemuSystemPath,
        'qemuImgPath': qemuImgPath,
        'vmsPath': vmsPath,
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        qemuSystemPath: json['qemuSystemPath'] ?? 'qemu-system-x86_64',
        qemuImgPath: json['qemuImgPath'] ?? 'qemu-img',
        vmsPath: json['vmsPath'] ?? '',
      );
}

class SettingsService {
  static const _key = 'settings';

  Future<void> saveSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<Settings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      try {
        return Settings.fromJson(jsonDecode(data));
      } catch (e) {
        return Settings();
      }
    }
    return Settings();
  }
}
