import 'package:flutter/material.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/theme/tokens.dart';

/// 纯展示组件：不依赖状态容器，可直接进行界面测试或预览。
class LocationTile extends StatelessWidget {
  const LocationTile({
    super.key,
    required this.location,
    required this.onTap,
    this.onRemove,
  });

  final Location location;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.place_outlined, color: theme.colorScheme.primary),
      title: Text(location.name),
      subtitle: location.subtitle.isEmpty
          ? null
          : Text(
              location.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: onRemove == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.close),
              onPressed: onRemove,
              constraints: const BoxConstraints(
                minWidth: AppTokens.minTouchTarget,
                minHeight: AppTokens.minTouchTarget,
              ),
            ),
    );
  }
}
