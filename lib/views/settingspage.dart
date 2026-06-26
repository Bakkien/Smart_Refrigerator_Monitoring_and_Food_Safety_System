import 'package:flutter/material.dart';
import '../models/user.dart';
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
  bool _isLoading = true;
  String _username = 'User';
  String _email = 'user@example.com';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final session = await AuthService.getSavedSession();
    if (!mounted) return;
    setState(() {
      _username = session?['username'] as String? ?? 'User';
      _email = session?['email'] as String? ?? 'user@example.com';
      _isLoading = false;
    });
  }

  Future<void> _editProfile() async {
    final usernameController = TextEditingController(text: _username);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (mounted && updated == true) {
      final session = await AuthService.getSavedSession();
      final updatedUser = User(
        id: session?['userId'] as int? ?? 0,
        username: usernameController.text.trim(),
        email: _email,
        deviceId: session?['deviceId'] as String? ?? widget.deviceId,
      );
      await AuthService.saveUserSession(updatedUser);
      if (!mounted) return;
      setState(() {
        _username = updatedUser.username;
      });
    }
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 24, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _username,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _editProfile,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
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
