class RouteModel {
  Trip? trip;

  RouteModel({this.trip});

  RouteModel.fromJson(Map<String, dynamic> json) {
    trip = json['trip'] != null ? Trip.fromJson(json['trip']) : null;
  }
}

class Trip {
  List<Legs>? legs;
  Summary? summary;
  String? statusMessage;
  int? status;
  String? units;
  String? language;

  Trip({
    this.legs,
    this.summary,
    this.statusMessage,
    this.status,
    this.units,
    this.language,
  });

  Trip.fromJson(Map<String, dynamic> json) {
    if (json['legs'] != null) {
      legs = <Legs>[];
      json['legs'].forEach((v) {
        legs!.add(Legs.fromJson(v));
      });
    }
    summary =
        json['summary'] != null ? Summary.fromJson(json['summary']) : null;
    statusMessage = json['status_message'];
    status = json['status'];
    units = json['units'];
    language = json['language'];
  }
}

class Legs {
  List<Maneuvers>? maneuvers;
  String? shape;

  Legs({this.maneuvers, this.shape});

  Legs.fromJson(Map<String, dynamic> json) {
    if (json['maneuvers'] != null) {
      maneuvers = <Maneuvers>[];
      json['maneuvers'].forEach((v) {
        maneuvers!.add(Maneuvers.fromJson(v));
      });
    }
    shape = json['shape'];
  }
}

class Maneuvers {
  int? type;
  String? instruction;
  String? verbalSuccinctTransitionInstruction;
  String? verbalPreTransitionInstruction;
  String? verbalPostTransitionInstruction;
  List<String>? streetNames;
  int? bearingAfter;
  double? time;
  double? length;
  double? cost;
  int? beginShapeIndex;
  int? endShapeIndex;
  bool? verbalMultiCue;
  String? travelMode;
  String? travelType;
  String? verbalTransitionAlertInstruction;
  int? bearingBefore;
  int? roundaboutExitCount;
  bool? highway;
  Sign? sign;

  Maneuvers({
    this.type,
    this.instruction,
    this.verbalSuccinctTransitionInstruction,
    this.verbalPreTransitionInstruction,
    this.verbalPostTransitionInstruction,
    this.streetNames,
    this.bearingAfter,
    this.time,
    this.length,
    this.cost,
    this.beginShapeIndex,
    this.endShapeIndex,
    this.verbalMultiCue,
    this.travelMode,
    this.travelType,
    this.verbalTransitionAlertInstruction,
    this.bearingBefore,
    this.roundaboutExitCount,
    this.highway,
    this.sign,
  });

  Maneuvers.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    instruction = json['instruction'];
    verbalSuccinctTransitionInstruction =
        json['verbal_succinct_transition_instruction'];
    verbalPreTransitionInstruction = json['verbal_pre_transition_instruction'];
    verbalPostTransitionInstruction =
        json['verbal_post_transition_instruction'];

    // Fix: Check if street_names exists and is not null before casting
    if (json['street_names'] != null) {
      streetNames = json['street_names'].cast<String>();
    }

    bearingAfter = json['bearing_after'];
    time = json['time']?.toDouble();
    length = json['length']?.toDouble();
    cost = json['cost']?.toDouble();
    beginShapeIndex = json['begin_shape_index'];
    endShapeIndex = json['end_shape_index'];
    verbalMultiCue = json['verbal_multi_cue'];
    travelMode = json['travel_mode'];
    travelType = json['travel_type'];
    verbalTransitionAlertInstruction =
        json['verbal_transition_alert_instruction'];
    bearingBefore = json['bearing_before'];
    roundaboutExitCount = json['roundabout_exit_count'];
    highway = json['highway'];
    sign = json['sign'] != null ? Sign.fromJson(json['sign']) : null;
  }
}

class Sign {
  List<ExitBranchElements>? exitBranchElements;

  Sign({this.exitBranchElements});

  Sign.fromJson(Map<String, dynamic> json) {
    if (json['exit_branch_elements'] != null) {
      exitBranchElements = <ExitBranchElements>[];
      json['exit_branch_elements'].forEach((v) {
        exitBranchElements!.add(ExitBranchElements.fromJson(v));
      });
    }
  }
}

class ExitBranchElements {
  String? text;

  ExitBranchElements({this.text});

  ExitBranchElements.fromJson(Map<String, dynamic> json) {
    text = json['text'];
  }
}

class Summary {
  bool? hasTimeRestrictions;
  bool? hasToll;
  bool? hasHighway;
  bool? hasFerry;
  double? minLat;
  double? minLon;
  double? maxLat;
  double? maxLon;
  double? time;
  double? length;
  double? cost;

  Summary({
    this.hasTimeRestrictions,
    this.hasToll,
    this.hasHighway,
    this.hasFerry,
    this.minLat,
    this.minLon,
    this.maxLat,
    this.maxLon,
    this.time,
    this.length,
    this.cost,
  });

  Summary.fromJson(Map<String, dynamic> json) {
    hasTimeRestrictions = json['has_time_restrictions'];
    hasToll = json['has_toll'];
    hasHighway = json['has_highway'];
    hasFerry = json['has_ferry'];
    minLat = json['min_lat']?.toDouble();
    minLon = json['min_lon']?.toDouble();
    maxLat = json['max_lat']?.toDouble();
    maxLon = json['max_lon']?.toDouble();
    time = json['time']?.toDouble();
    length = json['length']?.toDouble();
    cost = json['cost']?.toDouble();
  }
}
