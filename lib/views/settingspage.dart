import 'package:flutter/material.dart';
import '../services/apiservice.dart';
import '../models/settings.dart';

class SettingsPage extends StatefulWidget {
  final String deviceId;

  const SettingsPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsPage> {
  Settings? settings;
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  // Range values for sliders
  double _tempThreshold = 10.0;
  double _humidityLow = 50.0;
  double _humidityHigh = 85.0;
  int _gasNormal = 150;
  int _gasWarning = 300;
  int _uploadInterval = 5;
  bool _buzzerEnabled = true;

  @override
  void initState() {
    super.initState();
    fetchSettings();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId) {
      fetchSettings();
    }
  }

  Future<void> fetchSettings() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await ApiService().getSettings(widget.deviceId);
      setState(() {
        settings = data;
        isLoading = false;
        if (data != null) {
          _tempThreshold = data.temperatureThreshold;
          _humidityLow = data.humidityThresholdLow;
          _humidityHigh = data.humidityThresholdHigh;
          _gasNormal = data.gasThresholdNormal;
          _gasWarning = data.gasThresholdWarning;
          _uploadInterval = data.uploadInterval;
          _buzzerEnabled = data.buzzerEnabled;
          _normalizeThresholdRanges();
        } else {
          error = 'No settings found';
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Failed to load settings';
      });
    }
  }

  Future<void> _saveSettings() async {
    _normalizeThresholdRanges();

    setState(() {
      isSaving = true;
    });

    try {
      final updatedSettings = Settings(
        id: settings?.id ?? 0,
        deviceId: widget.deviceId,
        temperatureThreshold: _tempThreshold,
        humidityThresholdLow: _humidityLow,
        humidityThresholdHigh: _humidityHigh,
        gasThresholdNormal: _gasNormal,
        gasThresholdWarning: _gasWarning,
        uploadInterval: _uploadInterval,
        buzzerEnabled: _buzzerEnabled,
        updatedAt: DateTime.now(),
      );

      final success = await ApiService().updateSettings(updatedSettings);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await fetchSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });
  }

  void _normalizeThresholdRanges() {
    _humidityLow = _humidityLow.clamp(0, 100).toDouble();
    _humidityHigh = _humidityHigh.clamp(0, 100).toDouble();
    if (_humidityLow > _humidityHigh) {
      final temp = _humidityLow;
      _humidityLow = _humidityHigh;
      _humidityHigh = temp;
    }

    _gasNormal = _gasNormal.clamp(0, 1000);
    _gasWarning = _gasWarning.clamp(0, 1000);
    if (_gasNormal > _gasWarning) {
      final temp = _gasNormal;
      _gasNormal = _gasWarning;
      _gasWarning = temp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh settings',
            icon: const Icon(Icons.refresh),
            onPressed: isLoading || isSaving
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    fetchSettings();
                  },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(error!, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: fetchSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Device Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.devices, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Device ID',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.deviceId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (settings != null)
                          Text(
                            'Updated: ${_formatDate(settings!.updatedAt)}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Temperature Threshold
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Temperature Threshold',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_tempThreshold.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _tempThreshold,
                          min: 0,
                          max: 50,
                          divisions: 100,
                          activeColor: Colors.blue,
                          onChanged: (value) {
                            setState(() {
                              _tempThreshold = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Humidity Thresholds
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Humidity Thresholds',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRangeLabel(
                              'Low',
                              '${_humidityLow.toStringAsFixed(0)}%',
                              Colors.orange,
                            ),
                            _buildRangeLabel(
                              'High',
                              '${_humidityHigh.toStringAsFixed(0)}%',
                              Colors.red,
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(_humidityLow, _humidityHigh),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          labels: RangeLabels(
                            '${_humidityLow.toStringAsFixed(0)}%',
                            '${_humidityHigh.toStringAsFixed(0)}%',
                          ),
                          activeColor: Colors.blue,
                          inactiveColor: Colors.blue.withOpacity(0.15),
                          onChanged: (values) {
                            setState(() {
                              _humidityLow = values.start.roundToDouble();
                              _humidityHigh = values.end.roundToDouble();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Normal range: ${_humidityLow.toStringAsFixed(0)}% - ${_humidityHigh.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gas Thresholds
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gas Thresholds',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRangeLabel(
                              'Normal',
                              _gasNormal.toString(),
                              Colors.green,
                            ),
                            _buildRangeLabel(
                              'Warning',
                              _gasWarning.toString(),
                              Colors.orange,
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(
                            _gasNormal.toDouble(),
                            _gasWarning.toDouble(),
                          ),
                          min: 0,
                          max: 4095,
                          divisions: 819,
                          labels: RangeLabels(
                            _gasNormal.toString(),
                            _gasWarning.toString(),
                          ),
                          activeColor: Colors.orange,
                          inactiveColor: Colors.orange.withOpacity(0.15),
                          onChanged: (values) {
                            setState(() {
                              _gasNormal = values.start.round();
                              _gasWarning = values.end.round();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Normal: <$_gasNormal  |  Spoilage: $_gasNormal-$_gasWarning  |  Leak: >$_gasWarning',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upload Interval
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upload Interval',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (_uploadInterval > 1) {
                                  setState(() {
                                    _uploadInterval--;
                                  });
                                }
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_uploadInterval s',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (_uploadInterval < 60) {
                                  setState(() {
                                    _uploadInterval++;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buzzer Control
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _buzzerEnabled
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              color: _buzzerEnabled ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Buzzer',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _buzzerEnabled ? 'Enabled' : 'Disabled',
                                  style: TextStyle(
                                    color: _buzzerEnabled
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _buzzerEnabled,
                          onChanged: (value) {
                            setState(() {
                              _buzzerEnabled = value;
                            });
                          },
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Settings',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)} ${_pad(date.hour)}:${_pad(date.minute)}';
  }

  Widget _buildRangeLabel(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _pad(int value) {
    return value.toString().padLeft(2, '0');
  }
}
