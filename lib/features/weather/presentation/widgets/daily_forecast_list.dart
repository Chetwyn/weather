import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/weather_code_mapper.dart';
import '../../../../core/widgets/section_title.dart';
import '../../domain/entity/daily_forecast.dart';
import 'forecast_detail_sheet.dart';

/// 未来多日预报。
///
/// `items[0]` 即「今天」——直接使用 API 返回顺序，不拿设备时钟做比较，
/// 避免跨时区判断错日期。
class DailyForecastList extends StatelessWidget {
  const DailyForecastList({
    super.key,
    required this.items,
    required this.rangeMin,
    required this.rangeMax,
    required this.units,
  });

  final List<DailyForecast> items;
  final double rangeMin;
  final double rangeMax;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionTitle(strings.dailyForecastForDays(items.length)),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTokens.spacingSm,
              horizontal: AppTokens.spacingMd,
            ),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < items.length; index++) ...<Widget>[
                  _DailyRow(
                    key: ValueKey<DateTime>(items[index].date),
                    item: items[index],
                    dayLabel: _dayLabel(index, strings),
                    rangeMin: rangeMin,
                    rangeMax: rangeMax,
                    units: units,
                  ),
                  if (index != items.length - 1)
                    const Divider(height: 1, indent: 4, endIndent: 4),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _dayLabel(int index, AppStrings strings) {
    if (index == 0) return strings.today;
    if (index == 1) return strings.tomorrow;
    return strings.weekdayLabel(items[index].date);
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    super.key,
    required this.item,
    required this.dayLabel,
    required this.rangeMin,
    required this.rangeMax,
    required this.units,
  });

  final DailyForecast item;
  final String dayLabel;
  final double rangeMin;
  final double rangeMax;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final visual = describeWeatherCode(item.weatherCode);

    return InkWell(
      onTap: () => showForecastDetailSheet(
        context,
        item: item,
        units: units,
        dayLabel: dayLabel,
      ),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spacingMd),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(dayLabel, style: theme.textTheme.bodyMedium),
                  Text(
                    strings.monthDayLabel(item.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(visual.icon, size: 20, color: theme.colorScheme.primary),
            SizedBox(
              width: 44,
              child: Text(
                item.precipitationProbability == null
                    ? ''
                    : '${item.precipitationProbability}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${AppDateFormatter.temperature(item.minTemperature)}°',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spacingSm),
            Expanded(
              child: _TemperatureBar(
                min: item.minTemperature,
                max: item.maxTemperature,
                rangeMin: rangeMin,
                rangeMax: rangeMax,
              ),
            ),
            const SizedBox(width: AppTokens.spacingSm),
            SizedBox(
              width: 32,
              child: Text(
                '${AppDateFormatter.temperature(item.maxTemperature)}°',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 温度区间条：表现当日温度在整周区间中的相对位置。
class _TemperatureBar extends StatelessWidget {
  const _TemperatureBar({
    required this.min,
    required this.max,
    required this.rangeMin,
    required this.rangeMax,
  });

  final double min;
  final double max;
  final double rangeMin;
  final double rangeMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = rangeMax - rangeMin;
    final span = total.abs() < 0.1 ? 1.0 : total;

    final startFraction = ((min - rangeMin) / span).clamp(0.0, 1.0);
    final widthFraction = ((max - min) / span).clamp(0.06, 1.0);

    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final width = constraints.maxWidth;
          final barWidth = math.max(6.0, width * widthFraction);
          final left = (width * startFraction).clamp(0.0, width - barWidth);

          return Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: left,
                width: barWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        theme.colorScheme.primary.withValues(alpha: 0.45),
                        theme.colorScheme.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
