import 'package:flutter/material.dart';
import 'package:kidreminder/models/app_models.dart';

class OnboardingScreen extends StatefulWidget {
  final List<ReminderItem> templates;
  final void Function(List<ReminderItem> selected) onComplete;

  const OnboardingScreen({super.key, required this.templates, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    // 默认选中前 4 个
    for (var i = 0; i < 4 && i < widget.templates.length; i++) {
      _selected.add(widget.templates[i].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _page == 0 ? _buildWelcome() : _buildTemplateSelection(),
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.child_care, size: 80, color: Colors.teal),
          const SizedBox(height: 24),
          Text('欢迎使用小小提醒官', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            '用你的声音，温柔地提醒孩子\n不再需要反复唠叨',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600, height: 1.6),
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () => setState(() => _page = 1),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('开始设置', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelection() {
    final tasks = widget.templates.where((t) => t.isTask).toList();
    final behaviors = widget.templates.where((t) => t.isBehavior).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择提醒项', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('选择适合孩子的提醒，之后可以随时修改', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _sectionHeader('⏰ 任务提醒', '到点自动提醒'),
              ...tasks.map(_buildTemplateItem),
              const SizedBox(height: 16),
              _sectionHeader('💡 行为提醒', '随时一键播放'),
              ...behaviors.map(_buildTemplateItem),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(
            children: [
              Text('已选 ${_selected.length} 项', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _selected.isEmpty ? null : () {
                  final items = widget.templates.where((t) => _selected.contains(t.id)).toList();
                  widget.onComplete(items);
                },
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('完成设置', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(ReminderItem item) {
    final isSelected = _selected.contains(item.id);
    final timeText = item.hasTime ? '${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}' : '';

    return Card(
      color: isSelected ? Colors.teal.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Colors.teal, width: 1.5) : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(
          item.isTask ? Icons.schedule : Icons.psychology,
          color: isSelected ? Colors.teal : Colors.grey,
        ),
        title: Text(item.title),
        subtitle: timeText.isNotEmpty ? Text(timeText) : null,
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.teal)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selected.remove(item.id);
            } else {
              _selected.add(item.id);
            }
          });
        },
      ),
    );
  }
}
