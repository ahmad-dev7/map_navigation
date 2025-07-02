import 'package:avatar_map_navigation/hive_models/trip_model.dart';
import 'package:hive_flutter/hive_flutter.dart';


 part 'user_model.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  List<Trip> trips;

  User({required this.userId, required this.trips});
}
