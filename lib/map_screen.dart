import 'dart:math' as math;
import 'package:avatar_glow/avatar_glow.dart';
import 'package:avatar_map_navigation/animated_marker.dart';
import 'package:avatar_map_navigation/custom_search_bar.dart';
import 'package:avatar_map_navigation/my_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Obx(() {
        var isStarted = myController.isNavigationStarted.value;
        return FloatingActionButton.extended(
          onPressed:
              isStarted
                  ? myController.stopNavigation
                  : myController.startNavigation,
          label: Text(isStarted ? 'Stop' : 'Start Navigation'),
          icon: Icon(isStarted ? Icons.stop : CupertinoIcons.location_north),
          backgroundColor: isStarted ? Colors.red[100] : null,
        );
      }),
      body: Obx(() {
        if (myController.userLocation.value == null) {
          return Center(child: CupertinoActivityIndicator.partiallyRevealed());
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: myController.mapController,
              options: MapOptions(
                initialZoom: 18,
                maxZoom: 21,
                minZoom: 5,
                initialCenter: myController.userLocation.value!,
                onMapReady: () => Get.log('Map is Ready'),
                // Add interaction options for better navigation experience
                interactionOptions: InteractionOptions(
                  // Disable rotation during navigation for smoother experience
                  flags:
                      myController.isNavigationStarted.value
                          ? InteractiveFlag.all & ~InteractiveFlag.rotate
                          : InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(urlTemplate: myController.mapUrl),

                // Enhanced PolylineLayer with better rendering
                if (myController.polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: myController.polylinePoints,
                    // Add performance optimizations for smoother rendering
                  ),

                MarkerLayer(
                  markers: [
                    // Enhanced user location marker with smooth animations
                    Marker(
                      point: myController.userLocation.value!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Transform.rotate(
                          angle:
                              myController.isNavigationStarted.value
                                  ? (myController.userHeading.value) *
                                      (math.pi / 180)
                                  : 0,
                          child: AvatarGlow(
                            glowColor:
                                myController.isNavigationStarted.value
                                    ? Colors.greenAccent
                                    : Colors.blueAccent,
                            //endRadius: myController.isNavigationStarted.value ? 25.0 : 20.0,
                            duration: Duration(milliseconds: 2000),
                            repeat: true,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    myController.isNavigationStarted.value
                                        ? Colors.green
                                        : Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                myController.isNavigationStarted.value
                                    ? CupertinoIcons.location_north_fill
                                    : Icons.circle,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Enhanced destination marker
                    if (myController.destinationLocation.value != null)
                      Marker(
                        point: myController.destinationLocation.value!,
                        width: 50,
                        height: 50,
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Destination',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Icon(
                                Icons.location_pin,
                                size: 30,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            if (!myController.isNavigationStarted.value)
              // Show search bar if navigation is not started
              CustomSearchBar(),

            if (myController.isNavigationStarted.value)
              // Enhanced instruction panel with animations
              SafeArea(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.all(8),
                  child: Material(
                    type: MaterialType.card,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.blue[100]!, Colors.blue[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            myController.instructionTitle.value,
                            key: ValueKey(myController.instructionTitle.value),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        subtitle: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            myController.instructionSubtitle.value,
                            key: ValueKey(
                              myController.instructionSubtitle.value,
                            ),
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        leading: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            key: ValueKey(myController.instructionIcon.value),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              myController.instructionIcon.value,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Enhanced loader with better UX
            if (myController.isLoading.value)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Calculating route...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Enhanced recenter button
            Positioned(
              bottom: 20,
              left: 20,
              child: SafeArea(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton.icon(
                    onPressed: myController.recenter,

                    label: Text('Recenter'),
                    icon: Icon(Icons.my_location),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
