import '../entities/service_entity.dart';
import '../entities/ticket_entity.dart';

abstract class CustomerRepository {
  Future<TicketEntity?> getActiveTicket();

  Future<List<ServiceEntity>> getServices();

  Future<TicketEntity> issueTicket(int serviceId);

  Future<TicketEntity> getTicketStatus(int ticketId);

  Future<void> cancelTicket(int ticketId);
}
