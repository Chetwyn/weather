import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/state/selected_location_provider.dart';
import '../../../../core/state/unit_provider.dart';
import '../../../../core/utils/request_token.dart';
import '../../data/cache/weather_memory_cache.dart';
import '../../data/datasource/weather_remote_data_source.dart';
import '../../data/repository/weather_repository_impl.dart';
import '../../domain/repository/weather_repository.dart';
import '../../domain/usecase/get_weather_usecase.dart';
import '../state/weather_state.dart';

// ---------------- 依赖装配 ----------------

final Provider<WeatherRemoteDataSource> weatherRemoteDataSourceProvider =
    Provider<WeatherRemoteDataSource>(
      (Ref ref) => OpenMeteoWeatherDataSource(ref.watch(dioProvider)),
    );

final Provider<WeatherRepository> weatherRepositoryProvider =
    Provider<WeatherRepository>(
      (Ref ref) =>
          WeatherRepositoryImpl(ref.watch(weatherRemoteDataSourceProvider)),
    );

final Provider<GetWeatherUseCase> getWeatherUseCaseProvider =
    Provider<GetWeatherUseCase>(
      (Ref ref) => GetWeatherUseCase(ref.watch(weatherRepositoryProvider)),
    );

final Provider<WeatherMemoryCache> weatherCacheProvider =
    Provider<WeatherMemoryCache>((Ref ref) => WeatherMemoryCache());

// ---------------- 页面状态 ----------------

/// 天气数据状态。
///
/// 换城市会重建 provider 并回到骨架屏（本来就该展示新地点的加载态）；
/// 换单位**不重建**，而是在 [build] 里监听单位变化、保留当前画面重新加载：
/// 重建会把 state 打回 [WeatherLoading]，整页骨架屏闪一下。
class WeatherNotifier extends Notifier<WeatherState> {
  RequestToken? _token;

  @override
  WeatherState build() {
    final location = ref.watch(selectedLocationProvider);
    // 用 read 而不是 watch：单位变化不重建 provider，见下面的 listen。
    final units = ref.read(unitSystemProvider);

    ref.onDispose(() => _token?.cancel());

    ref.listen<UnitSystem>(unitSystemProvider, (
      UnitSystem? previous,
      UnitSystem next,
    ) {
      final current = ref.read(selectedLocationProvider);
      if (current == null) return;

      // 先把屏幕上的数据本地换算到新单位：新单位没缓存时要等接口，
      // 这期间如果保持旧数据，看起来就像"点了没反应"。
      final snapshot = state;
      if (snapshot is WeatherSuccess && snapshot.weather.units != next) {
        state = WeatherSuccess(snapshot.weather.convertTo(next));
      }

      unawaited(
        _load(current, next, _restartToken(), keepCurrentOnFailure: true),
      );
    });

    if (location == null) return const WeatherInitial();

    // build 必须是同步的，异步加载推到微任务。
    unawaited(
      Future<void>.microtask(() => _load(location, units, _restartToken())),
    );
    return const WeatherLoading();
  }

  /// 取新 token 并取消上一次请求，避免旧请求回来覆盖新单位的数据。
  RequestToken _restartToken() {
    final token = RequestToken();
    _token?.cancel();
    _token = token;
    return token;
  }

  Future<void> _load(
    Location location,
    UnitSystem units,
    RequestToken token, {

    /// 加载期间保留屏幕上的旧内容；失败时也不要把它换成全屏错误。
    bool keepCurrentOnFailure = false,
  }) async {
    if (!ref.mounted) return;

    final cache = ref.read(weatherCacheProvider);
    final key = WeatherMemoryCache.keyOf(location, units);

    final cached = cache.read(key);
    if (cached != null) {
      state = WeatherSuccess(cached);
      return;
    }

    try {
      final weather = await ref.read(getWeatherUseCaseProvider)(
        location: location,
        units: units,
        cancelToken: token,
      );
      if (token.isCancelled || !ref.mounted) return;
      cache.write(key, weather);
      state = WeatherSuccess(weather);
    } on Failure catch (failure) {
      if (failure is CancelledFailure || token.isCancelled || !ref.mounted) {
        return;
      }
      // 切换单位失败时保留旧单位的内容，比整页错误更不容易让人困惑。
      if (keepCurrentOnFailure && state is WeatherSuccess) return;
      state = WeatherError(failure);
    }
  }

  /// 下拉刷新：保留当前内容，失败只返回 [Failure] 由界面提示，
  /// 不把页面替换成全屏错误态。
  Future<Failure?> refresh() async {
    final location = ref.read(selectedLocationProvider);
    final units = ref.read(unitSystemProvider);
    if (location == null) return null;

    final useCase = ref.read(getWeatherUseCaseProvider);
    final cache = ref.read(weatherCacheProvider);
    final key = WeatherMemoryCache.keyOf(location, units);

    final token = _restartToken();

    try {
      final weather = await useCase(
        location: location,
        units: units,
        cancelToken: token,
      );
      if (!ref.mounted || token.isCancelled) return null;
      cache.write(key, weather);
      state = WeatherSuccess(weather);
      return null;
    } on Failure catch (failure) {
      if (failure is CancelledFailure) return null;
      return failure;
    }
  }

  /// 错误态重试：重建 provider，走一遍完整加载流程。
  void retry() => ref.invalidateSelf();
}

final NotifierProvider<WeatherNotifier, WeatherState> weatherProvider =
    NotifierProvider<WeatherNotifier, WeatherState>(WeatherNotifier.new);
