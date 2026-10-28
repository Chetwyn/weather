/// 领域层统一错误类型树。
///
/// 设计意图：
/// - UI 层只消费 [Failure]，不出现 `DioException` / `SocketException` 分支；
/// - 文案（[displayMessage]）与可重试性（[canRetry]）集中在错误类型自身，
///   修正文案时只需改这一个文件；
/// - [cause] 保留原始异常，仅用于日志，永不展示给用户。
sealed class Failure implements Exception {
  const Failure({this.cause, this.statusCode});

  /// 原始异常，仅用于日志排查。
  final Object? cause;

  /// HTTP 状态码（如适用）。
  final int? statusCode;

  /// 面向用户的中文文案。
  String get displayMessage;

  /// 是否允许（自动或手动）重试。
  bool get canRetry;

  /// 稳定的类型标识，用于日志与测试断言。
  String get code;

  @override
  String toString() =>
      'Failure($code, statusCode: $statusCode, cause: ${cause ?? '-'})';
}

/// 设备离线 / DNS 解析失败 / 连接被拒。
final class NetworkFailure extends Failure {
  const NetworkFailure({super.cause});

  @override
  String get code => 'network';

  @override
  String get displayMessage => '网络连接不可用，请检查网络后重试';

  @override
  bool get canRetry => true;
}

/// 连接 / 发送 / 接收超时。
final class TimeoutFailure extends Failure {
  const TimeoutFailure({super.cause});

  @override
  String get code => 'timeout';

  @override
  String get displayMessage => '请求超时，请稍后重试';

  @override
  bool get canRetry => true;
}

/// 服务端 5xx。
final class ServerFailure extends Failure {
  const ServerFailure({super.cause, super.statusCode});

  @override
  String get code => 'server';

  @override
  String get displayMessage => '天气服务暂时不可用，请稍后再试';

  @override
  bool get canRetry => true;
}

/// HTTP 429，触发限流。
final class RateLimitFailure extends Failure {
  const RateLimitFailure({super.cause, super.statusCode = 429});

  @override
  String get code => 'rate_limit';

  @override
  String get displayMessage => '查询过于频繁，请稍后再试';

  @override
  bool get canRetry => true;
}

/// 其余 4xx，请求本身有问题，重试无意义。
final class ClientFailure extends Failure {
  const ClientFailure({super.cause, super.statusCode});

  @override
  String get code => 'client';

  @override
  String get displayMessage => '请求参数有误，请稍后重试';

  @override
  bool get canRetry => false;
}

/// 资源不存在（如天气数据覆盖范围外的坐标）。
final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.cause, super.statusCode = 404});

  @override
  String get code => 'not_found';

  @override
  String get displayMessage => '该地点暂无天气数据';

  @override
  bool get canRetry => false;
}

/// JSON 结构变更、字段缺失或类型不符。
final class ParseFailure extends Failure {
  const ParseFailure({super.cause});

  @override
  String get code => 'parse';

  @override
  String get displayMessage => '数据解析异常，请稍后重试';

  @override
  bool get canRetry => false;
}

/// 请求被主动取消（用户修改了搜索词）。属于正常流程，不展示给用户。
final class CancelledFailure extends Failure {
  const CancelledFailure({super.cause});

  @override
  String get code => 'cancelled';

  @override
  String get displayMessage => '';

  @override
  bool get canRetry => false;
}

/// 兜底。
final class UnknownFailure extends Failure {
  const UnknownFailure({super.cause, super.statusCode});

  @override
  String get code => 'unknown';

  @override
  String get displayMessage => '加载失败，请重试';

  @override
  bool get canRetry => true;
}

/// 用户拒绝或未授予定位权限。不是页面级错误，由调用方决定是否提示。
final class LocationPermissionFailure extends Failure {
  const LocationPermissionFailure({
    super.cause,
    this.permanentlyDenied = false,
  });

  /// 是否被「永久拒绝」（需要在系统设置里手动开启）。
  final bool permanentlyDenied;

  @override
  String get code => 'location_permission';

  @override
  String get displayMessage =>
      permanentlyDenied ? '定位权限已被拒绝，请在系统设置中开启，或直接搜索城市' : '未获得定位权限，可手动搜索城市';

  @override
  bool get canRetry => false;
}

/// 定位服务不可用（系统关闭定位、定位超时、硬件不可用）。
final class LocationUnavailableFailure extends Failure {
  const LocationUnavailableFailure({super.cause});

  @override
  String get code => 'location_unavailable';

  @override
  String get displayMessage => '暂时无法获取当前位置，请手动搜索城市';

  @override
  bool get canRetry => true;
}
