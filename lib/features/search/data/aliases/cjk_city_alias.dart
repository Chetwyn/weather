/// 一个中文外来地名的可检索形式。
class CjkCityAlias {
  const CjkCityAlias({required this.query, required this.countryCode});

  /// 该城市在其本地的正式名称（OSM / 各 geocoder 可检索的形式）。
  final String query;

  /// ISO 3166-1 alpha-2 国家码。
  ///
  /// 必须带上：只写 `London` 会命中加拿大安大略省的 London，
  /// 只写 `Moscow` 会命中美国爱达荷州的 Moscow。
  final String countryCode;
}

/// 中文外来地名 → 可检索名称 + 国家码。
///
/// 两个地理编码源都按「本地名称」建索引，「纽约」是 New York 的中文译名，
/// 索引中不存在该词：Photon 只会命中境内叫「纽约上城」的 POI，
/// Open-Meteo 返回空（繁体「紐約」反而能命中）。
///
/// 免费地理编码服务中没有可靠的中文别名解析，因此用一张**有边界**的表桥接。
///
/// ## 维护约定
///
/// 1. 只收录「中文译名与本地名不同形」的城市。上海、北京、台北这类本身
///    就能命中的城市不收录，否则显示名会从中文变成当地语言。
///    东京是边界情况：繁体「東京」能命中「東京都」，简体「东京」只命中
///    境内同名城镇；因收录会把显示名改成 Tokyo，暂不收录。
/// 2. `query` 必须是该城市在 OSM 中的正式名称，且能在数据源里命中。
/// 3. 表外查询不受影响，仍走「CJK 优先 Photon」流程。
/// 4. 新增条目前用真实请求验证一次，避免「表里正确、线上错误」。
///
/// ## 验证方式
///
/// 桥接链路要求结果满足「国家码相同 + 名称等于 `query`」，因此每条可用
/// 一次请求自查：
///
/// ```
/// https://geocoding-api.open-meteo.com/v1/search
///   ?name=New%20York&count=30&language=en&format=json
/// ```
///
/// 返回中应存在 `country_code == 国家码` 且 `name == query` 的记录。
/// 名称对不上说明 `query` 写的是简称（`Frankfurt`、`Washington` 都会
/// 落到同国的小村镇），应改用正式名 `Frankfurt am Main` / `Washington D.C.`。
const Map<String, CjkCityAlias> kCjkCityAliases = <String, CjkCityAlias>{
  // ---- 北美 ----
  '纽约': CjkCityAlias(query: 'New York', countryCode: 'US'),
  '紐約': CjkCityAlias(query: 'New York', countryCode: 'US'),
  '旧金山': CjkCityAlias(query: 'San Francisco', countryCode: 'US'),
  '舊金山': CjkCityAlias(query: 'San Francisco', countryCode: 'US'),
  '洛杉矶': CjkCityAlias(query: 'Los Angeles', countryCode: 'US'),
  '洛杉磯': CjkCityAlias(query: 'Los Angeles', countryCode: 'US'),
  '西雅图': CjkCityAlias(query: 'Seattle', countryCode: 'US'),
  '芝加哥': CjkCityAlias(query: 'Chicago', countryCode: 'US'),
  '波士顿': CjkCityAlias(query: 'Boston', countryCode: 'US'),
  // 只写 `Washington` 会命中多个同名小镇（API 首条是宾州的 Washington），
  // D.C. 在数据源里的正式名带后缀，必须写全。
  '华盛顿': CjkCityAlias(query: 'Washington D.C.', countryCode: 'US'),
  '拉斯维加斯': CjkCityAlias(query: 'Las Vegas', countryCode: 'US'),
  '檀香山': CjkCityAlias(query: 'Honolulu', countryCode: 'US'),
  '多伦多': CjkCityAlias(query: 'Toronto', countryCode: 'CA'),
  '温哥华': CjkCityAlias(query: 'Vancouver', countryCode: 'CA'),

  // ---- 欧洲 ----
  '伦敦': CjkCityAlias(query: 'London', countryCode: 'GB'),
  '倫敦': CjkCityAlias(query: 'London', countryCode: 'GB'),
  '都柏林': CjkCityAlias(query: 'Dublin', countryCode: 'IE'),
  '巴黎': CjkCityAlias(query: 'Paris', countryCode: 'FR'),
  '柏林': CjkCityAlias(query: 'Berlin', countryCode: 'DE'),
  '慕尼黑': CjkCityAlias(query: 'Munich', countryCode: 'DE'),
  // 同 华盛顿：`Frankfurt` 命中的是巴伐利亚的小镇，
  // 美因河畔法兰克福的正式名是 `Frankfurt am Main`。
  '法兰克福': CjkCityAlias(query: 'Frankfurt am Main', countryCode: 'DE'),
  '罗马': CjkCityAlias(query: 'Rome', countryCode: 'IT'),
  '羅馬': CjkCityAlias(query: 'Rome', countryCode: 'IT'),
  '米兰': CjkCityAlias(query: 'Milan', countryCode: 'IT'),
  '威尼斯': CjkCityAlias(query: 'Venice', countryCode: 'IT'),
  '苏黎世': CjkCityAlias(query: 'Zurich', countryCode: 'CH'),
  '阿姆斯特丹': CjkCityAlias(query: 'Amsterdam', countryCode: 'NL'),
  '巴塞罗那': CjkCityAlias(query: 'Barcelona', countryCode: 'ES'),
  '马德里': CjkCityAlias(query: 'Madrid', countryCode: 'ES'),
  '里斯本': CjkCityAlias(query: 'Lisbon', countryCode: 'PT'),
  '维也纳': CjkCityAlias(query: 'Vienna', countryCode: 'AT'),
  '布拉格': CjkCityAlias(query: 'Prague', countryCode: 'CZ'),
  '斯德哥尔摩': CjkCityAlias(query: 'Stockholm', countryCode: 'SE'),
  '奥斯陆': CjkCityAlias(query: 'Oslo', countryCode: 'NO'),
  '哥本哈根': CjkCityAlias(query: 'Copenhagen', countryCode: 'DK'),
  '赫尔辛基': CjkCityAlias(query: 'Helsinki', countryCode: 'FI'),
  '雅典': CjkCityAlias(query: 'Athens', countryCode: 'GR'),
  '伊斯坦布尔': CjkCityAlias(query: 'Istanbul', countryCode: 'TR'),
  '莫斯科': CjkCityAlias(query: 'Moscow', countryCode: 'RU'),

  // ---- 亚洲 ----
  '首尔': CjkCityAlias(query: 'Seoul', countryCode: 'KR'),
  '首爾': CjkCityAlias(query: 'Seoul', countryCode: 'KR'),
  '釜山': CjkCityAlias(query: 'Busan', countryCode: 'KR'),
  '新加坡': CjkCityAlias(query: 'Singapore', countryCode: 'SG'),
  '曼谷': CjkCityAlias(query: 'Bangkok', countryCode: 'TH'),
  '吉隆坡': CjkCityAlias(query: 'Kuala Lumpur', countryCode: 'MY'),
  '雅加达': CjkCityAlias(query: 'Jakarta', countryCode: 'ID'),
  '马尼拉': CjkCityAlias(query: 'Manila', countryCode: 'PH'),
  '新德里': CjkCityAlias(query: 'New Delhi', countryCode: 'IN'),
  '孟买': CjkCityAlias(query: 'Mumbai', countryCode: 'IN'),
  '迪拜': CjkCityAlias(query: 'Dubai', countryCode: 'AE'),

  // ---- 大洋洲 / 非洲 ----
  '悉尼': CjkCityAlias(query: 'Sydney', countryCode: 'AU'),
  '墨尔本': CjkCityAlias(query: 'Melbourne', countryCode: 'AU'),
  '奥克兰': CjkCityAlias(query: 'Auckland', countryCode: 'NZ'),
  '开罗': CjkCityAlias(query: 'Cairo', countryCode: 'EG'),
};

/// 查表时统一 trim，避免用户输入带空格导致命中失败。
CjkCityAlias? cityAliasFor(String query) => kCjkCityAliases[query.trim()];
