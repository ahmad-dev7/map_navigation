import 'package:avatar_map_navigation/hive_models/user_model.dart';
import 'package:avatar_map_navigation/mapview/trip_list.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TripLogHomePage extends StatelessWidget {
  const TripLogHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Logs')),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<User>('users').listenable(),
        builder: (context, Box<User> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No user data found.'));
          }

          final user = box.getAt(0);

          if (user == null || user.trips.isEmpty) {
            return const Center(child: Text('No trips found.'));
          }

          return TripLogViewerScreen3(user: user);
        },
      ),
    );
  }
}
