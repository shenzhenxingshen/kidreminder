import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kidreminder/models/app_models.dart';
import 'package:kidreminder/services/audio_service.dart';
import 'package:kidreminder/services/notification_service.dart';
import 'package:kidreminder/services/storage_service.dart';
import 'package:kidreminder/screens/onboarding_screen.dart';
import 'package:kidreminder/widgets/celebration_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _setupBootReceiver();
  runApp(const KidReminderApp());
}

/// 设置开机广播接收器
void _setupBootReceiver() {
  const platform = MethodChannel('com.example.kidreminder/boot');
  
  platform.setMethodCallHandler((call) async {
    if (call.method == 'rescheduleNotifications') {
      // 在后台恢复所有通知
      await _rescheduleNotificationsInBackground();
    }
  });
}

/// 在后台恢复通知调度
Future<void> _rescheduleNotificationsInBackground() async {
  try {
    // 初始化通知服务（不请求权限，因为后台运行）
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // 加载保存的设置
    final storageService = StorageService();
    final settings = await storageService.loadSettings();
    
    // 重新调度通知
    await notificationService.scheduleForSettings(settings);
    
    if (kDebugMode) {
      print('后台通知恢复成功');
    }
  } catch (e) {
    if (kDebugMode) {
      print('后台通知恢复失败: $e');
    }
  }
}

class KidReminderApp extends StatelessWidget {
  const KidReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小小提醒官',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final AudioService _audioService = AudioService();
  final TextEditingController _newTitleController = TextEditingController();

  AppSettings _settings = AppSettings.defaults();
  bool _loading = true;
  bool _isRecording = false;
  bool _recordingPraise = false;
  String? _recordingItemId;
  int _tabIndex = 0;
  ReminderItemType _newItemType = ReminderItemType.task;
  
  // 编辑相关状态
  String? _editingItemId;
  final TextEditingController _editTitleController = TextEditingController();
  ReminderItemType _editItemType = ReminderItemType.task;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    _editTitleController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    AppSettings settings = AppSettings.defaults();

    // 初始化通知服务
    try {
      await _notificationService.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('初始化超时');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('通知初始化失败: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通知服务初始化失败: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 请求通知权限
    try {
      final granted = await _notificationService.requestPermissions().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('权限请求超时');
        },
      );
      
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('未授予通知权限，提醒功能可能无法正常工作'),
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: '去设置',
              onPressed: () {}, // 可在此添加跳转到系统设置的逻辑
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('权限请求失败: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('权限请求失败: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 加载用户设置
    try {
      settings = await _storageService.loadSettings().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('加载设置超时');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('加载设置失败: $e');
      }
      // 加载失败时使用默认设置，不中断流程
    }

    // 调度通知
    try {
      await _notificationService.scheduleForSettings(settings).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('调度通知超时');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('调度通知失败: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('提醒调度失败: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _settings = _normalizeDailyCount(settings);
      _loading = false;
    });
  }

  AppSettings _normalizeDailyCount(AppSettings settings) {
    final today = _todayKey();
    if (settings.completedDate == today) {
      return settings;
    }
    return settings.copyWith(
      completedDate: today,
      completedCountToday: 0,
    );
  }

  String _todayKey() {
    return AppSettings.buildDateKey(DateTime.now());
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final normalized = _normalizeDailyCount(settings);
    setState(() {
      _settings = normalized;
    });
    
    try {
      await _storageService.saveSettings(normalized);
      if (kDebugMode) {
        print('设置保存成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存设置失败: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存设置失败: ${e.toString()}')),
      );
      return;
    }

    try {
      await _notificationService.scheduleForSettings(normalized);
      if (kDebugMode) {
        print('通知调度成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('通知调度失败: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提醒更新失败: ${e.toString()}')),
      );
    }
  }

