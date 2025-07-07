import 'package:hive_flutter/hive_flutter.dart';

import '../hive_models/trip_model.dart';
import '../hive_models/turn_log_model.dart';
import '../hive_models/user_model.dart';

class HiveService {
  static const String userBoxName = 'users';
  static const String sessionBoxName = 'sessionBox';

  // 🔹 Utility method to get User box
  Future<Box<User>> getUserBox() async {
    return await Hive.openBox<User>(userBoxName);
  }

  // 🔹 Utility method to get Session box
  Future<Box> getSessionBox() async {
    return await Hive.openBox(sessionBoxName);
  }
  //New User
 static  Future<void> saveUser(User user) async {
    print('user id is : ${user.userId}');
    final userBox = await Hive.openBox<User>(userBoxName);
    await userBox.put(user.userId, user);
  }

  //User exist
  Future<bool> userExists(String userId) async {
    final userBox = await Hive.openBox<User>(userBoxName);
    return userBox.containsKey(userId);
  }

  //save user Id in sessionbox
  static Future<void> saveLoggedInUser(String userId) async {
    final sessionBox = await Hive.openBox(sessionBoxName);
    await sessionBox.put('loggedInUserId', userId);
  }

  //fetch the user from sessionbox
  Future<String?> getLoggedInUserId() async {
    final sessionBox = await Hive.openBox('sessionBox');
    print(sessionBox.values);
    print(sessionBox.get('loggedInUserId'));
    return sessionBox.get('loggedInUserId') as String?;
  }
}

//validate user login
Future<User?> validateUser(String email) async {
  final userBox = await Hive.openBox<User>('users');

  if (!userBox.containsKey(email)) return null;

  final user = userBox.get(email);

  if (user != null) {
    return user;
  } else {
    return null; // Incorrect password
  }
}

//add dummy data to hive
Future<void> addDummyUsers() async {
  final userBox = await Hive.openBox<User>('users');

  if (userBox.isEmpty) {
    final dummyUsers = getDummyUsers();

    for (var user in dummyUsers) {
      await userBox.put(user.userId, user); // Save with email as key
    }

    print('Dummy users added.');
  } else {
    print('Dummy users already exist.');
  }
}


// dummy_data_provider.dart


List<User> getDummyUsers() {
  return [
    //  User 1 - Has trips
    User(userId: 'reeja@gmail.com', trips: [getSampleTrip('T1001')]),
    //User 2 - Has trips
    User(userId: 'abc@gmail.com', trips: [getSampleTrip('T1002')]),
    //  User 3 - Has trips
    User(userId: 'user1@gmail.com', trips: [getSampleTrip('T1003')]),
    // ❌ User 4 - No trips
    User(userId: 'reejagrace@gmail.com', trips: []),
    // ❌ User 5 - No trips
    User(userId: 'user123@example.com', trips: []),
  ];
}

// Sample trip generator
TripLog getSampleTrip(String tripId) {
  return TripLog(
    tripId: tripId,
    startTime: DateTime.now(),
    startLat: 19.0728,
    startLong: 72.8826,
    destinationsBefore: ['Start Location'],
    destinationsDuring: ['Mid Location'],
    turnLogs: [
      TurnLog(
        lat: 19.0745,
        long: 72.8811,
        timestamp: DateTime.now(),
        direction: TurnDirection.left,
        instruction: "Turn left onto Sakal Bhavan Marg"
      ),
      TurnLog(
        lat: 19.0761,
        long: 72.8790,
        timestamp: DateTime.now(),
        direction: TurnDirection.right,
        instruction: "Turn left onto Sakal Bhavan Marg"
      ),
    ],
    endLat: 19.0801,
    endLong: 72.8750,
    endTime: DateTime.now(),
    endReason: 'Test end',
    isTripCompleted: true,
  );
}

