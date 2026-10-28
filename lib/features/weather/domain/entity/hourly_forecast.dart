/// 逐小时预报。时间为地点本地时间。
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    this.precipitationProbability,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;

  /// 降水概率 %
  final int? precipitationProbability;
}
