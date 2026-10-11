import 'dart:async';

import '../../domain/entities/queue_summary.dart';
import '../../domain/entities/ticket.dart';
import '../models/counter_model.dart';
import '../models/ticket_model.dart';
import 'counter_officer_data_source.dart';

/// Implementazione in memoria, utile per sviluppo e test.
class FakeCounterOfficerDataSource implements CounterOfficerDataSource {
  final _changes = StreamController<void>.broadcast();

  final List<CounterModel> _counters = const [
    CounterModel(id: 'c1', number: 1, description: 'General Services'),
    CounterModel(id: 'c2', number: 2, description: 'Document Verification'),
    CounterModel(id: 'c3', number: 3, description: 'Cashier & Payments'),
    CounterModel(id: 'c4', number: 4, description: 'Fast Track & Inquiries'),
    CounterModel(id: 'c5', number: 5, description: 'VIP & Appeals'),
  ];

  late final List<TicketModel> _tickets = _seedTickets();

  List<TicketModel> _seedTickets() {
    final now = DateTime.now();
    const services = [
      'Document Check',
      'Passport Renewal',
      'Address Update',
      'Signature Auth',
      'Payment',
    ];
    return List.generate(
      5,
      (i) => TicketModel(
        id: 't${141 + i}',
        code: 'A-${141 + i}',
        serviceType: services[i],
        arrivalTime: now.subtract(Duration(minutes: 25 - i * 4)),
        status: TicketStatus.waiting,
      ),
    );
  }

  TicketModel? _currentFor(String counterId) {
    for (final t in _tickets) {
      if (t.status == TicketStatus.serving && t.counterId == counterId) {
        return t;
      }
    }
    return null;
  }

  List<TicketModel> _waiting() {
    final list =
        _tickets.where((t) => t.status == TicketStatus.waiting).toList()
          ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
    return list;
  }

  QueueSummary _summary() {
    final waiting = _waiting();
    return QueueSummary(
      waitingCount: waiting.length,
      nextTicketCode: waiting.isEmpty ? null : waiting.first.code,
    );
  }

  @override
  Future<List<CounterModel>> getCounters() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _counters;
  }

  @override
  Stream<TicketModel?> watchCurrentTicket(String counterId) async* {
    yield _currentFor(counterId);
    await for (final _ in _changes.stream) {
      yield _currentFor(counterId);
    }
  }

  @override
  Stream<QueueSummary> watchQueue(String counterId) async* {
    yield _summary();
    await for (final _ in _changes.stream) {
      yield _summary();
    }
  }

  @override
  Future<TicketModel?> callNextTicket(String counterId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final current = _currentFor(counterId);
    if (current != null) return current; // sta già servendo qualcuno

    final waiting = _waiting();
    if (waiting.isEmpty) return null;

    final next = waiting.first.copyWith(
      status: TicketStatus.serving,
      calledAt: DateTime.now(),
      counterId: counterId,
    );
    _tickets[_tickets.indexWhere((t) => t.id == next.id)] = next;
    _changes.add(null);
    return next;
  }

  @override
  Future<void> completeTicket(String ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final i = _tickets.indexWhere((t) => t.id == ticketId);
    if (i == -1) return;
    _tickets[i] = _tickets[i].copyWith(status: TicketStatus.completed);
    _changes.add(null);
  }
}