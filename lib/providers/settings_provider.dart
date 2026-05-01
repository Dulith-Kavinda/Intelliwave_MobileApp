import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  static const String _themeKey = 'theme_mode';
  static const String _notificationKey = 'notifications_enabled';
  static const String _heartRateAlertKey = 'heart_rate_alert';
  static const String _highHeartRateAlertKey = 'high_heart_rate_alert';
  static const String _lowHeartRateAlertKey = 'low_heart_rate_alert';
  static const String _darkModeKey = 'dark_mode_enabled';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  String _theme = 'system'; // 'light', 'dark', 'system'
  bool _notificationsEnabled = true;
  bool _heartRateAlertsEnabled = true;
  bool _highHeartRateAlerts = true;
  bool _lowHeartRateAlerts = true;
  bool _darkModeEnabled = false;
  bool _onboardingCompleted = false;

  String get theme => _theme;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get heartRateAlertsEnabled => _heartRateAlertsEnabled;
  bool get highHeartRateAlerts => _highHeartRateAlerts;
  bool get lowHeartRateAlerts => _lowHeartRateAlerts;
  bool get darkModeEnabled => _darkModeEnabled;
  bool get onboardingCompleted => _onboardingCompleted;

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
    _highHeartRateAlerts =
        _storageService.getPreference(_highHeartRateAlertKey) != 'false';
    _lowHeartRateAlerts =
        _storageService.getPreference(_lowHeartRateAlertKey) != 'false';
    _darkModeEnabled =
        _storageService.getPreference(_darkModeKey) == 'true';
    _onboardingCompleted =
        _storageService.getPreference(_onboardingCompletedKey) == 'true';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String themeString;
    switch (mode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    _theme = themeString;
    await _storageService.setPreference(_themeKey, themeString);
    notifyListeners();
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

  Future<void> setHighHeartRateAlerts(bool enabled) async {
    _highHeartRateAlerts = enabled;
    await _storageService.setPreference(_highHeartRateAlertKey, enabled.toString());
    notifyListeners();
  }

  Future<void> setLowHeartRateAlerts(bool enabled) async {
    _lowHeartRateAlerts = enabled;
    await _storageService.setPreference(_lowHeartRateAlertKey, enabled.toString());
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    await _storageService.setPreference(_onboardingCompletedKey, 'true');
    notifyListeners();
  }
}
