import 'dart:io';

import 'package:dio/dio.dart';

import 'failure.dart';

/// 把任意异常统一映射为 [Failure]。
///
/// 这是「错误处理只在一处发生」的落点：DataSource / Repository 不做
/// try-catch 分支判断，UI 层也只认 [Failure]。
Failure mapError(Object error) {
  if (error is Failure) return error;
  if (error is DioException) return mapDioException(error);
  if (error is FormatException || error is TypeError) {
    return ParseFailure(cause: error);
  }
  return UnknownFailure(cause: error);
}

Failure mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return TimeoutFailure(cause: error.error);
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return NetworkFailure(cause: error.error);
    case DioExceptionType.cancel:
      return CancelledFailure(cause: error.error);
    case DioExceptionType.badResponse:
      return _mapStatusCode(error);
    case DioExceptionType.unknown:
      if (error.error is SocketException) {
        return NetworkFailure(cause: error.error);
      }
      return UnknownFailure(cause: error.error);
  }
}

Failure _mapStatusCode(DioException error) {
  final status = error.response?.statusCode;
  if (status == null) return UnknownFailure(cause: error.error);
  if (status == 429) {
    return RateLimitFailure(cause: error.error, statusCode: status);
  }
  if (status == 404) {
    return NotFoundFailure(cause: error.error, statusCode: status);
  }
  if (status >= 500) {
    return ServerFailure(cause: error.error, statusCode: status);
  }
  return ClientFailure(cause: error.error, statusCode: status);
}
