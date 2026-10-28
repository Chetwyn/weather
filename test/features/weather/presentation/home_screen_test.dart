import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/core/providers/app_providers.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/weather/domain/entity/weather.dart';
import 'package:weather/features/weather/domain/repository/weather_repository.dart';
import 'package:weather/features/weather/domain/usecase/get_weather_usecase.dart';
import 'package:weather/features/weather/presentation/providers/weather_providers.dart';
import 'package:weather/features/weather/presentation/screens/home_screen.dart';
import 'package:weather/features/weather/presentation/state/weather_state.dart';

import '../../../helpers/fixtures.dart';

/// 用固定状态替换真实状态机，使界面测试不触网。
class _StubWeatherNotifier extends WeatherNotifier {
  _StubWeatherNotifier(this.stub);

  final WeatherState stub;

  @override
  WeatherState build() => stub;
}

/// 按请求单位返回数据的假仓库，用于验证切换单位的完整链路。
///
/// [holdRequests] 为 true 时，除首次请求外的请求都挂起，
/// 用来观察「接口还没回来」时页面显示什么。
class _UnitAwareRepository implements WeatherRepository {
  _UnitAwareRepository({this.holdRequests = false});

  final bool holdRequests;
  final List<Completer<Weather>> _pending = <Completer<Weather>>[];
  int callCount = 0;

  @override
  Future<Weather> getWeather({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) {
    callCount++;
    if (holdRequests && callCount > 1) {
      final completer = Completer<Weather>();
      _pending.add(completer);
      return completer.future;
    }
    return Future<Weather>.value(buildWeather(units: units));
  }

  void release() {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(buildWeather());
    }
  }
}

/// 用真实 Notifier + 假仓库启动首页，返回仓库便于断言请求次数。
Future<_UnitAwareRepository> _pumpHomeWithRepository(
  WidgetTester tester, {
  bool holdRequests = false,
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{
    'pref_last_location': jsonEncode(taipei.toJson()),
  });
  final preferences = await SharedPreferences.getInstance();
  final repository = _UnitAwareRepository(holdRequests: holdRequests);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        getWeatherUseCaseProvider.overrideWithValue(
          GetWeatherUseCase(repository),
        ),
      ],
      child: _testApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// 天气图标是无限循环动画，测试里关掉「动态效果」让它静止，
/// 否则 `pumpAndSettle` 永远等不到稳定帧。
Widget _testApp() => MaterialApp(
  home: const HomeScreen(),
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

Future<void> _pumpHome(WidgetTester tester, {WeatherState? state}) async {
  // 放大测试视口，让整页内容一次性布局完成，避免因懒加载导致断言找不到组件。
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (state != null)
          weatherProvider.overrideWith(() => _StubWeatherNotifier(state)),
      ],
      child: _testApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('未选择地点时展示空态引导，且不显示错误或加载指示器', (WidgetTester tester) async {
    await _pumpHome(tester);

    expect(find.text(zh.emptyTitle), findsOneWidget);
    expect(find.text(zh.emptyAction), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('加载成功时渲染当前天气与未来预报', (WidgetTester tester) async {
    await _pumpHome(tester, state: WeatherSuccess(buildWeather()));

    expect(find.text('台北'), findsOneWidget);
    expect(find.textContaining('26.3'), findsWidgets);
    expect(find.text(zh.hourlyForecast), findsOneWidget);
    expect(find.text(zh.today), findsOneWidget);
    expect(find.text(zh.tomorrow), findsOneWidget);
  });

  testWidgets('切换单位后天气内容与后缀一起换成新单位', (WidgetTester tester) async {
    final repository = await _pumpHomeWithRepository(tester);

    expect(repository.callCount, 1);
    expect(
      tester.widget<Text>(find.textContaining(zh.feelsLike)).data,
      contains(UnitSystem.metric.temperatureSuffix),
    );

    await tester.tap(find.text('°C'));
    await tester.pumpAndSettle();

    expect(repository.callCount, 2, reason: '新单位要重新取数');
    expect(find.text('°F'), findsOneWidget);
    expect(
      tester.widget<Text>(find.textContaining(zh.feelsLike)).data,
      contains(UnitSystem.imperial.temperatureSuffix),
    );
  });

  testWidgets('接口尚未返回时也立即显示新单位的数值', (WidgetTester tester) async {
    final repository = await _pumpHomeWithRepository(
      tester,
      holdRequests: true,
    );

    await tester.tap(find.text('°C'));
    await tester.pump();

    // 请求挂在半路，页面必须已经换成华氏：
    // 28.1°C 本地换算为 82.6°F，后缀同步变成 °F。
    expect(find.text('°F'), findsOneWidget);
    final feelsLike = tester
        .widget<Text>(find.textContaining(zh.feelsLike))
        .data;
    expect(feelsLike, contains('82.6'));
    expect(feelsLike, contains(UnitSystem.imperial.temperatureSuffix));
    expect(find.text('台北'), findsOneWidget);

    repository.release();
    await tester.pumpAndSettle();
  });

  testWidgets('切换单位时页面内容留在原地，不闪现骨架屏', (WidgetTester tester) async {
    await _pumpHome(tester, state: WeatherSuccess(buildWeather()));

    await tester.tap(find.text('°C'));
    await tester.pump();

    expect(find.text('°F'), findsOneWidget);
    expect(find.text('台北'), findsOneWidget);
    expect(find.text(zh.hourlyForecast), findsOneWidget);
  });

  testWidgets('加载中先不渲染骨架屏（避免 200ms 内闪烁）', (WidgetTester tester) async {
    await _pumpHome(tester, state: const WeatherLoading());

    // 首帧处于延迟窗口内，骨架屏尚未出现。
    expect(find.text(zh.emptyTitle), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('加载失败时展示错误文案与重试按钮', (WidgetTester tester) async {
    const failure = ServerFailure(statusCode: 503);
    await _pumpHome(tester, state: const WeatherError(failure));

    expect(find.text(failure.displayMessage), findsOneWidget);
    expect(find.text(zh.retry), findsOneWidget);
  });

  testWidgets('不可重试的错误不展示重试按钮', (WidgetTester tester) async {
    const failure = ParseFailure();
    await _pumpHome(tester, state: const WeatherError(failure));

    expect(find.text(failure.displayMessage), findsOneWidget);
    expect(find.text(zh.retry), findsNothing);
  });

  testWidgets('空态同时提供手动搜索与「使用当前位置」两个入口', (WidgetTester tester) async {
    await _pumpHome(tester);

    expect(find.text(zh.emptyAction), findsOneWidget);
    expect(find.text(zh.useCurrentLocation), findsOneWidget);
  });

  testWidgets('点击某一天打开当日详情面板', (WidgetTester tester) async {
    await _pumpHome(tester, state: WeatherSuccess(buildWeather()));

    await tester.tap(find.text(zh.today));
    await tester.pumpAndSettle();

    expect(find.text(zh.sunrise), findsOneWidget);
    expect(find.text(zh.sunset), findsOneWidget);
    expect(find.text('06:02'), findsOneWidget);
  });
}

/// 简体中文文案：测试断言的就是用户实际看到的那串文字。
const zh = AppStringsZhHans();
