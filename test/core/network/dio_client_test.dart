import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/network/dio_client.dart';
import 'package:weather/core/network/http_log_interceptor.dart';

void main() {
  test('非 release 构建会挂载网络日志拦截器，且排在重试之前', () {
    final dio = createDio();

    // 测试环境 kReleaseMode 为 false，等价于 debug/profile 运行的配置。
    expect(kReleaseMode, isFalse);

    final loggerIndex = dio.interceptors.indexWhere(
      (dynamic interceptor) => interceptor is HttpLogInterceptor,
    );
    final retryIndex = dio.interceptors.indexWhere(
      (dynamic interceptor) => interceptor is RetryInterceptor,
    );

    expect(loggerIndex, isNot(-1), reason: '没有日志拦截器就什么都看不到');
    expect(retryIndex, isNot(-1));
    expect(loggerIndex, lessThan(retryIndex), reason: '重试的请求也要经过日志');
  });
}
