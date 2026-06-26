import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/apiservice.dart';

class SettingConfigurationPage extends StatefulWidget {
  final String deviceId;

  const SettingConfigurationPage({Key? key, required this.deviceId})
    : super(key: key);

  @override
  _SettingConfigurationPageState createState() =>
      _SettingConfigurationPageState();
}

class _SettingConfigurationPageState extends State<SettingConfigurationPage> {
  Settings? _settings;
  double _tempThreshold = 10.0;
  double _humidityLow = 50.0;
  double _humidityHigh = 85.0;
  int _gasNormal = 150;
  int _gasWarning = 300;
  int _uploadInterval = 5;
  bool _buzzerEnabled = true;
  bool _isSaving = false;
  bool _isLoadingDevices = true;
  bool _isLoadingSettings = true;
  List<String> _deviceIds = [];
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceList();
  }

  Future<void> _loadDeviceList() async {
    final devices = await ApiService().getDeviceList();
    if (!mounted) return;
    setState(() {
      _deviceIds = devices;
      _selectedDeviceId = widget.deviceId.isNotEmpty
          ? widget.deviceId
          : (devices.isNotEmpty ? devices.first : null);
      _isLoadingDevices = false;
    });

    if (_selectedDeviceId != null) {
      await _loadSettingsForDevice(_selectedDeviceId!);
    }
  }

  Future<void> _loadSettingsForDevice(String deviceId) async {
    setState(() {
      _isLoadingSettings = true;
    });

    final settings = await ApiService().getSettings(deviceId);
    if (!mounted) return;

    if (settings != null) {
      setState(() {
        _settings = settings;
        _tempThreshold = settings.temperatureThreshold;
        _humidityLow = settings.humidityThresholdLow;
        _humidityHigh = settings.humidityThresholdHigh;
        _gasNormal = settings.gasThresholdNormal;
        _gasWarning = settings.gasThresholdWarning;
        _uploadInterval = settings.uploadInterval;
        _buzzerEnabled = settings.buzzerEnabled;
        _isLoadingSettings = false;
      });
    } else {
      setState(() {
        _isLoadingSettings = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load settings for $deviceId.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _normalizeThresholds() {
    _humidityLow = _humidityLow.clamp(0, 100);
    _humidityHigh = _humidityHigh.clamp(0, 100);
    if (_humidityLow > _humidityHigh) {
      final temp = _humidityLow;
      _humidityLow = _humidityHigh;
      _humidityHigh = temp;
    }

    _gasNormal = _gasNormal.clamp(0, 4095);
    _gasWarning = _gasWarning.clamp(0, 4095);
    if (_gasNormal > _gasWarning) {
      final temp = _gasNormal;
      _gasNormal = _gasWarning;
      _gasWarning = temp;
    }
  }

  Future<void> _saveThresholds() async {
    _normalizeThresholds();
    setState(() {
      _isSaving = true;
    });

    final deviceId = _selectedDeviceId ?? widget.deviceId;
    final settingsToSave = Settings(
      id: _settings?.id ?? 0,
      deviceId: deviceId,
      temperatureThreshold: _tempThreshold,
      humidityThresholdLow: _humidityLow,
      humidityThresholdHigh: _humidityHigh,
      gasThresholdNormal: _gasNormal,
      gasThresholdWarning: _gasWarning,
      uploadInterval: _uploadInterval,
      buzzerEnabled: _buzzerEnabled,
      updatedAt: _settings?.updatedAt ?? DateTime.now(),
    );

    final success = await ApiService().updateSettings(settingsToSave);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Thresholds saved for $deviceId.'
              : 'Failed to save thresholds for $deviceId.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Thresholds')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select device to configure thresholds',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildDeviceSelector(),
              const SizedBox(height: 24),
              if (_isLoadingSettings)
                const Center(child: CircularProgressIndicator())
              else ...[
                _buildSliderCard(
                  title: 'Temperature Threshold',
                  value: _tempThreshold,
                  min: 0,
                  max: 50,
                  divisions: 100,
                  label: '${_tempThreshold.toStringAsFixed(1)} °C',
                  onChanged: (value) => setState(() => _tempThreshold = value),
                ),
                _buildRangeCard(
                  title: 'Humidity Thresholds',
                  startValue: _humidityLow,
                  endValue: _humidityHigh,
                  min: 20,
                  max: 90,
                  divisions: 70,
                  startLabel: '${_humidityLow.toStringAsFixed(0)}%',
                  endLabel: '${_humidityHigh.toStringAsFixed(0)}%',
                  onChanged: (values) {
                    setState(() {
                      _humidityLow = values.start.roundToDouble();
                      _humidityHigh = values.end.roundToDouble();
                    });
                  },
                  valueColor: Colors.blue,
                ),
                _buildRangeCard(
                  title: 'Gas Thresholds',
                  startValue: _gasNormal.toDouble(),
                  endValue: _gasWarning.toDouble(),
                  min: 0,
                  max: 4095,
                  divisions: 819,
                  startLabel: _gasNormal.toString(),
                  endLabel: _gasWarning.toString(),
                  onChanged: (values) {
                    setState(() {
                      _gasNormal = values.start.round();
                      _gasWarning = values.end.round();
                    });
                  },
                  valueColor: Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildUploadIntervalCard(),
                const SizedBox(height: 16),
                _buildBuzzerCard(),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveThresholds,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    final dropdownDevices = [
      if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty)
        _selectedDeviceId!,
      ..._deviceIds.where((deviceId) => deviceId != _selectedDeviceId),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: _isLoadingDevices
                ? const SizedBox(
                    height: 24,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : DropdownButton<String>(
                    value: _selectedDeviceId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Select device'),
                    items: dropdownDevices.map((deviceId) {
                      return DropdownMenuItem(
                        value: deviceId,
                        child: Text(deviceId),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedDeviceId = value;
                        _isLoadingSettings = true;
                      });
                      _loadSettingsForDevice(value);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              onChanged: onChanged,
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard({
    required String title,
    required double startValue,
    required double endValue,
    required double min,
    required double max,
    required int divisions,
    required String startLabel,
    required String endLabel,
    required ValueChanged<RangeValues> onChanged,
    required Color valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  endLabel,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(startValue, endValue),
              min: min,
              max: max,
              divisions: divisions,
              labels: RangeLabels(startLabel, endLabel),
              activeColor: valueColor,
              inactiveColor: valueColor.withOpacity(0.15),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadIntervalCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_uploadInterval s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildBuzzerCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _buzzerEnabled ? Icons.volume_up : Icons.volume_off,
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
                        color: _buzzerEnabled ? Colors.green : Colors.red,
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
    );
  }
}
