import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/weather_code_mapper.dart';

/// 当前天气的动画图标。
///
/// 动画为自绘，未引入 Lottie：这里只需要一个 72px 的图标动起来，
/// 用系统图标 + 轻量变换（旋转 / 位移 / 缩放 / 透明度）加少量粒子即可，
/// 引入动画库与 JSON 资源的包体积与收益不匹配。
///
/// 动画只做装饰：系统开启「减弱动态效果」时退化为静态图标。
/// 每帧只重绘图标所在的 [RepaintBoundary]，不会带动整张卡片。
class AnimatedWeatherIcon extends StatefulWidget {
  const AnimatedWeatherIcon({
    super.key,
    required this.visual,
    required this.isDay,
    this.size = 72,
    this.color = Colors.white,
  });

  final WeatherVisual visual;
  final bool isDay;
  final double size;
  final Color color;

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon>
    with SingleTickerProviderStateMixin {
  /// 一个完整周期 3.6s：慢一点才像「天气」，快了像加载指示器。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.visual.icon,
      size: widget.size,
      color: widget.color,
    );

    if (MediaQuery.disableAnimationsOf(context)) return icon;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: icon,
        builder: (BuildContext context, Widget? child) =>
            _buildFrame(_controller.value, child!),
      ),
    );
  }

  /// 所有效果都是 `wave`（-1..1 的正弦）的函数，天然首尾相接，
  /// 循环播放时不会有跳变。
  Widget _buildFrame(double progress, Widget child) {
    final wave = math.sin(progress * 2 * math.pi);
    // 与 [wave] 相位差 90°，让「摆动」和「呼吸」不同步，动作不呆板。
    final breath = math.cos(progress * 2 * math.pi);
    final size = widget.size;

    switch (widget.visual.group) {
      case WeatherGroup.clear:
        if (!widget.isDay) {
          // 月亮：上下漂浮 + 亮度呼吸。
          return Transform.translate(
            offset: Offset(0, wave * size * 0.035),
            child: Opacity(
              opacity: 0.86 + 0.14 * (0.5 + 0.5 * wave),
              child: child,
            ),
          );
        }
        // 太阳：左右轻摆 + 光晕呼吸。角度必须回到起点，
        // 否则每圈结束会「啪」地跳回 0°，看起来像卡帧。
        return Transform.rotate(
          angle: wave * 0.08,
          child: Transform.scale(scale: 1 + 0.045 * breath, child: child),
        );

      case WeatherGroup.cloudy:
        return Transform.translate(
          offset: Offset(wave * size * 0.05, 0),
          child: child,
        );

      case WeatherGroup.rain:
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.translate(
              offset: Offset(wave * size * 0.025, 0),
              child: child,
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _RainPainter(progress: progress, color: widget.color),
              ),
            ),
          ],
        );

      case WeatherGroup.snow:
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.rotate(angle: wave * 0.12, child: child),
            Positioned.fill(
              child: CustomPaint(
                painter: _SnowPainter(progress: progress, color: widget.color),
              ),
            ),
          ],
        );

      case WeatherGroup.thunder:
        // 取正弦峰值的十次方：绝大多数时间接近 0，只有一瞬高亮，
        // 比整体忽明忽暗更像闪电。
        final flash = math.pow(wave.clamp(0, 1), 10).toDouble();
        return Transform.scale(
          scale: 1 + 0.07 * flash,
          child: Opacity(opacity: 0.82 + 0.18 * flash, child: child),
        );

      case WeatherGroup.fog:
        return Transform.translate(
          offset: Offset(wave * size * 0.06, 0),
          child: Opacity(
            opacity: 0.75 + 0.25 * (0.5 + 0.5 * wave),
            child: child,
          ),
        );
    }
  }
}

/// 雨滴：三条细线从图标下缘循环落下，越往下越淡。
class _RainPainter extends CustomPainter {
  const _RainPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const int _dropCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final strokeWidth = math.max(2.0, size.width * 0.03);
    final span = size.height * 0.5;
    final start = size.height * 0.5;
    final length = size.height * 0.11;

    for (var index = 0; index < _dropCount; index++) {
      final phase = (progress + index / _dropCount) % 1;
      final dx = size.width * (0.3 + index * 0.2);
      final dy = start + span * phase;

      canvas.drawLine(
        Offset(dx, dy),
        Offset(dx, dy + length),
        Paint()
          ..color = color.withValues(alpha: 0.55 * (1 - phase))
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// 雪花：三个小圆点边落边左右飘。
class _SnowPainter extends CustomPainter {
  const _SnowPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const int _flakeCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final radius = math.max(1.5, size.width * 0.032);
    final span = size.height * 0.45;
    final start = size.height * 0.5;

    for (var index = 0; index < _flakeCount; index++) {
      final phase = (progress + index / _flakeCount) % 1;
      final dx =
          size.width * (0.28 + index * 0.22) +
          math.sin((phase + index) * 2 * math.pi) * size.width * 0.05;
      final dy = start + span * phase;

      canvas.drawCircle(
        Offset(dx, dy),
        radius,
        Paint()..color = color.withValues(alpha: 0.65 * (1 - phase * 0.5)),
      );
    }
  }

  @override
  bool shouldRepaint(_SnowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
