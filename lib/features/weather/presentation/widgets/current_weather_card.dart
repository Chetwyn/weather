import 'package:flutter/material.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/weather_code_mapper.dart';
import '../../domain/entity/current_weather.dart';
import '../../domain/entity/weather.dart';
import 'animated_weather_icon.dart';

/// 当前天气卡片。
///
/// 纯展示组件：只接收 [Weather] 与 [UnitSystem]，不 watch 任何 Provider，
/// 因此可以在界面测试中直接构造数据渲染，不需要模拟网络。
class CurrentWeatherCard extends StatelessWidget {
  const CurrentWeatherCard({
    super.key,
    required this.weather,
    required this.units,
  });

  final Weather weather;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final current = weather.current;
    final strings = AppStrings.of(context);
    final visual = describeWeatherCode(
      current.weatherCode,
      isDay: current.isDay,
    );

    return Container(
      padding: const EdgeInsets.all(AppTokens.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientFor(visual.group, current.isDay),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      // 「当前位置」是占位地名，按当前语言重新渲染。
                      weather.location.isCurrentLocation
                          ? strings.currentLocation
                          : weather.location.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (weather.location.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          weather.location.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${strings.updatedAt} '
                '${AppDateFormatter.hourMinute(current.observedAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacingLg),
          Row(
            children: <Widget>[
              AnimatedWeatherIcon(visual: visual, isDay: current.isDay),
              const SizedBox(width: AppTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${AppDateFormatter.temperature(current.temperature)}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.weatherLabel(current.weatherCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacingSm),
          Text(
            '${strings.feelsLike} '
            '${AppDateFormatter.temperature(current.apparentTemperature)}'
            '${units.temperatureSuffix}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: AppTokens.spacingMd),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppTokens.spacingMd),
          Wrap(
            spacing: AppTokens.spacingSm,
            runSpacing: AppTokens.spacingSm,
            children: _buildMetrics(current, units, strings),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMetrics(
    CurrentWeather current,
    UnitSystem units,
    AppStrings strings,
  ) {
    final metrics = <Widget>[
      _MetricChip(
        icon: Icons.water_drop_outlined,
        label: strings.humidity,
        value: '${current.humidity}%',
      ),
      _MetricChip(
        icon: Icons.air,
        label: strings.wind,
        value:
            '${strings.windDirectionName(current.windDirection)} '
            '${current.windSpeed.toStringAsFixed(1)} '
            '${units.windSpeedSuffix}',
      ),
    ];

    final precipitation = current.precipitation;
    if (precipitation != null) {
      metrics.add(
        _MetricChip(
          icon: Icons.grain,
          label: strings.precipitation,
          value:
              '${precipitation.toStringAsFixed(1)} '
              '${units.precipitationSuffix}',
        ),
      );
    }

    final pressure = current.pressure;
    if (pressure != null) {
      metrics.add(
        _MetricChip(
          icon: Icons.compress,
          label: strings.pressure,
          value: '${pressure.round()} hPa',
        ),
      );
    }

    final uvIndex = current.uvIndex;
    if (uvIndex != null) {
      metrics.add(
        _MetricChip(
          icon: Icons.wb_sunny_outlined,
          label: strings.uvIndex,
          value: uvIndex.toStringAsFixed(0),
        ),
      );
    }

    return metrics;
  }

  List<Color> _gradientFor(WeatherGroup group, bool isDay) {
    switch (group) {
      case WeatherGroup.rain:
      case WeatherGroup.snow:
      case WeatherGroup.thunder:
      case WeatherGroup.fog:
        return AppTokens.rainGradient;
      case WeatherGroup.clear:
      case WeatherGroup.cloudy:
        return isDay ? AppTokens.dayGradient : AppTokens.nightGradient;
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spacingMd,
        vertical: AppTokens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
