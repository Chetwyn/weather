import '../../../../core/domain/location.dart';
import '../../domain/entity/current_weather.dart';
import '../../domain/entity/daily_forecast.dart';
import '../../domain/entity/hourly_forecast.dart';
import '../../domain/entity/weather.dart';
import '../dto/weather_dto.dart';

/// DTO → Entity 映射。
///
/// 单独成文件的原因：映射逻辑带有业务判断（例如紫外线从 `daily`
/// 回填到 `current`），放在 DTO 内会让传输对象承担领域职责。
class WeatherMapper {
  const WeatherMapper._();

  static Weather toEntity(WeatherDto dto, Location location, UnitSystem units) {
    final daily = _mapDaily(dto.daily);
    final hourly = _mapHourly(dto.hourly);

    return Weather(
      location: location,
      units: units,
      current: CurrentWeather(
        observedAt: dto.current.time,
        temperature: dto.current.temperature,
        apparentTemperature: dto.current.apparentTemperature,
        humidity: dto.current.humidity,
        windSpeed: dto.current.windSpeed,
        windDirection: dto.current.windDirection,
        weatherCode: dto.current.weatherCode,
        isDay: dto.current.isDay,
        pressure: dto.current.pressure,
        precipitation: dto.current.precipitation,
        // `current` 区块不提供紫外线，用今日预报峰值回填，避免卡片上空一格。
        uvIndex: daily.isNotEmpty ? daily.first.maxUvIndex : null,
      ),
      hourly: hourly,
      daily: daily,
    );
  }

  static List<HourlyForecast> _mapHourly(HourlyForecastDto dto) {
    final result = <HourlyForecast>[];
    for (var index = 0; index < dto.length; index++) {
      result.add(
        HourlyForecast(
          time: dto.times[index],
          temperature: dto.temperatures[index],
          weatherCode: dto.weatherCodes[index],
          precipitationProbability: _valueAt(
            dto.precipitationProbabilities,
            index,
          ),
        ),
      );
    }
    return List<HourlyForecast>.unmodifiable(result);
  }

  static List<DailyForecast> _mapDaily(DailyForecastDto dto) {
    final result = <DailyForecast>[];
    for (var index = 0; index < dto.length; index++) {
      result.add(
        DailyForecast(
          date: dto.times[index],
          weatherCode: dto.weatherCodes[index],
          maxTemperature: dto.maxTemperatures[index],
          minTemperature: dto.minTemperatures[index],
          precipitationProbability: _valueAt(
            dto.precipitationProbabilities,
            index,
          ),
          sunrise: _valueAt(dto.sunrises, index),
          sunset: _valueAt(dto.sunsets, index),
          maxWindSpeed: _valueAt(dto.maxWindSpeeds, index),
          maxUvIndex: _valueAt(dto.maxUvIndexes, index),
        ),
      );
    }
    return List<DailyForecast>.unmodifiable(result);
  }

  /// 并行数组可能短于主数组，索引越界时返回 null 而不是崩溃。
  static T? _valueAt<T>(List<T?> values, int index) =>
      index < values.length ? values[index] : null;
}
