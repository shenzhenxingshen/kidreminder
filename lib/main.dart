import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kidreminder/models/app_models.dart';
import 'package:kidreminder/services/audio_service.dart';
import 'package:kidreminder/services/notification_service.dart';
import 'package:kidreminder/services/storage_service.dart';

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
    final next = _normalizeDailyCount(_settings).copyWith(
      completedDate: _todayKey(),
      completedCountToday: _settings.completedCountToday + 1,
    );
    await _saveSettings(next);
    await _playIfExists(next.praiseAudioPath, '还没有鼓励语音');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('太棒了，已记录一次完成')),
    );
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
    return Card(
      key: ValueKey(item.id),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(
          '提前提醒：${_preTime(hour, minute)}\n到点提醒：${_formatTime(hour, minute)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 通知开关
            Icon(
              item.enabled ? Icons.notifications_active : Icons.notifications_off,
              color: item.enabled ? Colors.teal : Colors.grey,
            ),
            // 编辑按钮
            IconButton(
              onPressed: () => _showEditDialog(item),
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
            ),
            // 删除按钮
            IconButton(
              onPressed: () => _deleteItem(item),
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              color: Colors.red,
            ),
          ],
        ),
        onTap: () => _pickTaskTime(item),
      ),
    );
  }

  Widget _buildHomeTab() {
    final tasks = _sortedTaskItems();
    final behaviorItems =
        _settings.behaviorItems.where((e) => e.enabled).toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '今日时间线',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('暂无计划任务，请去录音页新建任务并在计划页设置时间'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _onDonePressed,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('我做到了'),
          ),
          const SizedBox(height: 20),
          Text(
            '行为提醒',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: behaviorItems
                .map(
                  (item) => ElevatedButton(
                    onPressed: () => _playIfExists(item.audioPath, item.title),
                    child: Text(item.title),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '今日时间线（长按拖拽排序）',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  onReorder: (oldIndex, newIndex) => _reorderTasks(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    return _buildTimelineCard(tasks[index]);
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FilledButton(
                  onPressed: _onDonePressed,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  child: const Text('我做到了'),
                ),
                const SizedBox(height: 20),
                Text(
                  '行为提醒',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: behaviorItems
                      .map(
                        (item) => ElevatedButton(
                          onPressed: () => _playIfExists(item.audioPath, item.title),
                          child: Text(item.title),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
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
    final timeText =
        hasTime ? _formatTime(item.hour ?? 0, item.minute ?? 0) : '点击设置时间';
    return Card(
      key: ValueKey(item.id),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text('提醒时间：$timeText'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.enabled,
              onChanged: (v) => _toggleItem(item, v),
            ),
            IconButton(
              onPressed: () => _showEditDialog(item),
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
            ),
            IconButton(
              onPressed: () => _deleteItem(item),
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              color: Colors.red,
            ),
          ],
        ),
        onTap: () => _pickTaskTime(item),
      ),
    );
  }

  Widget _buildPlanTab() {
    final tasks = _settings.taskItems;
    
    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '计划设置',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('在录音页新建"该吃饭了"等任务后，可在这里设置时间'),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('暂无任务提醒，请先在录音页新建'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '计划设置（长按拖拽排序）',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('在录音页新建"该吃饭了"等任务后，可在这里设置时间'),
              const SizedBox(height: 12),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  onReorder: (oldIndex, newIndex) => _reorderPlanTasks(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    return _buildPlanTaskCard(tasks[index]);
                  },
                ),
              ),
            ],
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
    final typeText = item.type == ReminderItemType.task ? '任务提醒' : '行为提醒';
    final hasTime = item.hasTime
        ? _formatTime(item.hour ?? 0, item.minute ?? 0)
        : '未设置时间';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('$typeText · $hasTime'),
            const SizedBox(height: 6),
            Text(item.audioPath == null ? '未录制' : '已录制'),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed:
                      _isRecording ? null : () => _startRecordingForItem(item.id),
                  child: const Text('开始录音'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: recordingThis ? _stopRecording : null,
                  child: const Text('停止'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _playIfExists(item.audioPath, '还没有录音'),
                  child: const Text('播放'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _showEditDialog(item),
                  icon: const Icon(Icons.edit),
                  tooltip: '编辑',
                ),
                IconButton(
                  onPressed: () => _deleteItem(item),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '删除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTab() {
    final recordingPraise = _isRecording && _recordingPraise;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '录音中心',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _newTitleController,
                  decoration: const InputDecoration(
                    labelText: '提醒名称（如：该吃饭了、好好说话）',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ReminderItemType>(
                  initialValue: _newItemType,
                  items: const [
                    DropdownMenuItem(
                      value: ReminderItemType.task,
                      child: Text('任务提醒（可进计划）'),
                    ),
                    DropdownMenuItem(
                      value: ReminderItemType.behavior,
                      child: Text('行为提醒（快捷触发）'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _newItemType = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isRecording ? null : _createAndRecord,
                  child: const Text('新建并开始录音'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._settings.items.map(_buildRecordItemCard),
        Card(
          child: ListTile(
            title: const Text('鼓励语音'),
            subtitle: Text(_settings.praiseAudioPath == null ? '未录制' : '已录制'),
            trailing: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _isRecording ? null : _startRecordingForPraise,
                  child: const Text('录音'),
                ),
                TextButton(
                  onPressed: recordingPraise ? _stopRecording : null,
                  child: const Text('停止'),
                ),
                TextButton(
                  onPressed: () =>
                      _playIfExists(_settings.praiseAudioPath, '还没有鼓励语音'),
                  child: const Text('播放'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '家长页',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('今天完成次数'),
            subtitle: Text('${_settings.completedCountToday} 次'),
          ),
        ),
        const Card(
          child: ListTile(
            title: Text('建议'),
            subtitle: Text('先在录音页新建提醒，再去计划页设置任务时间。'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeTab(),
      _buildPlanTab(),
      _buildRecordTab(),
      _buildParentTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('小小提醒官'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.schedule), label: '计划'),
          NavigationDestination(icon: Icon(Icons.mic), label: '录音'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: '家长'),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
      ),
      floatingActionButton: _isRecording
          ? FloatingActionButton.extended(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('结束录音'),
            )
          : null,
    );
  }
}