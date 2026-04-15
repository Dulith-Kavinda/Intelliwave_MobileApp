import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  static const String _themeKey = 'theme_mode';
  static const String _notificationKey = 'notifications_enabled';
  static const String _heartRateAlertKey = 'heart_rate_alert';
  static const String _darkModeKey = 'dark_mode_enabled';

  String _theme = 'system'; // 'light', 'dark', 'system'
  bool _notificationsEnabled = true;
  bool _heartRateAlertsEnabled = true;
  bool _darkModeEnabled = false;

  String get theme => _theme;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get heartRateAlertsEnabled => _heartRateAlertsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;

  ThemeMode get themeMode {
    switch (_theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  SettingsProvider(this._storageService) {
    _loadSettings();
  }

  void _loadSettings() {
    _theme = _storageService.getPreference(_themeKey) ?? 'system';
    _notificationsEnabled =
        _storageService.getPreference(_notificationKey) != 'false';
    _heartRateAlertsEnabled =
        _storageService.getPreference(_heartRateAlertKey) != 'false';
    _darkModeEnabled =
        _storageService.getPreference(_darkModeKey) == 'true';
  }

  Future<void> setTheme(String theme) async {
    _theme = theme;
    await _storageService.setPreference(_themeKey, theme);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _storageService.setPreference(_notificationKey, enabled.toString());
    notifyListeners();
  }

  Future<void> setHeartRateAlertsEnabled(bool enabled) async {
    _heartRateAlertsEnabled = enabled;
    await _storageService.setPreference(_heartRateAlertKey, enabled.toString());
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    _darkModeEnabled = enabled;
    await _storageService.setPreference(_darkModeKey, enabled.toString());
    notifyListeners();
  }
}
