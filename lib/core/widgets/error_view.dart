import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../l10n/app_strings.dart';
import '../theme/tokens.dart';

/// 统一错误占位。
///
/// 只消费 [Failure]，不感知错误来源；是否展示「重试」由
/// [Failure.canRetry] 决定——不可重试的错误（如解析失败）不给用户
/// 无意义的按钮。
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final showRetry = onRetry != null && failure.canRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppTokens.spacingMd),
            Text(
              strings.failureMessage(failure),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (showRetry) ...<Widget>[
              const SizedBox(height: AppTokens.spacingLg),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(strings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
