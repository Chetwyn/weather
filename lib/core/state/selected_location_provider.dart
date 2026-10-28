import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/location.dart';
import '../providers/app_providers.dart';

/// 当前选中地点——全应用唯一数据源。
///
/// weather feature 通过 watch 它来触发数据加载，search 面板通过 `select()`
/// 写入它。这样避免了「搜索页保存一份、详情页再保存一份」的状态同步问题。
class SelectedLocationNotifier extends Notifier<Location?> {
  @override
  Location? build() => ref.watch(preferencesStoreProvider).readLastLocation();

  Future<void> select(Location location) async {
    if (state == location) return;
    state = location;
    await ref.read(preferencesStoreProvider).writeLastLocation(location);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(preferencesStoreProvider).writeLastLocation(null);
  }
}

final NotifierProvider<SelectedLocationNotifier, Location?>
selectedLocationProvider =
    NotifierProvider<SelectedLocationNotifier, Location?>(
      SelectedLocationNotifier.new,
    );
