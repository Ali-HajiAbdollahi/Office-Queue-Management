import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/data/datasources/remote_counter_officer_data_source.dart';
import 'package:frontend/features/counter_officer/domain/entities/ticket.dart';

/// Adapter finto: risponde senza fare chiamate di rete.
class _StubAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  _StubAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

RemoteCounterOfficerDataSource _build(
  Future<ResponseBody> Function(RequestOptions) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
    ..httpClientAdapter = _StubAdapter(handler);
  return RemoteCounterOfficerDataSource(dio);
}

const _services = '[{"id":1,"tag":"General Inquiries","service_time":5}]';

void main() {
  test('call-next con 404 restituisce null (coda vuota)', () async {
    final ds = _build((o) async {
      if (o.path == '/services') return _json(_services, 200);
      return _json('{"error":"not found"}', 404);
    });

    expect(await ds.callNextTicket('2'), isNull);
  });

  test('call-next con 200 mappa il ticket e il tipo di servizio', () async {
    final ds = _build((o) async {
      if (o.path == '/services') return _json(_services, 200);
      return _json(
        '{"id":3,"code":"A002","service_id":1,"status":"called",'
        '"issued_at":"2026-10-10T12:00:00.000Z",'
        '"served_at":"2026-10-10T12:05:00.000Z","counter_id":2}',
        200,
      );
    });

    final ticket = await ds.callNextTicket('2');

    expect(ticket?.code, 'A002');
    expect(ticket?.serviceType, 'General Inquiries');
    expect(ticket?.status, TicketStatus.serving);
    expect(await ds.watchCurrentTicket('2').first, isNotNull);
  });

  test('call-next con 500 lancia un errore', () async {
    final ds = _build((o) async {
      if (o.path == '/services') return _json(_services, 200);
      return _json('{"error":"boom"}', 500);
    });

    expect(() => ds.callNextTicket('2'), throwsA(isA<DioException>()));
  });

  // Queue statistics are hidden for this sprint.
  // test('queue-stats viene mappato in QueueSummary', () async {
  //   final ds = _build((o) async => _json(
  //         '{"waiting_count":4,"avg_wait_time":6,"next_ticket_code":"A-142"}',
  //         200,
  //       ));
  //
  //   final queue = await ds.watchQueue('2').first;
  //
  //   expect(queue.waitingCount, 4);
  //   expect(queue.nextTicketCode, 'A-142');
  // });
}
