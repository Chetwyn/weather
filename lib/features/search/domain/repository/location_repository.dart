import '../../../../core/domain/location.dart';
import '../../../../core/utils/request_token.dart';

/// 地点搜索的领域接口。
///
/// presentation 层只依赖此接口；具体实现（Open-Meteo / 其他供应商）
/// 在 data 层，替换数据源不影响上层。
abstract interface class LocationRepository {
  /// 按关键词搜索地点。
  ///
  /// [cancelToken] 用于取消上一请求（用户继续输入时）。
  /// 失败时抛出 `Failure`。
  Future<List<Location>> search(String query, {RequestToken? cancelToken});
}
