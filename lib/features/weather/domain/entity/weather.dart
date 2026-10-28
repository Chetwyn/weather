import '../../../../core/config/app_config.dart';
import '../../../../core/domain/location.dart';
import 'current_weather.dart';
import 'daily_forecast.dart';
import 'hourly_forecast.dart';

/// 聚合根：页面一次性消费的天气数据。
class Weather {
  const Weather({
    required this.location,
    required this.units,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final Location location;

  /// 这份数据请求时使用的单位制。
  ///
  /// 温度、风速、降水的数值本身就带单位（API 按单位返回），
  /// 展示时必须用同一份单位算后缀：切换单位时旧数据还会在屏幕上停留
  /// 一小会儿（等新数据回来），若用全局单位的后缀会出现「24 °F」这种错配。
  final UnitSystem units;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  /// 从当前小时起的 [limit] 小时预报。
  ///
  /// 用 `current.observedAt`（地点本地时间）而非 `DateTime.now()` 定位起点，
  /// 避免设备时区与地点时区不一致时错位。
  List<HourlyForecast> hourlyFromNow({int limit = AppConfig.hourlyHours}) {
    final startIndex = hourly.indexWhere(
      (HourlyForecast item) => !item.time.isBefore(current.observedAt),
    );
    final start = startIndex < 0 ? 0 : startIndex;
    return hourly.skip(start).take(limit).toList(growable: false);
  }

  /// 把整份数据换算到 [target] 单位制（纯本地计算，不请求接口）。
  ///
  /// 切换单位时先用它把屏幕上的内容原地换掉：新单位没有缓存时要等接口，
  /// 这期间界面看起来「点了没反应」；换算后数字与后缀立刻同步。
  /// 接口返回后仍会用官方数值覆盖（两者只差浮点精度）。
  Weather convertTo(UnitSystem target) {
    if (target == units) return this;

    return Weather(
      location: location,
      units: target,
      current: CurrentWeather(
        observedAt: current.observedAt,
        temperature: target.convertTemperatureFrom(current.temperature, units),
        apparentTemperature: target.convertTemperatureFrom(
          current.apparentTemperature,
          units,
        ),
        humidity: current.humidity,
        windSpeed: target.convertWindSpeedFrom(current.windSpeed, units),
        windDirection: current.windDirection,
        weatherCode: current.weatherCode,
        isDay: current.isDay,
        pressure: current.pressure,
        precipitation: current.precipitation == null
            ? null
            : target.convertPrecipitationFrom(current.precipitation!, units),
        uvIndex: current.uvIndex,
      ),
      hourly: <HourlyForecast>[
        for (final item in hourly)
          HourlyForecast(
            time: item.time,
            temperature: target.convertTemperatureFrom(item.temperature, units),
            weatherCode: item.weatherCode,
            precipitationProbability: item.precipitationProbability,
          ),
      ],
      daily: <DailyForecast>[
        for (final item in daily)
          DailyForecast(
            date: item.date,
            weatherCode: item.weatherCode,
            maxTemperature: target.convertTemperatureFrom(
              item.maxTemperature,
              units,
            ),
            minTemperature: target.convertTemperatureFrom(
              item.minTemperature,
              units,
            ),
            precipitationProbability: item.precipitationProbability,
            sunrise: item.sunrise,
            sunset: item.sunset,
            maxWindSpeed: item.maxWindSpeed == null
                ? null
                : target.convertWindSpeedFrom(item.maxWindSpeed!, units),
            maxUvIndex: item.maxUvIndex,
          ),
      ],
    );
  }

  /// 预报区间内的最低温，用于温度区间条形图的相对刻度。
  double get weeklyMinTemperature => daily.isEmpty
      ? current.temperature
      : daily
            .map((DailyForecast item) => item.minTemperature)
            .reduce((double a, double b) => a < b ? a : b);

  double get weeklyMaxTemperature => daily.isEmpty
      ? current.temperature
      : daily
            .map((DailyForecast item) => item.maxTemperature)
            .reduce((double a, double b) => a > b ? a : b);
}
