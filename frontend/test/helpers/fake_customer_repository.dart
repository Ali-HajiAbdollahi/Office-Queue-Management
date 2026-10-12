import 'dart:async';

import 'package:frontend/core/enums/ticket_status.dart';
import 'package:frontend/features/customer/domain/entities/service_entity.dart';
import 'package:frontend/features/customer/domain/entities/ticket_entity.dart';
import 'package:frontend/features/customer/domain/repositories/customer_repository.dart';

TicketEntity customerTicket({
  int id = 7,
  String code = 'S-0001',
  int serviceId = 1,
  TicketStatus status = TicketStatus.waiting,
  int? counterId,
  bool isActive = true,
  int? queueLength = 1,
}) =>
    TicketEntity(
      id: id,
      code: code,
      serviceId: serviceId,
      status: status,
      issuedAt: DateTime(2026, 10, 11, 9),
      counterId: counterId,
      isActive: isActive,
      queueLength: queueLength,
    );

final demoServices = [
  ServiceEntity(id: 1, tag: 'Shipping', serviceTime: 5),
  ServiceEntity(id: 2, tag: 'Deposit', serviceTime: 8),
];

/// Fake repository for the customer cubit and page.
class FakeCustomerRepository implements CustomerRepository {
  List<ServiceEntity> services = demoServices;
  Object? servicesError;

  TicketEntity? activeTicket;

  /// Ticket returned by issueTicket; when [issueCompleter] is set, its future is awaited instead.
  TicketEntity issuedTicket = customerTicket();
  Object? issueError;
  Completer<TicketEntity>? issueCompleter;
  final List<int> issuedFor = [];

  /// Responses of getTicketStatus, one per call (a TicketEntity or an error to throw).
  /// When they run out, the last one is repeated.
  final List<Object> statusResponses = [];
  int statusCalls = 0;

  @override
  Future<List<ServiceEntity>> getServices() async {
    if (servicesError != null) throw servicesError!;
    return services;
  }

  @override
  Future<TicketEntity?> getActiveTicket() async => activeTicket;

  @override
  Future<TicketEntity> issueTicket(int serviceId) async {
    issuedFor.add(serviceId);
    if (issueError != null) throw issueError!;
    if (issueCompleter != null) return issueCompleter!.future;
    return issuedTicket;
  }

  @override
  Future<TicketEntity> getTicketStatus(int ticketId) async {
    final index = statusCalls < statusResponses.length ? statusCalls : statusResponses.length - 1;
    statusCalls++;
    final response = statusResponses[index];
    if (response is TicketEntity) return response;
    throw response;
  }

  @override
  Future<void> cancelTicket(int ticketId) async {
    throw UnsupportedError('not used');
  }
}
