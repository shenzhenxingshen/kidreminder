import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidreminder/models/app_models.dart';
import 'package:kidreminder/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    test('loadSettings returns defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();

      final s = await service.loadSettings();
      expect(s.taskItems.length, greaterThanOrEqualTo(2));
      expect(s.behaviorItems.length, greaterThanOrEqualTo(2));
      expect(s.completedCountToday, 0);
    });

    test('loadSettings fallback defaults when invalid json', () async {
      SharedPreferences.setMockInitialValues({
        'app_settings_v1': 'invalid-json',
      });
      final service = StorageService();

      final s = await service.loadSettings();
      expect(s.taskItems.length, greaterThanOrEqualTo(2));
      expect(s.behaviorItems.length, greaterThanOrEqualTo(2));
    });

    test('save then load should be consistent', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();

      final base = AppSettings.defaults();
      final firstTask = base.taskItems.first;
      final updatedTask = firstTask.copyWith(audioPath: '/tmp/task.m4a');
      final updatedItems = base.items
          .map((e) => e.id == updatedTask.id ? updatedTask : e)
          .toList();

      final origin = base.copyWith(
        completedCountToday: 7,
        items: updatedItems,
      );
      await service.saveSettings(origin);

      final loaded = await service.loadSettings();
      expect(loaded.completedCountToday, 7);
      expect(loaded.itemById(updatedTask.id)?.audioPath, '/tmp/task.m4a');
    });

    test('load valid json from mock storage', () async {
      final raw = jsonEncode(
        AppSettings.defaults().copyWith(completedCountToday: 9).toJson(),
      );
      SharedPreferences.setMockInitialValues({'app_settings_v1': raw});
      final service = StorageService();

      final loaded = await service.loadSettings();
      expect(loaded.completedCountToday, 9);
    });
  });
}