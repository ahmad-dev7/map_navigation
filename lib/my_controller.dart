import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:avatar_map_navigation/search_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

late MyController myController;

class MyController extends GetxController with GetTickerProviderStateMixin {
  double? fixedLat = 26.141513; // Set to `null` to revert back
  double? fixedLon = 85.538383; // Set to `null` to revert back
  var mapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  var mapController = MapControllerImpl();
  Rx<LatLng?> userLocation = Rx<LatLng?>(null);
  Rx<LatLng?> destinationLocation = Rx<LatLng?>(null);
  RxDouble userHeading = 0.0.obs;
  var destinationOptions = [].obs;
  var polylinePoints = <Polyline>[].obs;
  var isNavigationStarted = false.obs;
  var isLoading = false.obs;
  var searchText = ''.obs;
  var searchBarController = FloatingSearchBarController();

  List<Map<String, dynamic>> _steps = [];
  RxInt currentStepIndex = 0.obs;
  RxString instructionTitle = ''.obs;
  RxString instructionSubtitle = ''.obs;
  Rx<IconData> instructionIcon = Icons.navigation.obs;

  final RxDouble currentBearing = 0.0.obs;
  LatLng? _previousLocation;

  StreamSubscription<Position>? _navigationStream;
  final Distance _distance = const Distance();
  List<LatLng> _fullPolylinePoints = [];

  // New variables for better route tracking
  int _currentRouteSegmentIndex = 0;
  LatLng? _currentStepStartLocation;
  final double _totalDistanceToCurrentStep = 0.0;

  // Animation controllers for smooth marker movement
  late AnimationController _markerAnimationController;
  late Animation<double> _markerAnimation;
  LatLng? _animationStartLocation;
  LatLng? _animationEndLocation;
  Timer? _animationTimer;

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

