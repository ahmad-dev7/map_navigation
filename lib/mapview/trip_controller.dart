import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../hive_models/trip_model.dart';
import '../hive_models/turn_log_model.dart';
import 'hiveService.dart';

class TripController extends GetxController {
  final HiveService _hiveService = HiveService();

  RxBool isTripOngoing = false.obs;
  Timer? _timer;
  late TripLog currentTrip;
  int turnCount = 0;

  // Start trip for logged-in user
  Future<void> startTrip() async {
    print('🔄 Attempting to start trip...');
    final userId = await _hiveService.getLoggedInUserId();
    if (userId == null) {
      print('❌ No logged-in user found!');
      return;
    }

    final userBox = await _hiveService.getUserBox();
    final user = userBox.get(userId);

    if (user == null) {
      print('❌ User not found in Hive for ID: $userId');
      return;
    }

    final timestamp = DateTime.now();
    final newTrip = TripLog(
      tripId:
          'T${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}${timestamp.hour}${timestamp.minute}${timestamp.second}',
      startTime: timestamp,
      startLat: 28.6139,
      startLong: 77.2090,
      destinationsBefore: ['India Gate', 'Red Fort'],
      destinationsDuring: ['Connaught Place', 'Lotus Temple'],
      turnLogs: [
        TurnLog(
          lat: 28.6145,
          long: 77.2100,
          timestamp: timestamp.add(const Duration(seconds: 5)),
          direction: TurnDirection.left,
          instruction: ": Turn left onto Sakal Bhavan Marg",
        ),
        TurnLog(
          lat: 28.6155,
          long: 77.2120,
          timestamp: timestamp.add(const Duration(seconds: 10)),
          direction: TurnDirection.right,
          instruction: ": Turn left onto Sakal Bhavan Marg",
        ),
      ],
      endLat: 28.6200,
      endLong: 77.2150,
      endTime: timestamp,
      endReason: 'Trip in progress',
      isTripCompleted: false,
    );
    user.trips = [
      ...user.trips,
      newTrip,
    ]; // 🔁 reassign the list (not just add)
    await userBox.put(userId, user); // ✅ now it will notify listeners

    currentTrip = user.trips.last;
    isTripOngoing.value = true;

    print('✅ Trip started for user: $userId - ${currentTrip.tripId}');
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => updateTripData(),
    );
  }

  Future<void> updateTripData() async {
    if (!isTripOngoing.value) return;

    turnCount++;
    final newLog = TurnLog(
      lat: 18.0 + turnCount * 0.001,
      long: 73.0 + turnCount * 0.001,
      timestamp: DateTime.now(),
      direction: TurnDirection.values[turnCount % TurnDirection.values.length],
      instruction: ": Turn left onto Sakal Bhavan Marg",
    );

    currentTrip.turnLogs.add(newLog);
    print(
      '📍 TurnLog #$turnCount: (${newLog.lat}, ${newLog.long}) ➝ ${newLog.direction}',
    );

    final userId = await _hiveService.getLoggedInUserId();
    if (userId == null) return;

    final userBox = await _hiveService.getUserBox();
    final user = userBox.get(userId);
    if (user == null) return;

    user.trips[user.trips.length - 1] = currentTrip;
    await userBox.put(userId, user);

    print('📦 Trip updated for $userId in Hive');

    Get.snackbar(
      'Trip Updated',
      'Lat: ${newLog.lat.toStringAsFixed(5)}, '
          'Long: ${newLog.long.toStringAsFixed(5)}\n'
          'Time: ${newLog.timestamp.toLocal().toIso8601String()}\n'
          'Direction: ${newLog.direction.name}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF323232),
      colorText: Colors.white,
      margin: const EdgeInsets.all(10),
    );
  }

  Future<void> stopTrip() async {
    print('🛑 Stopping trip...');
    _timer?.cancel();
    _timer = null;

    currentTrip.endTime = DateTime.now();
    currentTrip.endLat = 18.5;
    currentTrip.endLong = 73.5;
    currentTrip.endReason = 'Stopped by user';
    currentTrip.isTripCompleted = true;

    final userId = await _hiveService.getLoggedInUserId();
    if (userId == null) return;

    final userBox = await _hiveService.getUserBox();
    final user = userBox.get(userId);
    if (user == null) return;

    user.trips[user.trips.length - 1] = currentTrip;
    await userBox.put(userId, user);

    print('✅ Trip stopped and saved: ${currentTrip.tripId}');
    isTripOngoing.value = false;
  }

  @override
  void onClose() {
    _timer?.cancel();
    print('🧹 Timer cancelled in onClose()');
    super.onClose();
  }
}
