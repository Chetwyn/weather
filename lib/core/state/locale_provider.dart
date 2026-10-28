import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/app_providers.dart';

/// 语言菜单的选项。
///
/// 菜单值使用枚举而非 `Locale?`：`PopupMenuButton.onSelected` 只在
/// 选中的值**非 null** 时回调，null 会被当成「取消」，导致「跟随系统」
/// 这一项无法选中。枚举包一层后，每一项都有非空的值。
enum AppLocaleChoice {
  system,
  zhHans,
  zhHant,
  english;

  /// 选中项对应的 locale；null 表示跟随系统。
  Locale? get locale => switch (this) {
    AppLocaleChoice.system => null,
    AppLocaleChoice.zhHans => zhHansLocale,
    AppLocaleChoice.zhHant => zhHantLocale,
    AppLocaleChoice.english => enLocale,
  };

  static AppLocaleChoice fromLocale(Locale? locale) {
    if (locale == null) return AppLocaleChoice.system;
    if (locale.languageCode == 'en') return AppLocaleChoice.english;
    return isTraditionalChinese(locale)
        ? AppLocaleChoice.zhHant
        : AppLocaleChoice.zhHans;
  }
}

/// 界面语言偏好（持久化）。
///
/// 值为 null 表示跟随系统语言，由 `MaterialApp.locale` 交给
/// `resolveAppLocale` 解析；显式选择则覆盖系统设置。
class AppLocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => ref.watch(preferencesStoreProvider).readAppLocale();

  Future<void> setLocale(Locale? locale) async {
    if (state == locale) return;
    state = locale;
    await ref.read(preferencesStoreProvider).writeAppLocale(locale);
  }
}

final NotifierProvider<AppLocaleNotifier, Locale?> appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, Locale?>(AppLocaleNotifier.new);
