import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:avatar_map_navigation/hive_models/trip_model.dart';
import 'package:avatar_map_navigation/hive_models/turn_log_model.dart';
import 'package:avatar_map_navigation/map/components/route_model.dart';
import 'package:avatar_map_navigation/map/components/route_selection_sheet.dart';
import 'package:avatar_map_navigation/mapview/hiveService.dart';
import 'package:avatar_map_navigation/mapview/triphome.dart';
import 'package:avatar_map_navigation/search_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

//TODO: visit stopNvaigation method for trip log flow [Line 735]
late Controller ctrl;

class Controller extends GetxController with GetTickerProviderStateMixin {
  var mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  var mapController = MapControllerImpl();
  var userLocation = Rx<LatLng?>(null);
  var destinationLocation = Rx<LatLng?>(null);
  var tripLog = Rx<TripLog?>(null);
  // for user location marker rotation
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

  // Navigation instruction variables
  var currentManeuvers = <Maneuvers>[].obs;
  var currentInstructionIndex = 0.obs;
  var currentInstruction = "".obs;
  var nextInstruction = "".obs;
  var distanceToNextInstruction = 0.0.obs;
  var isApproachingInstruction = false.obs;

  // Navigation specific variables
  var currentRoutePolylinePoints = <LatLng>[].obs;
  var currentBearing = 0.0.obs;
  var distanceToDestination = 0.0.obs;
  var currentSegmentIndex = 0.obs;
  var traveledPolylinePoints = <LatLng>[].obs; // Gray polyline - traveled path
  var upcomingPolylinePoints = <LatLng>[].obs; // Blue polyline - upcoming path
  LatLng? _previousLocation;
  LatLng? _navigationStartLocation;
  Timer? _navigationTimer;

  // Enhanced navigation variables for smooth experience
  List<LatLng> _fullRoutePolylinePoints = [];
  int _currentRouteSegmentIndex = 0;
  final Distance _distance = const Distance();

  // Reroute specific variables
  var isRerouteInProgress = false.obs;
  var offRouteThreshold = 25.0; // meters
  var offRouteCount = 0; // Counter to avoid false positives
  var maxOffRouteCount = 3; // Trigger reroute after 3 consecutive off-route readings
  List<LatLng> _originalRoutePoints = []; // Store original route
  List<LatLng> _passedRoutePoints = []; // Points user has already passed
  LatLng? _lastOnRoutePoint; // Last point where user was on route
  LatLng? _rerouteStartPoint; // Point where reroute started
  bool _hasRerouted = false; // Flag to track if reroute has occurred
  List<LatLng> _rerouteConnectorPoints = []; // Points connecting old route to new route

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
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

  @override
  void onClose() {
    _markerAnimationController.dispose();
    _animationTimer?.cancel();
    _navigationStream?.cancel();
    _navigationTimer?.cancel();
    super.onClose();
  }

  // Add this method to initialize navigation instructions
  void _initializeNavigationInstructions() {
    if (selectedRouteIndex.value == -1 || routes.isEmpty) return;

    final selectedRoute = routes[selectedRouteIndex.value];
    if (selectedRoute.trip?.legs != null &&
        selectedRoute.trip!.legs!.isNotEmpty) {
      currentManeuvers.value = selectedRoute.trip!.legs!.first.maneuvers ?? [];
      currentInstructionIndex.value = 0;
      _updateCurrentInstruction();
    }
  }

  // Add this method to update current instruction based on user location
  void _updateNavigationInstructions(LatLng userLocation) {
    if (currentManeuvers.isEmpty || _fullRoutePolylinePoints.isEmpty) return;

    // Find which instruction segment the user is currently on
    int newInstructionIndex = _findCurrentInstructionIndex(userLocation);

    if (newInstructionIndex != currentInstructionIndex.value) {
      currentInstructionIndex.value = newInstructionIndex;
      _updateCurrentInstruction();
    }

    // Calculate distance to next instruction
    _calculateDistanceToNextInstruction(userLocation);
  }

