import '../entities/counter.dart';
import '../repositories/counter_officer_repository.dart';

class GetCounters {
  final CounterOfficerRepository repository;
  const GetCounters(this.repository);

  Future<List<Counter>> call() => repository.getCounters();
}