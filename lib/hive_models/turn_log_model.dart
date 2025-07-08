import 'package:hive_flutter/hive_flutter.dart';

part 'turn_log_model.g.dart';

enum TurnDirection { left, right, uTurn, straight }

@HiveType(typeId: 2)
class TurnLog extends HiveObject {
  @HiveField(0)
  double lat;

  @HiveField(1)
  double long;

  @HiveField(2)
  DateTime timestamp;

  @HiveField(3)
  final TurnDirection direction;

  @HiveField(4)
  String instruction;

  TurnLog({
    required this.lat,
    required this.long,
    required this.timestamp,
    required this.direction,
    required this.instruction,
  });

  @override
  String toString() {
    return '''
TurnLog {
  lat: $lat,
  long: $long,
  timestamp: $timestamp,
  direction: $direction,
  instruction: $instruction,
}
''';
  }
}
