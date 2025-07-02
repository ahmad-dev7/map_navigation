

import 'package:avatar_map_navigation/hive_models/trip_model.dart';
import 'package:avatar_map_navigation/hive_models/turn_log_model.dart';
import 'package:avatar_map_navigation/hive_models/user_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> addDummyData() async {
  final box = Hive.box<User>('users');

  if (box.isEmpty) {
    final user = User(
      userId: 'U123456',
      trips: [
        Trip(
          tripId: 'T20250624001',
          startTime: DateTime(2025, 6, 24, 9, 15),
          startLat: 19.0728,
          startLong: 72.8826,
          destinationsBefore: ['Gateway of India, Mumbai'],
          destinationsDuring: ['Marine Drive, Mumbai'],
          turnLogs: [
            TurnLog(
              lat: 19.0745,
              long: 72.8811,
              timestamp: DateTime(2025, 6, 24, 9, 17),
              direction: TurnDirection.left,
            ),
            TurnLog(
              lat: 19.0761,
              long: 72.8790,
              timestamp: DateTime(2025, 6, 24, 9, 19),
              direction: TurnDirection.right
            ),
            TurnLog(
              lat: 19.0780,
              long: 72.8765,
              timestamp: DateTime(2025, 6, 24, 9, 22),
              direction: TurnDirection.uTurn,
            ),
          ],
          endLat: 19.0801,
          endLong: 72.8750,
          endTime: DateTime(2025, 6, 24, 9, 30),
          endReason: 'App closed manually by user',
          isTripCompleted: true,
        ),
        Trip(
          tripId: 'T20250622001',
          startTime: DateTime(2025, 6, 22, 20, 0),
          startLat: 18.5204,
          startLong: 73.8567,
          destinationsBefore: ['Shaniwar Wada, Pune'],
          destinationsDuring: ['Lotus Temple'],
          turnLogs: [
            TurnLog(
              lat: 18.5210,
              long: 73.8570,
              timestamp: DateTime(2025, 6, 22, 20, 2),
              direction: TurnDirection.straight,
            ),
            TurnLog(
              lat: 18.5235,
              long: 73.8589,
              timestamp: DateTime(2025, 6, 22, 20, 5),
              direction: TurnDirection.right,
            ),
          ],
          endLat: 18.5235,
          endLong: 73.8589,
          endTime: DateTime(2025, 6, 22, 20, 25),
          endReason: 'Destination reached',
          isTripCompleted: true,
        ),
      ],
    );

    await box.add(user);
    print('Dummy data added successfully.');
  } else {
    print('Dummy data already exists.');
  }
}
