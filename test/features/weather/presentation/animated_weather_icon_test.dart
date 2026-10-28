import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/utils/weather_code_mapper.dart';
import 'package:weather/features/weather/presentation/widgets/animated_weather_icon.dart';

Future<void> _pumpIcon(
  WidgetTester tester, {
  required WeatherVisual visual,
  bool isDay = true,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: AnimatedWeatherIcon(visual: visual, isDay: isDay),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 卸载组件，避免无限循环的 Ticker 活到测试结束。
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  testWidgets('动画会随时间推进（晴）', (WidgetTester tester) async {
    await _pumpIcon(tester, visual: describeWeatherCode(0));

    final first = tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(AnimatedWeatherIcon),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage
        .toList();

    await tester.pump(const Duration(milliseconds: 700));

    final second = tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(AnimatedWeatherIcon),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage
        .toList();

    expect(second, isNot(equals(first)));

    await _unmount(tester);
  });

  testWidgets('系统开启「减弱动态效果」时退化为静态图标', (WidgetTester tester) async {
    await _pumpIcon(
      tester,
      visual: describeWeatherCode(0),
      disableAnimations: true,
    );

    expect(
      find.descendant(
        of: find.byType(AnimatedWeatherIcon),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('夜间用月亮图标并带漂浮动画', (WidgetTester tester) async {
    await _pumpIcon(
      tester,
      visual: describeWeatherCode(0, isDay: false),
      isDay: false,
    );

    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AnimatedWeatherIcon),
        matching: find.byType(Transform),
      ),
      findsWidgets,
    );

    await _unmount(tester);
  });

  testWidgets('雨天与雪天会绘制粒子', (WidgetTester tester) async {
    await _pumpIcon(tester, visual: describeWeatherCode(61));
    expect(
      find.descendant(
        of: find.byType(AnimatedWeatherIcon),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );

    await _unmount(tester);

    await _pumpIcon(tester, visual: describeWeatherCode(71));
    expect(
      find.descendant(
        of: find.byType(AnimatedWeatherIcon),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );

    await _unmount(tester);
  });

  for (final code in <int>[0, 2, 45, 61, 71, 95]) {
    testWidgets('天气代码 $code 能正常渲染', (WidgetTester tester) async {
      await _pumpIcon(tester, visual: describeWeatherCode(code));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });
  }
}
