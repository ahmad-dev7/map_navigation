import 'package:avatar_map_navigation/map/controller.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

MapOptions getMapOptions() {
  return MapOptions(
    initialZoom: 18,
    maxZoom: 21,
    minZoom: 5,
    initialCenter: ctrl.userLocation.value!,
    onMapReady: () => Get.log('Map is Ready'),
    // Add interaction options for better navigation experience
    interactionOptions: InteractionOptions(
      // Disable rotation during navigation for smoother experience
      flags:
          ctrl.isNavigationStarted.value
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.all,
    ),
  );
}
