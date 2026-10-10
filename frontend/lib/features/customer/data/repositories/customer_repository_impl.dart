import 'package:dio/dio.dart';

import '../../../../core/enums/ticket_status.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final Dio dio;

  CustomerRepositoryImpl({required this.dio});

  @override
  Future<TicketEntity?> getActiveTicket() async {
    try {
      final response = await dio.get('/api/tickets/active');
      final data = response.data;

      if (data == null) {
        return null;
      }

      return _ticketFromJson(data);
    } catch (e) {
      throw Exception('Failed to load active ticket: $e');
    }
  }

  @override
  Future<List<ServiceEntity>> getServices() async {
    try {
      final response = await dio.get('/api/services');

      return (response.data as List).map((json) {
        return ServiceEntity(
          id: int.parse(json['id'].toString()),
          tag: json['name'] ?? 'Unknown Service',
          serviceTime: json['service_time'] ?? 0,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to load services: $e');
    }
  }

  @override
  Future<TicketEntity> issueTicket(int serviceId) async {
    try {
      final response = await dio.post(
        '/api/tickets',
        data: {'service_id': serviceId},
      );

      return _ticketFromJson(response.data, serviceId: serviceId);
    } catch (e) {
      throw Exception('Failed to issue ticket: $e');
    }
  }

  @override
  Future<TicketEntity> getTicketStatus(int ticketId) async {
    try {
      final response = await dio.get('/api/tickets/$ticketId');

      return _ticketFromJson(response.data, ticketId: ticketId);
    } catch (e) {
      throw Exception('Failed to get ticket status: $e');
    }
  }

  @override
  Future<void> cancelTicket(int ticketId) async {
    try {
      await dio.delete('/api/tickets/$ticketId');
    } catch (e) {
      throw Exception('Failed to cancel ticket: $e');
    }
  }

  TicketEntity _ticketFromJson(dynamic json, {int? ticketId, int? serviceId}) {
    return TicketEntity(
      id: ticketId ?? int.parse(json['id'].toString()),
      code: json['code'] ?? 'A-000',
      serviceId: serviceId ?? int.parse(json['service_id'].toString()),
      issuedAt: DateTime.now(),
      status: json['status'] == 'called'
          ? TicketStatus.called
          : TicketStatus.waiting,
      counterId: json['counter_id'] == null
          ? null
          : int.parse(json['counter_id'].toString()),
    );
  }
}
