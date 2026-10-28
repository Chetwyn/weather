import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/request_token.dart';
import '../aliases/cjk_city_alias.dart';
import '../dto/location_dto.dart';
import 'geocoding_remote_data_source.dart';

/// 按查询语言选择首选源，另一个作为兜底。
///
/// 不采用「固定先查 A 再查 B」，原因：
/// - Open-Meteo 对拉丁字母召回好、响应快，但对中文基本无召回；
/// - Photon 对中日韩字符召回好，但结果是 POI 级别、需要排序。
///
/// 因此按关键词是否含 CJK 决定顺序，正常情况下只发一次请求；
/// 只有首选源返回空或失败时才多一次往返。
///
/// 例外是**中文译名**（「纽约」这类）：两个源都按本地名称建索引，
/// 中文译名词条根本不存在，先经 [kCjkCityAliases] 换成「本地名 + 国家码」
/// 再查，否则只会命中境内同名 POI。
class CompositeGeocodingDataSource implements GeocodingRemoteDataSource {
  CompositeGeocodingDataSource({required this.latin, required this.cjk});

  /// 拉丁字母首选源（Open-Meteo）。
  final GeocodingRemoteDataSource latin;

  /// CJK 首选源（Photon）。
  final GeocodingRemoteDataSource cjk;

  static final RegExp _cjkPattern = RegExp(
    r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af]',
  );

  static bool containsCjk(String text) => _cjkPattern.hasMatch(text);

  /// 别名查询固定用拉丁名称回调。
  ///
  /// 别名桥接靠「结果名 == 别名 query」挑出目标城市，而中文结果名并不可靠：
  /// `New York` + `language=zh` 的首条结果是内布拉斯加州的「约克」，
  /// 「罗马」返回「罗马市」、「西雅图」返回「西雅圖」——简繁与
  /// 后缀都不稳定。拉丁名称是唯一稳定的比较基准。
  ///
  /// 代价是别名命中的结果会显示英文名（`New York · New York · United States`），
  /// 与其它结果的中文名不一致——换取的是「搜中文译名一定落到正确的城市」。
  static const String _aliasLanguage = 'en';

  /// [language] 只对普通路径生效，原样转给子源；别名桥接固定用
  /// [_aliasLanguage]，否则「结果名 == 别名 query」的比较会失效。
  @override
  Future<List<LocationDto>> search(
    String query, {
    RequestToken? cancelToken,
    int limit = AppConfig.searchResultLimit,
    String? language,
  }) async {
    final alias = cityAliasFor(query);
    if (alias != null) {
      try {
        final bridged = await _searchByAlias(
          alias,
          cancelToken: cancelToken,
          limit: limit,
        );
        if (bridged.isNotEmpty) return bridged;
      } on CancelledFailure {
        rethrow;
      } on Failure {
        // 桥接失败不该让搜索整体失败：继续走下面的原始查询，
        // 中文关键词仍会交给 Photon，行为与没有别名时一致。
      }
    }

    final prefersCjk = containsCjk(query);
    final primary = prefersCjk ? cjk : latin;
    final secondary = prefersCjk ? latin : cjk;

    List<LocationDto> results;
    try {
      results = await primary.search(
        query,
        cancelToken: cancelToken,
        limit: limit,
        language: language,
      );
    } on Failure catch (failure) {
      // 用户主动取消不该再触发第二个请求。
      if (failure is CancelledFailure) rethrow;
      return secondary.search(
        query,
        cancelToken: cancelToken,
        limit: limit,
        language: language,
      );
    }

    if (results.isNotEmpty) return results;

    // 首选源返回空：可能是命名习惯不匹配（中/拉丁），交给另一个源兜底。
    return secondary.search(
      query,
      cancelToken: cancelToken,
      limit: limit,
      language: language,
    );
  }

  /// 用「本地正式名」查一次拉丁源，只保留同名同国的那几条。
  ///
  /// 国家码是必须的：`London` 会命中加拿大安大略省的 London，
  /// `Moscow` 会命中美国爱达荷州的 Moscow。
  Future<List<LocationDto>> _searchByAlias(
    CjkCityAlias alias, {
    RequestToken? cancelToken,
    required int limit,
  }) async {
    final results = await latin.search(
      alias.query,
      cancelToken: cancelToken,
      // 同名城市往往不止一个（美国有 7 个 New York），多取一些再筛。
      limit: limit * 3,
      language: _aliasLanguage,
    );

    return results
        .where((dto) => _matchesAlias(dto, alias))
        .take(limit)
        .toList(growable: false);
  }

  static bool _matchesAlias(LocationDto dto, CjkCityAlias alias) =>
      dto.countryCode == alias.countryCode &&
      dto.name.trim().toLowerCase() == alias.query.trim().toLowerCase();
}
