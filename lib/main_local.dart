import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'providers/index.dart';
import 'screens/index.dart';
import 'utils/index.dart';
import 'services/index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Skip Supabase initialization for local testing
  // Just initialize local storage
  try {
    setupServiceLocator();
    await storageService.initialize();
    bluetoothService.initialize();
    
    runApp(const MyTestApp());
  } catch (e) {
    runApp(ErrorScreen(error: e.toString()));
  }
}

class MyTestApp extends StatelessWidget {
  const MyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelIWave',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0066FF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const TestAppHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Test app with no auth state - just shows screens directly
class TestAppHome extends StatefulWidget {
  const TestAppHome({super.key});

  @override
  State<TestAppHome> createState() => _TestAppHomeState();
}

class _TestAppHomeState extends State<TestAppHome> {
  bool _showLoginScreen = true;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, storageService, userProfileService),
        ),
        ChangeNotifierProvider(
          create: (_) => BluetoothProvider(bluetoothService),
        ),
        ChangeNotifierProvider(
          create: (_) => HeartbeatProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => TimedCheckProvider(storageService),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IntelIWave - Local Test Mode'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _showLoginScreen = !_showLoginScreen);
              },
              child: Text(_showLoginScreen ? 'Show Home' : 'Show Login'),
            ),
          ],
        ),
        body: _showLoginScreen
            ? const LoginScreen()
            : const HomeScreenDemo(),
      ),
    );
  }
}

/// Demo home screen without authentication checks
class HomeScreenDemo extends StatefulWidget {
  const HomeScreenDemo({Key? key}) : super(key: key);

  @override
  State<HomeScreenDemo> createState() => _HomeScreenDemoState();
}

class _HomeScreenDemoState extends State<HomeScreenDemo> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardDemo(),
    Container(
      color: Colors.white,
      child: const Center(
        child: Text('Device Scanner Screen'),
      ),
    ),
    Container(
      color: Colors.white,
      child: const Center(
        child: Text('History Screen'),
      ),
    ),
    Container(
      color: Colors.white,
      child: const Center(
        child: Text('Notifications Screen'),
      ),
    ),
    Container(
      color: Colors.white,
      child: const Center(
        child: Text('Profile Screen'),
      ),
    ),
  ];

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bluetooth),
      label: 'Device',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.history),
      label: 'History',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: _navItems,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

/// Simple dashboard demo
class DashboardDemo extends StatelessWidget {
  const DashboardDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: Heart Rate
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Current Heart Rate',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red,
                          width: 4,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '72',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '72 BPM',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Healthy',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Card 2: Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: const [
                        Icon(Icons.favorite, color: Colors.red, size: 32),
                        SizedBox(height: 8),
                        Text('Avg: 70 BPM'),
                      ],
                    ),
                    Column(
                      children: const [
                        Icon(Icons.trending_up, color: Colors.blue, size: 32),
                        SizedBox(height: 8),
                        Text('Max: 95 BPM'),
                      ],
                    ),
                    Column(
                      children: const [
                        Icon(Icons.trending_down, color: Colors.purple, size: 32),
                        SizedBox(height: 8),
                        Text('Min: 60 BPM'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({required this.error, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[900],
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
