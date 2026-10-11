import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/ticket_status.dart';
import '../../domain/repositories/customer_repository.dart';
import 'customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  static const String _ticketKey = 'active_ticket_id';

  final CustomerRepository repository;
  Timer? _pollingTimer;
  int _pollVersion = 0;
  bool _issuing = false;

  static String _friendlyErrorMessage(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) {
        return 'Ticket no longer available. Please refresh.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'The office is busy right now. Please try again.';
      }
      final type = error.type;
      if (type == DioExceptionType.connectionError ||
          type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.sendTimeout) {
        return 'Cannot reach the office. Check your connection and try again.';
      }
      return 'Something went wrong. Please try again.';
    }

    final text = error.toString().toLowerCase();
    if (text.contains('offline') ||
        text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return 'Cannot reach the office. Check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  CustomerCubit({required this.repository}) : super(CustomerInitial());
  Future<void> loadInitialData() async {
    _stopPolling();
    emit(CustomerLoading());
    try {
      final services = await repository.getServices();
      // Only 404/inactive clears the saved id; network errors preserve it.
      final ticket = await repository.getActiveTicket();
      if (isClosed) {
        return;
      }
      emit(CustomerLoaded(services: services, activeTicket: ticket));
      if (ticket != null) {
        _startPolling(ticket.id);
      }
    } catch (error) {
      if (!isClosed) emit(CustomerError(_friendlyErrorMessage(error)));
    }
  }

  Future<void> getNewTicket(int serviceId) async {
    if (_issuing || state is! CustomerLoaded) return;
    final current = state as CustomerLoaded;
    if (current.activeTicket != null) return;
    _issuing = true;
    _stopPolling();
    emit(CustomerLoading());
    try {
      final ticket = await repository.issueTicket(serviceId);

      // Local storage failure must not turn successful issuance into a retry.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_ticketKey, ticket.id);
      } catch (_) {
        /* Ticket remains available for this app session. */
      }
      if (isClosed) {
        return;
      }
      emit(CustomerLoaded(services: current.services, activeTicket: ticket));
      _startPolling(ticket.id);
    } catch (error) {
      if (!isClosed) emit(CustomerError(_friendlyErrorMessage(error)));
    } finally {
      _issuing = false;
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollVersion++;
  }

  void _startPolling(int ticketId) {
    _stopPolling();
    final version = _pollVersion;
    bool inFlight = false;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (inFlight || isClosed || version != _pollVersion) {
        return;
      }
      inFlight = true;
      try {
        final ticket = await repository.getTicketStatus(ticketId);
        if (isClosed || version != _pollVersion || state is! CustomerLoaded) {
          return;
        }
        final current = state as CustomerLoaded;
        if (current.activeTicket?.id != ticketId) {
          return;
        }
        if (!ticket.isActive) {
          if (ticket.status == TicketStatus.called) {
            emit(
              CustomerLoaded(services: current.services, activeTicket: ticket),
            );
            return;
          }

          _stopPolling();
          emit(CustomerLoaded(services: current.services));
          await _forgetTicket(ticketId);
          return;
        }

        emit(CustomerLoaded(services: current.services, activeTicket: ticket));
      } on DioException catch (error) {
        if (error.response?.statusCode == 404 &&
            !isClosed &&
            version == _pollVersion &&
            state is CustomerLoaded) {
          final current = state as CustomerLoaded;
          _stopPolling();
          emit(CustomerLoaded(services: current.services));
          await _forgetTicket(ticketId);
        }
        // GET requests can be polled again after temporary network failures.
      } catch (_) {
        // Preserve the saved ticket; do not issue another POST automatically.
      } finally {
        inFlight = false;
      }
    });
  }

  Future<void> _forgetTicket(int expectedId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_ticketKey) == expectedId) {
        await prefs.remove(_ticketKey);
      }
    } catch (_) {
      /* Next load rechecks the ticket with the server. */
    }
  }

  Future<void> cancelTicket(int ticketId) async {
    // Cancellation requires a backend endpoint that is not available yet.
    // Keep the app stable by making the action inert until that API is ready.
    return;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
