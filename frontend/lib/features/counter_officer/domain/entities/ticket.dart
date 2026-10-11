import 'package:equatable/equatable.dart';

enum TicketStatus { waiting, serving, completed }

class Ticket extends Equatable {
  final String id;
  final String code;
  final String serviceType;
  final DateTime arrivalTime;
  final DateTime? calledAt;
  final TicketStatus status;

  const Ticket({
    required this.id,
    required this.code,
    required this.serviceType,
    required this.arrivalTime,
    this.calledAt,
    required this.status,
  });

  @override
  List<Object?> get props =>
      [id, code, serviceType, arrivalTime, calledAt, status];
}