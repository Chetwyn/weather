import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/theme/app_theme.dart';

void main() {
  test('浅色主题的状态栏图标是深色（否则白底白字看不见）', () {
    final style = AppTheme.light().appBarTheme.systemOverlayStyle!;

    expect(style.statusBarIconBrightness, Brightness.dark);
    // iOS 语义相反：描述的是状态栏背景亮度。
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.statusBarColor, Colors.transparent);
  });

  test('深色主题的状态栏图标是浅色', () {
    final style = AppTheme.dark().appBarTheme.systemOverlayStyle!;

    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('AppBar 实际应用主题里的状态栏样式', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(appBar: AppBar(title: const Text('天气'))),
      ),
    );

    final region = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .last;

    expect(region.value.statusBarIconBrightness, Brightness.dark);
  });
}
