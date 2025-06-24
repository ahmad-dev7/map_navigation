import 'package:avatar_map_navigation/MultiRoute/app_controller.dart';
import 'package:avatar_map_navigation/MultiRoute/map_screen.dart';
import 'package:avatar_map_navigation/map/controller.dart';
import 'package:avatar_map_navigation/map/map_page.dart';
import 'package:avatar_map_navigation/my_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:get/route_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: MapPage(),
    );
  }
}
