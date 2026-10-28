import '../../../../core/domain/location.dart';

/// 地理编码接口的传输对象。
///
/// DTO 只存在于 data 层，通过 [toEntity] 转换为领域实体，
/// 避免 API 字段名泄漏到 UI。
class LocationDto {
  const LocationDto({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.admin1,
    this.country,
    this.countryCode,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;
  final String? admin1;
  final String? country;

  /// ISO 3166-1 alpha-2 国家码（统一大写）。
  ///
  /// 只用于**过滤**，不进入领域实体：中文译名别名需要它来排除
  /// 同名异国城市（`London` → 加拿大安大略省）。
  final String? countryCode;

  /// 解析单条结果。
  ///
  /// 对字段类型做严格校验：字段缺失或类型不符时抛出 [FormatException]，
  /// 由 data 层统一映射为 `ParseFailure`，而不是让 `null` 一路传到 UI。
  factory LocationDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];

    if (id is! int ||
        name is! String ||
        latitude is! num ||
        longitude is! num) {
      throw FormatException('地理编码结果字段缺失或类型不符: $json');
    }

    return LocationDto(
      id: id,
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      timezone: json['timezone'] as String? ?? 'auto',
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
      countryCode: _normalizeCountryCode(json['country_code']),
    );
  }

  /// 各供应商的大小写并不一致（Open-Meteo 返回 `US`，Photon 返回 `US`，
  /// 也有返回小写的情况），统一成大写后再比较。
  static String? _normalizeCountryCode(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim().toUpperCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  Location toEntity() => Location(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    timezone: timezone,
    admin1: _cleanAdmin1(admin1),
    country: country,
  );

  /// 上游数据偶尔返回 `臺灣省 or 台灣省` 这类多值字符串，
  /// 直接展示会显得脏；这里取第一个候选值。清洗放在 data 层，
  /// 保证 domain 与 UI 拿到的都是可直接展示的文本。
  static String? _cleanAdmin1(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final first = raw.split(' or ').first.trim();
    return first.isEmpty ? null : first;
  }
}
