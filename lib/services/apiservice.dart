import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensordata.dart';
import '../models/settings.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'http://canorcannot.com/Bakkien/SRM/api';

  // Get latest data
  Future<SensorData?> getLatestData(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/getLatestData.php',
        ).replace(queryParameters: {'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return SensorData.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting latest data: $e');
      return null;
    }
  }

  // Get history data
  Future<List<SensorData>> getHistory(
    String deviceId, {
    int limit = 50,
    int days = 7,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getHistory.php').replace(
          queryParameters: {
            'device_id': deviceId,
            'days': days.toString(),
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<SensorData> history = [];
          for (var item in data['data']) {
            history.add(SensorData.fromJson(item));
          }
          return history;
        }
      }
      return [];
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  // Get settings
  Future<Settings?> getSettings(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/getSettings.php',
        ).replace(queryParameters: {'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return Settings.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting settings: $e');
      return null;
    }
  }

  // Update settings
  Future<bool> updateSettings(Settings settings) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/updateSettings.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: settings.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      
      return false;
    } catch (e) {
      print('Error updating settings: $e');
      return false;
    }
  }

  Future<User?> loginUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/loginUser.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return User.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error logging in: $e');
      return null;
    }
  }

  Future<User?> registerUser(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registerUser.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return User.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error registering user: $e');
      return null;
    }
  }

  Future<bool> registerDevice(int userId, String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registerDevice.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'user_id': userId.toString(),
          'device_id': deviceId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('Error registering device: $e');
      return false;
    }
  }

  // Get device list
  Future<List<String>> getDeviceList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/getDevice.php'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return _parseDeviceIds(data);
        }
      }
      return [];
    } catch (e) {
      print('Error getting device list: $e');
      return ['SRM01'];
    }
  }

  List<String> _parseDeviceIds(Map<String, dynamic> data) {
    final rawDevices = data['devices'] ?? data['device'] ?? data['data'];

    if (rawDevices is List) {
      return rawDevices
          .map((device) {
            if (device is Map) {
              return device['device_id'] ?? device['id'] ?? device['name'];
            }
            return device;
          })
          .where((deviceId) => deviceId != null)
          .map((deviceId) => deviceId.toString())
          .where((deviceId) => deviceId.isNotEmpty)
          .toList();
    }

    if (rawDevices is Map) {
      final deviceId =
          rawDevices['device_id'] ?? rawDevices['id'] ?? rawDevices['name'];
      return deviceId == null ? ['SRM01'] : [deviceId.toString()];
    }

    if (rawDevices is String && rawDevices.isNotEmpty) {
      return [rawDevices];
    }

    return ['SRM01'];
  }
}
