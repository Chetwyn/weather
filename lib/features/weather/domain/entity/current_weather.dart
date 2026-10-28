/// 当前天气观测值。
///
/// 所有时间为**地点本地时间**，由 API `timezone=auto` 保证。
class CurrentWeather {
  const CurrentWeather({
    required this.observedAt,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.isDay,
    this.pressure,
    this.precipitation,
    this.uvIndex,
  });

  final DateTime observedAt;
  final double temperature;
  final double apparentTemperature;

  /// 相对湿度 %
  final int humidity;

  final double windSpeed;

  /// 风向角度（0 = 北）
  final double windDirection;

  /// WMO 天气代码
  final int weatherCode;

  /// 白天/夜间，决定图标变体
  final bool isDay;

  final double? pressure;
  final double? precipitation;
  final double? uvIndex;
}
