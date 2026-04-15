import 'package:flutter/material.dart';
import '../screens/index.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String deviceScanner = '/device-scanner';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String timedCheck = '/timed-check';
  static const String notifications = '/notifications';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegistrationScreen(),
      home: (context) => const HomeScreen(),
      deviceScanner: (context) => const DeviceScannerScreen(),
      history: (context) => const HistoryScreen(),
      settings: (context) => const SettingsScreen(),
      profile: (context) => const ProfileScreen(),
      timedCheck: (context) => const TimedCheckScreen(),
      notifications: (context) => const NotificationsScreen(),
    };
  }
}
