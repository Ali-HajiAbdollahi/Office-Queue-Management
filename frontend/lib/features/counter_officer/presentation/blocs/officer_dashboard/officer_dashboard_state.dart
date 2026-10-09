import 'package:equatable/equatable.dart';

import '../../../domain/entities/counter.dart';
import '../../../domain/entities/queue_summary.dart';
import '../../../domain/entities/ticket.dart';

class OfficerDashboardState extends Equatable {
  final Counter counter;
  final Ticket? currentTicket;
  final QueueSummary queue;
  final bool isBusy; 
  final String? errorMessage;

  const OfficerDashboardState({
    required this.counter,
    this.currentTicket,
    this.queue = const QueueSummary(waitingCount: 0),
    this.isBusy = false,
    this.errorMessage,
  });

  bool get isServing => currentTicket != null;

  bool get canCallNext => !isServing && !queue.isEmpty && !isBusy;

  bool get canComplete => isServing && !isBusy;

  OfficerDashboardState copyWith({
    Ticket? currentTicket,
    bool clearCurrentTicket = false,
    QueueSummary? queue,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) =>
      OfficerDashboardState(
        counter: counter,
        currentTicket:
            clearCurrentTicket ? null : (currentTicket ?? this.currentTicket),
        queue: queue ?? this.queue,
        isBusy: isBusy ?? this.isBusy,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props =>
      [counter, currentTicket, queue, isBusy, errorMessage];
}