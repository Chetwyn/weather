/// 全局配置常量集中处。
///
/// 目的：消除散落在各处的「魔法数字」，让超时、防抖、预报天数等
/// 可调参数只有唯一修改点。
class AppConfig {
  const AppConfig._();

  // ---------- 网络 ----------
  static const String geocodingBaseUrl =
      'https://geocoding-api.open-meteo.com/v1';
  static const String forecastBaseUrl = 'https://api.open-meteo.com/v1';

  /// 备用地理编码（支持 CJK）。Open-Meteo 的索引以拉丁字母为主，
  /// 中文关键词常常搜不到，因此加一层基于 OpenStreetMap 的 Photon。
  static const String photonBaseUrl = 'https://photon.komoot.io';

  /// 公开地理编码服务要求携带可识别的 User-Agent。
  static const String userAgent = 'weather-app/1.0 (Flutter take-home)';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);

  // ---------- 搜索 ----------
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const int minQueryLength = 2;
  static const int searchResultLimit = 10;
  static const int maxRecentSearches = 5;

  // ---------- 天气 ----------
  static const int forecastDays = 7;
  static const int hourlyHours = 24;

  // ---------- 缓存 ----------
  /// 天气数据被视为「新鲜」的时长。缓存键 = (lat, lon, units)。
  static const Duration cacheFreshness = Duration(minutes: 10);

  // ---------- 定位 ----------
  static const Duration locationTimeout = Duration(seconds: 12);

  // ---------- UI ----------
  /// 加载态延迟展示时间，避免 200ms 内完成的请求造成骨架屏闪烁。
  static const Duration skeletonDelay = Duration(milliseconds: 200);
}
