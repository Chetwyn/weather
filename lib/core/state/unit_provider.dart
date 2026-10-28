import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/location.dart';
import '../providers/app_providers.dart';

/// 单位制偏好（持久化）。
///
/// 天气缓存键包含单位制，因此切换单位会触发重新请求，
/// 不会复用旧单位的数据。
class UnitSystemNotifier extends Notifier<UnitSystem> {
  @override
  UnitSystem build() => ref.watch(preferencesStoreProvider).readUnits();

  Future<void> setUnitSystem(UnitSystem units) async {
    if (state == units) return;
    state = units;
    await ref.read(preferencesStoreProvider).writeUnits(units);
  }

  Future<void> toggle() => setUnitSystem(
    state == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric,
  );
}

final NotifierProvider<UnitSystemNotifier, UnitSystem> unitSystemProvider =
    NotifierProvider<UnitSystemNotifier, UnitSystem>(UnitSystemNotifier.new);