  List<ReminderItem> _sortedTaskItems() {
    final tasks = _settings.taskItems.where((e) => e.hasTime).toList();
    tasks.sort((a, b) {
      final aMinutes = (a.hour ?? 0) * 60 + (a.minute ?? 0);
      final bMinutes = (b.hour ?? 0) * 60 + (b.minute ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
    return tasks;
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _preTime(int hour, int minute) {
    final total = hour * 60 + minute - 5;
    final normalized = (total + 24 * 60) % (24 * 60);
    final h = normalized ~/ 60;
    final m = normalized % 60;
    return _formatTime(h, m);
  }

  Future<void> _updateItem(ReminderItem nextItem) async {
    final newItems =
        _settings.items.map((e) => e.id == nextItem.id ? nextItem : e).toList();
    await _saveSettings(_settings.copyWith(items: newItems));
  }

  Future<void> _toggleItem(ReminderItem item, bool enabled) async {
    await _updateItem(item.copyWith(enabled: enabled));
  }

  Future<void> _pickTaskTime(ReminderItem item) async {
    final initial = item.time ?? const TimeOfDay(hour: 20, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '设置${item.title}时间',
    );
    if (selected == null) return;
    await _updateItem(item.copyWith(hour: selected.hour, minute: selected.minute));
  }

  String _newItemId(ReminderItemType type) {
    final prefix = type == ReminderItemType.task ? 'task' : 'behavior';
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<ReminderItem?> _createNewItem() async {
    final title = _newTitleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入提醒名称')),
      );
      return null;
    }

    final item = ReminderItem(
      id: _newItemId(_newItemType),
      type: _newItemType,
      title: title,
      enabled: true,
    );

    await _saveSettings(_settings.copyWith(items: [..._settings.items, item]));
    _newTitleController.clear();
    return item;
  }

  Future<void> _startRecordingForItem(String itemId) async {
    final hasPermission = await _audioService.checkPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先开启麦克风权限')),
      );
      return;
    }
    await _audioService.startRecording(fileName: '$itemId.m4a');
    setState(() {
      _isRecording = true;
      _recordingPraise = false;
      _recordingItemId = itemId;
    });
  }

  Future<void> _startRecordingForPraise() async {
    final hasPermission = await _audioService.checkPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先开启麦克风权限')),
      );
      return;
    }
    await _audioService.startRecording(fileName: 'praise.m4a');
    setState(() {
      _isRecording = true;
      _recordingPraise = true;
      _recordingItemId = null;
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final path = await _audioService.stopRecording();

    if (path == null || path.isEmpty) {
      setState(() {
        _isRecording = false;
        _recordingPraise = false;
        _recordingItemId = null;
      });
      return;
    }

    AppSettings next = _settings;
    if (_recordingPraise) {
      next = _settings.copyWith(praiseAudioPath: path);
    } else if (_recordingItemId != null) {
      final item = _settings.itemById(_recordingItemId!);
      if (item != null) {
        final updated = item.copyWith(audioPath: path);
        final newItems = _settings.items
            .map((e) => e.id == updated.id ? updated : e)
            .toList();
        next = _settings.copyWith(items: newItems);
      }
    }

    await _saveSettings(next);
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingPraise = false;
      _recordingItemId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('录音已保存')),
    );
  }

  Future<void> _playIfExists(String? path, String fallbackText) async {
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackText)),
      );
      return;
    }
    await _audioService.play(path);
  }

  Future<void> _onDonePressed() async {
    final today = _todayKey();
    final newCount = _settings.completedCountToday + 1;
    final newWeekly = Map<String, int>.from(_settings.weeklyData);
    newWeekly[today] = newCount;

    // 检查成就
    var achievements = List<Achievement>.from(_settings.achievements);
    achievements = _checkAchievements(achievements, newCount, newWeekly);

    final next = _normalizeDailyCount(_settings).copyWith(
      completedDate: today,
      completedCountToday: newCount,
      weeklyData: newWeekly,
      achievements: achievements,
    );
    await _saveSettings(next);

    // 显示庆祝动画
    setState(() => _showCelebration = true);
    await _playIfExists(next.praiseAudioPath, '太棒了，已记录一次完成');
  }

  List<Achievement> _checkAchievements(List<Achievement> achievements, int todayCount, Map<String, int> weekly) {
    final today = _todayKey();
    final totalAll = weekly.values.fold(0, (a, b) => a + b);

    // 计算连续天数
    int streak = 0;
    var d = DateTime.now();
    while (true) {
      final key = AppSettings.buildDateKey(d);
      if ((weekly[key] ?? 0) > 0) {
        streak++;
        d = d.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    final taskCount = _settings.taskItems.where((t) => t.enabled && t.hasTime).length;

    return achievements.map((a) {
      if (a.isUnlocked) return a;
      switch (a.id) {
        case 'first_done': return totalAll >= 1 ? a.unlock(today) : a;
        case 'streak_3': return streak >= 3 ? a.unlock(today) : a;
        case 'streak_7': return streak >= 7 ? a.unlock(today) : a;
        case 'total_10': return totalAll >= 10 ? a.unlock(today) : a;
        case 'total_50': return totalAll >= 50 ? a.unlock(today) : a;
        case 'all_tasks': return taskCount > 0 && todayCount >= taskCount ? a.unlock(today) : a;
        default: return a;
      }
    }).toList();
  }

  Future<void> _createAndRecord() async {
    final item = await _createNewItem();
    if (item == null) return;
    await _startRecordingForItem(item.id);
  }

  Future<void> _deleteItem(ReminderItem item) async {
    final confirmed = await _showDeleteConfirmDialog(item.title);
    if (!confirmed) return;

    // 删除录音文件（如果存在）
    if (item.audioPath != null && item.audioPath!.isNotEmpty) {
      try {
        await _audioService.deleteFile(item.audioPath!);
      } catch (e) {
        if (kDebugMode) {
          print('删除录音文件失败: $e');
        }
      }
    }

    // 从设置中删除
    final newItems = _settings.items.where((e) => e.id != item.id).toList();
    await _saveSettings(_settings.copyWith(items: newItems));
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.title} 已删除')),
    );
  }

  Future<bool> _showDeleteConfirmDialog(String title) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"$title"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showEditDialog(ReminderItem item) async {
    _editingItemId = item.id;
    _editTitleController.text = item.title;
    _editItemType = item.type;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑提醒'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _editTitleController,
                decoration: const InputDecoration(
                  labelText: '提醒名称',
                  hintText: '请输入提醒名称',
                ),
              ),
              const SizedBox(height: 16),
              const Text('提醒类型'),
              const SizedBox(height: 8),
              SegmentedButton<ReminderItemType>(
                segments: const [
                  ButtonSegment(
                    value: ReminderItemType.task,
                    label: Text('任务提醒'),
                    icon: Icon(Icons.schedule),
                  ),
                  ButtonSegment(
                    value: ReminderItemType.behavior,
                    label: Text('行为提醒'),
                    icon: Icon(Icons.psychology),
                  ),
                ],
                selected: {_editItemType},
                onSelectionChanged: (Set<ReminderItemType> selected) {
                  setState(() {
                    _editItemType = selected.first;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _editItemType == ReminderItemType.task
                    ? '任务提醒可设置定时提醒'
                    : '行为提醒可快速播放',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _editingItemId = null;
                Navigator.pop(context, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _editTitleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == true && _editingItemId != null) {
      final updated = item.copyWith(
        title: _editTitleController.text.trim(),
        type: _editItemType,
        // 如果从任务改为行为，清除时间设置
        clearTime: _editItemType == ReminderItemType.behavior && item.hasTime,
      );
      await _updateItem(updated);
    }
    _editingItemId = null;
  }

  Widget _buildTimelineCard(ReminderItem item) {
    final hour = item.hour ?? 20;
    final minute = item.minute ?? 0;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(item.title),
      onDismissed: (_) => _deleteItem(item),
      child: Card(
        child: ListTile(
          leading: Icon(
            item.enabled ? Icons.notifications_active : Icons.notifications_off,
            color: item.enabled ? Colors.teal : Colors.grey,
          ),
          title: Text(item.title),
          subtitle: Text('${_preTime(hour, minute)} 预提醒 · ${_formatTime(hour, minute)} 正式提醒'),
          trailing: IconButton(
            onPressed: () => _showEditDialog(item),
            icon: const Icon(Icons.more_vert),
            tooltip: '编辑',
          ),
          onTap: () => _pickTaskTime(item),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final tasks = _sortedTaskItems();
    final behaviorItems =
        _settings.behaviorItems.where((e) => e.enabled).toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              // === 今日时间线 ===
              Row(
                children: [
                  const Icon(Icons.timeline, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text('今日时间线', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                Card(
                  color: Colors.teal.withOpacity(0.05),
                  child: const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.teal),
                    title: Text('暂无计划任务'),
                    subtitle: Text('请去录音页新建任务，再到计划页设置时间'),
                  ),
                )
              else
                ...tasks.map(_buildTimelineCard),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // === 行为提醒 ===
              Row(
                children: [
                  const Icon(Icons.psychology, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('行为提醒', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              if (behaviorItems.isEmpty)
                Card(
                  color: Colors.orange.withOpacity(0.05),
                  child: const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.orange),
                    title: Text('暂无行为提醒'),
                    subtitle: Text('在录音页新建"好好说话"等行为提醒'),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: behaviorItems.map((item) => ActionChip(
                    avatar: const Icon(Icons.volume_up, size: 18),
                    label: Text(item.title),
                    onPressed: () => _playIfExists(item.audioPath, item.title),
                  )).toList(),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // === 底部固定：我做到了 ===
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              // 今日完成次数
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '今日 ${_settings.completedCountToday} 次',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 我做到了按钮
              Expanded(
                child: FilledButton.icon(
                  onPressed: _onDonePressed,
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('我做到了！', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reorderTasks(int oldIndex, newIndex) async {
    final tasks = _sortedTaskItems();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    // 从完整列表中找到要移动的任务
    final taskToMove = tasks[oldIndex];
    
    // 创建新的任务列表
    final otherTasks = _settings.taskItems.where((t) => t.id != taskToMove.id).toList();
    otherTasks.insert(newIndex, taskToMove);
    
    // 创建新的 items 列表（保留行为提醒）
    final behaviorItems = _settings.behaviorItems;
    final newItems = [...otherTasks, ...behaviorItems];
    
    await _saveSettings(_settings.copyWith(items: newItems));
  }

  Widget _buildPlanTaskCard(ReminderItem item) {
    final hasTime = item.hasTime;
    final timeText = hasTime ? _formatTime(item.hour ?? 0, item.minute ?? 0) : null;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(item.title),
      onDismissed: (_) => _deleteItem(item),
      child: Card(
        shape: hasTime
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, style: BorderStyle.solid, width: 1),
              ),
        child: ListTile(
          leading: hasTime
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(timeText!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15)),
                )
              : const Icon(Icons.access_time, color: Colors.grey),
          title: Text(item.title),
          subtitle: hasTime ? null : const Text('点击设置提醒时间', style: TextStyle(color: Colors.orange)),
          trailing: Switch(value: item.enabled, onChanged: (v) => _toggleItem(item, v)),
          onTap: () => _pickTaskTime(item),
        ),
      ),
    );
  }

  Widget _buildPlanTab() {
    final tasks = _settings.taskItems;
    final withTime = tasks.where((t) => t.hasTime).length;

    return Column(
      children: [
        // 统计条
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              Text('计划设置', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (tasks.isNotEmpty)
                Text('${tasks.length} 个任务 · $withTime 个已设时间',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
        if (tasks.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('暂无任务提醒', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _tabIndex = 2),
                    icon: const Icon(Icons.add),
                    label: const Text('去录音页新建'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tasks.length,
              onReorder: (oldIndex, newIndex) => _reorderPlanTasks(oldIndex, newIndex),
              itemBuilder: (context, index) => _buildPlanTaskCard(tasks[index]),
            ),
          ),
      ],
    );
  }

  Future<void> _reorderPlanTasks(int oldIndex, newIndex) async {
    final tasks = _settings.taskItems;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    // 重新排序任务列表
    final taskToMove = tasks[oldIndex];
    final otherTasks = [...tasks]..removeAt(oldIndex);
    otherTasks.insert(newIndex, taskToMove);
    
    // 创建新的 items 列表（保留行为提醒）
    final behaviorItems = _settings.behaviorItems;
    final newItems = [...otherTasks, ...behaviorItems];
    
    await _saveSettings(_settings.copyWith(items: newItems));
  }

  Widget _buildRecordItemCard(ReminderItem item) {
    final recordingThis = _isRecording && _recordingItemId == item.id;
    final typeLabel = item.type == ReminderItemType.task ? '任务' : '行为';
    final typeColor = item.type == ReminderItemType.task ? Colors.teal : Colors.orange;
    final hasAudio = item.audioPath != null && item.audioPath!.isNotEmpty;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(item.title),
      onDismissed: (_) => _deleteItem(item),
      child: Card(
        shape: recordingThis
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.red, width: 2))
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 类型标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(typeLabel, style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
                  // 录音状态
                  Icon(
                    hasAudio ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: hasAudio ? Colors.green : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 操作按钮行
              Row(
                children: [
                  if (recordingThis)
                    FilledButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('停止录音'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _isRecording ? null : () => _startRecordingForItem(item.id),
                      icon: const Icon(Icons.mic, size: 18),
                      label: Text(hasAudio ? '重新录音' : '录音'),
                    ),
                  const SizedBox(width: 8),
                  if (hasAudio)
                    OutlinedButton.icon(
                      onPressed: () => _playIfExists(item.audioPath, '还没有录音'),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('播放'),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showEditDialog(item),
                    icon: const Icon(Icons.more_vert),
                    tooltip: '编辑',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _showNewItemForm = false;
  bool _showCelebration = false;

  Widget _buildRecordTab() {
    final recordingPraise = _isRecording && _recordingPraise;
    final hasPraise = _settings.praiseAudioPath != null && _settings.praiseAudioPath!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === 鼓励语音（醒目卡片） ===
        Card(
          color: Colors.amber.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('鼓励语音', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(hasPraise ? '已录制 ✓' : '录一段鼓励的话，完成任务时播放', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                if (recordingPraise)
                  FilledButton(onPressed: _stopRecording, style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('停止'))
                else ...[
                  IconButton(onPressed: _isRecording ? null : _startRecordingForPraise, icon: const Icon(Icons.mic), tooltip: '录音'),
                  if (hasPraise)
                    IconButton(onPressed: () => _playIfExists(_settings.praiseAudioPath, '还没有鼓励语音'), icon: const Icon(Icons.play_arrow), tooltip: '播放'),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // === 新建区域 ===
        Row(
          children: [
            const Icon(Icons.mic, size: 20, color: Colors.teal),
            const SizedBox(width: 8),
            Text('提醒列表', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _showNewItemForm = !_showNewItemForm),
              icon: Icon(_showNewItemForm ? Icons.close : Icons.add),
              label: Text(_showNewItemForm ? '收起' : '新建'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_showNewItemForm) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                TextField(
                  controller: _newTitleController,
                  decoration: const InputDecoration(
                    labelText: '提醒名称',
                    hintText: '如：该吃饭了、好好说话',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ReminderItemType>(
                  segments: const [
                    ButtonSegment(value: ReminderItemType.task, label: Text('任务提醒'), icon: Icon(Icons.schedule)),
                    ButtonSegment(value: ReminderItemType.behavior, label: Text('行为提醒'), icon: Icon(Icons.psychology)),
                  ],
                  selected: {_newItemType},
                  onSelectionChanged: (s) => setState(() => _newItemType = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isRecording ? null : () async {
                          final item = await _createNewItem();
                          if (item != null) setState(() => _showNewItemForm = false);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('仅创建'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRecording ? null : () async {
                          await _createAndRecord();
                          setState(() => _showNewItemForm = false);
                        },
                        icon: const Icon(Icons.mic),
                        label: const Text('创建并录音'),
                      ),
                    ),
                  ],
                ),
              ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // === 已有提醒列表 ===
        if (_settings.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.mic_none, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('还没有提醒项', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('点击上方"新建"开始', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ..._settings.items.map(_buildRecordItemCard),
      ],
    );
  }

  Widget _buildParentTab() {
    final weekly = _settings.weeklyData;
    final achievements = _settings.achievements;
    final unlocked = achievements.where((a) => a.isUnlocked).toList();

    // 最近 7 天数据
    final days = <MapEntry<String, int>>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = AppSettings.buildDateKey(d);
      days.add(MapEntry('${d.month}/${d.day}', weekly[key] ?? 0));
    }
    final maxCount = days.map((e) => e.value).fold(1, (a, b) => a > b ? a : b);
    final weekTotal = days.map((e) => e.value).fold(0, (a, b) => a + b);
    final activeDays = days.where((e) => e.value > 0).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 周统计概览
        Row(
          children: [
            const Icon(Icons.bar_chart, size: 20, color: Colors.teal),
            const SizedBox(width: 8),
            Text('本周统计', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBadge('$weekTotal', '本周完成'),
                    _statBadge('$activeDays', '活跃天数'),
                    _statBadge('${_settings.completedCountToday}', '今日完成'),
                  ],
                ),
                const SizedBox(height: 16),
                // 柱状图
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.map((e) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (e.value > 0) Text('${e.value}', style: const TextStyle(fontSize: 11, color: Colors.teal)),
                            const SizedBox(height: 2),
                            Container(
                              height: e.value > 0 ? (e.value / maxCount * 60).clamp(8, 60) : 4,
                              decoration: BoxDecoration(
                                color: e.value > 0 ? Colors.teal : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(e.key, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 成就系统
        Row(
          children: [
            const Icon(Icons.emoji_events, size: 20, color: Colors.amber),
            const SizedBox(width: 8),
            Text('成就徽章', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${unlocked.length}/${achievements.length}', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievements.map((a) => Card(
            color: a.isUnlocked ? Colors.amber.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
            child: SizedBox(
              width: (MediaQuery.of(context).size.width - 48) / 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(a.icon, style: TextStyle(fontSize: 28, color: a.isUnlocked ? null : Colors.grey.shade400)),
                    const SizedBox(height: 4),
                    Text(a.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: a.isUnlocked ? Colors.amber.shade800 : Colors.grey)),
                    const SizedBox(height: 2),
                    Text(a.requirement, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),

        const SizedBox(height: 20),

        // 电池优化引导
        if (Platform.isAndroid) ...[
          Row(
            children: [
              const Icon(Icons.battery_alert, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Text('通知保障', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.orange.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('如果提醒不响，请检查以下设置：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _settingTip('设置 → 电池 → 小小提醒官 → 不受限制'),
                  _settingTip('设置 → 应用管理 → 小小提醒官 → 允许自启动'),
                  _settingTip('最近任务界面 → 锁定小小提醒官卡片'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.notifications_active, size: 18),
                    label: const Text('发送测试通知'),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _statBadge(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _settingTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.orange)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 首次引导
    if (!_settings.onboardingCompleted) {
      return OnboardingScreen(
        templates: AppSettings.defaultTemplates,
        onComplete: (selected) async {
          // 复制预置音频到本地并关联
          final items = <ReminderItem>[];
          for (final item in selected) {
            final assetName = '${item.id}.mp3';
            try {
              final localPath = await AudioService.copyAssetAudio(assetName);
              items.add(item.copyWith(audioPath: localPath));
            } catch (_) {
              items.add(item);
            }
          }
          // 复制鼓励语音
          String? praisePath;
          try {
            praisePath = await AudioService.copyAssetAudio('praise.mp3');
          } catch (_) {}

          final next = _settings.copyWith(
            items: items,
            onboardingCompleted: true,
            praiseAudioPath: praisePath,
          );
          await _saveSettings(next);
          _sendTestNotification();
        },
      );
    }

    final pages = [
      _buildHomeTab(),
      _buildPlanTab(),
      _buildRecordTab(),
      _buildParentTab(),
    ];

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('小小提醒官'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
                  label: Text('${_settings.completedCountToday}次'),
                  backgroundColor: Colors.teal.withOpacity(0.1),
                ),
              ),
            ],
          ),
          body: IndexedStack(index: _tabIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.schedule), label: '计划'),
              NavigationDestination(icon: Icon(Icons.mic), label: '录音'),
              NavigationDestination(icon: Icon(Icons.family_restroom), label: '家长'),
            ],
            onDestinationSelected: (index) {
              setState(() { _tabIndex = index; });
            },
          ),
          floatingActionButton: _isRecording
              ? FloatingActionButton.extended(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop),
                  label: const Text('结束录音'),
                )
              : null,
        ),
        if (_showCelebration)
          Container(
            color: Colors.black38,
            child: CelebrationOverlay(
              onComplete: () => setState(() => _showCelebration = false),
            ),
          ),
      ],
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      // 延迟 2 秒发送测试通知
      await Future.delayed(const Duration(seconds: 2));
      await _notificationService.sendTestNotification();
    } catch (e) {
      if (kDebugMode) print('测试通知发送失败: $e');
    }
  }
}