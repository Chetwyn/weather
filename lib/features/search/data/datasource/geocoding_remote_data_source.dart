import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/request_token.dart';
import '../dto/location_dto.dart';

abstract interface class GeocodingRemoteDataSource {
  /// [language] 是「结果语言的偏好」，不是所有源都支持：
  /// Open-Meteo 按它返回本地化名称，Photon 只返回 OSM 里的本地名（忽略此参数）。
  ///
  /// 别名桥接需要它：查 `New York` 时若返回中文名，就没法用
  /// 「名称 == 查询词」来挑出目标城市（见 CompositeGeocodingDataSource）。
  Future<List<LocationDto>> search(
    String query, {
    RequestToken? cancelToken,
    int limit,
    String? language,
  });
}

/// Open-Meteo Geocoding API 实现（免 API Key，克隆仓库即可运行）。
class OpenMeteoGeocodingDataSource implements GeocodingRemoteDataSource {
  OpenMeteoGeocodingDataSource(this._dio);

  final Dio _dio;

  @override
  Future<List<LocationDto>> search(
    String query, {
    RequestToken? cancelToken,
    int limit = AppConfig.searchResultLimit,
    String? language,
  }) async {
    final dioCancelToken = CancelToken();
    cancelToken?.onCancel(dioCancelToken.cancel);

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConfig.geocodingBaseUrl}/search',
        queryParameters: <String, dynamic>{
          'name': query,
          'count': limit,
          'language': language ?? 'zh',
          'format': 'json',
        },
        cancelToken: dioCancelToken,
      );

      final results = response.data?['results'];
      if (results is! List) return const <LocationDto>[];

      return results
          .whereType<Map<String, dynamic>>()
          .map(LocationDto.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on FormatException catch (error) {
      throw ParseFailure(cause: error);
    } on TypeError catch (error) {
      throw ParseFailure(cause: error);
    }
  }
}
