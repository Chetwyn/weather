import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/error/error_mapper.dart';
import 'package:weather/core/error/failure.dart';

void main() {
  final options = RequestOptions(path: '/forecast');

  DioException badResponse(int statusCode) => DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<void>(requestOptions: options, statusCode: statusCode),
  );

  group('HTTP 状态码映射', () {
    test('5xx → ServerFailure，可重试', () {
      final failure = mapDioException(badResponse(503));
      expect(failure, isA<ServerFailure>());
      expect(failure.canRetry, isTrue);
      expect(failure.statusCode, 503);
    });

    test('429 → RateLimitFailure', () {
      final failure = mapDioException(badResponse(429));
      expect(failure, isA<RateLimitFailure>());
      expect(failure.code, 'rate_limit');
    });

    test('404 → NotFoundFailure，不可重试', () {
      final failure = mapDioException(badResponse(404));
      expect(failure, isA<NotFoundFailure>());
      expect(failure.canRetry, isFalse);
    });

    test('其余 4xx → ClientFailure，不可重试', () {
      final failure = mapDioException(badResponse(400));
      expect(failure, isA<ClientFailure>());
      expect(failure.canRetry, isFalse);
    });
  });

  group('网络异常映射', () {
    test('连接超时 → TimeoutFailure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(failure, isA<TimeoutFailure>());
      expect(failure.canRetry, isTrue);
    });

    test('连接失败 → NetworkFailure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('unknown + SocketException → NetworkFailure', () {
      final failure = mapDioException(
        // 不传 type 时默认就是 unknown，模拟无法归类的底层异常。
        DioException(
          requestOptions: options,
          error: const SocketException('no route to host'),
        ),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('主动取消 → CancelledFailure，文案为空', () {
      final failure = mapDioException(
        DioException(requestOptions: options, type: DioExceptionType.cancel),
      );
      expect(failure, isA<CancelledFailure>());
      expect(failure.displayMessage, isEmpty);
    });
  });

  group('mapError 兜底', () {
    test('FormatException → ParseFailure', () {
      expect(mapError(const FormatException('bad')), isA<ParseFailure>());
    });

    test('未知异常 → UnknownFailure', () {
      expect(mapError(StateError('boom')), isA<UnknownFailure>());
    });

    test('已是 Failure 时原样返回，不重复包装', () {
      const failure = NetworkFailure();
      expect(mapError(failure), same(failure));
    });
  });
}
