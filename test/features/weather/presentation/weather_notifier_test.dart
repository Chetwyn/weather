import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/providers/app_providers.dart';
import 'package:weather/core/state/unit_provider.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/weather/domain/entity/weather.dart';
import 'package:weather/features/weather/domain/repository/weather_repository.dart';
import 'package:weather/features/weather/domain/usecase/get_weather_usecase.dart';
import 'package:weather/features/weather/presentation/providers/weather_providers.dart';
import 'package:weather/features/weather/presentation/state/weather_state.dart';

import '../../../helpers/fixtures.dart';

class _CountingRepository implements WeatherRepository {
  _CountingRepository({this.failure});

  final Failure? failure;
  int callCount = 0;

  @override
  Future<Weather> getWeather({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) async {
    callCount++;
    final error = failure;
    if (error != null) throw error;
    return buildWeather(units: units);
  }
}

/// 首次请求立即返回，之后的请求挂起，用来观察切换单位的中间态。
class _BlockingRepository implements WeatherRepository {
  final List<Completer<Weather>> _pending = <Completer<Weather>>[];
  int callCount = 0;

  @override
  Future<Weather> getWeather({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) {
    callCount++;
    if (callCount > 1) {
      final completer = Completer<Weather>();
      _pending.add(completer);
      return completer.future;
    }
    return Future<Weather>.value(buildWeather(units: units));
  }

  void completePending(Weather weather) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(weather);
    }
  }

  void failPending(Failure failure) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.completeError(failure);
    }
  }
}

/// 让排队的微任务与异步加载全部完成。
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<ProviderContainer> _createContainer(
  WeatherRepository repository, {
  bool withLastLocation = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (withLastLocation) 'pref_last_location': jsonEncode(taipei.toJson()),
  });
  final preferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      getWeatherUseCaseProvider.overrideWithValue(
        GetWeatherUseCase(repository),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen<WeatherState>(
    weatherProvider,
    (WeatherState? previous, WeatherState next) {},
    fireImmediately: true,
  );
  return container;
}

void main() {
  test('无已选地点时为 initial 态，且不发请求', () async {
    final repository = _CountingRepository();
    final container = await _createContainer(
      repository,
      withLastLocation: false,
    );
    await _settle();

    expect(container.read(weatherProvider), isA<WeatherInitial>());
    expect(repository.callCount, 0);
  });

  test('从持久化地点自动加载，build 先返回 loading 再进入 success', () async {
    final repository = _CountingRepository();
    final container = await _createContainer(repository);

    expect(container.read(weatherProvider), isA<WeatherLoading>());

    await _settle();
    expect(container.read(weatherProvider), isA<WeatherSuccess>());
    expect(repository.callCount, 1);
  });

  test('切换单位会重新请求（缓存键包含单位制）', () async {
    final repository = _CountingRepository();
    final container = await _createContainer(repository);
    await _settle();

    await container
        .read(unitSystemProvider.notifier)
        .setUnitSystem(UnitSystem.imperial);
    await _settle();

    expect(repository.callCount, 2);
    expect(container.read(weatherProvider), isA<WeatherSuccess>());
  });

  test('切回已看过的单位时命中缓存，不重复请求', () async {
    final repository = _CountingRepository();
    final container = await _createContainer(repository);
    await _settle();

    final notifier = container.read(unitSystemProvider.notifier);
    await notifier.setUnitSystem(UnitSystem.imperial);
    await _settle();
    await notifier.setUnitSystem(UnitSystem.metric);
    await _settle();

    expect(repository.callCount, 2);
    expect(container.read(weatherProvider), isA<WeatherSuccess>());
  });

  test('切换单位后立即本地换算，不等接口也不回骨架屏', () async {
    final repository = _BlockingRepository();
    final container = await _createContainer(repository);
    await _settle();

    expect(container.read(weatherProvider), isA<WeatherSuccess>());

    await container
        .read(unitSystemProvider.notifier)
        .setUnitSystem(UnitSystem.imperial);
    await _settle();

    // 接口还没返回，但屏幕上的数字必须已经换成华氏。
    final switched = container.read(weatherProvider);
    expect(switched, isA<WeatherSuccess>());
    final weather = (switched as WeatherSuccess).weather;
    expect(weather.units, UnitSystem.imperial);
    expect(weather.current.temperature, closeTo(26.3 * 9 / 5 + 32, 0.01));
    expect(repository.callCount, 2);

    repository.completePending(buildWeather(units: UnitSystem.imperial));
    await _settle();

    final after = container.read(weatherProvider);
    expect(after, isA<WeatherSuccess>());
    expect((after as WeatherSuccess).weather.units, UnitSystem.imperial);
  });

  test('切换单位失败时保留本地换算结果，不进入错误态', () async {
    final repository = _BlockingRepository();
    final container = await _createContainer(repository);
    await _settle();

    await container
        .read(unitSystemProvider.notifier)
        .setUnitSystem(UnitSystem.imperial);
    await _settle();

    repository.failPending(const TimeoutFailure());
    await _settle();

    final state = container.read(weatherProvider);
    expect(state, isA<WeatherSuccess>());
    expect((state as WeatherSuccess).weather.units, UnitSystem.imperial);
  });

  test('请求失败进入 error 态并携带 Failure', () async {
    final repository = _CountingRepository(failure: const TimeoutFailure());
    final container = await _createContainer(repository);
    await _settle();

    final state = container.read(weatherProvider);
    expect(state, isA<WeatherError>());
    expect((state as WeatherError).failure, isA<TimeoutFailure>());
  });

  test('下拉刷新失败时保留原有内容，只返回 Failure', () async {
    final repository = _CountingRepository();
    final container = await _createContainer(repository);
    await _settle();

    final failure = await container.read(weatherProvider.notifier).refresh();

    expect(failure, isNull, reason: '成功路径不返回错误');
    expect(container.read(weatherProvider), isA<WeatherSuccess>());
    expect(repository.callCount, 2, reason: '刷新穿透缓存，强制重新请求');
  });
}
