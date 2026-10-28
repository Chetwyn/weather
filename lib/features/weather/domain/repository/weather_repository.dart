import '../../../../core/domain/location.dart';
import '../../../../core/utils/request_token.dart';
import '../entity/weather.dart';

/// 天气数据的领域接口。
///
/// 上层不感知具体供应商：替换天气服务只需新增一个实现，
/// `domain` 与 `presentation` 零改动。
abstract interface class WeatherRepository {
  /// 失败时抛出 `Failure`。
  Future<Weather> getWeather({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  });
}