  @override
  void onClose() {
    _markerAnimationController.dispose();
    _animationTimer?.cancel();
    _navigationStream?.cancel();
    super.onClose();
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

  // INFO: Improved polyline update with better route tracking
  void _updatePolylinesImproved(LatLng currentLocation) {
    if (_fullPolylinePoints.isEmpty) return;

    // Find the best segment on the route where user is located
    int bestSegmentIndex = _findBestRouteSegment(currentLocation);

    // Only update if we found a valid segment and user is close enough to route
    double distanceToRoute = _distanceToLineSegment(
      currentLocation,
      _fullPolylinePoints[bestSegmentIndex],
      _fullPolylinePoints[math.min(
        bestSegmentIndex + 1,
        _fullPolylinePoints.length - 1,
      )],
    );

    if (distanceToRoute > 30) return; // Increased threshold for better accuracy

    // Update current segment only if we've moved forward significantly
    if (bestSegmentIndex > _currentRouteSegmentIndex ||
        (bestSegmentIndex == _currentRouteSegmentIndex &&
            distanceToRoute < 15)) {
      _currentRouteSegmentIndex = bestSegmentIndex;
    }

    polylinePoints.clear();

    // Gray polyline: ENTIRE route from start to destination (static background)
    polylinePoints.add(
      Polyline(
        points: List<LatLng>.from(_fullPolylinePoints),
        color: Colors.grey.withOpacity(0.7),
        strokeWidth: 6,
      ),
    );

    // Green polyline: from current user location to destination (dynamic overlay)
    List<LatLng> remainingPoints = [currentLocation];

    // Add remaining route points from current segment onwards
    for (
      int i = _currentRouteSegmentIndex + 1;
      i < _fullPolylinePoints.length;
      i++
    ) {
      remainingPoints.add(_fullPolylinePoints[i]);
    }

    // Only add green polyline if we have more than just the current location
    if (remainingPoints.length > 1) {
      polylinePoints.add(
        Polyline(points: remainingPoints, color: Colors.green, strokeWidth: 6),
      );
    }

    polylinePoints.refresh();
  }

  // INFO: Find best route segment for current location
  int _findBestRouteSegment(LatLng currentLocation) {
    double minDistance = double.infinity;
    int bestSegmentIndex = _currentRouteSegmentIndex;

    // Search in a reasonable range around current segment
    int searchStart = math.max(0, _currentRouteSegmentIndex - 5);
    int searchEnd = math.min(
      _fullPolylinePoints.length - 1,
      _currentRouteSegmentIndex + 20,
    );

    for (int i = searchStart; i < searchEnd; i++) {
      double distance;
      if (i < _fullPolylinePoints.length - 1) {
        // Distance to line segment
        distance = _distanceToLineSegment(
          currentLocation,
          _fullPolylinePoints[i],
          _fullPolylinePoints[i + 1],
        );
      } else {
        // Distance to point
        distance = _distance(currentLocation, _fullPolylinePoints[i]);
      }

      if (distance < minDistance) {
        minDistance = distance;
        bestSegmentIndex = i;
      }
    }

    return bestSegmentIndex;
  }

  // INFO: Calculate distance from point to line segment
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

  // INFO: Fetching user location
  getUserLocation() async {
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
  searchDestination(String? query) async {
    if (query == null || query.trim().isEmpty) {
      searchText.value = '';
      destinationOptions.clear();
      return;
    }

    searchText.value = query;
    isLoading.value = true;
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
      isLoading.value = false;
    }
  }

  // INFO: Draws polyline
  void drawPolyline({required LatLng destination, LatLng? source}) async {
    var start = source ?? userLocation.value;
    LatLng end;

    // Use fixed destination if set
    if (fixedLat != null && fixedLon != null) {
      end = LatLng(fixedLat!, fixedLon!);
    } else {
      end = destination;
    }
    isLoading.value = true;
    polylinePoints.clear();
    destinationLocation.value = destination;

    try {
      final url =
          'http://122.170.111.109:3095/route/v1/driving/${start!.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true';
      Get.log(url);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final coordinates =
            data['routes'][0]['geometry']['coordinates'] as List<dynamic>;

        final List<LatLng> latLngList =
            coordinates.map((point) => LatLng(point[1], point[0])).toList();

        // Initialize polylines and route tracking
        _fullPolylinePoints = latLngList;
        _currentRouteSegmentIndex = 0;

        // Draw the initial route as a single green polyline
        polylinePoints.clear();
        polylinePoints.add(
          Polyline(
            points: List<LatLng>.from(_fullPolylinePoints),
            color: Colors.green,
            strokeWidth: 6,
          ),
        );

        _steps.clear();
        currentStepIndex.value = 0;

        final legs = data['routes'][0]['legs'] as List;
        if (legs.isNotEmpty) {
          _steps = List<Map<String, dynamic>>.from(legs[0]['steps']);
          _initializeStepLocations(); // Initialize step locations
          _updateInstructionFromStep(
            userLocation.value,
          ); // Set initial instruction
        }

        final bounds = LatLngBounds(start, end);
        for (final point in latLngList) {
          bounds.extend(point);
        }

        mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      } else {
        Get.snackbar('Error', 'Failed to get route data.');
        Get.log(response.body);
      }
    } catch (e) {
      Get.log('Error drawing polyline: $e');
      Get.snackbar('Error', 'Something went wrong drawing the route.');
    } finally {
      isLoading.value = false;
    }
  }

