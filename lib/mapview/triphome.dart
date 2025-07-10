import 'package:avatar_map_navigation/hive_models/user_model.dart';
import 'package:avatar_map_navigation/mapview/trip_list.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hiveService.dart';

class TripLogHomePage extends StatefulWidget {
  const TripLogHomePage({super.key});

  @override
  State<TripLogHomePage> createState() => _TripLogHomePageState();
}

class _TripLogHomePageState extends State<TripLogHomePage> {
  final HiveService service = HiveService();
  String? loggedInUserId;

  @override
  void initState() {
    super.initState();
    loadUserId();
  }

  Future<void> loadUserId() async {
    final id = await service.getLoggedInUserId();
    setState(() {
      loggedInUserId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loggedInUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(


      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('🚗 Trip Log Viewer', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.indigo,
        elevation: 0,
        // actions: [ElevatedButton(onPressed: () => Get.to(() => TripSessionScreen()), child: Text("Start New Trip"))],
      ), body: ValueListenableBuilder(
      valueListenable: Hive.box<User>('users').listenable(),
      builder: (context, Box<User> box, _) {
        final user = box.get(loggedInUserId); // ✅ FIXED

        if (user == null) {
          return const Center(child: Text('User not found.'));
        }

        if (user.trips.isEmpty) {
          return const Center(child: Text('No trips found.'));
        }

        return TripLogViewerScreen3(user: user);
      },
    ),
    );
  }
}



