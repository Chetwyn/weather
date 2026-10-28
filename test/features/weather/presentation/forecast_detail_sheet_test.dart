import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/features/weather/domain/entity/daily_forecast.dart';
import 'package:weather/features/weather/presentation/widgets/forecast_detail_sheet.dart';

import '../../../helpers/fixtures.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required DailyForecast item,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ForecastDetailSheet(
          item: item,
          units: UnitSystem.metric,
          dayLabel: zh.today,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('展示日出、日落、最大风速与紫外线峰值', (WidgetTester tester) async {
    await _pumpSheet(tester, item: buildWeather().daily.first);

    expect(find.text(zh.sunrise), findsOneWidget);
    expect(find.text(zh.sunset), findsOneWidget);
    expect(find.text(zh.maxWind), findsOneWidget);
    expect(find.text(zh.maxUv), findsOneWidget);
    expect(find.text('06:02'), findsOneWidget);
    expect(find.text('17:20'), findsOneWidget);
    expect(find.text('14.2 km/h'), findsOneWidget);
    expect(find.text('6.4'), findsOneWidget);
  });

  testWidgets('缺失字段整行隐藏，不留占位符', (WidgetTester tester) async {
    await _pumpSheet(tester, item: buildWeather().daily.last);

    expect(find.text(zh.precipitationProbability), findsOneWidget);
    expect(find.text(zh.sunrise), findsNothing);
    expect(find.text(zh.sunset), findsNothing);
    expect(find.text(zh.maxWind), findsNothing);
    expect(find.text(zh.maxUv), findsNothing);
    expect(find.text('--'), findsNothing);
  });

  testWidgets('全部字段缺失时给出说明而不是空白面板', (WidgetTester tester) async {
    await _pumpSheet(
      tester,
      item: DailyForecast(
        date: DateTime(2026, 10, 27),
        weatherCode: 0,
        maxTemperature: 30,
        minTemperature: 24,
      ),
    );

    expect(find.text('暂无更多数据'), findsOneWidget);
  });
}

/// 简体中文文案：测试断言的就是用户实际看到的那串文字。
const zh = AppStringsZhHans();
