import '../../domain/entities/service_entity.dart';
import '../../domain/entities/ticket_entity.dart';

abstract class CustomerState {}

class CustomerInitial extends CustomerState {}

class CustomerLoading extends CustomerState {}

class CustomerLoaded extends CustomerState {
  final List<ServiceEntity> services;
  final TicketEntity? activeTicket;

  CustomerLoaded({required this.services, this.activeTicket});
}

class CustomerError extends CustomerState {
  final String message;

  CustomerError(this.message);
}
