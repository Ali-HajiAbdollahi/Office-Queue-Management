import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/queue_summary.dart';
import '../models/counter_model.dart';
import '../models/ticket_model.dart';
import 'counter_officer_data_source.dart';

/// Implementazione REST. Il base URL (es. http://localhost:3000/api)
/// si imposta sull'istanza di Dio passata dal costruttore.
class RemoteCounterOfficerDataSource implements CounterOfficerDataSource {
  final Dio _dio;
  final Duration pollInterval;

  RemoteCounterOfficerDataSource(
    this._dio, {
    this.pollInterval = const Duration(seconds: 3),
  });

  /// Ticket servito da ciascun counter: l'API non ha un endpoint per
  /// leggerlo, quindi lo teniamo in memoria dopo call-next.
  final Map<String, TicketModel> _current = {};
  final _changes = StreamController<String>.broadcast();
  Map<int, String>? _services;

  Future<Map<int, String>> _serviceNames() async {
    final cached = _services;
    if (cached != null) return cached;

    final res = await _dio.get<List<dynamic>>('/services');
    final map = <int, String>{};
    for (final raw in res.data!) {
      final s = raw as Map<String, dynamic>;
      map[s['id'] as int] = s['tag'] as String;
    }
    return _services = map;
  }

  @override
  Future<List<CounterModel>> getCounters() async {
    final res = await _dio.get<List<dynamic>>('/counters');
    return [
      for (final raw in res.data!)
        CounterModel.fromApi(raw as Map<String, dynamic>),
    ];
  }

  @override
  Stream<TicketModel?> watchCurrentTicket(String counterId) async* {
    yield _current[counterId];
    await for (final id in _changes.stream) {
      if (id == counterId) yield _current[counterId];
    }
  }

  /// Polling: l'API non definisce ancora WebSocket/SSE.
  @override
  Stream<QueueSummary> watchQueue(String counterId) async* {
    while (true) {
      yield await _fetchQueue(counterId);
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<QueueSummary> _fetchQueue(String counterId) async {
    // Queue statistics are hidden for this sprint.
    // final res = await _dio.get<Map<String, dynamic>>(
    //   '/counters/$counterId/queue-stats',
    // );
    // final json = res.data!;
    // return QueueSummary(
    //   waitingCount: json['waiting_count'] as int,
    //   nextTicketCode: json['next_ticket_code'] as String?,
    // );
    return const QueueSummary(waitingCount: 0);
  }

  @override
  Future<TicketModel?> callNextTicket(String counterId) async {
    final names = await _serviceNames();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/counters/$counterId/call-next',
      );
      final json = res.data!;
      final serviceId = json['service_id'];
      final ticket = TicketModel.fromApi(
        json,
        serviceType: names[serviceId] ?? 'Service $serviceId',
      );
      _current[counterId] = ticket;
      _changes.add(counterId);
      return ticket;
    } on DioException catch (e) {
      // 404 = nessun ticket in attesa per i servizi di questo counter.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> completeTicket(String ticketId) async {
    await _dio.put<void>('/tickets/$ticketId/complete');
    final counters = _current.entries
        .where((e) => e.value.id == ticketId)
        .map((e) => e.key)
        .toList();
    for (final c in counters) {
      _current.remove(c);
      _changes.add(c);
    }
  }
}
