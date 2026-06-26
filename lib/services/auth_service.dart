import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String _userIdKey = 'user_id';
  static const String _deviceIdKey = 'device_id';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';

  static Future<void> saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, user.id);
    await prefs.setString(_deviceIdKey, user.deviceId);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_emailKey, user.email);
  }

  static Future<Map<String, dynamic>?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_userIdKey);
    if (userId == null) return null;

    final deviceId = prefs.getString(_deviceIdKey) ?? '';
    return {
      'userId': userId,
      'deviceId': deviceId,
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
  }
}
