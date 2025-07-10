import 'dart:math' as math;

import 'package:avatar_glow/avatar_glow.dart';
import 'package:avatar_map_navigation/map/controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

Marker getUserMarker() {
  return Marker(
    point: ctrl.userLocation.value!,
    width: 35,
    height: 35,
    alignment: Alignment.center,
    child: AnimatedContainer(
      duration: Durations.extralong1,
      child: Transform.rotate(
        angle: ctrl.userHeading.value * (math.pi / 180),
        child: AvatarGlow(
          glowColor:
              ctrl.isNavigationStarted.value
                  ? Colors.greenAccent
                  : Colors.blueAccent,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  ctrl.isNavigationStarted.value ? Colors.green : Colors.blue,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              ctrl.isNavigationStarted.value
                  ? CupertinoIcons.location_north_fill
                  : Icons.circle,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
      ),
    ),
  );
}

Marker getDestinationMarker() {
  return Marker(
    point: ctrl.destinationLocation.value!,
    width: 65,
    height: 65,
    alignment: Alignment.center,
    child: AnimatedContainer(
      duration: Durations.extralong1,
      child: Transform.rotate(
        angle: ctrl.userHeading.value * (math.pi / 180),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(Icons.pin_drop, color: Colors.redAccent, size: 30),
        ),
      ),
    ),
  );
}
