import '../../../../core/domain/location.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/request_token.dart';
import '../entity/weather.dart';
import '../repository/weather_repository.dart';

/// 获取天气的业务入口。
///
/// 这里承载一条真正的领域规则：**没有任何逐日预报的数据视为不完整**，
/// 直接视为解析失败，避免 UI 渲染出一个空列表的"成功"页面。
class GetWeatherUseCase {
  const GetWeatherUseCase(this._repository);

  final WeatherRepository _repository;

  Future<Weather> call({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) async {
    final weather = await _repository.getWeather(
      location: location,
      units: units,
      cancelToken: cancelToken,
    );

    if (weather.daily.isEmpty) {
      throw const ParseFailure();
    }
    return weather;
  }
}
