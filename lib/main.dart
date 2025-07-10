import 'package:avatar_map_navigation/map/controller.dart';
import 'package:avatar_map_navigation/mapview/SignUp_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/instance_manager.dart';
import 'package:hive_flutter/adapters.dart';
import 'hive_models/enum_adapter.dart';
import 'hive_models/trip_model.dart';
import 'hive_models/turn_log_model.dart';
import 'hive_models/user_model.dart';
import 'mapview/hiveService.dart';

// TODO NOTE:
// User should be able to toggle turns log visibility similar to trip log
// Remove thr [Start New Trip] button from triplog page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //initialize hive
  await Hive.initFlutter();

  // Register Hive Adapters
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(TripLogAdapter());
  Hive.registerAdapter(TurnLogAdapter());
  Hive.registerAdapter(TurnDirectionAdapter());


  // Open Box
  await Hive.openBox<User>('users');

  //for dummy data purpose
  await addDummyUsers();
  //myController = Get.put(MyController());
  //appController = Get.put(AppController());
  ctrl = Get.put(Controller());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Map',
      debugShowCheckedModeBanner: false,
      //home: MapPage(),
      home: SignUpScreen(),
      // home: LoginScreen(),
    );
  }
}
