import 'package:get/get.dart';
import '../hive_models/user_model.dart';
import 'hiveService.dart';


class UserController extends GetxController {
  final HiveService _hiveService = HiveService();

  Rx<User?> loggedInUser = Rx<User?>(null);

  // Check if user is already logged in from session box
  Future<void> loadLoggedInUser() async {
    final userId = await _hiveService.getLoggedInUserId();
    if (userId != null) {
      final box = await _hiveService.getUserBox();
      final user = box.get(userId);
      if (user != null) {
        loggedInUser.value = user;
        print('👤 Loaded logged-in user: ${user.userId}');
      } else {
        print('⚠️ User ID in session but not found in Hive box.');
      }
    } else {
      print('ℹ️ No logged-in user ID found in session.');
    }
  }

  // Login logic
  Future<bool> login(String email) async {
    final user = await validateUser(email);
    if (user != null) {
      await HiveService.saveLoggedInUser(user.userId);
      loggedInUser.value = user;
      print('✅ User logged in: ${user.userId}');
      return true;
    } else {
      print('❌ Login failed for email: $email');
      return false;
    }
  }

  // Optional logout
  Future<void> logout() async {
    final sessionBox = await _hiveService.getSessionBox();
    await sessionBox.delete('loggedInUserId');
    loggedInUser.value = null;
    print('🚪 User logged out');
  }
}