  // Find current instruction index based on user location
  int _findCurrentInstructionIndex(LatLng userLocation) {
    if (currentManeuvers.isEmpty) return 0;

    // Convert current route segment to instruction index
    // Each maneuver has beginShapeIndex and endShapeIndex
    for (int i = 0; i < currentManeuvers.length; i++) {
      final maneuver = currentManeuvers[i];
      final beginIndex = maneuver.beginShapeIndex ?? 0;
      final endIndex =
          maneuver.endShapeIndex ?? _fullRoutePolylinePoints.length - 1;

      // Check if current route segment falls within this maneuver's range
      if (_currentRouteSegmentIndex >= beginIndex &&
          _currentRouteSegmentIndex <= endIndex) {
        return i;
      }
    }

    return currentInstructionIndex.value; // Return current if no change
  }

  // Update current and next instructions
  void _updateCurrentInstruction() {
    if (currentManeuvers.isEmpty) {
      currentInstruction.value = "Continue straight";
      nextInstruction.value = "";
      return;
    }

    final currentIndex = currentInstructionIndex.value;

    // Set current instruction
    if (currentIndex < currentManeuvers.length) {
      final maneuver = currentManeuvers[currentIndex];
      currentInstruction.value = maneuver.instruction ?? "Continue";
    }

    // Set next instruction
    if (currentIndex + 1 < currentManeuvers.length) {
      final nextManeuver = currentManeuvers[currentIndex + 1];
      nextInstruction.value = nextManeuver.instruction ?? "";
    } else {
      nextInstruction.value = "Destination reached";
    }
    //! Updating turn logs
    ctrl.tripLog.value?.turnLogs.add(
      TurnLog(
        lat: userLocation.value!.latitude,
        long: userLocation.value!.longitude,
        timestamp: DateTime.now(),
        direction: TurnDirection.straight,
        instruction: currentInstruction.value,
      ),
    );
    Get.log(ctrl.tripLog.value.toString());
  }

