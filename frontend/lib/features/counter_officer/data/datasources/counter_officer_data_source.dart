import '../models/counter_model.dart';
import '../models/ticket_model.dart';

abstract class CounterOfficerDataSource {
  Future<List<CounterModel>> getCounters();
  Stream<TicketModel?> watchCurrentTicket(String counterId);
  Stream<List<TicketModel>> watchWaitingTickets();
  Future<TicketModel?> callNextTicket(String counterId);
  Future<void> completeTicket(String ticketId);
}