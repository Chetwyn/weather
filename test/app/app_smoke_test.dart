import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/app/app.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/core/providers/app_providers.dart';

/// 冒烟测试：确保 app.dart / router.dart / main 装配链路能真正挂载起来。
void main() {
  testWidgets('应用可挂载并进入首页', (WidgetTester tester) async {
    // 测试默认语言是 en_US，这里固定成简体中文，断言才对应中文界面。
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
    await tester.pump();

    expect(find.text(zh.appTitle), findsOneWidget);
    expect(find.text(zh.emptyTitle), findsOneWidget);
  });
}

/// 简体中文文案：测试断言的就是用户实际看到的那串文字。
const zh = AppStringsZhHans();
