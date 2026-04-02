import 'dart:convert';

import 'package:kidreminder/models/app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _settingsKey = 'app_settings_v1';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return AppSettings.defaults();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, raw);
  }
}