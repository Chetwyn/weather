import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 网络请求 / 响应日志。
///
/// 没有使用 Dio 自带的 [LogInterceptor]，原因是：
/// - 它把整个响应体塞进一行 `debugPrint`，长 JSON 会被拆成难以阅读的碎片；
/// - 不记录每个请求的耗时；
/// - 会原样打印 `Authorization` / `Cookie` 这类头。
///
/// 这里按「一个请求一块」输出：方法 + URL、缩进后的请求体、状态码 + 耗时、
/// 缩进后的响应体；超长内容截断，敏感头打码。
///
/// 只在非 release 构建下由 [createDio] 挂载（debug 与 profile），
/// release 包不会调用。
class HttpLogInterceptor extends Interceptor {
  HttpLogInterceptor({this.maxLength = 4000, this.print = _defaultPrint});

  /// 单条日志最多输出多少字符，避免大响应把控制台刷没。
  final int maxLength;

  /// 输出通道，测试中可替换为收集器。
  final void Function(String message) print;

  /// 请求发出时间存在 `extra` 里，响应回来时算差值。
  static const String _startedAtKey = 'http_log_started_at';

  static const Set<String> _sensitiveHeaders = <String>{
    'authorization',
    'cookie',
    'set-cookie',
  };

  /// 用 [debugPrint] 而不是 `dart:developer` 的 `log()`：
  /// 后者只把消息发到 VM service，`flutter run` 的控制台默认看不到，
  /// 表现就是「日志明明写了却一条都没打印」。
  static void _defaultPrint(String message) => debugPrint('[HTTP] $message');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();

    final buffer = StringBuffer()
      ..writeln('→ ${options.method} ${options.uri}');
    if (options.headers.isNotEmpty) {
      buffer.writeln('  headers: ${_maskHeaders(options.headers)}');
    }
    if (options.data != null) {
      buffer.writeln('  body: ${_format(options.data)}');
    }

    _emit(buffer);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final buffer = StringBuffer()
      ..writeln(
        '← ${response.statusCode} ${response.requestOptions.uri}'
        '${_elapsed(response.requestOptions)}',
      );
    if (response.data != null) {
      buffer.writeln('  body: ${_format(response.data)}');
    }

    _emit(buffer);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final buffer = StringBuffer()
      ..writeln(
        '✗ ${err.type.name} ${err.requestOptions.uri}'
        '${_elapsed(err.requestOptions)}',
      )
      ..writeln('  ${err.message ?? '未知错误'}');

    final response = err.response;
    if (response != null) {
      buffer.writeln('  status: ${response.statusCode}');
      if (response.data != null) {
        buffer.writeln('  body: ${_format(response.data)}');
      }
    }

    _emit(buffer);
    handler.next(err);
  }

  void _emit(StringBuffer buffer) {
    var text = buffer.toString().trimRight();
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength)}\n  …（已截断）';
    }
    print(text);
  }

  String _elapsed(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! DateTime) return '';
    return ' (${DateTime.now().difference(startedAt).inMilliseconds} ms)';
  }

  /// JSON 尽量缩进展示；解析不了就按原样输出。
  String _format(Object? data) {
    if (data == null) return '-';

    if (data is String) {
      final decoded = _decode(data);
      return decoded ?? _truncate(data);
    }

    try {
      return _truncate(const JsonEncoder.withIndent('  ').convert(data));
    } on Object {
      return _truncate(data.toString());
    }
  }

  String? _decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return _truncate(
        const JsonEncoder.withIndent('  ').convert(jsonDecode(raw)),
      );
    } on FormatException {
      return null;
    }
  }

  /// body 自身的截断阈值比整条日志小一半，给请求行和 head 留出空间。
  String _truncate(String value) {
    final limit = maxLength ~/ 2;
    if (value.length <= limit) return value;
    return '${value.substring(0, limit)}…（body 已截断）';
  }

  Map<String, Object?> _maskHeaders(Map<String, dynamic> headers) {
    return <String, Object?>{
      for (final MapEntry<String, dynamic> entry in headers.entries)
        entry.key: _sensitiveHeaders.contains(entry.key.toLowerCase())
            ? '***'
            : entry.value,
    };
  }
}
