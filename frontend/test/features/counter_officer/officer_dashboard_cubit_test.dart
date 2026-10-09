import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/data/datasources/fake_counter_officer_data_source.dart';
import 'package:frontend/features/counter_officer/data/repositories/counter_officer_repository_impl.dart';
import 'package:frontend/features/counter_officer/domain/entities/counter.dart';
import 'package:frontend/features/counter_officer/domain/usecases/call_next_ticket.dart';
import 'package:frontend/features/counter_officer/domain/usecases/complete_ticket.dart';
import 'package:frontend/features/counter_officer/presentation/blocs/officer_dashboard/officer_dashboard_cubit.dart';

void main() {
  const counter =
      Counter(id: 'c1', number: 1, description: 'General Services');

  late OfficerDashboardCubit cubit;

  setUp(() {
    final repo = CounterOfficerRepositoryImpl(FakeCounterOfficerDataSource());
    cubit = OfficerDashboardCubit(
      counter: counter,
      repository: repo,
      callNextTicket: CallNextTicket(repo),
      completeTicket: CompleteTicket(repo),
    )..start();
  });

  tearDown(() => cubit.close());

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('inizialmente nessun ticket servito e 5 in coda', () async {
    await pump();
    expect(cubit.state.currentTicket, isNull);
    expect(cubit.state.queue.waitingCount, 5);
    expect(cubit.state.queue.nextTicketCode, 'A-141');
    expect(cubit.state.canCallNext, isTrue);
  });

  test('callNext assegna il ticket e disabilita un nuovo call', () async {
    await pump();
    await cubit.callNext();
    await pump();

    expect(cubit.state.currentTicket?.code, 'A-141');
    expect(cubit.state.queue.waitingCount, 4);
    expect(cubit.state.canCallNext, isFalse);
    expect(cubit.state.canComplete, isTrue);
  });

  test('complete libera il counter e il prossimo è A-142', () async {
    await pump();
    await cubit.callNext();
    await pump();
    await cubit.complete();
    await pump();

    expect(cubit.state.currentTicket, isNull);
    expect(cubit.state.queue.nextTicketCode, 'A-142');
    expect(cubit.state.canCallNext, isTrue);
  });
}