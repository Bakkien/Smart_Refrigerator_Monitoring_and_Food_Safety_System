import 'package:flutter/material.dart';
import '../services/apiservice.dart';

class WifiConfigurationPage extends StatefulWidget {
  final String deviceId;

  const WifiConfigurationPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  _WifiConfigurationPageState createState() => _WifiConfigurationPageState();
}

class _WifiConfigurationPageState extends State<WifiConfigurationPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingDevices = true;
  bool _isLoadingConfig = true;
  List<String> _deviceIds = [];
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceList();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      await _loadWifiConfig(_selectedDeviceId!);
    } else {
      setState(() {
        _isLoadingConfig = false;
      });
    }
  }

  Future<void> _loadWifiConfig(String deviceId) async {
    setState(() {
      _isLoadingConfig = true;
    });

    final config = await ApiService().getWifiConfig(deviceId);
    if (!mounted) return;

    setState(() {
      _ssidController.text = config?['wifi_ssid'] ?? '';
      _passwordController.text = config?['wifi_password'] ?? '';
      _isLoadingConfig = false;
    });
  }

  Future<void> _saveWifiConfiguration() async {
    final deviceId = _selectedDeviceId ?? widget.deviceId;
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a device before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await ApiService().updateWifiConfig(
      deviceId,
      _ssidController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Wi-Fi settings saved for $deviceId.'
            : 'Failed to save Wi-Fi settings.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Configuration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select device for Wi-Fi setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildDeviceSelector(),
            const SizedBox(height: 24),
            if (_isLoadingConfig)
              const Center(child: CircularProgressIndicator())
            else ...[
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi SSID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveWifiConfiguration,
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
                      : const Text('Save Wi-Fi Settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    final dropdownDevices = [
      if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty) _selectedDeviceId!,
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
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : DropdownButton<String>(
                    value: _selectedDeviceId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Select device'),
                    items: dropdownDevices.map((deviceId) {
                      return DropdownMenuItem(value: deviceId, child: Text(deviceId));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedDeviceId = value;
                      });
                      _loadWifiConfig(value);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
