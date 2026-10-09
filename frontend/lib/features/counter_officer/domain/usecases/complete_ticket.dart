import '../repositories/counter_officer_repository.dart';

class CompleteTicket {
  final CounterOfficerRepository repository;
  const CompleteTicket(this.repository);

  Future<void> call(String ticketId) => repository.completeTicket(ticketId);
}