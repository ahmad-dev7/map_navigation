import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:latlong2/latlong.dart';

class AnimatedMarker extends StatefulWidget {
  final LatLng targetLocation;
  final double heading;
  final bool isNavigationStarted;
  final void Function(LatLng point) onPositionChanged;

  const AnimatedMarker({
    super.key,
    required this.targetLocation,
    required this.heading,
    required this.isNavigationStarted,
    required this.onPositionChanged,
  });

  @override
  State<AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<AnimatedMarker>
    with SingleTickerProviderStateMixin {
  late LatLng _currentLocation;
  late AnimationController _controller;
  late Animation<LatLng> _locationAnimation;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.targetLocation;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _locationAnimation = LatLngTween(
      begin: _currentLocation,
      end: widget.targetLocation,
    ).animate(_controller)..addListener(() {
      setState(() {
        _currentLocation = _locationAnimation.value;
      });
      widget.onPositionChanged(_currentLocation);
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.targetLocation != widget.targetLocation) {
      _locationAnimation = LatLngTween(
        begin: _currentLocation,
        end: widget.targetLocation,
      ).animate(_controller);

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: widget.heading * (math.pi / 180),
      child: AvatarGlow(
        glowColor: Colors.blueAccent,
        child: Icon(
          widget.isNavigationStarted
              ? CupertinoIcons.location_north_fill
              : Icons.circle,
          color: Colors.blue,
        ),
      ),
    );
  }
}

/// Helper Tween for LatLng interpolation
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
    : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) => LatLng(
    lerpDouble(begin!.latitude, end!.latitude, t),
    lerpDouble(begin!.longitude, end!.longitude, t),
  );

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
