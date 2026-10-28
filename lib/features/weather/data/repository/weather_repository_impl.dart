import '../../../../core/domain/location.dart';
import '../../../../core/utils/request_token.dart';
import '../../domain/entity/weather.dart';
import '../../domain/repository/weather_repository.dart';
import '../datasource/weather_remote_data_source.dart';
import '../mapper/weather_mapper.dart';

/// 组合远程数据源，并把 DTO 转换为领域实体。
///
/// 未来若要加本地缓存，只需在此组合一个新的 DataSource，domain 与
/// presentation 不受影响——这正是保留 Repository 抽象的价值。
class WeatherRepositoryImpl implements WeatherRepository {
  WeatherRepositoryImpl(this._remoteDataSource);

  final WeatherRemoteDataSource _remoteDataSource;

  @override
  Future<Weather> getWeather({
    required Location location,
    required UnitSystem units,
    RequestToken? cancelToken,
  }) async {
    final dto = await _remoteDataSource.fetch(
      location: location,
      units: units,
      cancelToken: cancelToken,
    );
    return WeatherMapper.toEntity(dto, location, units);
  }
}
