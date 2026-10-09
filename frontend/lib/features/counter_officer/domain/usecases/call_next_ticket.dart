import '../entities/ticket.dart';
import '../repositories/counter_officer_repository.dart';

class CallNextTicket {
  final CounterOfficerRepository repository;
  const CallNextTicket(this.repository);

  Future<Ticket?> call(String counterId) =>
      repository.callNextTicket(counterId);
}