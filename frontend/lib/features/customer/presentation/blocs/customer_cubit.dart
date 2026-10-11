import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/customer_repository.dart';
import 'customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  final CustomerRepository repository;
  Timer? _pollingTimer;
  int _pollVersion = 0;
  bool _issuing = false;
  static const String _ticketKey = 'active_ticket_id';

  CustomerCubit({required this.repository}) : super(CustomerInitial());
  Future<void> loadInitialData() async {
    _stopPolling();
    emit(CustomerLoading());
    try {
      final services = await repository.getServices();
      // Only 404/inactive clears the saved id; network errors preserve it.
      final ticket = await repository.getActiveTicket();
      if (isClosed) return;
      emit(CustomerLoaded(services: services, activeTicket: ticket));
      if (ticket != null) _startPolling(ticket.id);
    } catch (error) {
      if (!isClosed) emit(CustomerError(error.toString()));
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
      } catch (_) { /* Ticket remains available for this app session. */ }
      if (isClosed) return;
      emit(CustomerLoaded(services: current.services, activeTicket: ticket));
      _startPolling(ticket.id);
    } catch (error) {
      if (!isClosed) emit(CustomerError(error.toString()));
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
      if (inFlight || isClosed || version != _pollVersion) return;
      inFlight = true;
      try {
        final ticket = await repository.getTicketStatus(ticketId);
        if (isClosed || version != _pollVersion || state is! CustomerLoaded) return;
        final current = state as CustomerLoaded;
        if (current.activeTicket?.id != ticketId) return;
        if (!ticket.isActive) {
          _stopPolling();
          emit(CustomerLoaded(services: current.services));
          await _forgetTicket(ticketId);
          return;
        }

        emit(CustomerLoaded(services: current.services, activeTicket: ticket));

      } on DioException catch (error) {
        if (error.response?.statusCode == 404 &&
            !isClosed && version == _pollVersion && state is CustomerLoaded) {
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
      if (prefs.getInt(_ticketKey) == expectedId) await prefs.remove(_ticketKey);
    } catch (_) { /* Next load rechecks the ticket with the server. */ }
  }

  Future<void> cancelTicket(int ticketId) async {
    // Cancellation belongs to a separate API task. The UI control is disabled.
    throw UnsupportedError('Ticket cancellation is not implemented in this scope');
  }


  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}