import 'package:flutter/material.dart';
import 'main/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DeviceScannerScreen(),
    const HistoryScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
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
        type: BottomNavigationBarType.fixed,
        items: _navItems,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              child: const Icon(Icons.settings),
            )
          : null,
    );
  }
}
