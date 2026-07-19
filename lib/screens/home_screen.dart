import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/notification_provider.dart';
import 'main/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Cache screens so they are only built once
  final Map<int, Widget> _screenCache = {};

  Widget _getScreen(int index) {
    return _screenCache.putIfAbsent(index, () => _buildScreen(index));
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const DeviceScannerScreen();
      case 2: return const HistoryScreen();
      case 3: return const NotificationsScreen();
      case 4: return const AIBotScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Keep system UI overlay in sync
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? AppColors.darkSurface : Colors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          5,
          (i) {
            if (i > _selectedIndex) return const SizedBox.shrink();
            if (i == 4) return AIBotScreen(isActive: _selectedIndex == 4);
            return _getScreen(i);
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: isDark
              ? const Border(
                  top: BorderSide(color: AppColors.darkBorder, width: 1),
                )
              : const Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
        ),
        child: Consumer<NotificationProvider>(
          builder: (context, notificationProvider, _) {
            return NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 64,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bluetooth_outlined),
                  selectedIcon: Icon(Icons.bluetooth_rounded),
                  label: 'Device',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: notificationProvider.unreadCount > 0,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: notificationProvider.unreadCount > 0,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  label: 'Alerts',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.chat_outlined),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Health Service',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
