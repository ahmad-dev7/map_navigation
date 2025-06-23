import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

class RouteController extends GetxController {
  // 0. Belapur to nerul
  // final double sourceLat = 19.02066;
  // final double sourceLon = 73.040787;
  // final double destLat = 19.0296;
  // final double destLon = 73.0166;

  // 1. Thane to colaba
  // final double sourceLat = 19.1864;
  // final double sourceLon = 72.9581;
  // final double destLat = 18.9067;
  // final double destLon = 72.8147;

  // 2. Churchgate to Navi Mumbai (Vashi)
  // final double sourceLat = 18.9322;
  // final double sourceLon = 72.8264;
  // final double destLat = 19.0728;
  // final double destLon = 73.0117;

  // 3. Bandra to Andheri
  final double sourceLat = 19.0596;
  final double sourceLon = 72.8295;
  final double destLat = 19.1197;
  final double destLon = 72.8697;

  // 4. Powai to Lower Parel
  // final double sourceLat = 19.1197;
  // final double sourceLon = 72.9089;
  // final double destLat = 19.0135;
  // final double destLon = 72.8302;

  // 5. Borivali to Worli
  // final double sourceLat = 19.2307;
  // final double sourceLon = 72.8567;
  // final double destLat = 19.0176;
  // final double destLon = 72.8133;

  // 6. Mulund to BKC (Bandra Kurla Complex)
  // final double sourceLat = 19.1728;
  // final double sourceLon = 72.9569;
  // final double destLat = 19.0632;
  // final double destLon = 72.8679;
  // Observable lists for routes
  final RxList<List<LatLng>> routes = <List<LatLng>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // API endpoint
  final String apiUrl = 'https://valhalla1.openstreetmap.de/route';

  @override
  void onInit() {
    super.onInit();
    fetchRoutes();
  }

  Future<void> fetchRoutes() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      routes.clear();

      // Prepare request body
      final requestBody = {
        "locations": [
          {"lat": sourceLat, "lon": sourceLon},
          {"lat": destLat, "lon": destLon},
        ],
        "costing": "auto",
        "alternates": true,
        "directions_options": {"units": "kilometers"},
      };

      // Make API request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _parseRoutes(data);
      } else {
        errorMessage.value = 'Failed to fetch routes: ${response.statusCode}';
        print('Error: ${response.body}');
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      print('Exception: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _parseRoutes(Map<String, dynamic> data) {
    try {
      // Parse main route
      if (data['trip'] != null && data['trip']['legs'] != null) {
        final mainRoute = _decodePolyline(data['trip']['legs'][0]['shape']);
        if (mainRoute.isNotEmpty) {
          routes.add(mainRoute);
        }
      }

      // Parse alternate routes
      if (data['alternates'] != null) {
        for (var alternate in data['alternates']) {
          if (alternate['trip'] != null &&
              alternate['trip']['legs'] != null &&
              alternate['trip']['legs'].isNotEmpty) {
            final alternateRoute = _decodePolyline(
              alternate['trip']['legs'][0]['shape'],
            );
            if (alternateRoute.isNotEmpty) {
              routes.add(alternateRoute);
            }
          }
        }
      }

      print('Total routes found: ${routes.length}');
    } catch (e) {
      errorMessage.value = 'Error parsing routes: $e';
      print('Parse error: $e');
    }
  }

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

  // Method to refresh routes
  void refreshRoutes() {
    fetchRoutes();
  }

  // Method to update source and destination
  void updateCoordinates(
    double newSourceLat,
    double newSourceLon,
    double newDestLat,
    double newDestLon,
  ) {
    // You can make these reactive if needed
    fetchRoutes();
  }
}
