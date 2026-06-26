import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final savedSession = await AuthService.getSavedSession();
    if (!mounted) return;

    if (savedSession != null) {
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {
          'userId': savedSession['userId'] as int,
          'deviceId': savedSession['deviceId'] as String,
        },
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
