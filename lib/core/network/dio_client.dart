import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'http_log_interceptor.dart';

/// 集中创建 Dio 实例。
///
/// 拦截器顺序很重要：日志 → 重试。重试放在最后，确保只对最终失败的
/// 请求做过一次重试决策。
Dio createDio({String? baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );

  // debug / profile 下输出结构化请求 / 响应日志（`flutter run --profile`
  // 排查性能时同样需要）；release 包不挂载，避免把请求参数写进日志。
  if (!kReleaseMode) {
    dio.interceptors.add(HttpLogInterceptor());
  }

  dio.interceptors.add(RetryInterceptor(dio: dio));
  return dio;
}

/// 对可重试失败做有限次指数退避重试。
///
/// 重试策略：
/// - 网络/超时：最多 2 次总尝试
/// - 5xx：最多 3 次总尝试
/// - 429：最多 2 次总尝试，优先遵循 `Retry-After`
/// - 其余 4xx：不重试
class RetryInterceptor extends Interceptor {
  RetryInterceptor({required this.dio});

  final Dio dio;

  static const String _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 1;
    final maxAttempts = _maxAttemptsFor(err);

    if (!_isRetryable(err) || attempt >= maxAttempts) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_delayFor(err, attempt));

    final options = err.requestOptions;
    options.extra = <String, dynamic>{
      ...options.extra,
      _attemptKey: attempt + 1,
    };

    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status == 429 || status >= 500;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  int _maxAttemptsFor(DioException err) {
    final status = err.response?.statusCode;
    if (status != null && status >= 500) return 3;
    return 2;
  }

  Duration _delayFor(DioException err, int attempt) {
    if (err.response?.statusCode == 429) {
      final retryAfter = err.response?.headers.value('retry-after');
      final seconds = int.tryParse(retryAfter ?? '');
      if (seconds != null) return Duration(seconds: seconds.clamp(0, 5));
    }
    final millis = 500 * (1 << (attempt - 1));
    return Duration(milliseconds: millis.clamp(500, 2000));
  }
}
