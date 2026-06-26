import 'package:flutter/material.dart';
import 'views/dashboardpage.dart';
import 'views/loginpage.dart';
import 'views/registerpage.dart';
import 'views/settingspage.dart';
import 'views/splashpage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Refrigerator Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const SplashPage(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final userId = args != null ? args['userId'] as int? : null;
          final deviceId = args != null ? args['deviceId'] as String? ?? '' : '';
          return MainScreen(initialDeviceId: deviceId, userId: userId);
        },
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final String initialDeviceId;
  final int? userId;

  const MainScreen({Key? key, this.initialDeviceId = '', this.userId}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String selectedDeviceId = '';

  @override
  void initState() {
    super.initState();
    selectedDeviceId = widget.initialDeviceId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? DashboardPage(
              deviceId: selectedDeviceId,
              userId: widget.userId,
              onDeviceChanged: (deviceId) {
                setState(() {
                  selectedDeviceId = deviceId;
                });
              },
            )
          : SettingsPage(deviceId: selectedDeviceId),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
