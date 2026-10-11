import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/ticket_status.dart';
import '../../domain/repositories/customer_repository.dart';
import 'customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  final CustomerRepository repository;
  Timer? _pollingTimer;

  static const String _ticketKey = 'active_ticket_id';

  CustomerCubit({required this.repository}) : super(CustomerInitial());

  Future<void> loadInitialData() async {
    emit(CustomerLoading());
    try {
      final services = await repository.getServices();

      final prefs = await SharedPreferences.getInstance();
      final savedTicketId = prefs.getInt(_ticketKey);

      if (savedTicketId != null) {
        try {
          final ticket = await repository.getTicketStatus(savedTicketId);
          emit(CustomerLoaded(services: services, activeTicket: ticket));
          _startPolling(ticket.id);
          return;
        } catch (_) {
          await prefs.remove(_ticketKey);
        }
      }

      emit(CustomerLoaded(services: services));
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_ticketKey, newTicket.id);

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ticketKey);

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
