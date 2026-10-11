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
  bool _ticketLoaded = false;
  bool _queueLoaded = false;

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
    _ticketLoaded = false;
    _queueLoaded = false;
    emit(state.copyWith(
      status: OfficerDashboardStatus.loading,
      clearError: true,
    ));

    _ticketSub = _repository.watchCurrentTicket(state.counter.id).listen(
      (ticket) {
        _ticketLoaded = true;
        emit(ticket == null
            ? state.copyWith(
                clearCurrentTicket: true, status: _statusAfterData())
            : state.copyWith(
                currentTicket: ticket, status: _statusAfterData()));
      },
      onError: (_) => _fail(),
    );

     _queueSub = _repository.watchQueue(state.counter.id).listen(
      (queue) {
        _queueLoaded = true;
        emit(state.copyWith(queue: queue, status: _statusAfterData()));
      },
      onError: (_) => _fail(),
    );
  }

  OfficerDashboardStatus _statusAfterData() =>
      state.status == OfficerDashboardStatus.loading &&
              _ticketLoaded &&
              _queueLoaded
          ? OfficerDashboardStatus.ready
          : state.status;

  void _fail() => emit(state.copyWith(
        status: OfficerDashboardStatus.failure,
        errorMessage: 'Connection error',
      ));

  Future<void> callNext() async {
    if (!state.canCallNext) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      final ticket = await _callNextTicket(state.counter.id);
      if (ticket == null) {
        // Risposta valida ma nessun ticket in coda.
        emit(state.copyWith(
            isBusy: false, errorMessage: 'No tickets available'));
      } else {
        // Mostra subito il ticket restituito dalla risposta.
        emit(state.copyWith(isBusy: false, currentTicket: ticket));
      }
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
      emit(state.copyWith(
        isBusy: false,
        errorMessage: 'Could not complete the ticket. Try again.',
      ));
    }
  }

  @override
  Future<void> close() {
    _ticketSub?.cancel();
    _queueSub?.cancel();
    return super.close();
  }
}