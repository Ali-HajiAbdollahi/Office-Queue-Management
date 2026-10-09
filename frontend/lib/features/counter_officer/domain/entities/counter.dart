import 'package:equatable/equatable.dart';

class Counter extends Equatable {
  final String id;
  final int number;
  final String description;

  const Counter({
    required this.id,
    required this.number,
    required this.description,
  });

  String get name => 'Counter $number';

  @override
  List<Object?> get props => [id, number, description];
}