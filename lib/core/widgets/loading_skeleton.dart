import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/tokens.dart';

/// 延迟展示骨架屏，避免快速请求造成的闪烁。
class DelayedSkeleton extends StatefulWidget {
  const DelayedSkeleton({
    super.key,
    required this.child,
    this.delay = AppConfig.skeletonDelay,
  });

  final Widget child;
  final Duration delay;

  @override
  State<DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<DelayedSkeleton> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return widget.child;
  }
}

/// 首页骨架屏：占位形状与真实布局一致，减少加载完成时的布局跳动。
class WeatherSkeleton extends StatelessWidget {
  const WeatherSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spacingMd),
      children: const <Widget>[
        _SkeletonBlock(height: 180),
        SizedBox(height: AppTokens.spacingMd),
        _SkeletonBlock(height: 88),
        SizedBox(height: AppTokens.spacingMd),
        _SkeletonBlock(height: 200),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
    );
  }
}
