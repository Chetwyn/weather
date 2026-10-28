import '../../../../core/domain/location.dart';
import 'location_dto.dart';

/// Photon（OSM 搜索）返回的 GeoJSON Feature 的传输对象。
///
/// 与 [LocationDto] 的关系：Photon 用它把**另一种**响应结构归一化成
/// search feature 的公共传输形态 [LocationDto]，这样 Repository 与上层
/// 完全不需要知道查询命中了哪个供应商。
///
/// 注意 OSM 的行政层级命名并不规整，同一个字段在不同地区含义不同：
/// 例如深圳的 `city` 是「深圳市」、`state` 是「广东省」，
/// 而上海的 `city` 却是「黄浦区」、`state` 才是「上海市」。
/// 因此不能简单地"取某个字段"，而要按用途分别选层级（见下方两个 getter）。
class PhotonFeatureDto {
  const PhotonFeatureDto({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.locality,
    this.district,
    this.city,
    this.county,
    this.state,
    this.country,
    this.countryCode,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// OSM 地点类型：city / county / district / locality / street / house ...
  final String type;

  /// 社区 / 街区。
  final String? locality;

  /// 区 / 街道。
  final String? district;

  /// 市（绝大多数地区），也可能是直辖市的下辖区（见类注释）。
  final String? city;

  /// 县。
  final String? county;

  /// 省 / 州。
  final String? state;

  final String? country;

  /// ISO 3166-1 alpha-2 国家码，来自 `countrycode`（OSM 的全大写形式）。
  final String? countryCode;

  /// 无法解析出必要字段时返回 null（调用方过滤掉，而不是整批失败）。
  static PhotonFeatureDto? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();

    final properties = json['properties'];
    final geometry = json['geometry'];
    if (properties is! Map || geometry is! Map) return null;

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (latitude is! num || longitude is! num) return null;

    final props = properties.cast<String, dynamic>();
    final name =
        _nonEmpty(props['name']) ??
        _nonEmpty(props['city']) ??
        _nonEmpty(props['street']);
    if (name == null) return null;

    final osmId = props['osm_id'];

    return PhotonFeatureDto(
      id: osmId is int ? osmId : name.hashCode,
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      type: _nonEmpty(props['type']) ?? '',
      locality: _nonEmpty(props['locality']),
      district: _nonEmpty(props['district']),
      city: _nonEmpty(props['city']),
      county: _nonEmpty(props['county']),
      state: _nonEmpty(props['state']),
      country: _nonEmpty(props['country']),
      countryCode: _nonEmpty(props['countrycode'])?.toUpperCase(),
    );
  }

  /// 搜索列表用的副标题：用省 / 市来区分同名地点，
  /// 与主名重复时返回 null（避免「臺北市 · 臺北市」）。
  String? get disambiguationSubtitle {
    final candidate = state ?? city ?? county;
    return candidate == name ? null : candidate;
  }

  /// 逆地理编码的主名：**越具体越好**。
  ///
  /// 顺序 city → county → state → name：天气按城市感知，
  /// 取到省级没有意义（「广东省」对用户毫无帮助）。
  String get primaryName => city ?? county ?? state ?? name;

  /// 逆地理编码的副名：区 / 街道，比省更有信息量。
  String? get areaName {
    final candidate = district ?? locality;
    if (candidate == null || candidate == primaryName) return null;
    return candidate;
  }

  /// 排序权重：优先行政区，其次街区，最后 POI。
  ///
  /// Photon 的原始顺序会把「台北车站」这类 POI 排在「臺北市」前面，
  /// 直接照搬会得到一个搜城市却返回火车站的结果。
  int get typePriority {
    switch (type) {
      case 'city':
      case 'state':
      case 'country':
        return 5;
      case 'county':
        return 4;
      case 'district':
      case 'locality':
        return 3;
      case 'street':
        return 1;
      case 'house':
        return 0;
      default:
        return 2;
    }
  }

  /// Photon 不返回时区；天气请求用 `timezone=auto`，因此这里填占位值。
  LocationDto toLocationDto() => LocationDto(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    timezone: 'auto',
    admin1: disambiguationSubtitle,
    country: country,
    countryCode: countryCode,
  );

  /// 坐标反查结果 → 地点实体。
  ///
  /// 主名取城市级、副名取区/街道，这样卡片上会显示
  /// 「臺北市」+「中山區 · 臺灣」，而不是只显示一个省名。
  Location toReverseLocation({
    required double latitude,
    required double longitude,
  }) => Location(
    id: id,
    name: primaryName,
    latitude: latitude,
    longitude: longitude,
    timezone: 'auto',
    admin1: areaName,
    country: country,
  );

  static String? _nonEmpty(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