  // INFO: Initialize step locations for better tracking
  void _initializeStepLocations() {
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final maneuver = step['maneuver'];
      final location = maneuver['location'];

      step['_stepLocation'] = LatLng(
        (location[1] as num).toDouble(),
        (location[0] as num).toDouble(),
      );

      // Calculate cumulative distance to this step
      if (i == 0) {
        step['_cumulativeDistance'] = 0.0;
      } else {
        final prevStep = _steps[i - 1];
        final stepDistance = (step['distance'] as num?)?.toDouble() ?? 0.0;
        step['_cumulativeDistance'] =
            (prevStep['_cumulativeDistance'] ?? 0.0) + stepDistance;
      }
    }
  }

  // INFO: Enhanced step progression with manual "continue straight" instruction
  void _updateStepProgression(LatLng currentLocation) {
    if (_steps.isEmpty || currentStepIndex.value >= _steps.length) return;

    final currentStep = _steps[currentStepIndex.value];
    final currentStepLocation = currentStep['_stepLocation'] as LatLng?;

    if (currentStepLocation == null) return;

    // Calculate distance to current step maneuver point
    final distanceToCurrentStep = _distance(
      currentLocation,
      currentStepLocation,
    );

    // Check if this is the final step (arrive)
    final maneuver = currentStep['maneuver'];
    final type = maneuver['type'] ?? '';

    // FIXED: Don't advance if this is already the last step
    if (currentStepIndex.value >= _steps.length - 1) {
      // Just update the instruction for the final step
      _updateInstructionFromStep(currentLocation);
      return;
    }

    // FIXED: Improved step advancement logic with turn completion detection
    bool shouldAdvanceStep = false;

    // Store the minimum distance reached for this step
    final String minDistanceKey = '_minDistance_${currentStepIndex.value}';
    if (currentStep[minDistanceKey] == null ||
        distanceToCurrentStep < (currentStep[minDistanceKey] as double)) {
      currentStep[minDistanceKey] = distanceToCurrentStep;
    }

    final minDistanceReached = currentStep[minDistanceKey] as double;

    // Advanced step progression logic
    if (distanceToCurrentStep < 25) {
      // User is very close to the maneuver point
      shouldAdvanceStep = true;
    } else if (minDistanceReached < 25 &&
        distanceToCurrentStep > minDistanceReached + 20) {
      // User was close to the maneuver point but is now moving away
      // This indicates they likely completed the turn
      shouldAdvanceStep = true;
      Get.log(
        'Turn completion detected: min distance was ${minDistanceReached.round()}m, current distance is ${distanceToCurrentStep.round()}m',
      );
    }

    // FIXED: For very short steps, use more conservative time-based progression
    final stepDistance = (currentStep['distance'] as num?)?.toDouble() ?? 0.0;
    if (!shouldAdvanceStep && stepDistance < 30) {
      if (currentStep['_startTime'] == null) {
        currentStep['_startTime'] = DateTime.now().millisecondsSinceEpoch;
      } else {
        final timeSinceStepStart =
            DateTime.now().millisecondsSinceEpoch -
            (currentStep['_startTime'] as int);
        // For short steps, advance after reasonable time if user was close
        if (timeSinceStepStart > 8000 && minDistanceReached < 50) {
          shouldAdvanceStep = true;
          Get.log(
            'Short step time-based advancement: ${timeSinceStepStart}ms elapsed, min distance was ${minDistanceReached.round()}m',
          );
        }
      }
    }

    // NEW: Check if next step is 'arrive' but destination is far - inject manual step
    // Only do this AFTER user has completed the current maneuver and moved ahead
    if (shouldAdvanceStep && currentStepIndex.value < _steps.length - 1) {
      final nextStep = _steps[currentStepIndex.value + 1];
      final nextManeuver = nextStep['maneuver'];
      final nextType = nextManeuver['type'] ?? '';

      if (nextType == 'arrive') {
        // Check distance to actual destination
        final actualDestination =
            _fullPolylinePoints.isNotEmpty
                ? _fullPolylinePoints.last
                : destinationLocation.value;

        if (actualDestination != null) {
          final distanceToDestination = _distance(
            currentLocation,
            actualDestination,
          );

          // NEW: Only inject manual step if user has actually moved past the current maneuver
          // This ensures they've completed the turn before showing "continue straight"
          bool userHasPassedManeuver = false;

          // Check if user was close to maneuver and is now moving away (turn completed)
          if (minDistanceReached < 25 &&
              distanceToCurrentStep > minDistanceReached + 5) {
            userHasPassedManeuver = true;
            Get.log(
              'User has passed the maneuver point - safe to inject manual step',
            );
          }

          // If destination is far (>300m) AND user has completed the maneuver, inject manual step
          if (distanceToDestination > 300 && userHasPassedManeuver) {
            _injectManualContinueStep(currentLocation, actualDestination);
            shouldAdvanceStep = true; // Still advance to the manual step
            Get.log(
              'Injected manual continue step: ${distanceToDestination.round()}m from destination',
            );
          } else if (distanceToDestination <= 300) {
            Get.log(
              'Allowing arrival step: ${distanceToDestination.round()}m from destination',
            );
          } else {
            // User hasn't completed the maneuver yet, don't inject manual step
            // But still prevent early arrival if destination is far
            shouldAdvanceStep = false;
            Get.log(
              'Prevented early arrival step: User still approaching maneuver, ${distanceToDestination.round()}m from destination',
            );
          }
        }
      }
    }

    // Advance to next step if conditions are met
    if (shouldAdvanceStep && currentStepIndex.value < _steps.length - 1) {
      Get.log(
        'ADVANCING STEP: From ${currentStepIndex.value} to ${currentStepIndex.value + 1}. Previous: ${instructionTitle.value}',
      );

      currentStepIndex.value++;

      // Force immediate instruction update
      _updateInstructionFromStep(currentLocation);

      Get.log(
        'NEW INSTRUCTION SET: ${instructionTitle.value} - ${instructionSubtitle.value}',
      );

      // Mark the start time for the new step
      if (currentStepIndex.value < _steps.length) {
        _steps[currentStepIndex.value]['_startTime'] =
            DateTime.now().millisecondsSinceEpoch;
      }

      // Force UI update by triggering observable updates
      instructionTitle.refresh();
      instructionSubtitle.refresh();
      instructionIcon.refresh();
    } else {
      // Update current instruction with live distance
      _updateInstructionFromStep(currentLocation);

      // Add debug logging to see why step isn't advancing
      if (shouldAdvanceStep && currentStepIndex.value >= _steps.length - 1) {
        Get.log('Step advancement blocked: Already at last step');
      } else if (!shouldAdvanceStep) {
        Get.log(
          'Step advancement conditions not met: distance=${distanceToCurrentStep.round()}m, minDistance=${minDistanceReached.round()}m',
        );
      }
    }
  }

  // NEW: Inject a manual "continue straight" step before arrival
  void _injectManualContinueStep(LatLng currentLocation, LatLng destination) {
    // Create a manual step for "continue straight"
    final Map<String, dynamic> manualStep = {
      'maneuver': {
        'type': 'continue',
        'modifier': 'straight',
        'location': [
          destination.longitude,
          destination.latitude,
        ], // Point to destination
      },
      'name': '', // No specific road name
      'distance': _distance(
        currentLocation,
        destination,
      ), // Distance to destination
      '_stepLocation': destination, // Set step location to destination
      '_cumulativeDistance': 0.0, // Will be calculated if needed
      '_isManualStep': true, // Flag to identify manual steps
    };

    // Insert the manual step before the arrive step
    final arriveStepIndex = currentStepIndex.value + 1;
    _steps.insert(arriveStepIndex, manualStep);

    Get.log('Manual continue step injected at index $arriveStepIndex');
  }

  // INFO: Enhanced instruction method with manual step support
  void _updateInstructionFromStep(LatLng? currentLocation) {
    if (currentStepIndex.value >= _steps.length) return;

    final step = _steps[currentStepIndex.value];
    final maneuver = step['maneuver'];
    final modifier = maneuver['modifier'] ?? '';
    final name = step['name'] ?? '';
    final type = maneuver['type'] ?? '';
    final stepLocation = step['_stepLocation'] as LatLng?;
    final isManualStep = step['_isManualStep'] == true;

    String title = '';
    String subtitle = name;
    IconData icon = Icons.navigation;

    // Calculate live distance to current step
    double distanceToStep = 0.0;
    if (currentLocation != null && stepLocation != null) {
      distanceToStep = _distance(currentLocation, stepLocation);
    }

    switch (type) {
      case 'depart':
        title = 'Start driving';
        icon = Icons.directions_car;
        break;
      case 'arrive':
        // FIXED: Better arrival detection
        if (currentLocation != null) {
          final actualDestination =
              _fullPolylinePoints.isNotEmpty
                  ? _fullPolylinePoints.last
                  : destinationLocation.value;

          if (actualDestination != null) {
            final distanceToDestination = _distance(
              currentLocation,
              actualDestination,
            );
            if (distanceToDestination < 50) {
              title = 'You have arrived';
            } else {
              title = 'Approaching destination';
              // Show distance to actual destination, not step location
              distanceToStep = distanceToDestination;
            }
          } else {
            title = 'You have arrived';
          }
        } else {
          title = 'You have arrived';
        }
        icon = Icons.flag;
        break;
      case 'turn':
        if (modifier.isNotEmpty) {
          title = 'Turn ${modifier.toString().capitalizeFirst}';
        } else {
          title = 'Turn';
        }
        icon = _iconForModifier(modifier);
        break;
      case 'new name':
        title = 'Continue straight';
        icon = Icons.straight;
        break;
      case 'continue':
        // NEW: Enhanced continue instruction for manual steps
        if (isManualStep) {
          title = 'Continue straight';
          subtitle = 'towards destination';
          icon = Icons.straight;
        } else {
          title = 'Continue';
          icon = Icons.arrow_upward;
        }
        break;
      case 'merge':
        title = 'Merge ${modifier.toString().capitalizeFirst}';
        icon = _iconForModifier(modifier);
        break;
      case 'on ramp':
        title = 'Take the ramp';
        icon = Icons.ramp_right;
        break;
      case 'off ramp':
        title = 'Take the exit';
        icon = Icons.ramp_left;
        break;
      case 'fork':
        title = 'Keep ${modifier.toString().capitalizeFirst}';
        icon = _iconForModifier(modifier);
        break;
      case 'roundabout':
        title = 'Take the roundabout';
        icon = Icons.roundabout_left;
        break;
      default:
        title = 'Continue';
        icon = Icons.navigation;
    }

    // FIXED: Better distance display logic with manual step support
    if (distanceToStep > 0 && type != 'arrive' && isNavigationStarted.value) {
      String distanceText;
      if (distanceToStep < 1000) {
        distanceText = 'in ${distanceToStep.round()}m';
      } else {
        distanceText = 'in ${(distanceToStep / 1000).toStringAsFixed(1)}km';
      }

      // NEW: Special handling for manual continue steps
      if (isManualStep && type == 'continue') {
        subtitle = 'Continue straight - $distanceText';
      } else {
        subtitle = '${name.isEmpty ? '' : '$name - '}$distanceText';
      }
    } else if (type == 'arrive' && distanceToStep > 50) {
      // FIXED: Show distance for arrive step when far from destination
      String distanceText;
      if (distanceToStep < 1000) {
        distanceText = 'in ${distanceToStep.round()}m';
      } else {
        distanceText = 'in ${(distanceToStep / 1000).toStringAsFixed(1)}km';
      }
      subtitle = distanceText;
    } else if (name.isNotEmpty && type != 'arrive') {
      subtitle = name;
    } else if (isManualStep && type == 'continue') {
      // NEW: Default subtitle for manual continue steps
      subtitle = 'towards destination';
    }

    instructionTitle.value = title;
    instructionSubtitle.value = subtitle;
    instructionIcon.value = icon;
  }

  // INFO: Calculate bearing between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * (math.pi / 180);
    final lon1 = from.longitude * (math.pi / 180);
    final lat2 = to.latitude * (math.pi / 180);
    final lon2 = to.longitude * (math.pi / 180);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  // INFO: Get the next point on route for bearing calculation
  LatLng? _getNextRoutePoint(LatLng currentLocation) {
    if (_fullPolylinePoints.isEmpty) return null;

    // Use current route segment for better accuracy
    int lookAheadIndex = math.min(
      _currentRouteSegmentIndex + 5,
      _fullPolylinePoints.length - 1,
    );
    return _fullPolylinePoints[lookAheadIndex];
  }

  // INFO: Start navigation
  void startNavigation() {
    final bool hasFixedDestination = fixedLat != null && fixedLon != null;
    final LatLng? destination =
        hasFixedDestination
            ? LatLng(fixedLat!, fixedLon!)
            : destinationLocation.value;

    if (_fullPolylinePoints.isEmpty || destination == null) {
      Get.snackbar(
        'No route selected',
        'Please select destination to start route',
      );
      return;
    }

    isNavigationStarted.value = true;
    _navigationStream?.cancel();
    _previousLocation = userLocation.value;
    _currentRouteSegmentIndex = 0; // Reset route tracking

    // Calculate initial bearing
    if (_fullPolylinePoints.isNotEmpty && userLocation.value != null) {
      final initialBearing = _calculateBearing(
        userLocation.value!,
        _fullPolylinePoints.first,
      );
      recenter(
        degreeOfRotation: -initialBearing,
        duration: Durations.extralong4 * 1.5,
      );
    }

    _navigationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      final currentLatLng = LatLng(position.latitude, position.longitude);

      // Use smooth animation during navigation
      _animateToNewLocation(currentLatLng);

      // Update polylines with improved method
      _updatePolylinesImproved(currentLatLng);

      // FIXED: Check for arrival using the actual final destination from route
      LatLng actualDestination;
      if (_fullPolylinePoints.isNotEmpty) {
        // Use the last point from the route polyline as the actual destination
        actualDestination = _fullPolylinePoints.last;
      } else {
        // Fallback to the original destination
        actualDestination = destination;
      }

      // Check if user is within 50-100 meters of the actual destination
      double distanceToDestination = _distance(
        currentLatLng,
        actualDestination,
      );
      if (distanceToDestination < 75) {
        // Changed from 15 to 75 meters
        stopNavigation();
        Get.snackbar('Navigation', 'You have reached your destination.');
        return;
      }

      // Update step progression with live distance updates
      _updateStepProgression(currentLatLng);

      // Calculate bearing for map rotation
      double mapRotation = 0.0;

      // Use movement direction if user is moving
      if (_previousLocation != null) {
        final distanceMoved = _distance(_previousLocation!, currentLatLng);
        if (distanceMoved > 3) {
          mapRotation = -_calculateBearing(_previousLocation!, currentLatLng);
          _previousLocation = currentLatLng;
        }
      }

      // Use route direction as fallback
      if (mapRotation == 0.0) {
        final nextPoint = _getNextRoutePoint(currentLatLng);
        if (nextPoint != null) {
          mapRotation = -_calculateBearing(currentLatLng, nextPoint);
        }
      }

      // Smooth rotation with navigation zoom
      mapController.moveAndRotateAnimatedRaw(
        currentLatLng,
        17.5,
        mapRotation,
        offset: Offset.zero,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        hasGesture: false,
        source: MapEventSource.custom,
      );
    });

    // Set first instruction
    if (_steps.isNotEmpty) {
      _updateInstructionFromStep(userLocation.value);
      _steps[0]['_startTime'] = DateTime.now().millisecondsSinceEpoch;
    }
  }

  // INFO: Stop navigation
  void stopNavigation() {
    isNavigationStarted.value = false;
    _navigationStream?.cancel();
    _navigationStream = null;
    _previousLocation = null;
    _currentRouteSegmentIndex = 0;
    polylinePoints.clear();
    destinationLocation.value = null;
    _fullPolylinePoints.clear();

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

  IconData _iconForModifier(String modifier) {
    switch (modifier) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'slight left':
        return Icons.turn_slight_left;
      case 'slight right':
        return Icons.turn_slight_right;
      case 'straight':
        return Icons.arrow_upward;
      default:
        return Icons.navigation;
    }
  }
}
