import '../../../../core/enums/ticket_status.dart';

class TicketEntity {
  final int id;
  final String code;
  final int serviceId;
  final TicketStatus status;
  final DateTime issuedAt;
  final DateTime? servedAt;
  final int? counterId;

  TicketEntity({
    required this.id,
    required this.code,
    required this.serviceId,
    required this.status,
    required this.issuedAt,
    this.servedAt,
    this.counterId,
  });
}
