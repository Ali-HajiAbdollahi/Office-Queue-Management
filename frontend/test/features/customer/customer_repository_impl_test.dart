import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/ticket_status.dart';
import 'package:frontend/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/stub_dio.dart';

const _savedTicketKey = 'active_ticket_id';

Map<String, dynamic> _ticketJson({
  int id = 7,
  String status = 'waiting',
  bool isActive = true,
  int? counterId,
  String? servedAt,
  int? queueLength,
}) =>
    {
      'id': id,
      'code': 'S-0001',
      'service_id': 1,
      'status': status,
      'issued_at': '2026-10-11T08:00:00.000Z',
      'served_at': servedAt,
      'counter_id': counterId,
      'is_active': isActive,
      'queue_length': ?queueLength,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('getServices', () {
    test('reads id, tag and service_time from GET /api/services', () async {
      final (dio, adapter) = stubDio((_) async => jsonResponse([
            {'id': 1, 'tag': 'Shipping', 'service_time': 5},
            {'id': 2, 'tag': 'Deposit', 'service_time': 8},
          ]));

      final services = await CustomerRepositoryImpl(dio: dio).getServices();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/services');
      expect(services.map((s) => [s.id, s.tag, s.serviceTime]), [
        [1, 'Shipping', 5],
        [2, 'Deposit', 8],
      ]);
    });
  });

  group('issueTicket', () {
    test('sends {service_id} as JSON to POST /api/tickets and reads the ticket', () async {
      final (dio, adapter) = stubDio((_) async => jsonResponse(_ticketJson(queueLength: 3), 201));

      final ticket = await CustomerRepositoryImpl(dio: dio).issueTicket(1);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/tickets');
      expect(request.contentType, Headers.jsonContentType);
      expect(request.data, {'service_id': 1});

      expect(ticket.id, 7);
      expect(ticket.code, 'S-0001');
      expect(ticket.serviceId, 1);
      expect(ticket.status, TicketStatus.waiting);
      expect(ticket.issuedAt, DateTime.utc(2026, 10, 11, 8));
      expect(ticket.servedAt, isNull);
      expect(ticket.counterId, isNull);
      expect(ticket.isActive, isTrue);
      expect(ticket.queueLength, 3);
    });

    test('a server error (404 unknown service) reaches the caller', () async {
      final (dio, _) = stubDio((_) async => jsonResponse({
            'error': {'code': 'SERVICE_NOT_FOUND', 'message': 'Service not found'},
          }, 404));

      expect(
        CustomerRepositoryImpl(dio: dio).issueTicket(99),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 404)),
      );
    });
  });

  group('getTicketStatus', () {
    test('a called ticket carries its counter and call time', () async {
      final (dio, adapter) = stubDio((_) async => jsonResponse(_ticketJson(
            status: 'called',
            isActive: false,
            counterId: 2,
            servedAt: '2026-10-11T08:05:00.000Z',
          )));

      final ticket = await CustomerRepositoryImpl(dio: dio).getTicketStatus(7);

      expect(adapter.requests.single.path, '/api/tickets/7');
      expect(ticket.status, TicketStatus.called);
      expect(ticket.counterId, 2);
      expect(ticket.servedAt, DateTime.utc(2026, 10, 11, 8, 5));
      expect(ticket.isActive, isFalse);
      expect(ticket.queueLength, isNull);
    });

    for (final (api, expected) in [
      ('waiting', TicketStatus.waiting),
      ('called', TicketStatus.called),
      ('completed', TicketStatus.completed),
      ('served', TicketStatus.completed),
    ]) {
      test('status "$api" becomes $expected', () async {
        final (dio, _) = stubDio((_) async => jsonResponse(_ticketJson(status: api)));
        final ticket = await CustomerRepositoryImpl(dio: dio).getTicketStatus(7);
        expect(ticket.status, expected);
      });
    }

    test('an unknown status is a format error', () async {
      final (dio, _) = stubDio((_) async => jsonResponse(_ticketJson(status: 'lost')));
      expect(CustomerRepositoryImpl(dio: dio).getTicketStatus(7), throwsFormatException);
    });
  });

  group('getActiveTicket', () {
    test('without a saved ticket it returns null and does not call the server', () async {
      final (dio, adapter) = stubDio((_) async => jsonResponse(_ticketJson()));

      expect(await CustomerRepositoryImpl(dio: dio).getActiveTicket(), isNull);
      expect(adapter.requests, isEmpty);
    });

    test('with a saved ticket that is still active it returns it', () async {
      SharedPreferences.setMockInitialValues({_savedTicketKey: 7});
      final (dio, adapter) = stubDio((_) async => jsonResponse(_ticketJson()));

      final ticket = await CustomerRepositoryImpl(dio: dio).getActiveTicket();

      expect(adapter.requests.single.path, '/api/tickets/7');
      expect(ticket?.id, 7);
      expect((await SharedPreferences.getInstance()).getInt(_savedTicketKey), 7);
    });

    test('when the ticket is no longer active it returns null and forgets the id', () async {
      SharedPreferences.setMockInitialValues({_savedTicketKey: 7});
      final (dio, _) = stubDio((_) async => jsonResponse(_ticketJson(status: 'called', isActive: false)));

      expect(await CustomerRepositoryImpl(dio: dio).getActiveTicket(), isNull);
      expect((await SharedPreferences.getInstance()).containsKey(_savedTicketKey), isFalse);
    });

    test('when the server answers 404 it returns null and forgets the id', () async {
      SharedPreferences.setMockInitialValues({_savedTicketKey: 7});
      final (dio, _) = stubDio((_) async => jsonResponse({'error': 'not found'}, 404));

      expect(await CustomerRepositoryImpl(dio: dio).getActiveTicket(), isNull);
      expect((await SharedPreferences.getInstance()).containsKey(_savedTicketKey), isFalse);
    });

    test('a server error (500) is rethrown and the id stays saved', () async {
      SharedPreferences.setMockInitialValues({_savedTicketKey: 7});
      final (dio, _) = stubDio((_) async => jsonResponse({'error': 'boom'}, 500));

      await expectLater(CustomerRepositoryImpl(dio: dio).getActiveTicket(), throwsA(isA<DioException>()));
      expect((await SharedPreferences.getInstance()).getInt(_savedTicketKey), 7);
    });
  });

  test('cancelTicket is not supported in this sprint', () {
    final (dio, _) = stubDio((_) async => jsonResponse(null));
    expect(CustomerRepositoryImpl(dio: dio).cancelTicket(7), throwsUnsupportedError);
  });
}
