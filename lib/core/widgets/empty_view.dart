import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/tokens.dart';

/// 空态引导。与错误态、无结果态是三个独立组件。
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.icon = Icons.travel_explore,
    this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.secondaryAction,
  });

  final IconData icon;

  /// 文案默认取当前语言；调用方也可以覆盖成场景化的说明。
  final String? title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 次要入口（如「使用当前位置」）。由调用方传入完整组件，
  /// 这样空态组件本身仍然是无状态、无业务依赖的展示组件。
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: AppTokens.spacingMd),
            Text(
              title ?? strings.emptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spacingSm),
            Text(
              hint ?? strings.emptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppTokens.spacingLg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.search),
                label: Text(actionLabel!),
              ),
            ],
            ?secondaryAction,
          ],
        ),
      ),
    );
  }
}
