import '../../../../core/domain/location.dart';
import '../../../../core/error/failure.dart';
import '../location_service.dart';
import '../repository/reverse_geocoder.dart';

/// 设备坐标 → 可展示的 [Location]。
///
/// 领域规则：
/// - 定位本身失败（无权限 / 服务关闭）时**向上抛**，由 UI 决定提示方式；
/// - 定位成功但反查地名失败时**不当作错误**：用「当前位置」兜底，
///   天气查询只需要经纬度，没必要因为拿不到城市名就让功能不可用。
class ResolveCurrentLocationUseCase {
  const ResolveCurrentLocationUseCase(
    this._locationService,
    this._reverseGeocoder,
  );

  final LocationService _locationService;
  final ReverseGeocoder _reverseGeocoder;

  /// 「当前位置」使用固定 ID，便于在缓存与最近搜索里去重。
  static const int currentLocationId = Location.currentLocationId;

  /// 占位地名。展示层会用当前语言重新渲染（见 `Location.isCurrentLocation`），
  /// 这里只是让缓存与最近搜索里有一个可读的兜底值。
  static const String _currentLocationName = '当前位置';

  Future<Location> call() async {
    final position = await _locationService.currentPosition();

    Location? named;
    try {
      named = await _reverseGeocoder.reverse(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Failure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      named = null;
    }

    return named ??
        Location(
          id: currentLocationId,
          name: _currentLocationName,
          latitude: position.latitude,
          longitude: position.longitude,
          timezone: 'auto',
        );
  }
}
