import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'settingconfigurationpage.dart';
import 'wificonfigurationpage.dart';

class SettingsPage extends StatefulWidget {
  final String deviceId;

  const SettingsPage({super.key, required this.deviceId});

  @override
  _SettingsMenuPageState createState() => _SettingsMenuPageState();
}

class _SettingsMenuPageState extends State<SettingsPage> {

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuTile(
              icon: Icons.wifi,
              title: 'Wi-Fi Configuration',
              subtitle: 'Set up network for your device',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WifiConfigurationPage(deviceId: widget.deviceId),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildMenuTile(
              icon: Icons.tune,
              title: 'Sensor Thresholds',
              subtitle: 'Adjust sensor threshold settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingConfigurationPage(deviceId: widget.deviceId),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildMenuTile(
              icon: Icons.logout,
              title: 'Log out',
              subtitle: 'Sign out of your account',
              onTap: _logout,
              titleColor: Colors.red,
              iconColor: Colors.red,
            ),
          ],
        ),
            ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? Colors.blue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: effectiveIconColor.withOpacity(0.12),
                child: Icon(icon, color: effectiveIconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
