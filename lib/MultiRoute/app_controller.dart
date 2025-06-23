import 'dart:async';
import 'dart:convert';

import 'package:avatar_map_navigation/search_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

late AppController appController;

class RouteData {
  final String polyline;
  final List<String> instructions;

  RouteData({required this.polyline, required this.instructions});
}

class AppController extends GetxController with GetTickerProviderStateMixin {
  // OpenStreet map tiles url
  var mapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  // Map controller
  var mapController = MapControllerImpl();
  // Current location of user
  Rx<LatLng?> userLocation = Rx<LatLng?>(null);
  // Destination location of the route user'll be traveling
  Rx<LatLng?> destinationLocation = Rx<LatLng?>(null);
  // Current heading of user [Mobile]
  RxDouble userHeading = 0.0.obs;
  // Destination search bar controller
  var searchBarController = FloatingSearchBarController();
  // Is navigation started
  var isNavigationStarted = false.obs;
  // Is search hints loading
  var isSearchHintsLoading = false.obs;
  // Search value from SearchBar
  var searchText = ''.obs;
  // Searched hints options
  var destinationOptions = [].obs;

  final routes = <RouteData>[].obs;
  final selectedRouteIndex = 0.obs;

  // Animation controllers for smooth marker movement
  late AnimationController _markerAnimationController;
  late Animation<double> _markerAnimation;
  LatLng? _animationStartLocation;
  LatLng? _animationEndLocation;
  Timer? _animationTimer;

  StreamSubscription<Position>? _navigationStream;

  @override
  void onInit() {
    super.onInit();

    // Initialize animation controller
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _markerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _markerAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _markerAnimation.addListener(_updateAnimatedLocation);

    getUserLocation();
    _listenToCompass();
  }

  RouteData get currentRoute =>
      routes.isNotEmpty
          ? routes[selectedRouteIndex.value]
          : RouteData(polyline: '', instructions: []);

  Future<void> fetchRoutesFromValhalla({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    final url = Uri.parse(
      'https://valhalla1.openstreetmap.de/route?json={"locations":[{"lat":$startLat,"lon":$startLon},{"lat":$endLat,"lon":$endLon}],"costing":"auto","alternates":true,"directions_options":{"units":"kilometers"}}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        parseValhallaResponse(responseJson);
      } else {
        print("Valhalla API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Failed to fetch route: $e");
    }
  }

  // INFO: multi route parse
  void parseValhallaResponse(Map<String, dynamic> valhallaResponse) {
    routes.clear();

    void addRouteFromTrip(Map<String, dynamic> trip) {
      if (trip.containsKey('legs') && trip['legs'].isNotEmpty) {
        final leg = trip['legs'][0];
        final polyline = leg['shape'] ?? '';
        final maneuvers = leg['maneuvers'] as List;
        final instructions =
            maneuvers.map((m) => m['instruction'].toString()).toList();
        routes.add(RouteData(polyline: polyline, instructions: instructions));
      }
    }

    // Add main trip
    if (valhallaResponse.containsKey('trip')) {
      addRouteFromTrip(valhallaResponse['trip']);
    }

    // Add alternates
    if (valhallaResponse.containsKey('alternates')) {
      for (var alt in valhallaResponse['alternates']) {
        if (alt.containsKey('trip')) {
          addRouteFromTrip(alt['trip']);
        }
      }
    }

    selectedRouteIndex.value = 0;
  }

  // INFO: select route
  void selectRoute(int index) {
    if (index >= 0 && index < routes.length) {
      selectedRouteIndex.value = index;
      // Optionally call map update logic here
    }
  }

  // INFO: Smooth marker animation update
  void _updateAnimatedLocation() {
    if (_animationStartLocation != null && _animationEndLocation != null) {
      final progress = _markerAnimation.value;
      final lat =
          _animationStartLocation!.latitude +
          ((_animationEndLocation!.latitude -
                  _animationStartLocation!.latitude) *
              progress);
      final lng =
          _animationStartLocation!.longitude +
          ((_animationEndLocation!.longitude -
                  _animationStartLocation!.longitude) *
              progress);

      userLocation.value = LatLng(lat, lng);
    }
  }

  // INFO: Start smooth animation to new location
  void _animateToNewLocation(LatLng newLocation) {
    if (userLocation.value == null) {
      userLocation.value = newLocation;
      return;
    }

    _animationStartLocation = userLocation.value;
    _animationEndLocation = newLocation;

    _markerAnimationController.reset();
    _markerAnimationController.forward();
  }

  // INFO: Fetching user location
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
        _animateToNewLocation(newLocation);
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

  // INFO: Find destination locations
  void searchDestination(String? query) async {
    if (query == null || query.trim().isEmpty) {
      searchText.value = '';
      destinationOptions.clear();
      return;
    }

    searchText.value = query;
    isSearchHintsLoading.value = true;
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
      isSearchHintsLoading.value = false;
    }
  }

  @override
  void onClose() {
    _markerAnimationController.dispose();
    _animationTimer?.cancel();
    _navigationStream?.cancel();
    super.onClose();
  }
}
