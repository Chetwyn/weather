import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/core/utils/date_formatter.dart';
import 'package:weather/features/weather/domain/entity/hourly_forecast.dart';
import 'package:weather/features/weather/presentation/widgets/hourly_trend_chart.dart';

/// 24 小时正弦波形：极值落在中间，能覆盖「极值不在首尾」的绘制路径。
List<HourlyForecast> _hours({int count = 24}) => <HourlyForecast>[
  for (var index = 0; index < count; index++)
    HourlyForecast(
      time: DateTime(2026, 10, 25, 14).add(Duration(hours: index)),
      temperature: 24 + 5 * math.sin(index / 3),
      weatherCode: 1,
      precipitationProbability: index.isEven ? 40 : 0,
    ),
];

Future<void> _pumpChart(
  WidgetTester tester,
  List<HourlyForecast> items, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(child: HourlyTrendChart(items: items)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('渲染走势图标题与曲线', (WidgetTester tester) async {
    await _pumpChart(tester, _hours());

    expect(find.text(zh.temperatureTrend), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HourlyTrendChart),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('数据不足两点时整块隐藏', (WidgetTester tester) async {
    await _pumpChart(tester, _hours(count: 1));

    expect(find.text(zh.temperatureTrend), findsNothing);
  });

  testWidgets('等温数据不崩（极值标记退化）', (WidgetTester tester) async {
    final flat = <HourlyForecast>[
      for (var index = 0; index < 6; index++)
        HourlyForecast(
          time: DateTime(2026, 10, 25, 14).add(Duration(hours: index)),
          temperature: 25,
          weatherCode: 1,
        ),
    ];

    await _pumpChart(tester, flat);

    expect(tester.takeException(), isNull);
    expect(find.text(zh.temperatureTrend), findsOneWidget);
  });

  testWidgets('2 倍字号下仍能完成布局（标签不溢出）', (WidgetTester tester) async {
    await _pumpChart(tester, _hours(), textScale: 2);

    expect(tester.takeException(), isNull);
  });

  testWidgets('读屏可读出温度区间', (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await _pumpChart(tester, _hours());

    expect(find.bySemanticsLabel(RegExp('最低')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('最高')), findsOneWidget);

    handle.dispose();
  });

  testWidgets('横向滑动实时选中小时点，松手后保留', (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    final items = _hours();
    await _pumpChart(tester, items);

    final target = find.byKey(_touchTarget);
    final rect = tester.getRect(target);
    final semantics = find.bySemanticsLabel(RegExp('最低'));

    final gesture = await tester.startGesture(rect.center);
    // 先小步越过拖拽阈值让手势成立，再滑到目标位置（画布宽度 75% 处）。
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(Offset(rect.width * 0.25 - 20, 0));
    await tester.pump();

    final index = (0.75 * (items.length - 1)).round();
    final expected = AppDateFormatter.hour(items[index].time);
    expect(tester.getSemantics(semantics).value, contains(expected));

    await gesture.up();
    await tester.pump();

    // 抬手后保持选中，用手指挡住的气泡也还能继续读。
    expect(tester.getSemantics(semantics).value, contains(expected));

    handle.dispose();
  });

  testWidgets('滑出左边界时选中第一个点', (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    final items = _hours();
    await _pumpChart(tester, items);

    final rect = tester.getRect(find.byKey(_touchTarget));
    final semantics = find.bySemanticsLabel(RegExp('最低'));

    await tester.dragFrom(rect.center, Offset(-rect.width, 0));
    await tester.pump();

    expect(
      tester.getSemantics(semantics).value,
      contains(AppDateFormatter.hour(items.first.time)),
    );

    handle.dispose();
  });

  testWidgets('轻点某一小时也能选中该点', (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    final items = _hours();
    await _pumpChart(tester, items);

    final rect = tester.getRect(find.byKey(_touchTarget));
    await tester.tapAt(rect.center);
    await tester.pump();

    final index = ((items.length - 1) / 2).round();
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('最低'))).value,
      contains(AppDateFormatter.hour(items[index].time)),
    );

    handle.dispose();
  });

  testWidgets('竖向拖动交给外层滚动，不留下选中态', (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await _pumpChart(tester, _hours());

    await tester.drag(find.byKey(_touchTarget), const Offset(0, 80));
    await tester.pump();

    final semantics = tester.getSemantics(find.bySemanticsLabel(RegExp('最低')));
    expect(semantics.value, isEmpty);

    handle.dispose();
  });

  group('分带布局', () {
    test('上下标签带容得下整行文字与圆点', () {
      final layout = HourlyTrendLayout.of(TextScaler.noScaling);
      final size = Size(320, layout.totalHeight);
      final plot = layout.plotRect(size);

      expect(layout.labelHeight, greaterThan(0));
      // 顶部标签从 0 开始画、底部标签到时间轴为止，都不会伸出画布。
      expect(
        plot.top,
        greaterThanOrEqualTo(layout.labelHeight + HourlyTrendLayout.dotRadius),
      );
      expect(
        size.height - plot.bottom,
        greaterThanOrEqualTo(layout.labelHeight + HourlyTrendLayout.dotRadius),
      );
      // 时间轴贴着画布底边，也需要一整行的高度。
      expect(
        size.height - plot.bottom,
        greaterThanOrEqualTo(layout.labelHeight),
      );
      expect(
        layout.topInset +
            HourlyTrendLayout.plotHeight +
            layout.bottomInset +
            layout.axisHeight,
        layout.totalHeight,
      );
    });

    test('放大字号时画布跟随增高，曲线区高度不变', () {
      final normal = HourlyTrendLayout.of(const TextScaler.linear(1));
      final large = HourlyTrendLayout.of(const TextScaler.linear(2));

      expect(large.labelSize, closeTo(normal.labelSize * 2, 0.01));
      expect(large.totalHeight, greaterThan(normal.totalHeight));
      expect(
        large.plotRect(Size(320, large.totalHeight)).height,
        closeTo(normal.plotRect(Size(320, normal.totalHeight)).height, 0.01),
      );
    });
  });
}

/// 与 `_HourlyTrendChartState` 中的触摸层 key 保持一致。
const Key _touchTarget = ValueKey<String>('hourlyTrendChartTouchTarget');

/// 简体中文文案：测试断言的就是用户实际看到的那串文字。
const zh = AppStringsZhHans();
