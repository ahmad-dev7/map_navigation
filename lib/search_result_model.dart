class SearchResult {
  final List<PlaceFeature> features;

  SearchResult({required this.features});

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      features:
          (json['features'] as List)
              .map((e) => PlaceFeature.fromJson(e))
              .toList(),
    );
  }
}

class PlaceFeature {
  final String type;
  final PlaceProperties properties;
  final PlaceGeometry geometry;

  PlaceFeature({
    required this.type,
    required this.properties,
    required this.geometry,
  });

  factory PlaceFeature.fromJson(Map<String, dynamic> json) {
    return PlaceFeature(
      type: json['type'],
      properties: PlaceProperties.fromJson(json['properties']),
      geometry: PlaceGeometry.fromJson(json['geometry']),
    );
  }
}

class PlaceProperties {
  final String osmType;
  final int osmId;
  final String osmKey;
  final String osmValue;
  final String type;
  final String? postcode;
  final String countrycode;
  final String name;
  final String country;
  final String? city;
  final String? district;
  final String? state;
  final String? county;
  final String? locality;
  final String? street;
  final List<double>? extent;

  PlaceProperties({
    required this.osmType,
    required this.osmId,
    required this.osmKey,
    required this.osmValue,
    required this.type,
    this.postcode,
    required this.countrycode,
    required this.name,
    required this.country,
    this.city,
    this.district,
    this.state,
    this.county,
    this.locality,
    this.street,
    this.extent,
  });

  factory PlaceProperties.fromJson(Map<String, dynamic> json) {
    return PlaceProperties(
      osmType: json['osm_type'],
      osmId: json['osm_id'],
      osmKey: json['osm_key'],
      osmValue: json['osm_value'],
      type: json['type'],
      postcode: json['postcode'],
      countrycode: json['countrycode'],
      name: json['name'],
      country: json['country'],
      city: json['city'],
      district: json['district'],
      state: json['state'],
      county: json['county'],
      locality: json['locality'],
      street: json['street'],
      extent:
          (json['extent'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}

class PlaceGeometry {
  final String type;
  final List<double> coordinates;

  PlaceGeometry({required this.type, required this.coordinates});

  factory PlaceGeometry.fromJson(Map<String, dynamic> json) {
    return PlaceGeometry(
      type: json['type'],
      coordinates:
          (json['coordinates'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
    );
  }
}
