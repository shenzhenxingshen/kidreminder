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

class Achievement {
  const Achievement({required this.id, required this.title, required this.icon, required this.requirement, this.unlockedDate});
  final String id;
  final String title;
  final String icon;
  final String requirement;
  final String? unlockedDate;
  bool get isUnlocked => unlockedDate != null;
  Achievement unlock(String date) => Achievement(id: id, title: title, icon: icon, requirement: requirement, unlockedDate: date);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'icon': icon, 'requirement': requirement, 'unlockedDate': unlockedDate};
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(id: json['id'] ?? '', title: json['title'] ?? '', icon: json['icon'] ?? '⭐', requirement: json['requirement'] ?? '', unlockedDate: json['unlockedDate']);
}

class WeeklyStats {
  const WeeklyStats({required this.dailyCounts});
  final Map<String, int> dailyCounts;
  int get totalWeek => dailyCounts.values.fold(0, (a, b) => a + b);
  int get activeDays => dailyCounts.values.where((c) => c > 0).length;
  Map<String, dynamic> toJson() => {'dailyCounts': dailyCounts};
  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    final raw = json['dailyCounts'];
    final map = <String, int>{};
    if (raw is Map) { raw.forEach((k, v) { map[k.toString()] = v is int ? v : 0; }); }
    return WeeklyStats(dailyCounts: map);
  }
}

class AppSettings {
  const AppSettings({
    required this.items,
    this.praiseAudioPath,
    required this.completedCountToday,
    required this.completedDate,
    required this.onboardingCompleted,
    required this.achievements,
    required this.weeklyData,
  });

  final List<ReminderItem> items;
  final String? praiseAudioPath;
  final int completedCountToday;
  final String completedDate;
  final bool onboardingCompleted;
  final List<Achievement> achievements;
  final Map<String, int> weeklyData;

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

  static List<Achievement> get defaultAchievements => const [
    Achievement(id: 'first_done', title: '第一步', icon: '🌟', requirement: '完成第一次任务'),
    Achievement(id: 'streak_3', title: '三天小达人', icon: '🔥', requirement: '连续3天完成任务'),
    Achievement(id: 'streak_7', title: '一周小冠军', icon: '👑', requirement: '连续7天完成任务'),
    Achievement(id: 'total_10', title: '十全十美', icon: '💪', requirement: '累计完成10次'),
    Achievement(id: 'total_50', title: '超级宝贝', icon: '🏆', requirement: '累计完成50次'),
    Achievement(id: 'all_tasks', title: '全能小达人', icon: '🎯', requirement: '一天内完成所有任务'),
  ];

  static List<ReminderItem> get defaultTemplates => const [
    ReminderItem(id: 'tpl_eat', type: ReminderItemType.task, title: '该吃饭了', hour: 12, minute: 0),
    ReminderItem(id: 'tpl_nap', type: ReminderItemType.task, title: '该午睡了', hour: 13, minute: 0),
    ReminderItem(id: 'tpl_homework', type: ReminderItemType.task, title: '该做作业了', hour: 16, minute: 30),
    ReminderItem(id: 'tpl_wash', type: ReminderItemType.task, title: '该洗漱了', hour: 20, minute: 0),
    ReminderItem(id: 'tpl_sleep', type: ReminderItemType.task, title: '该睡觉了', hour: 21, minute: 0),
    ReminderItem(id: 'tpl_water', type: ReminderItemType.task, title: '该喝水了', hour: 10, minute: 0),
    ReminderItem(id: 'tpl_brush', type: ReminderItemType.task, title: '该刷牙了', hour: 7, minute: 30),
    ReminderItem(id: 'tpl_exercise', type: ReminderItemType.task, title: '该运动了', hour: 17, minute: 0),
    ReminderItem(id: 'bhv_talk', type: ReminderItemType.behavior, title: '好好说话'),
    ReminderItem(id: 'bhv_gentle', type: ReminderItemType.behavior, title: '小手轻轻'),
    ReminderItem(id: 'bhv_share', type: ReminderItemType.behavior, title: '学会分享'),
    ReminderItem(id: 'bhv_patient', type: ReminderItemType.behavior, title: '耐心等待'),
  ];

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
      onboardingCompleted: false,
      achievements: defaultAchievements,
      weeklyData: const {},
    );
  }

  AppSettings copyWith({
    List<ReminderItem>? items,
    String? praiseAudioPath,
    int? completedCountToday,
    String? completedDate,
    bool clearPraiseAudioPath = false,
    bool? onboardingCompleted,
    List<Achievement>? achievements,
    Map<String, int>? weeklyData,
  }) {
    return AppSettings(
      items: items ?? this.items,
      praiseAudioPath:
          clearPraiseAudioPath ? null : praiseAudioPath ?? this.praiseAudioPath,
      completedCountToday: completedCountToday ?? this.completedCountToday,
      completedDate: completedDate ?? this.completedDate,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      achievements: achievements ?? this.achievements,
      weeklyData: weeklyData ?? this.weeklyData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'praiseAudioPath': praiseAudioPath,
      'completedCountToday': completedCountToday,
      'completedDate': completedDate,
      'onboardingCompleted': onboardingCompleted,
      'achievements': achievements.map((e) => e.toJson()).toList(),
      'weeklyData': weeklyData,
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

    // Parse achievements
    final parsedAchievements = <Achievement>[];
    final rawAchievements = json['achievements'];
    if (rawAchievements is List) {
      for (final a in rawAchievements) {
        if (a is Map) {
          try {
            parsedAchievements.add(Achievement.fromJson(Map<String, dynamic>.from(a)));
          } catch (_) {}
        }
      }
    }

    // Parse weeklyData
    final parsedWeeklyData = <String, int>{};
    final rawWeekly = json['weeklyData'];
    if (rawWeekly is Map) {
      rawWeekly.forEach((k, v) { parsedWeeklyData[k.toString()] = v is int ? v : 0; });
    }

    return AppSettings(
      items: mergedItems,
      praiseAudioPath: json['praiseAudioPath'] as String?,
      completedCountToday: json['completedCountToday'] as int? ?? 0,
      completedDate: json['completedDate'] as String? ?? defaults.completedDate,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      achievements: parsedAchievements.isEmpty ? defaults.achievements : parsedAchievements,
      weeklyData: parsedWeeklyData,
    );
  }
}
