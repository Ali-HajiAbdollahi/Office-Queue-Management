import 'package:equatable/equatable.dart';

import '../../../domain/entities/counter.dart';
import '../../../domain/entities/queue_summary.dart';
import '../../../domain/entities/ticket.dart';

enum OfficerDashboardStatus { loading, ready, failure }

class OfficerDashboardState extends Equatable {
  final OfficerDashboardStatus status;
  final Counter counter;
  final Ticket? currentTicket;
  final QueueSummary queue;
  final bool isBusy;
  final String? errorMessage;

  const OfficerDashboardState({
    required this.counter,
    this.status = OfficerDashboardStatus.loading,
    this.currentTicket,
    this.queue = const QueueSummary(waitingCount: 0),
    this.isBusy = false,
    this.errorMessage,
  });

  bool get isServing => currentTicket != null;

  bool get canCallNext => !isServing && !isBusy;

  bool get canComplete => isServing && !isBusy;

  OfficerDashboardState copyWith({
    OfficerDashboardStatus? status,
    Ticket? currentTicket,
    bool clearCurrentTicket = false,
    QueueSummary? queue,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) =>
      OfficerDashboardState(
        counter: counter,
        status: status ?? this.status,
        currentTicket:
            clearCurrentTicket ? null : (currentTicket ?? this.currentTicket),
        queue: queue ?? this.queue,
        isBusy: isBusy ?? this.isBusy,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props =>
      [status, counter, currentTicket, queue, isBusy, errorMessage];
}