import '../../domain/entities/counter.dart';

class CounterModel extends Counter {
  const CounterModel({
    required super.id,
    required super.number,
    required super.description,
  });

  factory CounterModel.fromJson(Map<String, dynamic> json) => CounterModel(
        id: json['id'] as String,
        number: json['number'] as int,
        description: json['description'] as String,
      );

  /// Formato dell'API REST: `{ "id": 2, "name": "Counter 2" }`.
  /// L'API non fornisce una descrizione, quindi resta vuota.
  factory CounterModel.fromApi(Map<String, dynamic> json) {
    final id = json['id'] as int;
    return CounterModel(
      id: '$id',
      number: id,
      description: (json['description'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'description': description,
      };
}