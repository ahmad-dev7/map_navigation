import 'package:avatar_map_navigation/hive_models/trip_model.dart';
import 'package:avatar_map_navigation/hive_models/turn_log_model.dart';
import 'package:avatar_map_navigation/hive_models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:intl/intl.dart';

import 'newTripSesson_screen.dart';

class TripLogViewerScreen3 extends StatefulWidget {
  final User user;

  const TripLogViewerScreen3({super.key, required this.user});

  @override
  State<TripLogViewerScreen3> createState() => _TripLogViewerScreenState();
}

class _TripLogViewerScreenState extends State<TripLogViewerScreen3> {
  final Set<String> _expanded = {};
  final Set<String> _turnLogsExpanded = {};

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  void _toggleTurnLogs(String id) {
    setState(() {
      if (_turnLogsExpanded.contains(id)) {
        _turnLogsExpanded.remove(id);
      } else {
        _turnLogsExpanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            ...widget.user.trips.reversed.map((trip) {
              final isOpen = _expanded.contains(trip.tripId);
              return _buildTripCard(trip, isOpen);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(TripLog trip, bool isOpen) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('hh:mm a');
    final isTurnLogOpen = _turnLogsExpanded.contains(trip.tripId);

    // Icon _iconForDirection(TurnDirection dir) {
    //   switch (dir) {
    //     case TurnDirection.left:
    //       return const Icon(Icons.turn_left, size: 20);
    //     case TurnDirection.right:
    //       return const Icon(Icons.turn_right, size: 20);
    //     case TurnDirection.uTurn:
    //       return const Icon(Icons.u_turn_left, size: 20);
    //     case TurnDirection.straight:
    //     default:
    //       return const Icon(Icons.arrow_upward, size: 20);
    //   }
    // }

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
              Text(
                "📦 Destination (before start):\n  - ${trip.destinationsBefore}",
              ),
              Text(
                "📦 Destination (during trip):\n  - ${trip.destinationsDuring}",
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    "🔄 Turn Logs:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Spacer(),
                  TextButton.icon(
                    icon: Icon(isTurnLogOpen
                        ? Icons.expand_less
                        : Icons.expand_more),
                    label: Text(isTurnLogOpen ? 'Hide Logs' : 'View Logs'),
                    onPressed: () => _toggleTurnLogs(trip.tripId),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Container(
              //   decoration: BoxDecoration(
              //     border: Border.all(color: Colors.grey.shade400),
              //     borderRadius: BorderRadius.circular(8),
              //   ),
              //   child: Column(
              //     children:
              //         trip.turnLogs.map((log) {
              //           return Padding(
              //             padding: const EdgeInsets.symmetric(
              //               vertical: 6.0,
              //               horizontal: 8.0,
              //             ),
              //             child: Column(
              //               crossAxisAlignment: CrossAxisAlignment.start,
              //               children: [
              //                 Text(
              //                   "📝 Instruction: ${log.instruction}",
              //                   style: const TextStyle(
              //                     fontWeight: FontWeight.w500,
              //                     fontSize: 14,
              //                   ),
              //                 ),
              //                 const SizedBox(height: 4),
              //                 Text(
              //                   "📍 Lat: ${log.lat.toStringAsFixed(6)} | Long: ${log.long.toStringAsFixed(6)}",
              //                   style: const TextStyle(fontSize: 13),
              //                 ),
              //                 const SizedBox(height: 4),
              //                 Text(
              //                   "🕒 ${timeFormat.format(log.timestamp)}",
              //                   style: const TextStyle(
              //                     fontSize: 13,
              //                     color: Colors.grey,
              //                   ),
              //                 ),
              //                 const Divider(thickness: 0.8),
              //               ],
              //             ),
              //           );
              //         }).toList(),
              //   ),
              // ),
              if (isTurnLogOpen)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: trip.turnLogs.map((log) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6.0,
                          horizontal: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "📝 Instruction: ${log.instruction}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "📍 Lat: ${log.lat.toStringAsFixed(6)} | Long: ${log.long.toStringAsFixed(6)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "🕒 ${timeFormat.format(log.timestamp)}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const Divider(thickness: 0.8),
                          ],
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
