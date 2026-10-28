import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/app_strings.dart';
import '../providers/current_location_provider.dart';

/// 执行一次定位，并把失败原因在这里解释一遍。
///
/// 成功时地点已写入 `selectedLocationProvider`（由 notifier 完成），
/// 返回 null；失败时返回 [Failure] 并弹 SnackBar。
/// 「使用当前位置」有两处呈现（空态按钮 / 搜索面板列表行），
/// 失败提示只该写一次。
Future<Failure?> _locate(BuildContext context, WidgetRef ref) async {
  final failure = await ref.read(currentLocationProvider.notifier).locate();
  if (failure == null || !context.mounted) return failure;

  // 权限被永久拒绝时，用户唯一的自救路径是系统设置，
  // 所以在提示上直接给出跳转入口，而不是只留一句「请去设置里开启」。
  final canOpenSettings =
      failure is LocationPermissionFailure && failure.permanentlyDenied;

  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // 连续点按时不要在队列里堆叠多条提示。
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(strings.failureMessage(failure)),
      behavior: SnackBarBehavior.floating,
      // 带跳转按钮的提示停留久一点，否则还没看清就消失了。
      duration: canOpenSettings
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4),
      action: canOpenSettings
          ? SnackBarAction(
              label: strings.openSystemSettings,
              onPressed: () => ref.read(locationServiceProvider).openSettings(),
            )
          : null,
    ),
  );
  return failure;
}

/// 「使用当前位置」入口。
///
/// 自带加载态与失败提示：定位是副作用操作，失败原因（权限 / 服务关闭）
/// 只在这一处解释一次，不让每个调用方重复处理。
class UseCurrentLocationButton extends ConsumerWidget {
  const UseCurrentLocationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocating = ref.watch(currentLocationProvider);
    final strings = AppStrings.of(context);

    return TextButton.icon(
      onPressed: isLocating ? null : () => _locate(context, ref),
      icon: isLocating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location, size: 18),
      label: Text(isLocating ? strings.locating : strings.useCurrentLocation),
    );
  }
}

/// 搜索面板里的「使用当前位置」行。
///
/// 搜索面板保留常驻定位行：定位本质是「选一个地点」的快捷方式，
/// 而空态按钮只在没有选中地点时出现——用户选过一次城市后便无法再回到
/// 该入口。作为面板内的常驻行，任意时刻都能一键切回本地天气。
class UseCurrentLocationTile extends ConsumerWidget {
  const UseCurrentLocationTile({super.key, this.onLocated});

  /// 定位成功后回调（调用方通常用来关闭搜索面板）。
  final VoidCallback? onLocated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocating = ref.watch(currentLocationProvider);
    final strings = AppStrings.of(context);

    return ListTile(
      enabled: !isLocating,
      leading: isLocating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.my_location,
              color: Theme.of(context).colorScheme.primary,
            ),
      title: Text(isLocating ? strings.locating : strings.useCurrentLocation),
      onTap: isLocating
          ? null
          : () async {
              final failure = await _locate(context, ref);
              if (failure != null || !context.mounted) return;
              onLocated?.call();
            },
    );
  }
}
