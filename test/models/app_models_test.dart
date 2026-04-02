import 'package:flutter_test/flutter_test.dart';
import 'package:kidreminder/models/app_models.dart';

void main() {
  group('ReminderItem', () {
    test('fromJson unknown type fallback', () {
      final item = ReminderItem.fromJson({
        'id': 'x',
        'type': 'unknown',
        'title': '提示',
        'enabled': true,
      });

      expect(item.type, ReminderItemType.task);
      expect(item.id, 'x');
    });

    test('copyWith should update fields', () {
      const base = ReminderItem(
        id: 'task_1',
        type: ReminderItemType.task,
        title: '吃饭',
        hour: 12,
        minute: 30,
      );

      final copied = base.copyWith(title: '晚饭', hour: 18, minute: 0, enabled: false);
      expect(copied.title, '晚饭');
      expect(copied.hour, 18);
      expect(copied.minute, 0);
      expect(copied.enabled, false);
      expect(copied.id, 'task_1');
    });
  });

  group('AppSettings', () {
    test('buildDateKey format should be yyyy-MM-dd', () {
      final v = AppSettings.buildDateKey(DateTime(2026, 4, 2));
      expect(v, '2026-04-02');
    });

    test('defaults should include task and behavior items', () {
      final s = AppSettings.defaults();
      expect(s.taskItems.length, greaterThanOrEqualTo(2));
      expect(s.behaviorItems.length, greaterThanOrEqualTo(2));
    });

    test('fromJson legacy tasks should migrate to items', () {
      final s = AppSettings.fromJson({
        'tasks': [
          {
            'type': 'washAndBrush',
            'title': '洗漱',
            'hour': 20,
            'minute': 0,
            'enabled': true,
          },
          {
            'type': 'sleep',
            'title': '睡觉',
            'hour': 21,
            'minute': 0,
            'enabled': true,
          },
        ],
        'washAndBrushAudioPath': '/tmp/wash.m4a',
        'sleepAudioPath': '/tmp/sleep.m4a',
      });

      expect(s.taskItems.length, 2);
      expect(s.behaviorItems.isNotEmpty, true);
      expect(s.taskItems.firstWhere((e) => e.id == 'task_wash').audioPath, '/tmp/wash.m4a');
    });

    test('toJson/fromJson roundtrip', () {
      final origin = AppSettings.defaults().copyWith(
        completedCountToday: 5,
        praiseAudioPath: '/tmp/praise.m4a',
      );
      final restored = AppSettings.fromJson(origin.toJson());

      expect(restored.completedCountToday, 5);
      expect(restored.praiseAudioPath, '/tmp/praise.m4a');
      expect(restored.items.isNotEmpty, true);
    });
  });
}