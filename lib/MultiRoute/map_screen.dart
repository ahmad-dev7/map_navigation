import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'route_controller.dart';

class MultiRouteMapScreen extends StatelessWidget {
  const MultiRouteMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RouteController controller = Get.put(RouteController());

    // Define colors for different routes
    final List<Color> routeColors = [
      Colors.blue, // Main route
      Colors.red, // Alternate route 1
      Colors.green, // Alternate route 2
      Colors.orange, // Alternate route 3
      Colors.purple, // Alternate route 4
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshRoutes(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading routes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.refreshRoutes(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return FlutterMap(
          options: MapOptions(
            // Center the map between source and destination
            initialCenter: LatLng(
              (controller.sourceLat + controller.destLat) / 2,
              (controller.sourceLon + controller.destLon) / 2,
            ),
            initialZoom: 12.0,
          ),
          children: [
            // Tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),

            // Polyline layer for routes
            PolylineLayer(
              polylines:
                  controller.routes.asMap().entries.map((entry) {
                    int index = entry.key;
                    List<LatLng> route = entry.value;

                    return Polyline(
                      points: route,
                      strokeWidth: index == 0 ? 6.0 : 5.0, // Main route thicker
                      color: routeColors[index % routeColors.length],
                    );
                  }).toList(),
            ),

            // Marker layer for source and destination
            MarkerLayer(
              markers: [
                // Source marker
                Marker(
                  point: LatLng(controller.sourceLat, controller.sourceLon),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

                // Destination marker
                Marker(
                  point: LatLng(controller.destLat, controller.destLon),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),

      // Floating action button to show route info
      floatingActionButton: Obx(() {
        if (controller.routes.isEmpty) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          onPressed: () {
            _showRouteInfo(context, controller);
          },
          label: Text('${controller.routes.length} Routes'),
          icon: const Icon(Icons.route),
        );
      }),
    );
  }

  void _showRouteInfo(BuildContext context, RouteController controller) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Route Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total routes found: ${controller.routes.length}'),
                const SizedBox(height: 8),
                ...controller.routes.asMap().entries.map((entry) {
                  int index = entry.key;
                  List<LatLng> route = entry.value;
                  String routeType =
                      index == 0 ? 'Main Route' : 'Alternate $index';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                [
                                  Colors.blue,
                                  Colors.red,
                                  Colors.green,
                                  Colors.orange,
                                  Colors.purple,
                                ][index % 5],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$routeType (${route.length} points)'),
                      ],
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
