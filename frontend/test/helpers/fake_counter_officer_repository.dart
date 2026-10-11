import 'dart:async';

import 'package:frontend/features/counter_officer/domain/entities/counter.dart';
import 'package:frontend/features/counter_officer/domain/entities/queue_summary.dart';
import 'package:frontend/features/counter_officer/domain/entities/ticket.dart';
import 'package:frontend/features/counter_officer/domain/repositories/counter_officer_repository.dart';

const demoCounters = [
  Counter(id: '1', number: 1, description: ''),
  Counter(id: '2', number: 2, description: ''),
];

Ticket officerTicket({String id = '3', String code = 'D-0001', String serviceType = 'Deposit'}) => Ticket(
      id: id,
      code: code,
      serviceType: serviceType,
      arrivalTime: DateTime(2026, 10, 11, 9, 30),
      calledAt: DateTime(2026, 10, 11, 9, 45),
      status: TicketStatus.serving,
    );

/// Fake officer repository: like the REST data source, the ticket being served
/// changes after call-next and goes back to null after complete.
class FakeCounterOfficerRepository implements CounterOfficerRepository {
  List<Counter> counters = demoCounters;
  Object? countersError;
  int getCountersCalls = 0;

  /// Next results of callNextTicket (a Ticket, null or an error to throw).
  final List<Object?> nextResults = [];
  final List<String> calledFrom = [];
  final List<String> completed = [];
  Object? completeError;

  final Map<String, Ticket?> _current = {};
  final _changes = StreamController<String>.broadcast();

  @override
  Future<List<Counter>> getCounters() async {
    getCountersCalls++;
    if (countersError != null) throw countersError!;
    return counters;
  }

  @override
  Stream<Ticket?> watchCurrentTicket(String counterId) async* {
    yield _current[counterId];
    await for (final id in _changes.stream) {
      if (id == counterId) yield _current[counterId];
    }
  }

  @override
  Stream<QueueSummary> watchQueue(String counterId) =>
      Stream.value(const QueueSummary(waitingCount: 0));

  @override
  Future<Ticket?> callNextTicket(String counterId) async {
    calledFrom.add(counterId);
    final result = nextResults.isEmpty ? null : nextResults.removeAt(0);
    if (result is Ticket?) {
      if (result != null) {
        _current[counterId] = result;
        _changes.add(counterId);
      }
      return result;
    }
    throw result;
  }

  @override
  Future<void> completeTicket(String ticketId) async {
    if (completeError != null) throw completeError!;
    completed.add(ticketId);
    for (final entry in _current.entries.toList()) {
      if (entry.value?.id == ticketId) {
        _current[entry.key] = null;
        _changes.add(entry.key);
      }
    }
  }
}
