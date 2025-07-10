import 'package:avatar_map_navigation/mapview/trip_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TripSessionScreen extends StatelessWidget {
  final TripController controller = Get.put(TripController());

   TripSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('🖥️ TripSessionScreen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Session')),
      body: Center(
        child: Obx(() {
          final isOngoing = controller.isTripOngoing.value;
          print('🔁 Obx triggered: isTripOngoing = $isOngoing');
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            onPressed: () {
              isOngoing ? controller.stopTrip() : controller.startTrip();
            },
            child: Text(
              isOngoing ? 'Stop Trip' : 'Start Trip',
              style: const TextStyle(fontSize: 18),
            ),
          );
        }),
      ),
    );
  }
}
