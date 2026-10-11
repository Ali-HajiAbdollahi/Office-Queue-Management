import 'package:equatable/equatable.dart';

import '../../../domain/entities/counter.dart';

enum CounterSelectionStatus { loading, loaded, failure }

class CounterSelectionState extends Equatable {
  final CounterSelectionStatus status;
  final List<Counter> counters;
  final Counter? selected;

  const CounterSelectionState({
    this.status = CounterSelectionStatus.loading,
    this.counters = const [],
    this.selected,
  });

  bool get canContinue => selected != null;

  CounterSelectionState copyWith({
    CounterSelectionStatus? status,
    List<Counter>? counters,
    Counter? selected,
  }) =>
      CounterSelectionState(
        status: status ?? this.status,
        counters: counters ?? this.counters,
        selected: selected ?? this.selected,
      );

  @override
  List<Object?> get props => [status, counters, selected];
}