  // Calculate distance to next instruction
  void _calculateDistanceToNextInstruction(LatLng userLocation) {
    if (currentManeuvers.isEmpty || _fullRoutePolylinePoints.isEmpty) {
      distanceToNextInstruction.value = 0.0;
      return;
    }

    final currentIndex = currentInstructionIndex.value;
    if (currentIndex >= currentManeuvers.length - 1) {
      // Last instruction - distance to destination
      if (destinationLocation.value != null) {
        distanceToNextInstruction.value = _distance(
          userLocation,
          destinationLocation.value!,
        );
      }
      return;
    }

    // Get next maneuver's position
    final nextManeuver = currentManeuvers[currentIndex + 1];
    final nextManeuverShapeIndex = nextManeuver.beginShapeIndex ?? 0;

    if (nextManeuverShapeIndex < _fullRoutePolylinePoints.length) {
      final nextInstructionLocation =
          _fullRoutePolylinePoints[nextManeuverShapeIndex];
      distanceToNextInstruction.value = _distance(
        userLocation,
        nextInstructionLocation,
      );

      // Set approaching flag if within 100 meters
      isApproachingInstruction.value = distanceToNextInstruction.value <= 100;
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

    // Listen to position changes (light monitoring when not navigating)
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Larger filter when not navigating
      ),
    ).listen((Position pos) {
      final newLocation = LatLng(pos.latitude, pos.longitude);

      // Only animate when not navigating (navigation has its own stream)
      if (!isNavigationStarted.value) {
        _animateToNewLocation(newLocation);
      }
    });
  }

  // INFO: Enhanced polyline update with reroute support
  void _updatePolylinesEnhanced(LatLng currentLocation) {
    if (_fullRoutePolylinePoints.isEmpty) return;

    // Check if user is off route and handle reroute
    if (isNavigationStarted.value && !isRerouteInProgress.value) {
      _checkAndHandleReroute(currentLocation);
    }

    // Find the best segment on the route where user is located
    int bestSegmentIndex = _findBestRouteSegment(currentLocation);

    // Only update if we found a valid segment and user is close enough to route
    double distanceToRoute = _distanceToLineSegment(
      currentLocation,
      _fullRoutePolylinePoints[bestSegmentIndex],
      _fullRoutePolylinePoints[math.min(
        bestSegmentIndex + 1,
        _fullRoutePolylinePoints.length - 1,
      )],
    );

    // If user is on route, update the segment index and track passed points
    if (distanceToRoute <= offRouteThreshold) {
      offRouteCount = 0; // Reset off-route counter
      _lastOnRoutePoint = currentLocation;
      
      // Update current segment only if we've moved forward significantly
      if (bestSegmentIndex > _currentRouteSegmentIndex ||
          (bestSegmentIndex == _currentRouteSegmentIndex && distanceToRoute < 15)) {
        
        // Add passed points to the traveled route
        if (!_hasRerouted) {
          for (int i = _currentRouteSegmentIndex; i <= bestSegmentIndex; i++) {
            if (i < _originalRoutePoints.length && 
                !_passedRoutePoints.contains(_originalRoutePoints[i])) {
              _passedRoutePoints.add(_originalRoutePoints[i]);
            }
          }
        }
        
        _currentRouteSegmentIndex = bestSegmentIndex;
      }
    }

    _drawPolylines(currentLocation);
  }

  // INFO: Check if user is off route and handle reroute
  void _checkAndHandleReroute(LatLng currentLocation) {
    if (_fullRoutePolylinePoints.isEmpty) return;

    // Find closest point on route
    double minDistanceToRoute = double.infinity;
    for (int i = 0; i < _fullRoutePolylinePoints.length - 1; i++) {
      double distance = _distanceToLineSegment(
        currentLocation,
        _fullRoutePolylinePoints[i],
        _fullRoutePolylinePoints[i + 1],
      );
      if (distance < minDistanceToRoute) {
        minDistanceToRoute = distance;
      }
    }

    // Check if user is off route
    if (minDistanceToRoute > offRouteThreshold) {
      offRouteCount++;
      Get.log('Off route count: $offRouteCount, Distance: ${minDistanceToRoute.toStringAsFixed(2)}m');
      
      // Trigger reroute if consistently off route
      if (offRouteCount >= maxOffRouteCount) {
        _triggerReroute(currentLocation);
      }
    } else {
      offRouteCount = 0; // Reset counter when back on route
    }
  }

  // INFO: Trigger reroute functionality
  void _triggerReroute(LatLng currentLocation) async {
    if (isRerouteInProgress.value || destinationLocation.value == null) return;

    Get.log('Triggering reroute from: ${currentLocation.latitude}, ${currentLocation.longitude}');
    isRerouteInProgress.value = true;
    _rerouteStartPoint = currentLocation;

    // Show reroute notification
    Get.snackbar(
      'Recalculating Route',
      'Finding new route...',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    try {
      // Fetch new route from current location to destination
      await _fetchRerouteFromCurrentLocation(currentLocation);
      
      // If reroute was successful, update tracking variables
      if (!isRerouteInProgress.value) {
        _hasRerouted = true;
        offRouteCount = 0;
        
        // Create connector points if we have a last known on-route point
        if (_lastOnRoutePoint != null && _rerouteStartPoint != null) {
          _rerouteConnectorPoints = [_lastOnRoutePoint!, _rerouteStartPoint!];
        }
        
        Get.log('Reroute completed successfully');
      }
    } catch (e) {
      Get.log('Reroute failed: $e');
      isRerouteInProgress.value = false;
      Get.snackbar(
        'Reroute Failed',
        'Could not find new route. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // INFO: Fetch new route from current location
  Future<void> _fetchRerouteFromCurrentLocation(LatLng currentLocation) async {
    var baseUrl = 'https://valhalla1.openstreetmap.de/route';
    var body = {
      "locations": [
        {"lat": currentLocation.latitude, "lon": currentLocation.longitude},
        {"lat": destinationLocation.value!.latitude, "lon": destinationLocation.value!.longitude},
      ],
      "costing": "auto",
      "alternates": false, // Don't need alternates for reroute
      "directions_options": {"units": "kilometers"},
    };

    try {
      var response = await http.post(
        Uri.parse(baseUrl),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        
        // Parse new route
        var newRoute = RouteModel.fromJson(data);
        
        if (newRoute.trip?.legs != null && newRoute.trip!.legs!.isNotEmpty) {
          var encodedString = newRoute.trip!.legs!.first.shape ?? '';
          
          if (encodedString.isNotEmpty) {
            var decodedPolyline = _decodePolyline(encodedString);
            
            if (decodedPolyline.isNotEmpty) {
              // Update route with new polyline
              _fullRoutePolylinePoints = decodedPolyline;
              _currentRouteSegmentIndex = 0;
              
              // Update route in the routes list
              if (selectedRouteIndex.value != -1 && selectedRouteIndex.value < routes.length) {
                routes[selectedRouteIndex.value] = newRoute;
                
                // Update navigation instructions for new route
                currentManeuvers.value = newRoute.trip!.legs!.first.maneuvers ?? [];
                currentInstructionIndex.value = 0;
                _updateCurrentInstruction();
              }
              
              Get.log('New route loaded with ${decodedPolyline.length} points');
            }
          }
        }
        
        isRerouteInProgress.value = false;
      } else {
        throw Exception('Failed to fetch reroute: ${response.statusCode}');
      }
    } catch (e) {
      isRerouteInProgress.value = false;
      throw e;
    }
  }

  // INFO: Draw polylines with reroute support
  void _drawPolylines(LatLng currentLocation) {
    polylines.clear();

    if (_hasRerouted) {
      // Draw passed route points in gray (original route until reroute point)
      // if (_passedRoutePoints.isNotEmpty) {
      //   polylines.add(
      //     Polyline(
      //       points: List<LatLng>.from(_passedRoutePoints),
      //       color: Colors.grey.withOpacity(0.7),
      //       strokeWidth: 6,
      //     ),
      //   );
      // }

      // Draw connector line from last on-route point to reroute start point
      // if (_rerouteConnectorPoints.isNotEmpty) {
      //   polylines.add(
      //     Polyline(
      //       points: List<LatLng>.from(_rerouteConnectorPoints),
      //       color: Colors.grey.withOpacity(0.7),
      //       strokeWidth: 6,
      //     ),
      //   );
      // }

      // Draw new route from reroute start point to destination in blue
      if (_fullRoutePolylinePoints.isNotEmpty) {
        List<LatLng> newRoutePoints = [currentLocation];
        
        // Add remaining route points from current segment onwards
        for (int i = _currentRouteSegmentIndex + 1; i < _fullRoutePolylinePoints.length; i++) {
          newRoutePoints.add(_fullRoutePolylinePoints[i]);
        }

        if (newRoutePoints.length > 1) {
          polylines.add(
            Polyline(
              points: newRoutePoints,
              color: Colors.blue,
              strokeWidth: 8,
            ),
          );
        }
      }
    } else {
      // Original behavior - no reroute has occurred
      // Gray polyline: ENTIRE route from start to destination (static background)
      // polylines.add(
      //   Polyline(
      //     points: List<LatLng>.from(_fullRoutePolylinePoints),
      //     color: Colors.grey.withOpacity(0.7),
      //     strokeWidth: 6,
      //   ),
      // );

      // Blue polyline: from current user location to destination (dynamic overlay)
      List<LatLng> remainingPoints = [currentLocation];

      // Add remaining route points from current segment onwards
      for (int i = _currentRouteSegmentIndex + 1; i < _fullRoutePolylinePoints.length; i++) {
        remainingPoints.add(_fullRoutePolylinePoints[i]);
      }

      // Only add blue polyline if we have more than just the current location
      if (remainingPoints.length > 1) {
        polylines.add(
          Polyline(
            points: remainingPoints,
            color: Colors.blue,
            strokeWidth: 8,
          ),
        );
      }
    }

    polylines.refresh();
  }

  // INFO: Find best route segment for current location (from my_controller)
  int _findBestRouteSegment(LatLng currentLocation) {
    double minDistance = double.infinity;
    int bestSegmentIndex = _currentRouteSegmentIndex;

    // Search in a reasonable range around current segment
    int searchStart = math.max(0, _currentRouteSegmentIndex - 5);
    int searchEnd = math.min(
      _fullRoutePolylinePoints.length - 1,
      _currentRouteSegmentIndex + 20,
    );

    for (int i = searchStart; i < searchEnd; i++) {
      double distance;
      if (i < _fullRoutePolylinePoints.length - 1) {
        // Distance to line segment
        distance = _distanceToLineSegment(
          currentLocation,
          _fullRoutePolylinePoints[i],
          _fullRoutePolylinePoints[i + 1],
        );
      } else {
        // Distance to point
        distance = _distance(currentLocation, _fullRoutePolylinePoints[i]);
      }

      if (distance < minDistance) {
        minDistance = distance;
        bestSegmentIndex = i;
      }
    }

    return bestSegmentIndex;
  }

  // INFO: Calculate distance from point to line segment (from my_controller)
  double _distanceToLineSegment(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    // Convert to approximate meters using simple distance calculation
    double distanceToStart = _distance(point, lineStart);
    double distanceToEnd = _distance(point, lineEnd);
    double lineLength = _distance(lineStart, lineEnd);

    // If line has no length, return distance to start point
    if (lineLength == 0) return distanceToStart;

    // Calculate perpendicular distance using triangle area method
    double s = (distanceToStart + distanceToEnd + lineLength) / 2;
    double area = math.sqrt(
      s * (s - distanceToStart) * (s - distanceToEnd) * (s - lineLength),
    );
    double perpendicularDistance = (2 * area) / lineLength;

    // Check if perpendicular point lies on the segment
    double dotProduct =
        ((point.latitude - lineStart.latitude) *
                (lineEnd.latitude - lineStart.latitude) +
            (point.longitude - lineStart.longitude) *
                (lineEnd.longitude - lineStart.longitude));
    double squaredLength =
        math
            .pow(lineLength / 111000, 2)
            .toDouble(); // Rough conversion to degrees

    if (squaredLength == 0) return distanceToStart;

    double t = dotProduct / squaredLength;

    if (t < 0) return distanceToStart;
    if (t > 1) return distanceToEnd;

    return perpendicularDistance;
  }

  // INFO: Handle user location updates during navigation
  void _updateUserLocation(LatLng newLocation) {
    userLocation.value = newLocation;

    if (isNavigationStarted.value && _fullRoutePolylinePoints.isNotEmpty) {
      _updateNavigationState(newLocation);
    }
  }

  // INFO: Update navigation state with new user location
  void _updateNavigationState(LatLng newLocation) {
    // Update polylines with enhanced method
    _updatePolylinesEnhanced(newLocation);

    // Calculate bearing towards next point on route
    final nextPoint = _getNextRoutePoint(newLocation);
    if (nextPoint != null) {
      final bearing = _calculateBearing(newLocation, nextPoint);
      currentBearing.value = bearing;

      // Update map rotation to show direction of travel
      _rotateMapToDirection(bearing);
    }

    // Calculate distance to destination
    if (destinationLocation.value != null) {
      distanceToDestination.value = Geolocator.distanceBetween(
        newLocation.latitude,
        newLocation.longitude,
        destinationLocation.value!.latitude,
        destinationLocation.value!.longitude,
      );
    }

    _previousLocation = newLocation;
  }

  // INFO: Get the next point on route for bearing calculation (enhanced)
  LatLng? _getNextRoutePoint(LatLng currentLocation) {
    if (_fullRoutePolylinePoints.isEmpty) return null;

    // Use current route segment for better accuracy
    int lookAheadIndex = math.min(
      _currentRouteSegmentIndex +
          8, // Look ahead by more points for smoother navigation
      _fullRoutePolylinePoints.length - 1,
    );
    return _fullRoutePolylinePoints[lookAheadIndex];
  }

  // INFO: Calculate bearing between two points
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1Rad = start.latitude * (math.pi / 180);
    final lat2Rad = end.latitude * (math.pi / 180);
    final deltaLonRad = (end.longitude - start.longitude) * (math.pi / 180);

    final x = math.sin(deltaLonRad) * math.cos(lat2Rad);
    final y =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);

    final bearingRad = math.atan2(x, y);
    final bearingDeg = bearingRad * (180 / math.pi);

    return (bearingDeg + 360) % 360;
  }

  // INFO: Rotate map to show direction of travel (enhanced)
  void _rotateMapToDirection(double bearing) {
    if (userLocation.value == null) return;

    // Convert bearing to map rotation
    final mapRotation = -bearing * (math.pi / 180);

    mapController.moveAndRotateAnimatedRaw(
      userLocation.value!,
      18.0, // Zoom level for navigation
      mapRotation,
      offset: const Offset(0, 0.1), // Slight offset for better view
      duration: const Duration(milliseconds: 600), // Smoother rotation
      curve: Curves.easeInOut,
      hasGesture: false,
      source: MapEventSource.custom,
    );
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

  // INFO: Get source location name using Nominatim
  Future<List<String>> getSourceLocationName() async {
    final lat = ctrl.userLocation.value!.latitude;
    final lon = ctrl.userLocation.value!.longitude;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'YourAppName (your@email.com)', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          // You can split the display name if you want separate parts
          return displayName.split(',').map((e) => e.trim()).toList();
        }
      }
      return ['Unknown Location'];
    } catch (e) {
      print('Error fetching location name: $e');
      return ['Unknown Location'];
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
        headers: {'Content-Type': 'application/json'},
      );

      Get.log(jsonEncode(body));
      Get.log('Response Status: ${response.statusCode}');
      Get.log('Response Body: ${response.body}');

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

        // Set destination location
        destinationLocation.value = destination;

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

  // Update your existing stopNavigation method
  void stopNavigation() {
    // Reset values
    isNavigationStarted.value = false;
    selectedRouteIndex.value = -1;
    polylines.clear();
    routes.clear();
    currentRoutePolylinePoints.clear();
    traveledPolylinePoints.clear();
    upcomingPolylinePoints.clear();
    currentBearing.value = 0.0;
    distanceToDestination.value = 0.0;
    currentSegmentIndex.value = 0;

    // Clear navigation instructions - ADD THESE LINES
    currentManeuvers.clear();
    currentInstructionIndex.value = 0;
    currentInstruction.value = "";
    nextInstruction.value = "";
    distanceToNextInstruction.value = 0.0;
    isApproachingInstruction.value = false;

    // Clear enhanced navigation variables
    _fullRoutePolylinePoints.clear();
    _currentRouteSegmentIndex = 0;

    _navigationStream?.cancel();
    _navigationStream = null;
    _navigationTimer?.cancel();
    _navigationTimer = null;
    _previousLocation = null;
    _navigationStartLocation = null;
    destinationLocation.value = null;

    // Stop marker animation
    _markerAnimationController.stop();

    //TODO: Store trip log in Hive
    ctrl.tripLog.value!.endTime = DateTime.now(); // Set end time
    ctrl.tripLog.value!.endLat =
        userLocation.value!.latitude; // Set end latitude
    ctrl.tripLog.value!.endLong =
        userLocation.value!.longitude; // Set end longitude
    Get.log("final trip log: ${ctrl.tripLog.value!}");
    storeTrip(ctrl.tripLog.value!);

    //INFO:  TurnDirection is enum with following values {right, left, uTurn, straight}
    //! TripLog model
    // TripLog(
    //       tripId: 'T20250624001', // current time stamp
    //       startTime: DateTime(2025, 6, 24, 9, 15), // Time when user clicks [Start Navigation]
    //       startLat: 19.0728, // start location lat
    //       startLong: 72.8826, // start location long
    //       destinationsBefore: ['Gateway of India, Mumbai'], //
    //       destinationsDuring: ['Marine Drive, Mumbai'],
    //       turnLogs: [
    //         TurnLog(
    //           lat: 19.0745,
    //           long: 72.8811,
    //           timestamp: DateTime(2025, 6, 24, 9, 17),
    //           direction: TurnDirection.left,
    //         )
    //       ],
    //       endLat: 19.0801, // last location lat
    //       endLong: 72.8750, // last location long
    //       endTime: DateTime(2025, 6, 24, 9, 30), // Time when this function was called [current time]
    //       endReason: 'App closed manually by user', // Reason for ending trip
    //       isTripCompleted: true, // true if user reached destination, false if trip was ended manually
    //     ),

    // Reset map rotation to north
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

  // It stores the trip once it either stops manually or by reaching destination
  void storeTrip(TripLog newTrip) async {
    try {
      final HiveService hiveService = HiveService();
      final userId = await hiveService.getLoggedInUserId();
      if (userId == null) {
        print('❌ No logged-in user found!');
        return;
      }

      final userBox = await hiveService.getUserBox();
      final user = userBox.get(userId);

      if (user == null) {
        print('❌ User not found in Hive for ID: $userId');
        return;
      }

      user.trips = [
        ...user.trips,
        newTrip,
      ]; // 🔁 reassign the list (not just add)
      await userBox.put(userId, user); // ✅ now it will notify listeners
      Get.log('Trip stored successfully for user: $userId');
      Get.snackbar(
        'Trip Stored',
        'View trip log',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () => Get.to(() => TripLogHomePage()),
          child: const Text('View Trip Log'),
        ),
      );
    } catch (e) {
      Get.log('Error storing trip: $e');
    }
  }

  // INFO: Recenter map to focus on user's location
  void recenter({double? degreeOfRotation, Duration? duration}) {
    if (userLocation.value == null) return;

    double rotation = degreeOfRotation ?? 0.0;

    // During navigation, use current bearing for rotation
    if (isNavigationStarted.value) {
      rotation = -currentBearing.value * (math.pi / 180);
    }

    mapController.moveAndRotateAnimatedRaw(
      userLocation.value!,
      isNavigationStarted.value ? 18.0 : 17.0,
      rotation,
      offset: isNavigationStarted.value ? const Offset(0, 0.1) : Offset.zero,
      duration: duration ?? Durations.extralong4,
      curve: Curves.easeOut,
      hasGesture: false,
      source: MapEventSource.custom,
    );
  }

  // INFO: Start navigation (Enhanced)
  void startNavigation() {
    if (selectedRouteIndex.value != -1) {
      isNavigationStarted.value = true;

      // Store the navigation start location
      _navigationStartLocation = userLocation.value;

      // Get the selected route polyline points
      final selectedRoute = routes[selectedRouteIndex.value];
      final encodedPolyline = selectedRoute.trip!.legs![0].shape!;
      final decodedPoints = _decodePolyline(encodedPolyline);

      // Store full route points for enhanced navigation
      _fullRoutePolylinePoints = decodedPoints;
      currentRoutePolylinePoints.value = decodedPoints;
      _currentRouteSegmentIndex = 0; // Reset segment tracking

      // Initialize navigation instructions - ADD THIS LINE
      _initializeNavigationInstructions();

      // Initialize enhanced polylines
      if (userLocation.value != null) {
        _updatePolylinesEnhanced(userLocation.value!);

        // Calculate initial bearing
        final nextPoint = _getNextRoutePoint(userLocation.value!);
        if (nextPoint != null) {
          final bearing = _calculateBearing(userLocation.value!, nextPoint);
          currentBearing.value = bearing;

          // Start navigation with proper rotation
          _rotateMapToDirection(bearing);
        }
      }

      // Start enhanced navigation stream
      _startEnhancedNavigationStream();

      Get.log(
        'Enhanced navigation started with ${_fullRoutePolylinePoints.length} route points',
      );
    }
  }

  // INFO: Start enhanced navigation stream for smooth tracking
  void _startEnhancedNavigationStream() {
    _navigationStream?.cancel();
    _previousLocation = userLocation.value;

    _navigationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Very precise tracking during navigation
      ),
    ).listen((Position position) {
      final currentLatLng = LatLng(position.latitude, position.longitude);

      // Use smooth animation during navigation
      _animateToNewLocation(currentLatLng);

      // Update polylines with enhanced method
      _updatePolylinesEnhanced(currentLatLng);

      // Update navigation instructions - ADD THIS LINE
      _updateNavigationInstructions(currentLatLng);

      // Check for arrival using the actual final destination from route
      LatLng actualDestination;
      if (_fullRoutePolylinePoints.isNotEmpty) {
        actualDestination = _fullRoutePolylinePoints.last;
      } else {
        actualDestination = destinationLocation.value!;
      }

      // Check if user is within arrival threshold
      double distanceToDestination = _distance(
        currentLatLng,
        actualDestination,
      );
      if (distanceToDestination < 20) {
        // 20 meter arrival threshold
        ctrl.tripLog.value!.isTripCompleted = true;
        ctrl.tripLog.value!.endReason = "Destination reached";
        stopNavigation();
        Get.snackbar('Navigation', 'You have reached your destination.');

        return;
      }

      // Calculate distance to destination for display
      this.distanceToDestination.value = distanceToDestination;

      // Calculate bearing for map rotation
      double mapRotation = 0.0;

      // Use movement direction if user is moving
      if (_previousLocation != null) {
        final distanceMoved = _distance(_previousLocation!, currentLatLng);
        if (distanceMoved > 3) {
          mapRotation = -_calculateBearing(_previousLocation!, currentLatLng);
          currentBearing.value =
              -mapRotation * (180 / math.pi); // Update bearing
          _previousLocation = currentLatLng;
        }
      }

      // Use route direction as fallback
      if (mapRotation == 0.0) {
        final nextPoint = _getNextRoutePoint(currentLatLng);
        if (nextPoint != null) {
          mapRotation = -_calculateBearing(currentLatLng, nextPoint);
          currentBearing.value = -mapRotation * (180 / math.pi);
        }
      }

      // Smooth rotation with navigation zoom
      mapController.moveAndRotateAnimatedRaw(
        currentLatLng,
        18.0, // Navigation zoom level
        mapRotation,
        offset: const Offset(0, 0.1), // Slight offset for better view
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        hasGesture: false,
        source: MapEventSource.custom,
      );
    });
  }

  // INFO: Check if user has reached destination
  bool _hasReachedDestination() {
    if (userLocation.value == null || destinationLocation.value == null) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      userLocation.value!.latitude,
      userLocation.value!.longitude,
      destinationLocation.value!.latitude,
      destinationLocation.value!.longitude,
    );

    // Consider destination reached if within 50 meters (increased from 20)
    return distance <= 50;
  }

  // Update your existing getNavigationInstruction method
  String getNavigationInstruction() {
    if (!isNavigationStarted.value) {
      return "Start navigation";
    }

    if (_hasReachedDestination()) {
      return "You have arrived at your destination";
    }

    if (currentInstruction.value.isNotEmpty) {
      final distance = distanceToNextInstruction.value;
      if (distance > 1000) {
        return "${currentInstruction.value} in ${(distance / 1000).toStringAsFixed(1)} km";
      } else if (distance > 100) {
        return "${currentInstruction.value} in ${distance.toInt()} m";
      } else if (distance > 50) {
        return "Prepare to ${currentInstruction.value.toLowerCase()}";
      } else {
        return currentInstruction.value;
      }
    }

    final distance = (distanceToDestination.value / 1000).toStringAsFixed(1);
    return "Continue for $distance km";
  }

  // Helper method to get formatted distance to next instruction
  String getDistanceToNextInstruction() {
    final distance = distanceToNextInstruction.value;
    if (distance > 1000) {
      return "${(distance / 1000).toStringAsFixed(1)} km";
    } else {
      return "${distance.toInt()} m";
    }
  }

  // Helper method to get next instruction text
  String getNextInstructionText() {
    if (nextInstruction.value.isNotEmpty &&
        nextInstruction.value != "Destination reached") {
      return "Then ${nextInstruction.value.toLowerCase()}";
    }
    return nextInstruction.value;
  }
}
