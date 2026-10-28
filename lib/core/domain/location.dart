/// 共享内核实体：地点。
///
/// 放在 core/domain 而非某个 feature 的 domain 下，是因为 search 与 weather
/// 两个 feature 都必须依赖它。若放在某个 feature 里，另一个 feature 就只能
/// 跨 feature 引用 domain，破坏「feature 之间不互相依赖」的边界。
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.admin1,
    this.country,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// IANA 时区（如 `Asia/Shanghai`）。API 使用 `timezone=auto` 返回。
  final String timezone;

  /// 一级行政区，用于消歧同名地点。
  final String? admin1;

  /// 国家名。
  final String? country;

  /// 「当前位置」使用固定 ID，便于在缓存与最近搜索里去重。
  static const int currentLocationId = -1;

  /// 是否是「当前位置」这种没有真实地名的地点。
  ///
  /// 名称本身是不带头衔的占位（`当前位置`），展示时要用当前语言再说一遍。
  bool get isCurrentLocation => id == currentLocationId;

  /// 「名称 · 行政区 · 国家」展示串，自动省略缺失项。
  String get subtitle {
    final parts = <String>[
      if (admin1 != null && admin1!.isNotEmpty) admin1!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(' · ');
  }

  /// 缓存键的一部分；Riverpod 3 用 `==` 过滤状态更新，
  /// 因此必须实现值相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          other.id == id &&
          other.name == name &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'admin1': admin1,
    'country': country,
  };

  static Location? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final lat = json['latitude'];
    final lon = json['longitude'];
    if (id is! int || name is! String || lat is! num || lon is! num) {
      return null;
    }
    return Location(
      id: id,
      name: name,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      timezone: json['timezone'] as String? ?? 'auto',
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
    );
  }

  @override
  String toString() => 'Location($id, $name, $latitude, $longitude)';
}

/// 单位制。影响 API 请求参数与展示后缀。
enum UnitSystem {
  metric,
  imperial;

  String get apiTemperatureUnit =>
      this == UnitSystem.metric ? 'celsius' : 'fahrenheit';

  String get apiWindSpeedUnit => this == UnitSystem.metric ? 'kmh' : 'mph';

  String get apiPrecipitationUnit => this == UnitSystem.metric ? 'mm' : 'inch';

  String get temperatureSuffix => this == UnitSystem.metric ? '°C' : '°F';

  String get windSpeedSuffix => this == UnitSystem.metric ? 'km/h' : 'mph';

  String get precipitationSuffix => this == UnitSystem.metric ? 'mm' : 'in';

  String get label => this == UnitSystem.metric ? '公制' : '英制';

  /// 温度：°C ↔ °F。`source` 是数值原本的单位。
  double convertTemperatureFrom(double value, UnitSystem source) {
    if (this == source) return value;
    return this == UnitSystem.imperial
        ? value * 9 / 5 + 32
        : (value - 32) * 5 / 9;
  }

  /// 风速：km/h ↔ mph。
  double convertWindSpeedFrom(double value, UnitSystem source) {
    if (this == source) return value;
    return this == UnitSystem.imperial ? value * 0.621371 : value / 0.621371;
  }

  /// 降水：mm ↔ in。
  double convertPrecipitationFrom(double value, UnitSystem source) {
    if (this == source) return value;
    return this == UnitSystem.imperial ? value / 25.4 : value * 25.4;
  }

  static UnitSystem fromName(String? name) => UnitSystem.values.firstWhere(
    (UnitSystem value) => value.name == name,
    orElse: () => UnitSystem.metric,
  );
}
