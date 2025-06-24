import 'package:avatar_map_navigation/map/components/map_options.dart';
import 'package:avatar_map_navigation/map/components/search_bar.dart';
import 'package:avatar_map_navigation/map/components/markers.dart';
import 'package:avatar_map_navigation/map/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    var ctrl = Get.put(Controller());
    return Scaffold(
      body: Obx(() {
        if (ctrl.userLocation.value == null) {
          return Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading map'),
          );
        }

        if (ctrl.isFetchingRoutes.value) {
          return Center(
            child: CircularProgressIndicator(semanticsLabel: 'Fetching routes'),
          );
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: ctrl.mapController,
              options: getMapOptions(),
              children: [
                TileLayer(urlTemplate: ctrl.mapTileUrl),
                if (ctrl.polylines.isNotEmpty)
                  PolylineLayer(polylines: ctrl.polylines),
                if (ctrl.selectedRouteIndex.value != -1)
                  PolylineLayer(polylines: ctrl.polylines),
                MarkerLayer(
                  markers: [
                    // User's current location
                    getUserMarker(),
                    if (ctrl.destinationLocation.value != null)
                      getDestinationMarker(),
                  ],
                ),
              ],
            ),
            RouteSearchBar(),
            if (ctrl.isNavigationStarted.value)
              Positioned(
                bottom: 10,
                right: 10,
                child: ElevatedButton.icon(
                  onPressed: ctrl.stopNavigation,
                  label: Text('Stop'),
                  icon: Icon(Icons.stop),
                ),
              ),
            Positioned(
              bottom: 10,
              left: 10,
              child: ElevatedButton.icon(
                onPressed: ctrl.recenter,
                label: Text('Recenter'),
                icon: Icon(Icons.location_searching),
              ),
            ),
          ],
        );
      }),
    );
  }
}
