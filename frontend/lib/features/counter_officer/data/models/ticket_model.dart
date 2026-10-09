import '../../domain/entities/ticket.dart';

class TicketModel extends Ticket {
  final String? counterId;

  const TicketModel({
    required super.id,
    required super.code,
    required super.serviceType,
    required super.arrivalTime,
    super.calledAt,
    required super.status,
    this.counterId,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
        id: json['id'] as String,
        code: json['code'] as String,
        serviceType: json['serviceType'] as String,
        arrivalTime: DateTime.parse(json['arrivalTime'] as String),
        calledAt: json['calledAt'] == null
            ? null
            : DateTime.parse(json['calledAt'] as String),
        status: TicketStatus.values.byName(json['status'] as String),
        counterId: json['counterId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'serviceType': serviceType,
        'arrivalTime': arrivalTime.toIso8601String(),
        'calledAt': calledAt?.toIso8601String(),
        'status': status.name,
        'counterId': counterId,
      };

  TicketModel copyWith({
    DateTime? calledAt,
    TicketStatus? status,
    String? counterId,
  }) =>
      TicketModel(
        id: id,
        code: code,
        serviceType: serviceType,
        arrivalTime: arrivalTime,
        calledAt: calledAt ?? this.calledAt,
        status: status ?? this.status,
        counterId: counterId ?? this.counterId,
      );

  @override
  List<Object?> get props => [...super.props, counterId];
}