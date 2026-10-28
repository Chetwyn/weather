import '../../../../core/domain/location.dart';
import '../../../../core/utils/request_token.dart';
import '../../domain/repository/location_repository.dart';
import '../datasource/geocoding_remote_data_source.dart';

/// Repository 实现：职责边界很窄——组合数据源 + DTO→Entity 映射。
///
/// 刻意不在这里做 try/catch：错误已在 DataSource 层映射为 `Failure`，
/// 再包一层只会产生重复逻辑。
class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._remoteDataSource);

  final GeocodingRemoteDataSource _remoteDataSource;

  @override
  Future<List<Location>> search(
    String query, {
    RequestToken? cancelToken,
  }) async {
    final dtos = await _remoteDataSource.search(
      query,
      cancelToken: cancelToken,
    );
    return dtos.map((dto) => dto.toEntity()).toList(growable: false);
  }
}
