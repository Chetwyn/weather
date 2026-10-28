import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/domain/location.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/request_token.dart';
import '../dto/weather_dto.dart';

abstract interface class WeatherRemoteDataSource {
  Future<WeatherDto> fetch({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  });
}

/// Open-Meteo Forecast API 实现。
///
/// 一次请求取回当前天气、逐小时与逐日预报，减少往返次数。
class OpenMeteoWeatherDataSource implements WeatherRemoteDataSource {
  OpenMeteoWeatherDataSource(this._dio);

  final Dio _dio;

  static const String _currentFields =
      'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,'
      'precipitation,weather_code,surface_pressure,'
      'wind_speed_10m,wind_direction_10m';

  static const String _hourlyFields =
      'temperature_2m,weather_code,precipitation_probability';

  static const String _dailyFields =
      'weather_code,temperature_2m_max,temperature_2m_min,'
      'precipitation_probability_max,sunrise,sunset,'
      'wind_speed_10m_max,uv_index_max';

  @override
  Future<WeatherDto> fetch({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) async {
    final dioCancelToken = CancelToken();
    cancelToken?.onCancel(dioCancelToken.cancel);

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConfig.forecastBaseUrl}/forecast',
        queryParameters: <String, dynamic>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          'current': _currentFields,
          'hourly': _hourlyFields,
          'daily': _dailyFields,
          'timezone': 'auto', // 返回地点本地时间
          'forecast_days': AppConfig.forecastDays,
          'temperature_unit': units.apiTemperatureUnit,
          'wind_speed_unit': units.apiWindSpeedUnit,
          'precipitation_unit': units.apiPrecipitationUnit,
        },
        cancelToken: dioCancelToken,
      );

      final data = response.data;
      if (data == null) {
        throw const ParseFailure(cause: '天气接口返回空响应体');
      }
      return WeatherDto.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on FormatException catch (error) {
      throw ParseFailure(cause: error);
    } on TypeError catch (error) {
      throw ParseFailure(cause: error);
    }
  }
}
