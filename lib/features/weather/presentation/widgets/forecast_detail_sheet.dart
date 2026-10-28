import 'package:flutter/material.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/weather_code_mapper.dart';
import '../../domain/entity/daily_forecast.dart';

Future<void> showForecastDetailSheet(
  BuildContext context, {
  required DailyForecast item,
  required UnitSystem units,
  required String dayLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        ForecastDetailSheet(item: item, units: units, dayLabel: dayLabel),
  );
}

/// 单日预报详情。
///
/// 只展示该日已有的字段——缺失的字段整行隐藏，而不是显示 `--`。
class ForecastDetailSheet extends StatelessWidget {
  const ForecastDetailSheet({
    super.key,
    required this.item,
    required this.units,
    required this.dayLabel,
  });

  final DailyForecast item;
  final UnitSystem units;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final visual = describeWeatherCode(item.weatherCode);
    final rows = _buildRows(strings);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spacingLg,
        0,
        AppTokens.spacingLg,
        AppTokens.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(dayLabel, style: theme.textTheme.titleLarge),
                    Text(
                      strings.monthDayLabel(item.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(visual.icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(width: AppTokens.spacingSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    AppDateFormatter.temperatureRange(
                      item.minTemperature,
                      item.maxTemperature,
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    strings.weatherLabel(item.weatherCode),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacingMd),
          const Divider(height: 1),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spacingMd),
              child: Text(
                strings.noMoreData,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  List<Widget> _buildRows(AppStrings strings) {
    final rows = <Widget>[];

    final probability = item.precipitationProbability;
    if (probability != null) {
      rows.add(
        _DetailRow(
          icon: Icons.umbrella_outlined,
          label: strings.precipitationProbability,
          value: '$probability%',
        ),
      );
    }

    final sunrise = item.sunrise;
    if (sunrise != null) {
      rows.add(
        _DetailRow(
          icon: Icons.wb_twilight,
          label: strings.sunrise,
          value: AppDateFormatter.hourMinute(sunrise),
        ),
      );
    }

    final sunset = item.sunset;
    if (sunset != null) {
      rows.add(
        _DetailRow(
          icon: Icons.nights_stay_outlined,
          label: strings.sunset,
          value: AppDateFormatter.hourMinute(sunset),
        ),
      );
    }

    final maxWindSpeed = item.maxWindSpeed;
    if (maxWindSpeed != null) {
      rows.add(
        _DetailRow(
          icon: Icons.air,
          label: strings.maxWind,
          value: '${maxWindSpeed.toStringAsFixed(1)} ${units.windSpeedSuffix}',
        ),
      );
    }

    final maxUvIndex = item.maxUvIndex;
    if (maxUvIndex != null) {
      rows.add(
        _DetailRow(
          icon: Icons.wb_sunny_outlined,
          label: strings.maxUv,
          value: maxUvIndex.toStringAsFixed(1),
        ),
      );
    }

    return rows;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spacingMd),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTokens.spacingMd),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
