import '../../domain/entities/queue_summary.dart';
import '../models/counter_model.dart';
import '../models/ticket_model.dart';

abstract class CounterOfficerDataSource {
  Future<List<CounterModel>> getCounters();
  Stream<TicketModel?> watchCurrentTicket(String counterId);
  Stream<QueueSummary> watchQueue(String counterId);
  Future<TicketModel?> callNextTicket(String counterId);
  Future<void> completeTicket(String ticketId);
}