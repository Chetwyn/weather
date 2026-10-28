import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../core/state/locale_provider.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class WeatherApp extends ConsumerWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 显式选择的语言；null 表示跟随系统。
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppStrings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        const AppStringsDelegate(),
        ...GlobalMaterialLocalizations.delegates,
      ],
      // 自己解析简繁：默认算法会把 zh_TW 落到简体。
      localeListResolutionCallback: resolveAppLocale,
    );
  }
}
