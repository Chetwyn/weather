import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/domain/location.dart';

import '../../../helpers/fixtures.dart';

void main() {
  test('摄氏转华氏：温度、风速一起换算', () {
    final metric = buildWeather();
    final imperial = metric.convertTo(UnitSystem.imperial);

    expect(imperial.units, UnitSystem.imperial);
    expect(imperial.current.temperature, closeTo(79.34, 0.01));
    expect(imperial.current.apparentTemperature, closeTo(82.58, 0.01));
    expect(imperial.current.windSpeed, closeTo(5.22, 0.01));
    expect(imperial.hourly.first.temperature, closeTo(77.18, 0.01));
    expect(imperial.daily.first.maxTemperature, closeTo(83.12, 0.01));
    expect(imperial.daily.first.maxWindSpeed, closeTo(8.82, 0.01));
  });

  test('与单位无关的字段原样保留', () {
    final metric = buildWeather();
    final imperial = metric.convertTo(UnitSystem.imperial);

    expect(imperial.location, metric.location);
    expect(imperial.current.humidity, metric.current.humidity);
    expect(imperial.current.weatherCode, metric.current.weatherCode);
    expect(imperial.current.observedAt, metric.current.observedAt);
    expect(imperial.hourly, hasLength(metric.hourly.length));
    expect(imperial.daily, hasLength(metric.daily.length));
    expect(
      imperial.hourly.first.precipitationProbability,
      metric.hourly.first.precipitationProbability,
    );
    expect(imperial.daily.first.sunrise, metric.daily.first.sunrise);
  });

  test('换算可逆：华氏转回摄氏恢复原值', () {
    final metric = buildWeather();
    final roundTrip = metric
        .convertTo(UnitSystem.imperial)
        .convertTo(UnitSystem.metric);

    expect(roundTrip.units, UnitSystem.metric);
    expect(roundTrip.current.temperature, closeTo(26.3, 0.01));
    expect(roundTrip.current.windSpeed, closeTo(8.4, 0.01));
  });

  test('目标单位与当前单位相同时直接返回自身', () {
    final metric = buildWeather();

    expect(identical(metric.convertTo(UnitSystem.metric), metric), isTrue);
  });

  test('降水换算：mm ↔ in', () {
    expect(
      UnitSystem.imperial.convertPrecipitationFrom(25.4, UnitSystem.metric),
      closeTo(1, 0.001),
    );
    expect(
      UnitSystem.metric.convertPrecipitationFrom(1, UnitSystem.imperial),
      closeTo(25.4, 0.001),
    );
  });
}
