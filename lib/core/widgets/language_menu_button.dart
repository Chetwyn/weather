import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../state/locale_provider.dart';

/// AppBar 里的语言切换入口。
///
/// 菜单值用 [AppLocaleChoice] 而不是 `Locale?`：null 值会被
/// `PopupMenuButton` 当成「取消」，「跟随系统」就点不动了。
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = AppLocaleChoice.fromLocale(ref.watch(appLocaleProvider));
    final strings = AppStrings.of(context);

    return PopupMenuButton<AppLocaleChoice>(
      tooltip: strings.language,
      icon: const Icon(Icons.translate),
      initialValue: current,
      onSelected: (AppLocaleChoice choice) =>
          ref.read(appLocaleProvider.notifier).setLocale(choice.locale),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppLocaleChoice>>[
        CheckedPopupMenuItem<AppLocaleChoice>(
          value: AppLocaleChoice.system,
          checked: current == AppLocaleChoice.system,
          child: Text(strings.followSystem),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<AppLocaleChoice>(
          value: AppLocaleChoice.zhHans,
          checked: current == AppLocaleChoice.zhHans,
          child: Text(strings.simplifiedChinese),
        ),
        CheckedPopupMenuItem<AppLocaleChoice>(
          value: AppLocaleChoice.zhHant,
          checked: current == AppLocaleChoice.zhHant,
          child: Text(strings.traditionalChinese),
        ),
        CheckedPopupMenuItem<AppLocaleChoice>(
          value: AppLocaleChoice.english,
          checked: current == AppLocaleChoice.english,
          child: Text(strings.english),
        ),
      ],
    );
  }
}
