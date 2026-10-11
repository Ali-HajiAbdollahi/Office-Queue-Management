import '../entities/counter.dart';
import '../entities/queue_summary.dart';
import '../entities/ticket.dart';

abstract class CounterOfficerRepository {
  Future<List<Counter>> getCounters();

  /// Ticket attualmente servito dal counter (null se nessuno).
  Stream<Ticket?> watchCurrentTicket(String counterId);

  /// Stato della coda per i servizi gestiti dal counter.
  Stream<QueueSummary> watchQueue(String counterId);

  /// Assegna il prossimo ticket al counter. Null se la coda è vuota.
  Future<Ticket?> callNextTicket(String counterId);

  Future<void> completeTicket(String ticketId);
}