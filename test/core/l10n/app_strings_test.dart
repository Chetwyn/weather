import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/app/app.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/core/providers/app_providers.dart';
import 'package:weather/core/state/locale_provider.dart';

void main() {
  group('语言解析', () {
    test('zh_TW / zh_HK 走繁体，zh_CN / zh_SG 走简体', () {
      expect(
        resolveAppLocale(<Locale>[
          const Locale('zh', 'TW'),
        ], supportedAppLocales),
        zhHantLocale,
      );
      expect(
        resolveAppLocale(<Locale>[
          const Locale('zh', 'HK'),
        ], supportedAppLocales),
        zhHantLocale,
      );
      expect(
        resolveAppLocale(<Locale>[
          const Locale('zh', 'CN'),
        ], supportedAppLocales),
        zhHansLocale,
      );
      expect(
        resolveAppLocale(<Locale>[
          const Locale('zh', 'SG'),
        ], supportedAppLocales),
        zhHansLocale,
      );
    });

    test('带 script 的中文 locale 按 script 判断', () {
      expect(
        resolveAppLocale(const <Locale>[
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ], supportedAppLocales),
        zhHantLocale,
      );
      expect(
        resolveAppLocale(const <Locale>[
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ], supportedAppLocales),
        zhHansLocale,
      );
    });

    test('英文可用；不支持的语言回退简体', () {
      expect(
        resolveAppLocale(<Locale>[
          const Locale('en', 'US'),
        ], supportedAppLocales),
        enLocale,
      );
      expect(
        resolveAppLocale(<Locale>[
          const Locale('ja', 'JP'),
        ], supportedAppLocales),
        zhHansLocale,
      );
      expect(resolveAppLocale(null, supportedAppLocales), zhHansLocale);
    });

    test('按顺序取第一个支持的语言', () {
      expect(
        resolveAppLocale(<Locale>[
          const Locale('ja'),
          const Locale('en'),
        ], supportedAppLocales),
        enLocale,
      );
    });
  });

  group('文案', () {
    test('应用名：云舒 / 雲舒 / Cirrus', () {
      expect(const AppStringsZhHans().appTitle, '云舒');
      expect(const AppStringsZhHant().appTitle, '雲舒');
      expect(const AppStringsEn().appTitle, 'Cirrus');
    });

    test('天气描述随语言变化', () {
      expect(const AppStringsZhHans().weatherLabel(0), '晴');
      expect(const AppStringsZhHant().weatherLabel(2), '多雲');
      expect(const AppStringsEn().weatherLabel(0), 'Clear');
      expect(const AppStringsEn().weatherLabel(95), 'Thunderstorm');
    });

    test('风向随语言变化', () {
      expect(const AppStringsZhHans().windDirectionName(0), '北');
      expect(const AppStringsZhHant().windDirectionName(90), '東');
      expect(const AppStringsEn().windDirectionName(0), 'N');
      expect(const AppStringsEn().windDirectionName(225), 'SW');
    });

    test('日期与星期随语言变化', () {
      final date = DateTime(2026, 10, 25); // 周日
      expect(const AppStringsZhHans().monthDayLabel(date), '10月25日');
      expect(const AppStringsEn().monthDayLabel(date), 'Oct 25');
      expect(const AppStringsZhHans().weekdayLabel(date), '周日');
      expect(const AppStringsZhHant().weekdayLabel(date), '週日');
      expect(const AppStringsEn().weekdayLabel(date), 'Sun');
    });

    test('错误文案不再写死中文', () {
      expect(
        const AppStringsEn().failureMessage(const NetworkFailure()),
        contains('network'),
      );
      expect(
        const AppStringsZhHans().failureMessage(const NetworkFailure()),
        contains('网络'),
      );
      expect(
        const AppStringsEn().failureMessage(
          const LocationPermissionFailure(permanentlyDenied: true),
        ),
        contains('Settings'),
      );
    });

    test('每种语言的关键文案都不为空', () {
      for (final AppStrings strings in <AppStrings>[
        const AppStringsZhHans(),
        const AppStringsZhHant(),
        const AppStringsEn(),
      ]) {
        expect(strings.appTitle.trim(), isNotEmpty);
        expect(strings.retry.trim(), isNotEmpty);
        expect(strings.emptyTitle.trim(), isNotEmpty);
        expect(strings.searchHint.trim(), isNotEmpty);
        expect(strings.currentWeather.trim(), isNotEmpty);
        expect(strings.dailyForecast.trim(), isNotEmpty);
        expect(strings.unknownError.trim(), isNotEmpty);
        expect(strings.weatherLabel(0).trim(), isNotEmpty);
        expect(strings.windDirectionLabels, hasLength(8));
        expect(strings.weekdayLabels, hasLength(7));
      }
    });
  });

  testWidgets('Localizations 按当前语言注入文案', (WidgetTester tester) async {
    Future<void> pumpWith(Locale locale) {
      return tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            const AppStringsDelegate(),
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Builder(
            builder: (BuildContext context) =>
                Text(AppStrings.of(context).appTitle),
          ),
        ),
      );
    }

    await pumpWith(zhHantLocale);
    await tester.pump();
    expect(find.text('雲舒'), findsOneWidget);

    await pumpWith(enLocale);
    await tester.pump();
    expect(find.text('Cirrus'), findsOneWidget);
  });

  test('选择语言后写入偏好，选「跟随系统」会清掉记录', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider), isNull, reason: '默认跟随系统');

    await container.read(appLocaleProvider.notifier).setLocale(enLocale);
    expect(container.read(appLocaleProvider), enLocale);
    expect(preferences.getString('pref_locale'), 'en');

    await container.read(appLocaleProvider.notifier).setLocale(null);
    expect(container.read(appLocaleProvider), isNull);
    expect(preferences.getString('pref_locale'), isNull, reason: '跟随系统 = 无记录');
  });

  test('菜单选项与 locale 互转', () {
    expect(AppLocaleChoice.fromLocale(null), AppLocaleChoice.system);
    expect(AppLocaleChoice.fromLocale(zhHansLocale), AppLocaleChoice.zhHans);
    expect(
      AppLocaleChoice.fromLocale(const Locale('zh', 'TW')),
      AppLocaleChoice.zhHant,
    );
    expect(AppLocaleChoice.fromLocale(enLocale), AppLocaleChoice.english);

    // 每一项都必须有非空值，否则 PopupMenuButton 会当成「取消」。
    for (final AppLocaleChoice choice in AppLocaleChoice.values) {
      expect(choice.name, isNotEmpty);
    }
    expect(AppLocaleChoice.system.locale, isNull);
  });

  testWidgets('通过语言菜单切换后界面文案立即更新', (WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = <Locale>[
      const Locale('zh', 'CN'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const WeatherApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('云舒'), findsOneWidget);
    expect(find.text('搜索城市查看天气'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<AppLocaleChoice>, 'English'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cirrus'), findsOneWidget);
    expect(find.text('Search a city to see the weather'), findsOneWidget);

    // 再点「跟随系统」：系统语言是 zh_CN，应立刻切回简体。
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<AppLocaleChoice>).first);
    await tester.pumpAndSettle();

    expect(find.text('云舒'), findsOneWidget);
    expect(find.text('搜索城市查看天气'), findsOneWidget);
  });
}
