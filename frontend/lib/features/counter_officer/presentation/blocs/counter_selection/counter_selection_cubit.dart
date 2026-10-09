import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/counter.dart';
import '../../../domain/usecases/get_counters.dart';
import 'counter_selection_state.dart';

class CounterSelectionCubit extends Cubit<CounterSelectionState> {
  final GetCounters _getCounters;

  CounterSelectionCubit(this._getCounters)
      : super(const CounterSelectionState());

  Future<void> load() async {
    emit(state.copyWith(status: CounterSelectionStatus.loading));
    try {
      final counters = await _getCounters();
      emit(state.copyWith(
        status: CounterSelectionStatus.loaded,
        counters: counters,
      ));
    } catch (_) {
      emit(state.copyWith(status: CounterSelectionStatus.failure));
    }
  }

  void select(Counter counter) => emit(state.copyWith(selected: counter));
}