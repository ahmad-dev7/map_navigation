import 'package:avatar_map_navigation/hive_models/trip_model.dart';
import 'package:avatar_map_navigation/hive_models/turn_log_model.dart';
import 'package:avatar_map_navigation/hive_models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripLogViewerScreen3 extends StatefulWidget {
  final User user;

  const TripLogViewerScreen3({super.key, required this.user});

  @override
  State<TripLogViewerScreen3> createState() => _TripLogViewerScreenState();
}

class _TripLogViewerScreenState extends State<TripLogViewerScreen3> {
  final Set<String> _expanded = {};

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id))
        _expanded.remove(id);
      else
        _expanded.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('🚗 Trip Log Viewer'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListView(
          children: [
            Text(
              'User ID: ${widget.user.userId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.user.trips.map((trip) {
              final isOpen = _expanded.contains(trip.tripId);
              return _buildTripCard(trip, isOpen);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip, bool isOpen) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('hh:mm a');
    Icon _iconForDirection(TurnDirection dir) {
      switch (dir) {
        case TurnDirection.left:
          return const Icon(Icons.turn_left, size: 20);
        case TurnDirection.right:
          return const Icon(Icons.turn_right, size: 20);
        case TurnDirection.uTurn:
          return const Icon(Icons.u_turn_left, size: 20);
        case TurnDirection.straight:
        default:
          return const Icon(Icons.arrow_upward, size: 20);
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 4,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${trip.destinationsBefore ?? '${trip.startLat}, ${trip.startLong}'}  →  ${trip.destinationsDuring ?? '${trip.endLat}, ${trip.endLong}'}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        trip.tripId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 4),
                      Text(
                        "📅 Date: ${dateFormat.format(trip.startTime)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
                  color: Colors.indigo,
                  onPressed: () => _toggle(trip.tripId),
                ),
              ],
            ),
            if (isOpen) ...[
              const Divider(height: 20, thickness: 1.2),
              const SizedBox(height: 8),
              Text("🕒 Start Time: ${timeFormat.format(trip.startTime)}"),
              Text(
                "📍 Start Location: Lat: ${trip.startLat} | Long: ${trip.startLong}",
              ),
              const SizedBox(height: 8),
              if (trip.destinationsBefore != null)
                Text(
                  "📦 Destination (before start):\n  - ${trip.destinationsBefore}",
                ),
              if (trip.destinationsDuring != null)
                Text(
                  "📦 Destination (during trip):\n  - ${trip.destinationsDuring}",
                ),
              const SizedBox(height: 8),
              const Text(
                "🔄 Turn Logs:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children:
                      trip.turnLogs.map((log) {
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          trailing: _iconForDirection(log.direction),
                          title: Text("Lat: ${log.lat} | Long: ${log.long}"),
                          subtitle: Text(
                            "🕒 ${timeFormat.format(log.timestamp)}",
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    trip.isTripCompleted ? Icons.check_circle : Icons.cancel,
                    color: trip.isTripCompleted ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    trip.isTripCompleted
                        ? 'Reached Destination'
                        : 'Trip Ended Early',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "📍 Last Location: Lat: ${trip.endLat} | Long: ${trip.endLong}",
              ),
              Text("🕒 End Time: ${timeFormat.format(trip.endTime!)}"),
              Text("📝 Reason: ${trip.endReason}"),
            ],
          ],
        ),
      ),
    );
  }
}
