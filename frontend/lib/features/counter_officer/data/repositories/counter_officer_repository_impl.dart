import '../../domain/entities/counter.dart';
import '../../domain/entities/queue_summary.dart';
import '../../domain/entities/ticket.dart';
import '../../domain/repositories/counter_officer_repository.dart';
import '../datasources/counter_officer_data_source.dart';

class CounterOfficerRepositoryImpl implements CounterOfficerRepository {
  final CounterOfficerDataSource dataSource;
  const CounterOfficerRepositoryImpl(this.dataSource);

  @override
  Future<List<Counter>> getCounters() => dataSource.getCounters();

  @override
  Stream<Ticket?> watchCurrentTicket(String counterId) =>
      dataSource.watchCurrentTicket(counterId);

  @override
  Stream<QueueSummary> watchQueue(String counterId) =>
      dataSource.watchQueue(counterId);

  @override
  Future<Ticket?> callNextTicket(String counterId) =>
      dataSource.callNextTicket(counterId);

  @override
  Future<void> completeTicket(String ticketId) =>
      dataSource.completeTicket(ticketId);
}