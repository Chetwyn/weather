/// Open-Meteo `/v1/forecast` 的传输对象。
///
/// 设计要点：
/// - 这一层是唯一知道 JSON 字段名的地方；
/// - 数组字段（hourly / daily 是「并行数组」结构）在这里完成对齐与裁剪，
///   让上层拿到的是安全的、长度一致的数据；
/// - 字段缺失或类型不符统一抛 [FormatException]，由 DataSource 映射为
///   `ParseFailure`，不做静默兜底。
class WeatherDto {
  const WeatherDto({
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final CurrentWeatherDto current;
  final HourlyForecastDto hourly;
  final DailyForecastDto daily;

  factory WeatherDto.fromJson(Map<String, dynamic> json) {
    return WeatherDto(
      current: CurrentWeatherDto.fromJson(_asMap(json['current'], 'current')),
      hourly: HourlyForecastDto.fromJson(_asMap(json['hourly'], 'hourly')),
      daily: DailyForecastDto.fromJson(_asMap(json['daily'], 'daily')),
    );
  }
}

class CurrentWeatherDto {
  const CurrentWeatherDto({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.isDay,
    this.pressure,
    this.precipitation,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final double windDirection;
  final int weatherCode;
  final bool isDay;
  final double? pressure;
  final double? precipitation;

  factory CurrentWeatherDto.fromJson(Map<String, dynamic> json) {
    return CurrentWeatherDto(
      time: _asDateTime(json['time'], 'current.time'),
      temperature: _asDouble(json['temperature_2m'], 'current.temperature_2m'),
      apparentTemperature: _asDouble(
        json['apparent_temperature'],
        'current.apparent_temperature',
      ),
      humidity: _asInt(
        json['relative_humidity_2m'],
        'current.relative_humidity_2m',
      ),
      windSpeed: _asDouble(json['wind_speed_10m'], 'current.wind_speed_10m'),
      windDirection: _asDouble(
        json['wind_direction_10m'],
        'current.wind_direction_10m',
      ),
      weatherCode: _asInt(json['weather_code'], 'current.weather_code'),
      isDay: _asInt(json['is_day'], 'current.is_day') == 1,
      pressure: _asDoubleOrNull(json['surface_pressure']),
      precipitation: _asDoubleOrNull(json['precipitation']),
    );
  }
}

class HourlyForecastDto {
  const HourlyForecastDto({
    required this.times,
    required this.temperatures,
    required this.weatherCodes,
    required this.precipitationProbabilities,
  });

  final List<DateTime> times;
  final List<double> temperatures;
  final List<int> weatherCodes;
  final List<int?> precipitationProbabilities;

  /// 有效条目数：以最短数组为准，容忍个别字段缺项。
  int get length => <int>[
    times.length,
    temperatures.length,
    weatherCodes.length,
  ].reduce((int a, int b) => a < b ? a : b);

  factory HourlyForecastDto.fromJson(Map<String, dynamic> json) {
    return HourlyForecastDto(
      times: _asList(json['time'], 'hourly.time')
          .map((Object? value) => _asDateTime(value, 'hourly.time'))
          .toList(growable: false),
      temperatures: _asList(json['temperature_2m'], 'hourly.temperature_2m')
          .map((Object? value) => _asDouble(value, 'hourly.temperature_2m'))
          .toList(growable: false),
      weatherCodes: _asList(json['weather_code'], 'hourly.weather_code')
          .map((Object? value) => _asInt(value, 'hourly.weather_code'))
          .toList(growable: false),
      precipitationProbabilities:
          _asListOrNull(json['precipitation_probability'])
              ?.map(_asIntOrNull)
              .toList(growable: false) ??
          const <int?>[],
    );
  }
}

class DailyForecastDto {
  const DailyForecastDto({
    required this.times,
    required this.weatherCodes,
    required this.maxTemperatures,
    required this.minTemperatures,
    required this.precipitationProbabilities,
    required this.sunrises,
    required this.sunsets,
    required this.maxWindSpeeds,
    required this.maxUvIndexes,
  });

  final List<DateTime> times;
  final List<int> weatherCodes;
  final List<double> maxTemperatures;
  final List<double> minTemperatures;
  final List<int?> precipitationProbabilities;
  final List<DateTime?> sunrises;
  final List<DateTime?> sunsets;
  final List<double?> maxWindSpeeds;
  final List<double?> maxUvIndexes;

  int get length => <int>[
    times.length,
    weatherCodes.length,
    maxTemperatures.length,
    minTemperatures.length,
  ].reduce((int a, int b) => a < b ? a : b);

  factory DailyForecastDto.fromJson(Map<String, dynamic> json) {
    return DailyForecastDto(
      times: _asList(json['time'], 'daily.time')
          .map((Object? value) => _asDateTime(value, 'daily.time'))
          .toList(growable: false),
      weatherCodes: _asList(json['weather_code'], 'daily.weather_code')
          .map((Object? value) => _asInt(value, 'daily.weather_code'))
          .toList(growable: false),
      maxTemperatures:
          _asList(json['temperature_2m_max'], 'daily.temperature_2m_max')
              .map(
                (Object? value) => _asDouble(value, 'daily.temperature_2m_max'),
              )
              .toList(growable: false),
      minTemperatures:
          _asList(json['temperature_2m_min'], 'daily.temperature_2m_min')
              .map(
                (Object? value) => _asDouble(value, 'daily.temperature_2m_min'),
              )
              .toList(growable: false),
      precipitationProbabilities:
          _asListOrNull(json['precipitation_probability_max'])
              ?.map(_asIntOrNull)
              .toList(growable: false) ??
          const <int?>[],
      sunrises:
          _asListOrNull(json['sunrise'])
              ?.map(_asDateTimeOrNull)
              .toList(growable: false) ??
          const <DateTime?>[],
      sunsets:
          _asListOrNull(json['sunset'])
              ?.map(_asDateTimeOrNull)
              .toList(growable: false) ??
          const <DateTime?>[],
      maxWindSpeeds:
          _asListOrNull(json['wind_speed_10m_max'])
              ?.map(_asDoubleOrNull)
              .toList(growable: false) ??
          const <double?>[],
      maxUvIndexes:
          _asListOrNull(json['uv_index_max'])
              ?.map(_asDoubleOrNull)
              .toList(growable: false) ??
          const <double?>[],
    );
  }
}

// ---------------- 解析工具 ----------------
// 统一的校验入口：宁可抛出 FormatException 并被映射为 ParseFailure，
// 也不让 null 或错误类型静默流入界面层。

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('字段 $field 缺失或不是对象');
}

List<dynamic> _asList(Object? value, String field) {
  if (value is List) return value;
  throw FormatException('字段 $field 缺失或不是数组');
}

List<dynamic>? _asListOrNull(Object? value) => value is List ? value : null;

double _asDouble(Object? value, String field) {
  if (value is num) return value.toDouble();
  throw FormatException('字段 $field 不是数值');
}

double? _asDoubleOrNull(Object? value) =>
    value is num ? value.toDouble() : null;

int _asInt(Object? value, String field) {
  if (value is num) return value.toInt();
  throw FormatException('字段 $field 不是数值');
}

int? _asIntOrNull(Object? value) => value is num ? value.toInt() : null;

DateTime _asDateTime(Object? value, String field) {
  final parsed = _asDateTimeOrNull(value);
  if (parsed == null) throw FormatException('字段 $field 不是合法时间');
  return parsed;
}

DateTime? _asDateTimeOrNull(Object? value) {
  if (value is! String) return null;
  // 不带时区偏移的字符串按原样保留「墙上时钟」，不做时区转换。
  return DateTime.tryParse(value);
}
