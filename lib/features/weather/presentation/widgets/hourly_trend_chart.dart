import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/section_title.dart';
import '../../domain/entity/hourly_forecast.dart';

/// 24 小时温度走势图。
///
/// 曲线为自绘，未引入图表库：
/// - 只需要「一条曲线 + 几个刻度」，引入 fl_chart 这类依赖要为整个图表模型
///   承担包体积与升级成本，收益不匹配；
/// - 自绘能直接使用主题色与 `TextScaler`，图表标签跟随系统字号缩放。
///
/// 只画温度、不叠降水柱：降水概率已在下方「逐小时预报」的卡片中展示，
/// 放在同一张图会让最低温标签与柱子相互挤压。
///
/// 数据不足两点时整块隐藏（单点画不出趋势，只会在图里留一个孤立的点）。
///
/// 触摸交互：横向滑动实时选中最近的小时点，竖向滑动仍然交给外层滚动，
/// 两种手势由 Flutter 的手势竞技场按方向裁决，不需要手动加阈值。
class HourlyTrendChart extends StatefulWidget {
  const HourlyTrendChart({super.key, required this.items});

  final List<HourlyForecast> items;

  @override
  State<HourlyTrendChart> createState() => _HourlyTrendChartState();
}

class _HourlyTrendChartState extends State<HourlyTrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant HourlyTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了城市/刷新后小时序列会整条替换，旧的选中下标可能越界或指向别的时刻。
    if (oldWidget.items != widget.items) {
      _selectedIndex = null;
    }
  }

  /// 把触摸点的横坐标映射到最近的小时下标；横向拖动时被连续调用。
  void _selectAt(double dx, double width, HourlyTrendSeries series) {
    final index = series.indexAt(dx, width);
    if (index == _selectedIndex) return;

    if (_selectedIndex != null) HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  /// 按下位置与「本次触摸是否已判定为横向滑动」。
  ///
  /// 这里用 [Listener] 而不是 `GestureDetector.onHorizontalDrag*`：
  /// 图表外层是可滚动列表，水平/垂直识别器虽然能按方向仲裁，但当列表
  /// 内容不足一屏、滚动不参与竞技场时，垂直拖动也会被强制判给水平识别器，
  /// 造成「滚页面却选中了点」。自己看位移方向就不会误判，同时不抢滚动。
  Offset? _downPosition;
  bool _isHorizontalDrag = false;

  void _handlePointerDown(PointerDownEvent event) {
    _downPosition = event.localPosition;
    _isHorizontalDrag = false;
  }

  void _handlePointerMove(
    PointerMoveEvent event,
    double width,
    HourlyTrendSeries series,
  ) {
    final origin = _downPosition;
    if (origin == null) return;

    final delta = event.localPosition - origin;
    if (!_isHorizontalDrag) {
      if (delta.dy.abs() > delta.dx.abs()) {
        // 竖向为主：让外层列表滚动，本次触摸不再选点。
        if (delta.dy.abs() > kTouchSlop) _downPosition = null;
        return;
      }
      if (delta.dx.abs() < kTouchSlop) return;
      _isHorizontalDrag = true;
    }
    _selectAt(event.localPosition.dx, width, series);
  }

  void _handlePointerUp(
    PointerUpEvent event,
    double width,
    HourlyTrendSeries series,
  ) {
    final origin = _downPosition;
    _downPosition = null;
    // 没滑动的轻点也选点，直接看某一小时的值。
    if (origin != null && !_isHorizontalDrag) {
      _selectAt(event.localPosition.dx, width, series);
    }
    _isHorizontalDrag = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _downPosition = null;
    _isHorizontalDrag = false;
  }

  @override
  Widget build(BuildContext context) {
    final series = HourlyTrendSeries.tryFrom(widget.items);
    if (series == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // 画布高度与画笔内部的坐标共用同一套布局，避免两处公式漂移导致标签被裁。
    final layout = HourlyTrendLayout.of(MediaQuery.textScalerOf(context));
    final chartHeight = layout.totalHeight;

    final selected = _selectedIndex == null
        ? null
        : series.items[_selectedIndex!.clamp(0, series.items.length - 1)];

    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionTitle(strings.temperatureTrend),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTokens.spacingMd,
              horizontal: AppTokens.spacingMd,
            ),
            child: SizedBox(
              height: chartHeight,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Listener(
                    key: _touchTargetKey,
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: (PointerMoveEvent event) =>
                        _handlePointerMove(event, constraints.maxWidth, series),
                    onPointerUp: (PointerUpEvent event) =>
                        _handlePointerUp(event, constraints.maxWidth, series),
                    onPointerCancel: _handlePointerCancel,
                    child: Semantics(
                      image: true,
                      label: series.describe(strings),
                      // 选中项单独走 value：拖动时只播报变化的值，不重读整段摘要。
                      value: selected == null
                          ? null
                          : series.describeItem(selected),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _TrendPainter(
                            series: series,
                            layout: layout,
                            lineColor: theme.colorScheme.primary,
                            labelColor: theme.colorScheme.onSurfaceVariant,
                            ringColor: theme.colorScheme.surfaceContainerLow,
                            bubbleColor:
                                theme.colorScheme.surfaceContainerHighest,
                            selectedIndex: _selectedIndex,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 手势层需要覆盖整块画布；测试也用它定位触摸区域。
  static const Key _touchTargetKey = ValueKey<String>(
    'hourlyTrendChartTouchTarget',
  );
}

/// 走势图的纯几何模型。
///
/// 只做「数值 → 0..1 比例」的换算，不碰 Canvas，因此可以直接单测边界情况
/// （等温、只有两个点）。
class HourlyTrendSeries {
  HourlyTrendSeries._({
    required this.items,
    required this.minTemperature,
    required this.maxTemperature,
    required this.minIndex,
    required this.maxIndex,
  });

  /// 少于两个点时返回 null：一个点没有「走势」可言。
  static HourlyTrendSeries? tryFrom(List<HourlyForecast> items) {
    if (items.length < 2) return null;

    var minIndex = 0;
    var maxIndex = 0;
    for (var index = 1; index < items.length; index++) {
      if (items[index].temperature < items[minIndex].temperature) {
        minIndex = index;
      }
      if (items[index].temperature > items[maxIndex].temperature) {
        maxIndex = index;
      }
    }

    return HourlyTrendSeries._(
      items: items,
      minTemperature: items[minIndex].temperature,
      maxTemperature: items[maxIndex].temperature,
      minIndex: minIndex,
      maxIndex: maxIndex,
    );
  }

  final List<HourlyForecast> items;
  final double minTemperature;
  final double maxTemperature;
  final int minIndex;
  final int maxIndex;

  /// 温差太小时曲线会贴成一条直线，此时不画极值标记（两个标签会叠在一起）。
  bool get isFlat => (maxTemperature - minTemperature) < 0.5;

  /// 0 = 最低温（画在图底），1 = 最高温（画在图顶）。
  ///
  /// 等温时统一返回 0.5，让曲线落在垂直中线而不是贴着底边。
  double fractionAt(int index) {
    if (isFlat) return 0.5;
    final ratio =
        (items[index].temperature - minTemperature) /
        (maxTemperature - minTemperature);
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  /// 读屏用的走势摘要（Canvas 本身对无障碍不可见）。
  ///
  /// 标点与语序按语言不同，交给 [AppStrings.trendSummary] 拼装。
  String describe(AppStrings strings) => strings.trendSummary(
    lowValue: '${AppDateFormatter.temperature(minTemperature)}°',
    lowTime: AppDateFormatter.hour(items[minIndex].time),
    highValue: '${AppDateFormatter.temperature(maxTemperature)}°',
    highTime: AppDateFormatter.hour(items[maxIndex].time),
  );

  /// 单个小时点的读屏文本，例如 `08:00 21°`。
  String describeItem(HourlyForecast item) =>
      '${AppDateFormatter.hour(item.time)} '
      '${AppDateFormatter.temperature(item.temperature)}°';

  /// 触摸横坐标 → 最近的小时下标。
  ///
  /// 坐标与画笔保持同一套约定：首个点在 `x = 0`、末个点在 `x = width`，
  /// 所以这里只按比例换算，不需要知道上下标签带占了多少高度。
  int indexAt(double dx, double width) {
    if (items.length < 2) return 0;
    if (width <= 0) return 0;
    final ratio = (dx / width).clamp(0.0, 1.0);
    return (ratio * (items.length - 1)).round().clamp(0, items.length - 1);
  }
}

/// 趋势图的分带布局：上下极值标签带 + 曲线区 + 时间轴。
///
/// 画布高度与画笔内部坐标必须来自同一套计算。之前两处各写一份公式、
/// 并用 `labelSize * 1.6` 估算行高：中文字体行高比估算值更高，大字号时
/// 顶部/底部的标签就被画布边缘裁掉了一截。
class HourlyTrendLayout {
  const HourlyTrendLayout({required this.labelSize, required this.labelHeight});

  /// 按当前系统字号量出标签的**真实**行高。
  factory HourlyTrendLayout.of(TextScaler textScaler) {
    final labelSize = textScaler.scale(labelBaseSize);
    final painter = TextPainter(
      text: TextSpan(
        text: '00:00',
        style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      // 字号上面已经缩放过了，这里不能再叠加 textScaler。
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final labelHeight = painter.height;
    painter.dispose();
    return HourlyTrendLayout(labelSize: labelSize, labelHeight: labelHeight);
  }

  static const double labelBaseSize = 11;

  /// 曲线区的固定高度。
  static const double plotHeight = 84;

  static const double dotRadius = 3.5;

  /// 标签与圆点之间的呼吸间距。
  static const double labelGap = 4;

  final double labelSize;
  final double labelHeight;

  /// 顶部/底部极值标签带：整行文字 + 圆点 + 间距。
  double get topInset => labelHeight + dotRadius + labelGap;

  double get bottomInset => labelHeight + dotRadius + labelGap;

  /// 时间轴：行高 + 与曲线区之间的间距。
  double get axisHeight => labelHeight + AppTokens.spacingXs;

  /// 画布总高：三段相加，画出来正好铺满画布，不会被裁。
  double get totalHeight => topInset + plotHeight + bottomInset + axisHeight;

  /// 曲线区（数据点的活动范围），上下标签都落在它之外。
  Rect plotRect(Size size) => Rect.fromLTRB(
    0,
    topInset,
    size.width,
    size.height - axisHeight - bottomInset,
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.series,
    required this.lineColor,
    required this.labelColor,
    required this.ringColor,
    required this.bubbleColor,
    required this.layout,
    this.selectedIndex,
  });

  final HourlyTrendSeries series;
  final HourlyTrendLayout layout;
  final Color lineColor;
  final Color labelColor;
  final Color ringColor;
  final Color bubbleColor;

  /// 触摸选中的小时下标；为空时按默认样式绘制极值标签。
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final plot = layout.plotRect(size);
    // 字号极大时留给曲线的空间可能被吃光，此时宁可不画也不要画到负高度。
    if (plot.height < 8 || plot.width < 8) return;

    final points = <Offset>[
      for (var index = 0; index < series.items.length; index++)
        Offset(
          plot.left + plot.width * index / (series.items.length - 1),
          plot.bottom - plot.height * series.fractionAt(index),
        ),
    ];

    _paintCurve(canvas, plot, points);
    _paintHourTicks(canvas, size, points);
    // 选中态与极值标签互斥：气泡和「最高/最低」都会贴在点上方，
    // 同时画会叠字，选中时把焦点让给手指选中的点。
    final index = selectedIndex;
    if (index != null) {
      _paintSelection(canvas, size, plot, points, index);
    } else {
      _paintExtremes(canvas, size, points);
    }
  }

  void _paintCurve(Canvas canvas, Rect plot, List<Offset> points) {
    final line = _catmullRom(points);
    final area = Path.from(line)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();

    canvas.save();
    // 平滑曲线会轻微过冲，裁到绘图区附近：外扩一个圆点半径，
    // 否则贴边（最高/最低）处的描边会被削掉一半，看着像被截断。
    canvas.clipRect(plot.inflate(dotRadius));
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor,
    );
    canvas.restore();
  }

  /// Catmull-Rom 转三次贝塞尔：曲线**精确穿过**每个数据点，
  /// 这样极值标记和曲线不会错位（中点平滑法会把峰值削掉）。
  Path _catmullRom(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final p0 = points[math.max(0, index - 1)];
      final p1 = points[index];
      final p2 = points[index + 1];
      final p3 = points[math.min(points.length - 1, index + 2)];

      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  /// 常量转发，方法体里不用到处写类名。
  static const double dotRadius = HourlyTrendLayout.dotRadius;
  static const double labelGap = HourlyTrendLayout.labelGap;

  void _paintHourTicks(Canvas canvas, Size size, List<Offset> points) {
    // 最多 5 个刻度（首、1/4、1/2、3/4、尾），再多会挤在一起。
    final last = series.items.length - 1;
    final indices = <int>{
      0,
      (last / 4).round(),
      (last / 2).round(),
      (last * 3 / 4).round(),
      last,
    }.toList()..sort();

    for (final index in indices) {
      _paintText(
        canvas,
        AppDateFormatter.hour(series.items[index].time),
        centerX: points[index].dx,
        // 时间轴正好贴着画布底边，行高已经算进 layout.axisHeight，不会被裁。
        top: size.height - layout.labelHeight,
        fontSize: layout.labelSize,
        maxWidth: size.width,
      );
    }
  }

  void _paintExtremes(Canvas canvas, Size size, List<Offset> points) {
    if (series.isFlat) return;

    _paintExtreme(
      canvas,
      point: points[series.maxIndex],
      value: series.maxTemperature,
      above: true,
      maxWidth: size.width,
    );
    _paintExtreme(
      canvas,
      point: points[series.minIndex],
      value: series.minTemperature,
      above: false,
      maxWidth: size.width,
    );
  }

  void _paintExtreme(
    Canvas canvas, {
    required Offset point,
    required double value,
    required bool above,
    required double maxWidth,
  }) {
    canvas.drawCircle(point, dotRadius + 1.5, Paint()..color = ringColor);
    canvas.drawCircle(point, dotRadius, Paint()..color = lineColor);

    _paintText(
      canvas,
      '${AppDateFormatter.temperature(value)}°',
      centerX: point.dx,
      // 标签贴在圆点外侧，整块文字高度都留在对应的标签带里。
      top: above
          ? point.dy - dotRadius - labelGap - layout.labelHeight
          : point.dy + dotRadius + labelGap,
      fontSize: layout.labelSize,
      maxWidth: maxWidth,
      bold: true,
    );
  }

  /// 触摸选中态：竖向指示线 + 高亮圆点 + 时间/温度气泡。
  void _paintSelection(
    Canvas canvas,
    Size size,
    Rect plot,
    List<Offset> points,
    int rawIndex,
  ) {
    final index = rawIndex.clamp(0, points.length - 1);
    final point = points[index];

    canvas.drawLine(
      Offset(point.dx, plot.top),
      Offset(point.dx, plot.bottom),
      Paint()
        ..color = lineColor.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );

    canvas.drawCircle(point, dotRadius + 2.5, Paint()..color = ringColor);
    canvas.drawCircle(point, dotRadius + 0.5, Paint()..color = lineColor);

    _paintBubble(canvas, size, plot, point, index);
  }

  void _paintBubble(
    Canvas canvas,
    Size size,
    Rect plot,
    Offset point,
    int index,
  ) {
    const double hPadding = 7;
    const double vPadding = 4;
    const double gap = labelGap + 2;

    final painter = TextPainter(
      text: TextSpan(
        text: series.describeItem(series.items[index]),
        style: TextStyle(
          color: labelColor,
          fontSize: layout.labelSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      // 同上：字号已经缩放过了，不能再叠加 textScaler。
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout(maxWidth: math.max(0, size.width - hPadding * 2));

    final bubbleWidth = painter.width + hPadding * 2;
    final bubbleHeight = painter.height + vPadding * 2;
    final left = (point.dx - bubbleWidth / 2)
        .clamp(0.0, math.max(0.0, size.width - bubbleWidth))
        .toDouble();

    // 优先贴在点上方；顶部放不下（峰值）就翻到点下方，再整体夹回画布内。
    var top = point.dy - dotRadius - gap - bubbleHeight;
    if (top < plot.top) top = point.dy + dotRadius + gap;
    top = top.clamp(0.0, math.max(0.0, size.height - bubbleHeight)).toDouble();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, bubbleWidth, bubbleHeight),
        const Radius.circular(7),
      ),
      Paint()..color = bubbleColor,
    );
    painter.paint(canvas, Offset(left + hPadding, top + vPadding));
  }

  /// 居中绘制标签，左右各夹一次，避免首尾标签被裁掉。
  void _paintText(
    Canvas canvas,
    String text, {
    required double centerX,
    required double top,
    required double fontSize,
    required double maxWidth,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      // [fontSize] 已经是 `textScaler.scale(baseLabelSize)` 的结果，
      // 这里再传 textScaler 会把字号放大两次（2 倍字号 → 4 倍字），
      // 文字被撑出画布，看起来就像上下各被截掉一截。
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);

    final left = (centerX - painter.width / 2)
        .clamp(0.0, math.max(0.0, maxWidth - painter.width))
        .toDouble();
    painter.paint(canvas, Offset(left, top));
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.series.items != series.items ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.bubbleColor != bubbleColor ||
      oldDelegate.layout.labelHeight != layout.labelHeight ||
      oldDelegate.layout.labelSize != layout.labelSize ||
      oldDelegate.selectedIndex != selectedIndex;
}
