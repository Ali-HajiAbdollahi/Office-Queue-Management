import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/data/datasources/remote_counter_officer_data_source.dart';

import '../../helpers/stub_dio.dart';

const _services = [
  {'id': 1, 'tag': 'Shipping', 'service_time': 5},
  {'id': 2, 'tag': 'Deposit', 'service_time': 8},
];

Map<String, dynamic> _calledTicket({int serviceId = 2}) => {
      'id': 3,
      'code': 'D-0001',
      'service_id': serviceId,
      'status': 'called',
      'issued_at': '2026-10-11T08:00:00.000Z',
      'served_at': '2026-10-11T08:05:00.000Z',
      'counter_id': 2,
    };

(RemoteCounterOfficerDataSource, StubAdapter) _build(StubHandler handler) {
  final (dio, adapter) = stubDio(handler, baseUrl: 'http://test/api');
  return (RemoteCounterOfficerDataSource(dio), adapter);
}

void main() {
  group('getCounters', () {
    test('reads the counters from GET /counters', () async {
      final (ds, adapter) = _build((_) async => jsonResponse([
            {'id': 1, 'name': 'Counter 1'},
            {'id': 2, 'name': 'Counter 2'},
          ]));

      final counters = await ds.getCounters();

      expect(adapter.requests.single.path, '/counters');
      expect(counters.map((c) => c.name), ['Counter 1', 'Counter 2']);
      expect(counters.map((c) => c.id), ['1', '2']);
    });

    test('a server error reaches the caller', () async {
      final (ds, _) = _build((_) async => jsonResponse({'error': 'boom'}, 500));
      expect(ds.getCounters(), throwsA(isA<DioException>()));
    });
  });

  group('callNextTicket', () {
    test('calls POST /counters/:id/call-next for the right counter', () async {
      final (ds, adapter) = _build((o) async =>
          o.path == '/services' ? jsonResponse(_services) : jsonResponse(_calledTicket()));

      await ds.callNextTicket('2');

      final call = adapter.requests.last;
      expect(call.method, 'POST');
      expect(call.path, '/counters/2/call-next');
    });

    test('an unknown service is shown as "Service <id>"', () async {
      final (ds, _) = _build((o) async =>
          o.path == '/services' ? jsonResponse(_services) : jsonResponse(_calledTicket(serviceId: 9)));

      expect((await ds.callNextTicket('2'))?.serviceType, 'Service 9');
    });

    test('the services are fetched only once', () async {
      final (ds, adapter) = _build((o) async =>
          o.path == '/services' ? jsonResponse(_services) : jsonResponse(_calledTicket()));

      await ds.callNextTicket('2');
      await ds.callNextTicket('2');

      expect(adapter.requests.where((r) => r.path == '/services'), hasLength(1));
    });

    test('the called ticket does not appear on other counters', () async {
      final (ds, _) = _build((o) async =>
          o.path == '/services' ? jsonResponse(_services) : jsonResponse(_calledTicket()));

      await ds.callNextTicket('2');

      expect(await ds.watchCurrentTicket('1').first, isNull);
      expect((await ds.watchCurrentTicket('2').first)?.code, 'D-0001');
    });
  });

  group('completeTicket', () {
    test('calls PUT /tickets/:id/complete and frees the counter', () async {
      final (ds, adapter) = _build((o) async => switch (o.path) {
            '/services' => jsonResponse(_services),
            '/tickets/3/complete' => jsonResponse({'id': 3, 'status': 'completed'}),
            _ => jsonResponse(_calledTicket()),
          });
      await ds.callNextTicket('2');
      final updates = ds.watchCurrentTicket('2').take(2).toList();

      await ds.completeTicket('3');

      expect(adapter.requests.last.method, 'PUT');
      expect(adapter.requests.last.path, '/tickets/3/complete');
      final seen = await updates;
      expect(seen.first?.code, 'D-0001');
      expect(seen.last, isNull);
    });

    test('when the backend refuses (409) the counter stays busy', () async {
      final (ds, _) = _build((o) async => switch (o.path) {
            '/services' => jsonResponse(_services),
            '/tickets/3/complete' => jsonResponse({'error': 'not called'}, 409),
            _ => jsonResponse(_calledTicket()),
          });
      await ds.callNextTicket('2');

      await expectLater(ds.completeTicket('3'), throwsA(isA<DioException>()));
      expect((await ds.watchCurrentTicket('2').first)?.code, 'D-0001');
    });
  });
}
