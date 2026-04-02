import 'package:flutter/material.dart';

enum ReminderItemType { task, behavior }

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.type,
    required this.title,
    this.audioPath,
    this.hour,
    this.minute,
    this.enabled = true,
  });

  final String id;
  final ReminderItemType type;
  final String title;
  final String? audioPath;
  final int? hour;
  final int? minute;
  final bool enabled;

  bool get isTask => type == ReminderItemType.task;
  bool get isBehavior => type == ReminderItemType.behavior;
  bool get hasTime => hour != null && minute != null;

  TimeOfDay? get time {
    if (!hasTime) return null;
    return TimeOfDay(hour: hour!, minute: minute!);
  }

  ReminderItem copyWith({
    String? title,
    ReminderItemType? type,
    String? audioPath,
    int? hour,
    int? minute,
    bool? enabled,
    bool clearAudioPath = false,
    bool clearTime = false,
  }) {
    return ReminderItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      hour: clearTime ? null : hour ?? this.hour,
      minute: clearTime ? null : minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'audioPath': audioPath,
      'hour': hour,
      'minute': minute,
      'enabled': enabled,
    };
  }

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? ReminderItemType.task.name;
    return ReminderItem(
      id: json['id'] as String? ?? '',
      type: ReminderItemType.values.firstWhere(
        (v) => v.name == typeName,
        orElse: () => ReminderItemType.task,
      ),
      title: json['title'] as String? ?? '',
      audioPath: json['audioPath'] as String?,
      hour: json['hour'] as int?,
      minute: json['minute'] as int?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.items,
    this.praiseAudioPath,
    required this.completedCountToday,
    required this.completedDate,
  });

  final List<ReminderItem> items;
  final String? praiseAudioPath;
  final int completedCountToday;
  final String completedDate;

  static String buildDateKey(DateTime dateTime) {
    final y = dateTime.year.toString();
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<ReminderItem> get taskItems =>
      items.where((e) => e.type == ReminderItemType.task).toList();

  List<ReminderItem> get behaviorItems =>
      items.where((e) => e.type == ReminderItemType.behavior).toList();

  ReminderItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  factory AppSettings.defaults() {
    final now = DateTime.now();
    final date = buildDateKey(now);
    return AppSettings(
      items: const [
        ReminderItem(
          id: 'task_wash',
          type: ReminderItemType.task,
          title: '洗漱',
          hour: 20,
          minute: 0,
          enabled: true,
        ),
        ReminderItem(
          id: 'task_sleep',
          type: ReminderItemType.task,
          title: '睡觉',
          hour: 21,
          minute: 0,
          enabled: true,
        ),
        ReminderItem(
          id: 'behavior_nice_talk',
          type: ReminderItemType.behavior,
          title: '好好说话',
          enabled: true,
        ),
        ReminderItem(
          id: 'behavior_gentle_hands',
          type: ReminderItemType.behavior,
          title: '小手轻轻',
          enabled: true,
        ),
      ],
      completedCountToday: 0,
      completedDate: date,
    );
  }

  AppSettings copyWith({
    List<ReminderItem>? items,
    String? praiseAudioPath,
    int? completedCountToday,
    String? completedDate,
    bool clearPraiseAudioPath = false,
  }) {
    return AppSettings(
      items: items ?? this.items,
      praiseAudioPath:
          clearPraiseAudioPath ? null : praiseAudioPath ?? this.praiseAudioPath,
      completedCountToday: completedCountToday ?? this.completedCountToday,
      completedDate: completedDate ?? this.completedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'praiseAudioPath': praiseAudioPath,
      'completedCountToday': completedCountToday,
      'completedDate': completedDate,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults();

    final parsedItems = <ReminderItem>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          try {
            parsedItems.add(ReminderItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }

    if (parsedItems.isEmpty) {
      final legacyTasks = <ReminderItem>[];
      final rawTasks = json['tasks'];
      if (rawTasks is List) {
        for (final task in rawTasks) {
          if (task is Map) {
            try {
              final map = Map<String, dynamic>.from(task);
              final typeName = map['type'] as String? ?? 'washAndBrush';
              final title = map['title'] as String? ??
                  (typeName == 'sleep' ? '睡觉' : '洗漱');
              final id = typeName == 'sleep' ? 'task_sleep' : 'task_wash';
              final audioPath = typeName == 'sleep'
                  ? json['sleepAudioPath'] as String?
                  : json['washAndBrushAudioPath'] as String?;
              legacyTasks.add(
                ReminderItem(
                  id: id,
                  type: ReminderItemType.task,
                  title: title,
                  hour: map['hour'] as int?,
                  minute: map['minute'] as int?,
                  enabled: map['enabled'] as bool? ?? true,
                  audioPath: audioPath,
                ),
              );
            } catch (_) {}
          }
        }
      }
      if (legacyTasks.isNotEmpty) {
        parsedItems.addAll(legacyTasks);
      }
    }

    final finalItems = parsedItems.isEmpty ? defaults.items : parsedItems;
    final hasBehavior = finalItems.any((e) => e.type == ReminderItemType.behavior);
    final mergedItems = hasBehavior
        ? finalItems
        : [...finalItems, ...defaults.behaviorItems];

    return AppSettings(
      items: mergedItems,
      praiseAudioPath: json['praiseAudioPath'] as String?,
      completedCountToday: json['completedCountToday'] as int? ?? 0,
      completedDate: json['completedDate'] as String? ?? defaults.completedDate,
    );
  }
}