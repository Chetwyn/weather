import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/features/weather/data/dto/weather_dto.dart';
import 'package:weather/features/weather/data/mapper/weather_mapper.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('WeatherDto + WeatherMapper', () {
    test('完整响应可解析为实体', () {
      final dto = WeatherDto.fromJson(weatherJsonFixture());
      final weather = WeatherMapper.toEntity(dto, taipei, UnitSystem.metric);

      expect(weather.location.name, '台北');
      expect(weather.units, UnitSystem.metric, reason: '实体要记住数据用的单位');
      expect(weather.current.temperature, 26.3);
      expect(weather.current.humidity, 71);
      expect(weather.current.isDay, isTrue);
      expect(weather.hourly, hasLength(4));
      expect(weather.daily, hasLength(2));
      expect(weather.daily.first.sunrise, DateTime(2026, 10, 25, 6, 2));
    });

    test('紫外线从当日预报回填到当前天气', () {
      final dto = WeatherDto.fromJson(weatherJsonFixture());
      final weather = WeatherMapper.toEntity(dto, taipei, UnitSystem.metric);

      expect(weather.current.uvIndex, 6.4);
    });

    test('降水概率中的 null 被保留为 null 而不是 0', () {
      final dto = WeatherDto.fromJson(weatherJsonFixture());
      final weather = WeatherMapper.toEntity(dto, taipei, UnitSystem.metric);

      expect(weather.hourly.last.precipitationProbability, isNull);
      expect(weather.hourly[2].precipitationProbability, 20);
    });

    test('缺少 current 区块时抛 FormatException（映射为 ParseFailure）', () {
      final json = weatherJsonFixture()..remove('current');
      expect(() => WeatherDto.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('字段类型不符时抛 FormatException', () {
      final json = weatherJsonFixture();
      (json['current']! as Map<String, dynamic>)['temperature_2m'] = 'hot';
      expect(() => WeatherDto.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('Weather.hourlyFromNow', () {
    test('从当前观测小时开始截取，而不是固定取前 24 条', () {
      final dto = WeatherDto.fromJson(weatherJsonFixture());
      final weather = WeatherMapper.toEntity(dto, taipei, UnitSystem.metric);

      final fromNow = weather.hourlyFromNow();
      expect(fromNow.first.time, DateTime(2026, 10, 25, 14));
      expect(fromNow, hasLength(2));
    });

    test('limit 生效', () {
      final dto = WeatherDto.fromJson(weatherJsonFixture());
      final weather = WeatherMapper.toEntity(dto, taipei, UnitSystem.metric);

      expect(weather.hourlyFromNow(limit: 1), hasLength(1));
    });
  });
}
