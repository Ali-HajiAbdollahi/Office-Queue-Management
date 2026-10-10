import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/enums/ticket_status.dart';
import '../../domain/repositories/customer_repository.dart';
import 'customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  final CustomerRepository repository;
  Timer? _pollingTimer;

  CustomerCubit({required this.repository}) : super(CustomerInitial());

  Future<void> loadInitialData() async {
    emit(CustomerLoading());
    try {
      final services = await repository.getServices();
      final activeTicket = await repository.getActiveTicket();
      emit(CustomerLoaded(services: services, activeTicket: activeTicket));

      if (activeTicket != null) {
        _startPolling(activeTicket.id);
      }
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> getNewTicket(int serviceId) async {
    if (state is! CustomerLoaded) {
      return;
    }

    final currentState = state as CustomerLoaded;
    emit(CustomerLoading());
    try {
      final newTicket = await repository.issueTicket(serviceId);
      emit(
        CustomerLoaded(
          services: currentState.services,
          activeTicket: newTicket,
        ),
      );
      _startPolling(newTicket.id);
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  void _startPolling(int ticketId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final updatedTicket = await repository.getTicketStatus(ticketId);

        if (isClosed) {
          timer.cancel();
          return;
        }

        if (state is CustomerLoaded) {
          final currentState = state as CustomerLoaded;
          if (updatedTicket.status == TicketStatus.called &&
              currentState.activeTicket?.status != TicketStatus.called) {
            emit(
              CustomerLoaded(
                services: currentState.services,
                activeTicket: updatedTicket,
              ),
            );
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      } catch (_) {
        // Keep polling so transient network errors are retried.
      }
    });
  }

  Future<void> cancelTicket(int ticketId) async {
    if (state is! CustomerLoaded) {
      return;
    }

    final currentState = state as CustomerLoaded;
    emit(CustomerLoading());
    try {
      await repository.cancelTicket(ticketId);
      _pollingTimer?.cancel();
      emit(CustomerLoaded(services: currentState.services, activeTicket: null));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
