import 'package:flutter/material.dart';

class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const CelebrationOverlay({super.key, required this.onComplete});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _scale = Tween<double>(begin: 0.3, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.elasticOut)));
    _fade = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)));
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: _fade.value,
        child: Center(
          child: Transform.scale(
            scale: _scale.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text('太棒了！', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.amber.shade700, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
