import '../entities/counter.dart';
import '../entities/queue_summary.dart';
import '../entities/ticket.dart';

abstract class CounterOfficerRepository {
  Future<List<Counter>> getCounters();

  /// Actual ticket served by the counter. Null if no ticket is being served.
  Stream<Ticket?> watchCurrentTicket(String counterId);

  /// Queue status (current one + waiting ons)
  Stream<QueueSummary> watchQueue();

  /// Assigns the next ticket to the counter. Returns the assigned ticket or null if no ticket is available.
  Future<Ticket?> callNextTicket(String counterId);

  Future<void> completeTicket(String ticketId);
}