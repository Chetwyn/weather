import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/search/data/datasource/composite_geocoding_data_source.dart';
import 'package:weather/features/search/data/datasource/geocoding_remote_data_source.dart';
import 'package:weather/features/search/data/dto/location_dto.dart';

class _RecordingDataSource implements GeocodingRemoteDataSource {
  _RecordingDataSource({
    this.name = 'source',
    this.results = const <LocationDto>[],
    this.failure,
  });

  final String name;
  final List<LocationDto> results;
  final Failure? failure;
  final List<String> queries = <String>[];
  final List<String?> languages = <String?>[];

  @override
  Future<List<LocationDto>> search(
    String query, {
    RequestToken? cancelToken,
    int limit = 10,
    String? language,
  }) async {
    queries.add(query);
    languages.add(language);
    final error = failure;
    if (error != null) throw error;
    return results;
  }
}

LocationDto _dto(String name, {String? countryCode}) => LocationDto(
  id: name.hashCode,
  name: name,
  latitude: 1,
  longitude: 2,
  timezone: 'auto',
  countryCode: countryCode,
);

void main() {
  group('CJK 检测', () {
    test('识别中文与日文', () {
      expect(CompositeGeocodingDataSource.containsCjk('台北'), isTrue);
      expect(CompositeGeocodingDataSource.containsCjk('東京'), isTrue);
      expect(CompositeGeocodingDataSource.containsCjk('上海'), isTrue);
    });

    test('拉丁字母不视为 CJK', () {
      expect(CompositeGeocodingDataSource.containsCjk('Taipei'), isFalse);
      expect(CompositeGeocodingDataSource.containsCjk('New York'), isFalse);
    });
  });

  test('中文查询优先走 CJK 源，命中后不再请求拉丁源', () async {
    final latin = _RecordingDataSource(
      name: 'latin',
      results: <LocationDto>[_dto('Taipei')],
    );
    final cjk = _RecordingDataSource(
      name: 'cjk',
      results: <LocationDto>[_dto('臺北市')],
    );
    final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

    final results = await composite.search('台北');

    expect(results.single.name, '臺北市');
    expect(cjk.queries, hasLength(1));
    expect(latin.queries, isEmpty);
  });

  test('英文查询优先走拉丁源', () async {
    final latin = _RecordingDataSource(
      name: 'latin',
      results: <LocationDto>[_dto('Taipei')],
    );
    final cjk = _RecordingDataSource(
      name: 'cjk',
      results: <LocationDto>[_dto('臺北市')],
    );
    final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

    final results = await composite.search('Taipei');

    expect(results.single.name, 'Taipei');
    expect(latin.queries, hasLength(1));
    expect(cjk.queries, isEmpty);
  });

  test('首选源返回空时回退到另一个源', () async {
    final latin = _RecordingDataSource(name: 'latin');
    final cjk = _RecordingDataSource(
      name: 'cjk',
      results: <LocationDto>[_dto('臺北市')],
    );
    final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

    final results = await composite.search('Taipei');

    expect(results.single.name, '臺北市');
    expect(latin.queries, hasLength(1));
    expect(cjk.queries, hasLength(1));
  });

  test('首选源失败时也尝试备用源', () async {
    final latin = _RecordingDataSource(
      name: 'latin',
      failure: const NetworkFailure(),
    );
    final cjk = _RecordingDataSource(
      name: 'cjk',
      results: <LocationDto>[_dto('臺北市')],
    );
    final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

    final results = await composite.search('Taipei');

    expect(results.single.name, '臺北市');
  });

  test('用户取消时不再发起第二个请求', () async {
    final latin = _RecordingDataSource(
      name: 'latin',
      failure: const CancelledFailure(),
    );
    final cjk = _RecordingDataSource(name: 'cjk');
    final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

    await expectLater(
      composite.search('Taipei'),
      throwsA(isA<CancelledFailure>()),
    );
    expect(cjk.queries, isEmpty);
  });

  test('两个源都失败时抛出备用源的 Failure', () async {
    final latin = _RecordingDataSource(
      name: 'latin',
      failure: const TimeoutFailure(),
    );
    final cjk = _RecordingDataSource(
      name: 'cjk',
      failure: const ServerFailure(statusCode: 503),
    );
    final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

    await expectLater(
      composite.search('Taipei'),
      throwsA(isA<ServerFailure>()),
    );
  });

  group('中文译名别名', () {
    test('「纽约」用本地名 New York 查拉丁源，并只保留同国结果', () async {
      final latin = _RecordingDataSource(
        name: 'latin',
        results: <LocationDto>[
          _dto('New York', countryCode: 'US'),
          _dto('New York', countryCode: 'CA'),
          _dto('York', countryCode: 'US'),
        ],
      );
      final cjk = _RecordingDataSource(
        name: 'cjk',
        results: <LocationDto>[_dto('纽约上城')],
      );
      final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

      final results = await composite.search('纽约');

      expect(results, hasLength(1));
      expect(results.single.countryCode, 'US');
      // 拉丁源的模糊召回会带出约克之类的城镇，名称必须与别名一致。
      expect(results.single.name, 'New York');
      expect(latin.queries, <String>['New York']);
      // 中文结果名不可靠（「约克」「紐約」都可能），必须显式要拉丁名。
      expect(latin.languages, <String?>['en']);
      expect(cjk.queries, isEmpty);
    });

    test('别名在源里没命中时退回原文查询', () async {
      final latin = _RecordingDataSource(
        name: 'latin',
        results: <LocationDto>[_dto('New York', countryCode: 'CA')],
      );
      final cjk = _RecordingDataSource(
        name: 'cjk',
        results: <LocationDto>[_dto('纽约上城')],
      );
      final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

      final results = await composite.search('纽约');

      expect(results.single.name, '纽约上城');
      expect(latin.queries, <String>['New York']);
      expect(cjk.queries, <String>['纽约']);
    });

    test('别名桥接失败时不阻断原有流程', () async {
      final latin = _RecordingDataSource(
        name: 'latin',
        failure: const NetworkFailure(),
      );
      final cjk = _RecordingDataSource(
        name: 'cjk',
        results: <LocationDto>[_dto('臺北市')],
      );
      final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

      final results = await composite.search('纽约');

      expect(results.single.name, '臺北市');
      expect(cjk.queries, <String>['纽约']);
    });

    test('表外中文关键词不经过别名，仍优先 Photon', () async {
      final latin = _RecordingDataSource(name: 'latin');
      final cjk = _RecordingDataSource(
        name: 'cjk',
        results: <LocationDto>[_dto('上海市')],
      );
      final composite = CompositeGeocodingDataSource(latin: latin, cjk: cjk);

      final results = await composite.search('上海');

      expect(results.single.name, '上海市');
      expect(latin.queries, isEmpty);
      expect(cjk.queries, <String>['上海']);
    });
  });
}
