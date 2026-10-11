import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/counter_officer/domain/usecases/get_counters.dart';
import 'package:frontend/features/counter_officer/presentation/blocs/counter_selection/counter_selection_cubit.dart';
import 'package:frontend/features/counter_officer/presentation/blocs/counter_selection/counter_selection_state.dart';

import '../../helpers/fake_counter_officer_repository.dart';

void main() {
  late FakeCounterOfficerRepository repository;
  late CounterSelectionCubit cubit;

  setUp(() {
    repository = FakeCounterOfficerRepository();
    cubit = CounterSelectionCubit(GetCounters(repository));
  });

  tearDown(() => cubit.close());

  test('starts loading and cannot continue', () {
    expect(cubit.state.status, CounterSelectionStatus.loading);
    expect(cubit.state.canContinue, isFalse);
  });

  test('load shows the counters from the backend', () async {
    await cubit.load();

    expect(cubit.state.status, CounterSelectionStatus.loaded);
    expect(cubit.state.counters, demoCounters);
    expect(cubit.state.selected, isNull);
  });

  test('reports a failed load', () async {
    repository.countersError = Exception('offline');

    await cubit.load();

    expect(cubit.state.status, CounterSelectionStatus.failure);
  });

  test('after an error, retrying loads the counters', () async {
    repository.countersError = Exception('offline');
    await cubit.load();
    repository.countersError = null;

    await cubit.load();

    expect(cubit.state.status, CounterSelectionStatus.loaded);
    expect(repository.getCountersCalls, 2);
  });

  test('choosing a counter allows to continue', () async {
    await cubit.load();

    cubit.select(demoCounters[1]);

    expect(cubit.state.selected, demoCounters[1]);
    expect(cubit.state.canContinue, isTrue);
  });
}
