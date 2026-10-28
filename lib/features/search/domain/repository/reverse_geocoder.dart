import '../../../../core/domain/location.dart';
import '../../../../core/utils/request_token.dart';

/// 坐标 → 地点（逆地理编码）。
///
/// 「使用当前位置」需要把设备坐标变成一个可展示、可缓存的 [Location]；
/// 定位本身是平台能力，把它变成地点属于 search 的职责。
abstract interface class ReverseGeocoder {
  /// 解析失败返回 null（调用方用「当前位置」兜底），网络异常抛 `Failure`。
  Future<Location?> reverse({
    required double latitude,
    required double longitude,
    RequestToken? cancelToken,
  });
}
