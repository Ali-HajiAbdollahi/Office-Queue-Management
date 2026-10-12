import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/ticket_status.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final Dio dio;
  CustomerRepositoryImpl({required this.dio});

  @override
  Future<List<ServiceEntity>> getServices() async {
    final response = await dio.get('/api/services');
    return (response.data as List)
        .map(
          (json) => ServiceEntity(
            id: (json['id'] as num).toInt(),
            tag: json['tag'] as String,
            serviceTime: (json['service_time'] as num).toInt(),
          ),
        )
        .toList();
  }

  @override
  Future<TicketEntity> issueTicket(int serviceId) async {
    final response = await dio.post(
      '/api/tickets',
      data: {'service_id': serviceId},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _ticketFromJson(Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<TicketEntity> getTicketStatus(int ticketId) async {
    final response = await dio.get('/api/tickets/$ticketId');
    return _ticketFromJson(Map<String, dynamic>.from(response.data as Map));
  }

  // No GET /api/tickets/active is needed: the device retains its ticket id.
  @override
  Future<TicketEntity?> getActiveTicket() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('active_ticket_id');
    if (id == null) return null;
    try {
      final ticket = await getTicketStatus(id);
      if (ticket.isActive || ticket.status == TicketStatus.called) {
        return ticket;
      }
      await prefs.remove('active_ticket_id');
      return null;
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) {
        rethrow;
      }
      await prefs.remove('active_ticket_id');
      return null;
    }
  }

  // Keep the interface, but disable the cancellation control in this sprint.
  @override
  Future<void> cancelTicket(int ticketId) async {
    throw UnsupportedError(
      'Ticket cancellation is not implemented in this scope',
    );
  }

  TicketEntity _ticketFromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'waiting' => TicketStatus.waiting,
      'served' => TicketStatus.completed,
      'called' => TicketStatus.called,
      'completed' => TicketStatus.completed,
      _ => throw FormatException('Unknown ticket status: ${json['status']}'),
    };

    return TicketEntity(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String,
      serviceId: (json['service_id'] as num).toInt(),
      status: status,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      servedAt: json['served_at'] == null
          ? null
          : DateTime.parse(json['served_at'] as String),
      counterId: (json['counter_id'] as num?)?.toInt(),
      isActive: json['is_active'] as bool,
      queueLength: (json['queue_length'] as num?)?.toInt(),
    );
  }
}
