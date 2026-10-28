import '../../../../core/config/app_config.dart';
import '../../../../core/domain/location.dart';
import '../../domain/entity/weather.dart';

class _CacheEntry {
  const _CacheEntry(this.weather, this.storedAt);

  final Weather weather;
  final DateTime storedAt;
}

/// 进程内天气缓存。
///
/// 天气数据时效性短，用内存缓存即可满足「切回刚看过的城市不重复请求」，
/// 无需引入持久化存储依赖。
///
/// 缓存键 = (纬度, 经度, 单位制)。把单位制放进键里，避免切换公制/英制后
/// 命中旧单位的数据。
class WeatherMemoryCache {
  WeatherMemoryCache({Duration? freshness})
    : _freshness = freshness ?? AppConfig.cacheFreshness;

  final Duration _freshness;
  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};

  static String keyOf(Location location, UnitSystem units) =>
      '${location.latitude},${location.longitude},${units.name}';

  Weather? read(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > _freshness) {
      _entries.remove(key);
      return null;
    }
    return entry.weather;
  }

  void write(String key, Weather weather) {
    _entries[key] = _CacheEntry(weather, DateTime.now());
  }

  void clear() => _entries.clear();

  int get size => _entries.length;
}
