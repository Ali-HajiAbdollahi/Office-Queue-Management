import 'package:equatable/equatable.dart';

class QueueSummary extends Equatable {
  final int waitingCount;
  final String? nextTicketCode;

  const QueueSummary({required this.waitingCount, this.nextTicketCode});

  bool get isEmpty => waitingCount == 0;

  @override
  List<Object?> get props => [waitingCount, nextTicketCode];
}