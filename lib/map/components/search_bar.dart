import 'package:avatar_map_navigation/map/controller.dart';
import 'package:avatar_map_navigation/search_result_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

class RouteSearchBar extends StatelessWidget {
  const RouteSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingSearchBar(
      hint: 'Search destination...',
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 600),
      transitionCurve: Curves.easeInOut,
      physics: const BouncingScrollPhysics(),
      openAxisAlignment: 0.0,
      width: 600,
      debounceDelay: const Duration(milliseconds: 500),
      automaticallyImplyBackButton: false,
      onQueryChanged: ctrl.searchDestination,
      controller: ctrl.searchController,
      leadingActions: [FloatingSearchBarAction.back(showIfClosed: false)],
      builder: (context, transition) {
        return Material(
          borderRadius: BorderRadius.circular(10),
          child: Obx(() {
            var isLoading = ctrl.isLoadingSearchOptions.value;
            var query = ctrl.searchController.query;
            var destinationOptions = ctrl.destinationOptions;
            if (query.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Start typing to search...'),
              );
            } else if (isLoading) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: CupertinoActivityIndicator()),
              );
            } else if (destinationOptions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No results found.'),
              );
            } else {
              return Material(
                borderRadius: BorderRadius.circular(10),
                elevation: 4.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      destinationOptions.map((e) {
                        e as PlaceFeature;
                        return ListTile(
                          title: Text(
                            '${e.properties.name} ${e.properties.locality ?? ''} ${e.properties.district ?? ''}',
                          ),
                          onTap: () {
                            Get.log(e.geometry.coordinates.toString());
                            ctrl.searchController.close();

                            ctrl.destinationLocation.value = LatLng(
                              e.geometry.coordinates[1],
                              e.geometry.coordinates[0],
                            );
                            ctrl.fetchRoutes(
                              destination: ctrl.destinationLocation.value!,
                            );
                          },
                        );
                      }).toList(),
                ),
              );
            }
          }),
        );
      },
    );
  }
}
