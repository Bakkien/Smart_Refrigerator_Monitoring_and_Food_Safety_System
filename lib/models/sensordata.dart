class SensorData {
  final int id;
  final String deviceId;
  final double temperature;
  final double humidity;
  final int gasLevel;
  final String doorStatus;
  final String status;
  final DateTime createdAt;

  SensorData({
    required this.id,
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    required this.gasLevel,
    required this.doorStatus,
    required this.status,
    required this.createdAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: _toInt(json['id']),
      deviceId: json['device_id'] ?? '',
      temperature: _toDouble(json['temperature']),
      humidity: _toDouble(json['humidity']),
      gasLevel: _toInt(json['gas_level']),
      doorStatus: json['door_status'] ?? 'CLOSED',
      status: json['status'] ?? 'NORMAL',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
