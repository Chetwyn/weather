import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/domain/location.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/request_token.dart';
import '../../domain/repository/reverse_geocoder.dart';
import '../dto/location_dto.dart';
import '../dto/photon_feature_dto.dart';
import 'geocoding_remote_data_source.dart';

/// Photon（基于 OpenStreetMap）实现。
///
/// 存在的理由：Open-Meteo 的地理编码索引以拉丁字母为主，中文关键词
/// （如「台北」）直接返回空。Photon 索引了 OSM 的本地名称，能召回中文，
/// 因此作为中文查询的首选源、拉丁字母查询的兜底源。
///
/// 同一个类同时实现 [ReverseGeocoder]：它的 `/reverse` 端点把坐标
/// 解析成地名，供「使用当前位置」展示城市名。
class PhotonGeocodingDataSource
    implements GeocodingRemoteDataSource, ReverseGeocoder {
  PhotonGeocodingDataSource(this._dio);

  final Dio _dio;

  /// Photon 没有 API Key，但要求可识别的 User-Agent。
  static final Options _options = Options(
    headers: <String, dynamic>{'User-Agent': AppConfig.userAgent},
  );

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
        '${AppConfig.photonBaseUrl}/api/',
        queryParameters: <String, dynamic>{
          'q': query,
          // 多取一些再排序，避免 POI 挤掉行政区。
          'limit': limit * 3,
        },
        options: _options,
        cancelToken: dioCancelToken,
      );

      final features = response.data?['features'];
      if (features is! List) return const <LocationDto>[];

      final parsed = <({PhotonFeatureDto dto, int index})>[];
      for (var index = 0; index < features.length; index++) {
        final dto = PhotonFeatureDto.tryFromJson(features[index]);
        if (dto != null) parsed.add((dto: dto, index: index));
      }

      // 稳定排序：先按地点类型权重，再按原始相关度顺序。
      parsed.sort((a, b) {
        final byPriority = b.dto.typePriority.compareTo(a.dto.typePriority);
        return byPriority != 0 ? byPriority : a.index.compareTo(b.index);
      });

      return parsed
          .take(limit)
          .map((entry) => entry.dto.toLocationDto())
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on FormatException catch (error) {
      throw ParseFailure(cause: error);
    } on TypeError catch (error) {
      throw ParseFailure(cause: error);
    }
  }

  @override
  Future<Location?> reverse({
    required double latitude,
    required double longitude,
    RequestToken? cancelToken,
  }) async {
    final dioCancelToken = CancelToken();
    cancelToken?.onCancel(dioCancelToken.cancel);

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConfig.photonBaseUrl}/reverse',
        queryParameters: <String, dynamic>{'lat': latitude, 'lon': longitude},
        options: _options,
        cancelToken: dioCancelToken,
      );

      final features = response.data?['features'];
      if (features is! List || features.isEmpty) return null;

      final feature = PhotonFeatureDto.tryFromJson(features.first);
      if (feature == null) return null;

      // 逆地理编码返回的往往是门牌级 POI；主名取城市级、副名取区/街道，
      // 具体层级选择逻辑见 PhotonFeatureDto.primaryName / areaName。
      return feature.toReverseLocation(
        latitude: latitude,
        longitude: longitude,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on FormatException catch (error) {
      throw ParseFailure(cause: error);
    }
  }
}
