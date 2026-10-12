import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/data/models/counter_model.dart';
import 'package:frontend/features/counter_officer/data/models/ticket_model.dart';
import 'package:frontend/features/counter_officer/domain/entities/ticket.dart';

Map<String, dynamic> _apiTicket({String status = 'called', Object? counterId = 2, String? servedAt = '2026-10-11T08:05:00.000Z'}) => {
      'id': 3,
      'code': 'D-0001',
      'service_id': 2,
      'status': status,
      'issued_at': '2026-10-11T08:00:00.000Z',
      'served_at': servedAt,
      'counter_id': counterId,
    };

void main() {
  group('TicketModel.fromApi', () {
    test('reads the called ticket from the backend', () {
      final ticket = TicketModel.fromApi(_apiTicket(), serviceType: 'Deposit');

      expect(ticket.id, '3');
      expect(ticket.code, 'D-0001');
      expect(ticket.serviceType, 'Deposit');
      expect(ticket.status, TicketStatus.serving);
      expect(ticket.counterId, '2');
    });

    test('dates arrive in UTC and are converted to local time', () {
      final ticket = TicketModel.fromApi(_apiTicket(), serviceType: 'Deposit');

      expect(ticket.arrivalTime.isUtc, isFalse);
      expect(ticket.arrivalTime, DateTime.utc(2026, 10, 11, 8).toLocal());
      expect(ticket.calledAt, DateTime.utc(2026, 10, 11, 8, 5).toLocal());
    });

    test('missing served_at and counter_id stay null', () {
      final ticket = TicketModel.fromApi(_apiTicket(status: 'waiting', counterId: null, servedAt: null), serviceType: 'Deposit');

      expect(ticket.calledAt, isNull);
      expect(ticket.counterId, isNull);
    });

    for (final (api, expected) in [
      ('called', TicketStatus.serving),
      ('completed', TicketStatus.completed),
      ('waiting', TicketStatus.waiting),
    ]) {
      test('status "$api" becomes $expected', () {
        expect(TicketModel.fromApi(_apiTicket(status: api), serviceType: 'Deposit').status, expected);
      });
    }
  });

  test('TicketModel: toJson and fromJson are symmetric', () {
    final ticket = TicketModel.fromApi(_apiTicket(), serviceType: 'Deposit');
    expect(TicketModel.fromJson(ticket.toJson()), ticket);
  });

  group('CounterModel.fromApi', () {
    test('uses the id as the counter number', () {
      final counter = CounterModel.fromApi({'id': 2, 'name': 'Counter 2'});

      expect(counter.id, '2');
      expect(counter.number, 2);
      expect(counter.name, 'Counter 2');
      expect(counter.description, '');
    });

    test('keeps the description when the backend sends it', () {
      final counter = CounterModel.fromApi({'id': 1, 'name': 'Counter 1', 'description': 'Shipping'});
      expect(counter.description, 'Shipping');
    });
  });
}
