import 'package:weather/core/domain/location.dart';
import 'package:weather/features/weather/domain/entity/current_weather.dart';
import 'package:weather/features/weather/domain/entity/daily_forecast.dart';
import 'package:weather/features/weather/domain/entity/hourly_forecast.dart';
import 'package:weather/features/weather/domain/entity/weather.dart';

const Location taipei = Location(
  id: 1668341,
  name: '台北',
  latitude: 25.0478,
  longitude: 121.5319,
  timezone: 'Asia/Taipei',
  admin1: '台北市',
  country: '台湾',
);

/// 与真实 API 形状一致的响应样本（截取必要字段）。
Map<String, dynamic> weatherJsonFixture() => <String, dynamic>{
  'latitude': 25.05,
  'longitude': 121.53,
  'timezone': 'Asia/Taipei',
  'current': <String, dynamic>{
    'time': '2026-10-25T14:00',
    'temperature_2m': 26.3,
    'relative_humidity_2m': 71,
    'apparent_temperature': 28.1,
    'is_day': 1,
    'precipitation': 0.0,
    'weather_code': 1,
    'surface_pressure': 1012.3,
    'wind_speed_10m': 8.4,
    'wind_direction_10m': 120,
  },
  'hourly': <String, dynamic>{
    'time': <String>[
      '2026-10-25T12:00',
      '2026-10-25T13:00',
      '2026-10-25T14:00',
      '2026-10-25T15:00',
    ],
    'temperature_2m': <double>[25.1, 25.8, 26.3, 26.0],
    'weather_code': <int>[1, 1, 2, 3],
    'precipitation_probability': <int?>[0, 10, 20, null],
  },
  'daily': <String, dynamic>{
    'time': <String>['2026-10-25', '2026-10-26'],
    'weather_code': <int>[2, 61],
    'temperature_2m_max': <double>[28.4, 26.1],
    'temperature_2m_min': <double>[21.2, 20.4],
    'precipitation_probability_max': <int?>[20, 80],
    'sunrise': <String>['2026-10-25T06:02', '2026-10-26T06:03'],
    'sunset': <String>['2026-10-25T17:20', '2026-10-26T17:19'],
    'wind_speed_10m_max': <double?>[14.2, 20.1],
    'uv_index_max': <double?>[6.4, 3.1],
  },
};

Weather buildWeather({UnitSystem units = UnitSystem.metric}) => Weather(
  location: taipei,
  units: units,
  current: CurrentWeather(
    observedAt: DateTime(2026, 10, 25, 14),
    temperature: 26.3,
    apparentTemperature: 28.1,
    humidity: 71,
    windSpeed: 8.4,
    windDirection: 120,
    weatherCode: 1,
    isDay: true,
    pressure: 1012.3,
    precipitation: 0,
    uvIndex: 6.4,
  ),
  hourly: <HourlyForecast>[
    HourlyForecast(
      time: DateTime(2026, 10, 25, 12),
      temperature: 25.1,
      weatherCode: 1,
      precipitationProbability: 0,
    ),
    HourlyForecast(
      time: DateTime(2026, 10, 25, 14),
      temperature: 26.3,
      weatherCode: 2,
      precipitationProbability: 20,
    ),
    HourlyForecast(
      time: DateTime(2026, 10, 25, 15),
      temperature: 26.0,
      weatherCode: 3,
    ),
  ],
  daily: <DailyForecast>[
    DailyForecast(
      date: DateTime(2026, 10, 25),
      weatherCode: 2,
      maxTemperature: 28.4,
      minTemperature: 21.2,
      precipitationProbability: 20,
      sunrise: DateTime(2026, 10, 25, 6, 2),
      sunset: DateTime(2026, 10, 25, 17, 20),
      maxWindSpeed: 14.2,
      maxUvIndex: 6.4,
    ),
    DailyForecast(
      date: DateTime(2026, 10, 26),
      weatherCode: 61,
      maxTemperature: 26.1,
      minTemperature: 20.4,
      precipitationProbability: 80,
    ),
  ],
);
