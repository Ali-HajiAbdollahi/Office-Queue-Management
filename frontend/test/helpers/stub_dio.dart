import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef StubHandler = Future<ResponseBody> Function(RequestOptions options);

/// Fake adapter: answers without network calls and records the requests.
class StubAdapter implements HttpClientAdapter {
  final StubHandler handler;
  final List<RequestOptions> requests = [];

  StubAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// JSON response with the given status.
ResponseBody jsonResponse(Object? body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Dio wired to a [StubAdapter]; the adapter is returned to inspect the requests.
(Dio, StubAdapter) stubDio(StubHandler handler, {String baseUrl = 'http://test'}) {
  final adapter = StubAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
  return (dio, adapter);
}

/// HTTP error as Dio throws it for a response with the given status.
DioException httpError(int status) {
  final options = RequestOptions(path: '/');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
    type: DioExceptionType.badResponse,
  );
}
