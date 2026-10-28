import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/features/weather/domain/entity/hourly_forecast.dart';
import 'package:weather/features/weather/presentation/widgets/hourly_trend_chart.dart';

const zh = AppStringsZhHans();

HourlyForecast _hour(
  double temperature, {
  int hour = 14,
  int? precipitationProbability,
}) => HourlyForecast(
  time: DateTime(2026, 10, 25, hour),
  temperature: temperature,
  weatherCode: 1,
  precipitationProbability: precipitationProbability,
);

void main() {
  group('极值定位', () {
    test('找出最高/最低温及其下标', () {
      final series = HourlyTrendSeries.tryFrom(<HourlyForecast>[
        _hour(22),
        _hour(27),
        _hour(24),
        _hour(19),
      ])!;

      expect(series.maxTemperature, 27);
      expect(series.maxIndex, 1);
      expect(series.minTemperature, 19);
      expect(series.minIndex, 3);
    });

    test('少于两个点时返回 null（一个点没有走势）', () {
      expect(HourlyTrendSeries.tryFrom(const <HourlyForecast>[]), isNull);
      expect(HourlyTrendSeries.tryFrom(<HourlyForecast>[_hour(22)]), isNull);
    });
  });

  group('比例换算', () {
    test('最低温到底、最高温到顶，中间线性插值', () {
      final series = HourlyTrendSeries.tryFrom(<HourlyForecast>[
        _hour(20),
        _hour(25),
        _hour(30),
      ])!;

      expect(series.fractionAt(0), 0);
      expect(series.fractionAt(1), 0.5);
      expect(series.fractionAt(2), 1);
    });

    test('等温时全部落在垂直中线，避免曲线贴着底边', () {
      final series = HourlyTrendSeries.tryFrom(<HourlyForecast>[
        _hour(23),
        _hour(23),
        _hour(23),
      ])!;

      expect(series.isFlat, isTrue);
      for (var index = 0; index < series.items.length; index++) {
        expect(series.fractionAt(index), 0.5);
      }
    });

    test('温差极小时也视为等温（极值标签会重叠）', () {
      final series = HourlyTrendSeries.tryFrom(<HourlyForecast>[
        _hour(23.0),
        _hour(23.2),
      ])!;

      expect(series.isFlat, isTrue);
    });
  });

  test('读屏摘要包含极值与出现时间', () {
    final series = HourlyTrendSeries.tryFrom(<HourlyForecast>[
      _hour(22),
      _hour(29, hour: 17),
      _hour(24, hour: 20),
    ])!;

    expect(series.describe(zh), contains('最低 22°（14:00）'));
    expect(series.describe(zh), contains('最高 29°（17:00）'));
  });

  group('触摸映射', () {
    final series = HourlyTrendSeries.tryFrom(<HourlyForecast>[
      for (var index = 0; index < 5; index++)
        _hour(20.0 + index, hour: 14 + index),
    ])!;

    test('按横向比例选中最近的点', () {
      expect(series.indexAt(0, 300), 0);
      expect(series.indexAt(150, 300), 2);
      expect(series.indexAt(300, 300), 4);
    });

    test('滑出画布两侧时夹在首尾，不越界', () {
      expect(series.indexAt(-80, 300), 0);
      expect(series.indexAt(380, 300), 4);
    });

    test('宽度未完成布局时退化为第一个点', () {
      expect(series.indexAt(42, 0), 0);
    });

    test('单项文本包含时间与温度', () {
      expect(series.describeItem(series.items[0]), '14:00 20°');
    });
  });
}
