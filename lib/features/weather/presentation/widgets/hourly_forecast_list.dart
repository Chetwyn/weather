import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/weather_code_mapper.dart';
import '../../../../core/widgets/section_title.dart';
import '../../domain/entity/hourly_forecast.dart';

/// 逐小时预报（横向滚动）。
///
/// 用 `IntrinsicHeight` 让所有卡片等高，而不是写死一个像素高度：
/// 卡片高度会随系统字号缩放自然变化，1.6 倍字号下不会溢出。
class HourlyForecastList extends StatelessWidget {
  const HourlyForecastList({super.key, required this.items});

  final List<HourlyForecast> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionTitle(AppStrings.of(context).hourlyForecast),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var index = 0; index < items.length; index++) ...<Widget>[
                  if (index != 0) const SizedBox(width: AppTokens.spacingSm),
                  _HourlyTile(item: items[index]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({required this.item});

  final HourlyForecast item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 逐小时数据不带 is_day，用小时数近似判断昼夜图标。
    final isDay = item.time.hour >= 6 && item.time.hour < 18;
    final visual = describeWeatherCode(item.weatherCode, isDay: isDay);
    final probability = item.precipitationProbability;

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.spacingMd,
        horizontal: AppTokens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            AppDateFormatter.hour(item.time),
            maxLines: 1,
            style: theme.textTheme.bodySmall,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.spacingSm),
            child: Icon(
              visual.icon,
              size: 22,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            '${AppDateFormatter.temperature(item.temperature)}°',
            maxLines: 1,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(
            height: 16,
            child: probability == null
                ? null
                : Text(
                    '$probability%',
                    maxLines: 1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
