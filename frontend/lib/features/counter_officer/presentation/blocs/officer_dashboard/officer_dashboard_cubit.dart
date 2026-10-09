import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/counter.dart';
import '../../../domain/repositories/counter_officer_repository.dart';
import '../../../domain/usecases/call_next_ticket.dart';
import '../../../domain/usecases/complete_ticket.dart';
import 'officer_dashboard_state.dart';

class OfficerDashboardCubit extends Cubit<OfficerDashboardState> {
  final CounterOfficerRepository _repository;
  final CallNextTicket _callNextTicket;
  final CompleteTicket _completeTicket;

  StreamSubscription? _ticketSub;
  StreamSubscription? _queueSub;

  OfficerDashboardCubit({
    required Counter counter,
    required CounterOfficerRepository repository,
    required CallNextTicket callNextTicket,
    required CompleteTicket completeTicket,
  })  : _repository = repository,
        _callNextTicket = callNextTicket,
        _completeTicket = completeTicket,
        super(OfficerDashboardState(counter: counter));

  void start() {
    _ticketSub?.cancel();
    _queueSub?.cancel();

    _ticketSub = _repository.watchCurrentTicket(state.counter.id).listen(
      (ticket) => emit(ticket == null
          ? state.copyWith(clearCurrentTicket: true)
          : state.copyWith(currentTicket: ticket)),
      onError: (_) => emit(state.copyWith(errorMessage: 'Connection error')),
    );

    _queueSub = _repository.watchQueue().listen(
      (queue) => emit(state.copyWith(queue: queue)),
      onError: (_) => emit(state.copyWith(errorMessage: 'Connection error')),
    );
  }

  Future<void> callNext() async {
    if (!state.canCallNext) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      await _callNextTicket(state.counter.id);
      emit(state.copyWith(isBusy: false));
    } catch (_) {
      emit(state.copyWith(isBusy: false, errorMessage: 'Could not call next'));
    }
  }

  Future<void> complete() async {
    final ticket = state.currentTicket;
    if (ticket == null || !state.canComplete) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      await _completeTicket(ticket.id);
      emit(state.copyWith(isBusy: false));
    } catch (_) {
      emit(state.copyWith(isBusy: false, errorMessage: 'Could not complete'));
    }
  }

  @override
  Future<void> close() {
    _ticketSub?.cancel();
    _queueSub?.cancel();
    return super.close();
  }
}