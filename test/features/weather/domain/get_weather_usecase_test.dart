import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/weather/domain/entity/daily_forecast.dart';
import 'package:weather/features/weather/domain/entity/weather.dart';
import 'package:weather/features/weather/domain/repository/weather_repository.dart';
import 'package:weather/features/weather/domain/usecase/get_weather_usecase.dart';

import '../../../helpers/fixtures.dart';

class _FakeWeatherRepository implements WeatherRepository {
  _FakeWeatherRepository({this.weather, this.failure});

  final Weather? weather;
  final Failure? failure;
  int callCount = 0;

  @override
  Future<Weather> getWeather({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) async {
    callCount++;
    final error = failure;
    if (error != null) throw error;
    return weather!;
  }
}

void main() {
  test('返回仓库结果', () async {
    final repository = _FakeWeatherRepository(weather: buildWeather());
    final useCase = GetWeatherUseCase(repository);

    final result = await useCase(location: taipei, units: UnitSystem.metric);

    expect(result.daily, hasLength(2));
    expect(repository.callCount, 1);
  });

  test('没有任何逐日预报时判定为数据不完整，抛 ParseFailure', () async {
    final incomplete = Weather(
      location: taipei,
      units: UnitSystem.metric,
      current: buildWeather().current,
      hourly: buildWeather().hourly,
      daily: const <DailyForecast>[],
    );
    final useCase = GetWeatherUseCase(
      _FakeWeatherRepository(weather: incomplete),
    );

    expect(
      () => useCase(location: taipei, units: UnitSystem.metric),
      throwsA(isA<ParseFailure>()),
    );
  });

  test('仓库的 Failure 原样向上抛，不被吞掉', () async {
    final useCase = GetWeatherUseCase(
      _FakeWeatherRepository(failure: const ServerFailure(statusCode: 503)),
    );

    expect(
      () => useCase(location: taipei, units: UnitSystem.metric),
      throwsA(isA<ServerFailure>()),
    );
  });
}
