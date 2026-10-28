/// 逐日预报。日期为地点本地时间。
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.maxTemperature,
    required this.minTemperature,
    this.precipitationProbability,
    this.sunrise,
    this.sunset,
    this.maxWindSpeed,
    this.maxUvIndex,
  });

  final DateTime date;
  final int weatherCode;
  final double maxTemperature;
  final double minTemperature;

  /// 降水概率 %
  final int? precipitationProbability;

  final DateTime? sunrise;
  final DateTime? sunset;
  final double? maxWindSpeed;
  final double? maxUvIndex;
}
