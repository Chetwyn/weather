import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/domain/location.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/request_token.dart';
import '../../data/datasource/composite_geocoding_data_source.dart';
import '../../data/datasource/geocoding_remote_data_source.dart';
import '../../data/datasource/photon_geocoding_data_source.dart';
import '../../data/repository/location_repository_impl.dart';
import '../../domain/repository/location_repository.dart';
import '../../domain/repository/reverse_geocoder.dart';
import '../state/search_state.dart';

// ---------------- 依赖装配 ----------------

/// Photon 实例同时承担「中文搜索」与「坐标反查地名」两个职责，
/// 共用同一个 Dio 与 User-Agent 配置。
final Provider<PhotonGeocodingDataSource> photonDataSourceProvider =
    Provider<PhotonGeocodingDataSource>(
      (Ref ref) => PhotonGeocodingDataSource(ref.watch(dioProvider)),
    );

/// 组合数据源：拉丁字母走 Open-Meteo，CJK 走 Photon，互为兜底。
final Provider<GeocodingRemoteDataSource> geocodingDataSourceProvider =
    Provider<GeocodingRemoteDataSource>(
      (Ref ref) => CompositeGeocodingDataSource(
        latin: OpenMeteoGeocodingDataSource(ref.watch(dioProvider)),
        cjk: ref.watch(photonDataSourceProvider),
      ),
    );

final Provider<LocationRepository> locationRepositoryProvider =
    Provider<LocationRepository>(
      (Ref ref) =>
          LocationRepositoryImpl(ref.watch(geocodingDataSourceProvider)),
    );

final Provider<ReverseGeocoder> reverseGeocoderProvider =
    Provider<ReverseGeocoder>((Ref ref) => ref.watch(photonDataSourceProvider));

// ---------------- 输入与结果 ----------------

/// 原始输入文本（不做防抖，输入即更新）。
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

final NotifierProvider<SearchQueryNotifier, String> searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// 地点搜索：负责防抖、请求取消与状态流转。
///
/// 防抖放在状态层而不是界面层，好处是：
/// - 输入组件保持无状态、可复用；
/// - 防抖时长、最短长度这些规则集中在配置里；
/// - 可以直接对状态机写单测，不需要渲染界面。
class LocationSearchNotifier extends Notifier<SearchState> {
  Timer? _debounceTimer;
  RequestToken? _token;

  @override
  SearchState build() {
    final query = ref.watch(searchQueryProvider).trim();

    ref.onDispose(() {
      _debounceTimer?.cancel();
      _token?.cancel();
    });

    if (query.isEmpty) return const SearchIdle();
    if (query.length < AppConfig.minQueryLength) return const SearchTooShort();

    _debounceTimer = Timer(
      AppConfig.searchDebounce,
      () => unawaited(_search(query)),
    );
    return const SearchLoading();
  }

  Future<void> _search(String query) async {
    if (!ref.mounted) return;

    final repository = ref.read(locationRepositoryProvider);
    final token = RequestToken();
    _token = token;

    try {
      final results = await repository.search(query, cancelToken: token);
      if (token.isCancelled || !ref.mounted) return;
      state = results.isEmpty ? SearchEmpty(query) : SearchResults(results);
    } on Failure catch (failure) {
      if (failure is CancelledFailure || token.isCancelled || !ref.mounted) {
        return;
      }
      state = SearchError(failure);
    }
  }

  /// 搜索失败后重试同一关键词。
  void retry() => ref.invalidateSelf();
}

final NotifierProvider<LocationSearchNotifier, SearchState>
locationSearchProvider = NotifierProvider<LocationSearchNotifier, SearchState>(
  LocationSearchNotifier.new,
);

// ---------------- 最近搜索 ----------------

class RecentSearchesNotifier extends Notifier<List<Location>> {
  @override
  List<Location> build() =>
      ref.watch(preferencesStoreProvider).readRecentLocations();

  Future<void> add(Location location) async {
    final next = <Location>[
      location,
      ...state.where((Location item) => item != location),
    ].take(AppConfig.maxRecentSearches).toList(growable: false);

    state = next;
    await ref.read(preferencesStoreProvider).writeRecentLocations(next);
  }

  Future<void> remove(Location location) async {
    final next = state
        .where((Location item) => item != location)
        .toList(growable: false);
    state = next;
    await ref.read(preferencesStoreProvider).writeRecentLocations(next);
  }
}

final NotifierProvider<RecentSearchesNotifier, List<Location>>
recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<Location>>(
      RecentSearchesNotifier.new,
    );
