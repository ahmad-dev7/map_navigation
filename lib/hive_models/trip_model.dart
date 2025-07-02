import 'package:avatar_map_navigation/hive_models/turn_log_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

 part 'trip_model.g.dart';

@HiveType(typeId: 1)
class Trip extends HiveObject {
  @HiveField(0)
  String tripId;

  @HiveField(1)
  DateTime startTime;

  @HiveField(2)
  double startLat;

  @HiveField(3)
  double startLong;

  @HiveField(4)
  List<String> destinationsBefore;

  @HiveField(5)
  List<String> destinationsDuring;

  @HiveField(6)
  List<TurnLog> turnLogs;

  @HiveField(7)
  double? endLat;

  @HiveField(8)
  double? endLong;

  @HiveField(9)
  DateTime? endTime;

  @HiveField(10)
  String? endReason;

  @HiveField(11)
  bool isTripCompleted;

  Trip({
    required this.tripId,
    required this.startTime,
    required this.startLat,
    required this.startLong,
    required this.destinationsBefore,
    required this.destinationsDuring,
    required this.turnLogs,
    this.endLat,
    this.endLong,
    this.endTime,
    this.endReason,
    this.isTripCompleted = false,
  });
}
