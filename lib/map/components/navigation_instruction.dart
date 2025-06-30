import 'package:avatar_map_navigation/map/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NavigationInstructionsWidget extends StatelessWidget {
  final Controller controller;

  const NavigationInstructionsWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isNavigationStarted.value) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current Instruction
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        controller.isApproachingInstruction.value
                            ? Colors.orange
                            : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getInstructionIcon(controller.currentInstruction.value),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.currentInstruction.value.isNotEmpty
                            ? controller.currentInstruction.value
                            : "Continue straight",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (controller.distanceToNextInstruction.value > 0)
                        Text(
                          "in ${controller.getDistanceToNextInstruction()}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Next Instruction (if available)
            if (controller.nextInstruction.value.isNotEmpty &&
                controller.nextInstruction.value != "Destination reached")
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getInstructionIcon(controller.nextInstruction.value),
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.getNextInstructionText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Distance to Destination
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Destination: ${(controller.distanceToDestination.value / 1000).toStringAsFixed(1)} km",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Helper method to get appropriate icon for instruction
  IconData _getInstructionIcon(String instruction) {
    final lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('left')) {
      if (lowerInstruction.contains('slight')) {
        return Icons.turn_slight_left;
      } else if (lowerInstruction.contains('sharp')) {
        return Icons.turn_sharp_left;
      }
      return Icons.turn_left;
    } else if (lowerInstruction.contains('right')) {
      if (lowerInstruction.contains('slight')) {
        return Icons.turn_slight_right;
      } else if (lowerInstruction.contains('sharp')) {
        return Icons.turn_sharp_right;
      }
      return Icons.turn_right;
    } else if (lowerInstruction.contains('u-turn') ||
        lowerInstruction.contains('uturn')) {
      return Icons.u_turn_left;
    } else if (lowerInstruction.contains('straight') ||
        lowerInstruction.contains('continue')) {
      return Icons.straight;
    } else if (lowerInstruction.contains('roundabout')) {
      return Icons.roundabout_left;
    } else if (lowerInstruction.contains('exit')) {
      return Icons.exit_to_app;
    } else if (lowerInstruction.contains('merge')) {
      return Icons.merge;
    } else if (lowerInstruction.contains('destination') ||
        lowerInstruction.contains('arrived')) {
      return Icons.location_on;
    }

    return Icons.navigation;
  }
}
