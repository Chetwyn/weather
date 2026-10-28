import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/state/unit_provider.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/language_menu_button.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../search/presentation/widgets/search_sheet.dart';
import '../../../search/presentation/widgets/use_current_location_button.dart';
import '../../domain/entity/weather.dart';
import '../providers/weather_providers.dart';
import '../state/weather_state.dart';
import '../widgets/current_weather_card.dart';
import '../widgets/daily_forecast_list.dart';
import '../widgets/hourly_forecast_list.dart';
import '../widgets/hourly_trend_chart.dart';

void openSearchSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => const SearchSheet(),
  );
}

/// 首页。唯一职责：把状态机映射到四种视图，不做数据处理。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherProvider);
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: <Widget>[
          const LanguageMenuButton(),
          // 单位按钮单独 watch，切换单位时只重建按钮本身，
          // 页面内容原地换成新单位的数据，不会整体重建。
          const _UnitToggleButton(),
          IconButton(
            tooltip: strings.searchHint,
            icon: const Icon(Icons.search),
            onPressed: () => openSearchSheet(context),
          ),
          const SizedBox(width: AppTokens.spacingSm),
        ],
      ),
      body: switch (state) {
        WeatherInitial() => EmptyView(
          actionLabel: strings.emptyAction,
          onAction: () => openSearchSheet(context),
          secondaryAction: const UseCurrentLocationButton(),
        ),
        WeatherLoading() => const DelayedSkeleton(child: WeatherSkeleton()),
        WeatherSuccess(:final Weather weather) => _WeatherContent(
          weather: weather,
        ),
        WeatherError(:final failure) => ErrorView(
          failure: failure,
          onRetry: ref.read(weatherProvider.notifier).retry,
        ),
      },
    );
  }
}

class _UnitToggleButton extends ConsumerWidget {
  const _UnitToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitSystemProvider);
    return TextButton(
      onPressed: ref.read(unitSystemProvider.notifier).toggle,
      child: Text(
        units == UnitSystem.metric ? '°C' : '°F',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _WeatherContent extends ConsumerWidget {
  const _WeatherContent({required this.weather});

  final Weather weather;

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    final failure = await ref.read(weatherProvider.notifier).refresh();
    if (failure == null || !context.mounted) return;

    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${strings.refreshFailed}：${strings.failureMessage(failure)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 走势图与逐小时卡片共用同一批数据，只算一次。
    final hourly = weather.hourlyFromNow();

    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context, ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.spacingMd),
        children: <Widget>[
          // 单位取自数据本身：切换单位后、新数据回来前，
          // 屏幕上仍是旧单位的数据，后缀也必须跟着旧数据走。
          CurrentWeatherCard(weather: weather, units: weather.units),
          const SizedBox(height: AppTokens.spacingLg),
          HourlyTrendChart(items: hourly),
          const SizedBox(height: AppTokens.spacingLg),
          HourlyForecastList(items: hourly),
          const SizedBox(height: AppTokens.spacingLg),
          DailyForecastList(
            items: weather.daily,
            rangeMin: weather.weeklyMinTemperature,
            rangeMax: weather.weeklyMaxTemperature,
            units: weather.units,
          ),
          const SizedBox(height: AppTokens.spacingLg),
        ],
      ),
    );
  }
}
