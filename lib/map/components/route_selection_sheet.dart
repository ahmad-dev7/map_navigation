import 'package:avatar_map_navigation/map/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RouteSelectionSheet extends StatelessWidget {
  const RouteSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.15, // Start with just the header visible
      minChildSize: 0.15, // Minimum size - shows only header
      maxChildSize: 0.7, // Maximum size when fully expanded
      expand: false,
      snap: true, // Snap to specific positions
      snapSizes: const [0.15, 0.7], // Snap points
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              // Prevent scroll when at the top - allows dragging from header
              if (scrollNotification is ScrollStartNotification) {
                if (scrollController.offset <= 0) {
                  return true; // Consume the event, allow dragging
                }
              }
              return false;
            },
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Fixed Header
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 80,
                    child: Column(
                      children: [
                        // Drag handle indicator
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),

                        // Header content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.route),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Choose Route',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: Get.back,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divider
                const SliverToBoxAdapter(child: Divider(height: 1)),

                // Route List
                SliverToBoxAdapter(
                  child: Obx(
                    () => ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: ctrl.routes.length,
                      itemBuilder: (context, index) {
                        var route = ctrl.routes[index].trip;
                        return Obx(
                          () => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  width: 2,
                                  color:
                                      ctrl.selectedRouteIndex.value == index
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                ),
                              ),
                              tileColor:
                                  ctrl.selectedRouteIndex.value == index
                                      ? Colors.blue[50]
                                      : null,
                              title: Text(
                                index == 0 ? 'Main Route' : 'Alternate Route',
                                style: TextStyle(
                                  fontWeight:
                                      ctrl.selectedRouteIndex.value == index
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildInfoChip(
                                      'Time: ${(route!.summary!.time! / 60).round()} min',
                                      Icons.access_time,
                                    ),
                                    _buildInfoChip(
                                      'Toll: ${route.summary!.hasToll! ? 'Yes' : 'No'}',
                                      route.summary!.hasToll!
                                          ? Icons.toll
                                          : Icons.money_off,
                                    ),
                                    _buildInfoChip(
                                      'Highway: ${route.summary!.hasHighway! ? 'Yes' : 'No'}',
                                      route.summary!.hasHighway!
                                          ? Icons.track_changes
                                          : Icons.local_shipping,
                                    ),
                                    _buildInfoChip(
                                      'Distance: ${route.summary!.length} km',
                                      Icons.straighten,
                                    ),
                                  ],
                                ),
                              ),
                              onTap:
                                  () => ctrl.selectedRouteIndex.value = index,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Start Navigation Button
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Obx(
                        () => ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                ctrl.selectedRouteIndex.value == -1
                                    ? Colors.grey[300]
                                    : Colors.blue,
                            foregroundColor:
                                ctrl.selectedRouteIndex.value == -1
                                    ? Colors.grey[600]
                                    : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation:
                                ctrl.selectedRouteIndex.value == -1 ? 0 : 2,
                          ),
                          onPressed:
                              ctrl.selectedRouteIndex.value == -1
                                  ? null
                                  : () {
                                    ctrl.startNavigation();
                                    Get.back();
                                  },
                          child: const Text(
                            'Start Navigation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
