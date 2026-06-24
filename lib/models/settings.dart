class Settings {
  final int id;
  final String deviceId;
  double temperatureThreshold;
  double humidityThresholdLow;
  double humidityThresholdHigh;
  int gasThresholdNormal;
  int gasThresholdWarning;
  int uploadInterval;
  bool buzzerEnabled;
  final DateTime updatedAt;

  Settings({
    required this.id,
    required this.deviceId,
    required this.temperatureThreshold,
    required this.humidityThresholdLow,
    required this.humidityThresholdHigh,
    required this.gasThresholdNormal,
    required this.gasThresholdWarning,
    required this.uploadInterval,
    required this.buzzerEnabled,
    required this.updatedAt,
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      id: _toInt(json['id']),
      deviceId: json['device_id'] ?? '',
      temperatureThreshold: _toDouble(json['temperature_threshold'], 10.0),
      humidityThresholdLow: _toDouble(json['humidity_threshold_low'], 50.0),
      humidityThresholdHigh: _toDouble(json['humidity_threshold_high'], 85.0),
      gasThresholdNormal: _toInt(json['gas_threshold_normal'], 150),
      gasThresholdWarning: _toInt(json['gas_threshold_warning'], 300),
      uploadInterval: _toInt(json['upload_interval'], 5),
      buzzerEnabled: _toBool(json['buzzer_enabled']),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, String> toJson() {
    return {
      'device_id': deviceId,
      'temperature_threshold': temperatureThreshold.toString(),
      'humidity_threshold_low': humidityThresholdLow.toString(),
      'humidity_threshold_high': humidityThresholdHigh.toString(),
      'gas_threshold_normal': gasThresholdNormal.toString(),
      'gas_threshold_warning': gasThresholdWarning.toString(),
      'upload_interval': uploadInterval.toString(),
      'buzzer_enabled': buzzerEnabled ? '1' : '0',
    };
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final normalized = value?.toString().toLowerCase();
    return normalized == null || normalized == '1' || normalized == 'true';
  }
}
