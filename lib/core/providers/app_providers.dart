import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import '../storage/preferences_store.dart';

/// 由 `main()` 在 `ProviderScope.overrides` 中注入，避免界面层处理
/// `Future` 初始化。
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError(
        'sharedPreferencesProvider 必须在 main() 中被 override',
      ),
    );

final Provider<PreferencesStore> preferencesStoreProvider =
    Provider<PreferencesStore>(
      (Ref ref) => PreferencesStore(ref.watch(sharedPreferencesProvider)),
    );

/// 全局唯一的 Dio 实例。Repository 共享连接池与拦截器配置。
final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final dio = createDio();
  ref.onDispose(dio.close);
  return dio;
});
