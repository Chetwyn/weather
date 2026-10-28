import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/config/app_config.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/search/domain/repository/location_repository.dart';
import 'package:weather/features/search/presentation/providers/search_providers.dart';
import 'package:weather/features/search/presentation/state/search_state.dart';

import '../../../helpers/fixtures.dart';

class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository({this.results = const <Location>[], this.failure});

  final List<Location> results;
  final Failure? failure;
  int callCount = 0;

  @override
  Future<List<Location>> search(
    String query, {
    RequestToken? cancelToken,
  }) async {
    callCount++;
    final error = failure;
    if (error != null) throw error;
    return results;
  }
}

ProviderContainer _createContainer(_FakeLocationRepository repository) {
  final container = ProviderContainer(
    overrides: [locationRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  // 必须先建立订阅：Riverpod 的 provider 是惰性的，
  // 没有监听者时依赖变化不会立即重建，防抖计时器也就不会启动。
  container.listen<SearchState>(
    locationSearchProvider,
    (SearchState? previous, SearchState next) {},
    fireImmediately: true,
  );
  return container;
}

Future<void> _waitDebounce() => Future<void>.delayed(
  AppConfig.searchDebounce + const Duration(milliseconds: 100),
);

void main() {
  test('初始为空闲态', () {
    final container = _createContainer(_FakeLocationRepository());
    expect(container.read(locationSearchProvider), isA<SearchIdle>());
  });

  test('关键词不足 2 字符时不发请求', () async {
    final repository = _FakeLocationRepository(results: <Location>[taipei]);
    final container = _createContainer(repository);

    container.read(searchQueryProvider.notifier).update('台');
    await _waitDebounce();

    expect(container.read(locationSearchProvider), isA<SearchTooShort>());
    expect(repository.callCount, 0);
  });

  test('防抖期间只发起一次请求', () async {
    final repository = _FakeLocationRepository(results: <Location>[taipei]);
    final container = _createContainer(repository);
    final notifier = container.read(searchQueryProvider.notifier);

    notifier.update('台');
    notifier.update('台北');
    notifier.update('台北市');

    await _waitDebounce();

    expect(repository.callCount, 1);
    expect(container.read(locationSearchProvider), isA<SearchResults>());
  });

  test('无匹配结果时为 SearchEmpty 而不是错误态', () async {
    final container = _createContainer(_FakeLocationRepository());

    container.read(searchQueryProvider.notifier).update('zzzz');
    await _waitDebounce();

    final state = container.read(locationSearchProvider);
    expect(state, isA<SearchEmpty>());
    expect((state as SearchEmpty).query, 'zzzz');
  });

  test('请求失败时为 SearchError 并携带 Failure', () async {
    final container = _createContainer(
      _FakeLocationRepository(failure: const NetworkFailure()),
    );

    container.read(searchQueryProvider.notifier).update('台北');
    await _waitDebounce();

    expect(container.read(locationSearchProvider), isA<SearchError>());
  });

  test('关键词前后空格会被裁剪', () async {
    final repository = _FakeLocationRepository(results: <Location>[taipei]);
    final container = _createContainer(repository);

    container.read(searchQueryProvider.notifier).update('  台北  ');
    await _waitDebounce();

    expect(container.read(locationSearchProvider), isA<SearchResults>());
  });
}
