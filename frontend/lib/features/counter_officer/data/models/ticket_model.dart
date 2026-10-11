import '../../domain/entities/ticket.dart';

class TicketModel extends Ticket {
  /// Counter che sta servendo il ticket (solo livello dati).
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

  /// Formato dell'API REST. Il tipo di servizio non è nel ticket
  /// (c'è solo `service_id`), quindi viene passato dall'esterno.
  factory TicketModel.fromApi(
    Map<String, dynamic> json, {
    required String serviceType,
  }) {
    final servedAt = json['served_at'] as String?;
    final counterId = json['counter_id'];
    return TicketModel(
      id: '${json['id']}',
      code: json['code'] as String,
      serviceType: serviceType,
      arrivalTime: DateTime.parse(json['issued_at'] as String).toLocal(),
      calledAt: servedAt == null ? null : DateTime.parse(servedAt).toLocal(),
      status: _statusFromApi(json['status'] as String),
      counterId: counterId == null ? null : '$counterId',
    );
  }

  static TicketStatus _statusFromApi(String status) => switch (status) {
        'called' => TicketStatus.serving,
        'completed' => TicketStatus.completed,
        _ => TicketStatus.waiting,
      };

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