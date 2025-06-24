import 'dart:async';
import 'dart:convert';
import 'package:avatar_map_navigation/map/components/route_model.dart';
import 'package:avatar_map_navigation/map/components/route_selection_sheet.dart';
import 'package:avatar_map_navigation/search_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

late Controller ctrl;

class Controller extends GetxController with GetTickerProviderStateMixin {
  var mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  var mapController = MapControllerImpl();
  var userLocation = Rx<LatLng?>(null);
  var destinationLocation = Rx<LatLng?>(null);
  var userHeading = 0.0.obs;
  var isNavigationStarted = false.obs;
  var searchController = FloatingSearchBarController();
  var isLoadingSearchOptions = false.obs;
  var isFetchingRoutes = false.obs;
  var selectedRouteIndex = (-1).obs;
  // For search suggestions
  var destinationOptions = [].obs;
  // This contains both the main route and alternate routes if available
  var routes = <RouteModel>[].obs;
  // Contains all polylines
  var polylines = <Polyline>[].obs;

  // Animation controllers for smooth marker movement
  late AnimationController _markerAnimationController;
  late Animation<double> _markerAnimation;
  LatLng? _animationStartLocation;
  LatLng? _animationEndLocation;
  Timer? _animationTimer;
  StreamSubscription<Position>? _navigationStream;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    getUserLocation();
    _listenToCompass();
  }

  @override
  void onClose() {
    _markerAnimationController.dispose();
    _animationTimer?.cancel();
    _navigationStream?.cancel();
    super.onClose();
  }

  //INFO: Get current location of user
  void getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar('Location Error', 'Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar('Permission Denied', 'Location permission is denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar(
        'Permission Denied',
        'Location permissions are permanently denied.',
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
    );
    userLocation.value = LatLng(position.latitude, position.longitude);

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      final newLocation = LatLng(pos.latitude, pos.longitude);

      // Only animate if navigation is not started
      if (!isNavigationStarted.value) {
        //TODO Add this function later
        // _animateToNewLocation(newLocation);
      }
    });
  }

  // INFO: updates user heading as user rotates phone
  void _listenToCompass() {
    FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        userHeading.value = event.heading!;
      }
    });
  }

  // INFO: Find destination locations
  searchDestination(String? query) async {
    if (query == null || query.trim().isEmpty) {
      searchController.query = '';
      destinationOptions.clear();
      return;
    }

    searchController.query = query;
    isLoadingSearchOptions.value = true;
    destinationOptions.clear();

    var destinationUrl = 'https://photon.komoot.io/api/?q=$query&limit=7';
    try {
      var response = await http.get(Uri.parse(destinationUrl));
      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        var searchResult = SearchResult.fromJson(jsonData);
        destinationOptions.assignAll(searchResult.features);
      }
    } catch (e) {
      Get.log("Exception during destination search: $e");
    } finally {
      isLoadingSearchOptions.value = false;
    }
  }

  // INFO: Fetch routes
  void fetchRoutes({LatLng? source, required LatLng destination}) async {
    var start = source ?? userLocation.value;
    var baseUrl = 'https://valhalla1.openstreetmap.de/route';
    var body = {
      "locations": [
        {"lat": start!.latitude, "lon": start.longitude},
        {"lat": destination.latitude, "lon": destination.longitude},
      ],
      "costing": "auto",
      "alternates": true,
      "directions_options": {"units": "kilometers"},
    };

    try {
      isFetchingRoutes.value = true;
      var response = await http.post(
        Uri.parse(baseUrl),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'}, // Add this header
      );

      Get.log(jsonEncode(body));
      Get.log('Response Status: ${response.statusCode}');
      Get.log(
        'Response Body: ${response.body}',
      ); // Add this to see the full response

      //* Check if the data is fetched successfully
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        // Clear previous routes and polylines
        routes.clear();
        polylines.clear();

        // Parse main route
        var mainRoute = RouteModel.fromJson(data);
        var allRoutes = <RouteModel>[mainRoute];

        // Parse alternate routes with proper null checking
        if (data['alternates'] != null && data['alternates'] is List) {
          var alternatesData = data['alternates'] as List;
          for (var alternateData in alternatesData) {
            // Check if the alternate route has a valid trip
            if (alternateData != null &&
                alternateData['trip'] != null &&
                alternateData['trip']['legs'] != null) {
              var alternateRoute = RouteModel.fromJson(alternateData);
              allRoutes.add(alternateRoute);
            }
          }
        }

        routes.value = allRoutes;

        // Generate polylines for all routes
        for (int i = 0; i < routes.length; i++) {
          var route = routes[i];

          // Check if route has valid data
          if (route.trip?.legs != null && route.trip!.legs!.isNotEmpty) {
            var encodedString = route.trip!.legs!.first.shape ?? '';

            if (encodedString.isNotEmpty) {
              var decodedPolyline = _decodePolyline(encodedString);
              if (decodedPolyline.isNotEmpty) {
                polylines.add(
                  Polyline(
                    points: decodedPolyline,
                    strokeWidth: i == 0 ? 8 : 6,
                    color: i == 0 ? Colors.blue : Colors.green,
                  ),
                );
              } else {
                Get.log('Decoded polyline is empty for route $i');
              }
            }
          }
        }
        // Update UI before showing bottom sheet
        update(['routes']);

        isFetchingRoutes.value = false;

        Get.bottomSheet(
          RouteSelectionSheet(),
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
        );
        Get.log('Successfully fetched ${routes.length} routes');
      } else {
        Get.log('Error Response: ${response.body}');
        Get.showSnackbar(
          GetSnackBar(
            title: 'Error Occurred',
            message: 'Server returned status: ${response.statusCode}',
          ),
        );
        isFetchingRoutes.value = false;
      }
    } catch (e) {
      Get.log('Exception: $e');
      isFetchingRoutes.value = false;
      Get.showSnackbar(
        GetSnackBar(
          title: 'Error Occurred',
          message: 'Failed to fetch routes. Please try again later.',
        ),
      );
    }
  }

  // INFO: Decode polyline
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e6, lng / 1e6));
    }

    return points;
  }

  // INFO: Stop navigation
  void stopNavigation() {
    isNavigationStarted.value = false;
    selectedRouteIndex.value = -1;
    polylines.clear();
    routes.clear();
    _navigationStream?.cancel();
    _navigationStream = null;
    //_previousLocation = null;
    //_currentRouteSegmentIndex = 0;
    //polylinePoints.clear();
    destinationLocation.value = null;
    //_fullPolylinePoints.clear();

    // Stop marker animation
    _markerAnimationController.stop();

    // Reset map rotation
    if (userLocation.value != null) {
      mapController.moveAndRotateAnimatedRaw(
        userLocation.value!,
        17.0,
        0.0,
        offset: Offset.zero,
        duration: Durations.extralong4,
        curve: Curves.easeOut,
        hasGesture: false,
        source: MapEventSource.custom,
      );
    }
  }

  // INFO: Recenter map to focus on user's location
  void recenter({double? degreeOfRotation, Duration? duration}) {
    if (userLocation.value == null) return;
    mapController.moveAndRotateAnimatedRaw(
      userLocation.value!,
      17,
      degreeOfRotation ?? 0.0,
      offset: Offset.zero,
      duration: duration ?? Durations.extralong4,
      curve: Curves.easeOut,
      hasGesture: false,
      source: MapEventSource.custom,
    );
  }

  // INFO: Start navigation
  void startNavigation() {
    if (selectedRouteIndex.value != -1) {
      isNavigationStarted.value = true;
      polylines.clear();
      polylines.add(
        Polyline(
          points: _decodePolyline(
            routes[selectedRouteIndex.value].trip!.legs![0].shape!,
          ),
          strokeWidth: 8,
          color: Colors.blue,
        ),
      );
      recenter();
    }
  }
}
