import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/state/selected_location_provider.dart';
import '../../data/geolocator_location_service.dart';
import '../../domain/location_service.dart';
import '../../domain/usecase/resolve_current_location_usecase.dart';
import 'search_providers.dart';

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) => const GeolocatorLocationService());

final Provider<ResolveCurrentLocationUseCase>
resolveCurrentLocationUseCaseProvider = Provider<ResolveCurrentLocationUseCase>(
  (Ref ref) => ResolveCurrentLocationUseCase(
    ref.watch(locationServiceProvider),
    ref.watch(reverseGeocoderProvider),
  ),
);

/// 「使用当前位置」的执行状态。
///
/// state 只表示"是否正在定位"——定位结果本身直接写入
/// [selectedLocationProvider]，天气数据会因而自动重新加载，
/// 不需要在这里再存一份。
class CurrentLocationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 成功返回 null；失败返回 [Failure] 由 UI 决定如何提示。
  Future<Failure?> locate() async {
    if (state) return null;

    state = true;
    try {
      final location = await ref.read(resolveCurrentLocationUseCaseProvider)();
      if (!ref.mounted) return null;
      await ref.read(selectedLocationProvider.notifier).select(location);
      return null;
    } on Failure catch (failure) {
      return failure;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final NotifierProvider<CurrentLocationNotifier, bool> currentLocationProvider =
    NotifierProvider<CurrentLocationNotifier, bool>(
      CurrentLocationNotifier.new,
    );
