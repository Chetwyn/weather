import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/network/http_log_interceptor.dart';

/// 不起真实网络：直接返回预置响应体。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    this.body = '{"ok":true}',
    this.statusCode = 200,
    this.contentType = 'application/json',
  });

  final String body;
  final int statusCode;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createDio(_FakeAdapter adapter, List<String> logs, {int? maxLength}) {
  return Dio(BaseOptions(baseUrl: 'https://example.com'))
    ..httpClientAdapter = adapter
    ..interceptors.add(
      HttpLogInterceptor(print: logs.add, maxLength: maxLength ?? 4000),
    );
}

void main() {
  test('打印请求行、响应状态码与耗时，响应 JSON 自动缩进', () async {
    final logs = <String>[];

    await _createDio(_FakeAdapter(), logs).get<dynamic>(
      '/v1/forecast',
      queryParameters: <String, dynamic>{'latitude': 25.0},
    );

    final output = logs.join('\n');
    expect(
      output,
      contains('→ GET https://example.com/v1/forecast?latitude=25.0'),
    );
    expect(output, contains('← 200 https://example.com/v1/forecast'));
    expect(output, matches(RegExp(r'\(\d+ ms\)')));
    expect(output, contains('"ok": true'));
  });

  test('失败响应打印错误类型、状态码与响应体', () async {
    final logs = <String>[];

    await expectLater(
      _createDio(
        _FakeAdapter(body: '{"error":"boom"}', statusCode: 500),
        logs,
      ).get<dynamic>('/v1/forecast'),
      throwsA(isA<DioException>()),
    );

    final output = logs.join('\n');
    expect(output, contains('✗ badResponse'));
    expect(output, contains('status: 500'));
    expect(output, contains('"error": "boom"'));
  });

  test('敏感请求头被打码', () async {
    final logs = <String>[];

    await _createDio(_FakeAdapter(), logs).get<dynamic>(
      '/v1/forecast',
      options: Options(
        headers: <String, dynamic>{'Authorization': 'Bearer secret-token'},
      ),
    );

    final output = logs.join('\n');
    expect(output, contains('Authorization: ***'));
    expect(output, isNot(contains('secret-token')));
  });

  test('超长响应体被截断，不会刷屏', () async {
    final logs = <String>[];
    final longBody = 'x' * 2000;

    await _createDio(
      _FakeAdapter(body: longBody, contentType: 'text/plain'),
      logs,
      maxLength: 200,
    ).get<dynamic>('/v1/forecast');

    final output = logs.join('\n');
    expect(output, contains('截断'));
    expect(output.length, lessThan(longBody.length));
  });
}
