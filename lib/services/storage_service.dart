import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/heartbeat_data.dart';
import '../models/bluetooth_device_model.dart';
import '../models/notification_model.dart';
import '../models/timed_check_session.dart';
import '../models/ecg_recording_model.dart';
import '../models/ecg_inference_result.dart';

class StorageService {
  static const String usersBoxName = 'users';
  static const String heartbeatBoxName = 'heartbeat_data';
  static const String devicesBoxName = 'devices';
  static const String notificationsBoxName = 'notifications';
  static const String sessionsBoxName = 'timed_sessions';
  static const String preferencesBoxName = 'preferences';

  late Box<UserModel> _usersBox;
  late Box<HeartbeatData> _heartbeatBox;
  late Box<BluetoothDeviceModel> _devicesBox;
  late Box<AppNotification> _notificationsBox;
  late Box<TimedCheckSession> _sessionsBox;
  late Box<String> _preferencesBox;

  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters safely without throwing if already registered
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HeartbeatDataAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BluetoothDeviceModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AppNotificationAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TimedCheckSessionAdapter());

    // Open boxes with recovery fallback for corrupted/locked files on mobile
    _usersBox = await _openBoxSafely<UserModel>(usersBoxName);
    _heartbeatBox = await _openBoxSafely<HeartbeatData>(heartbeatBoxName);
    _devicesBox = await _openBoxSafely<BluetoothDeviceModel>(devicesBoxName);
    _notificationsBox = await _openBoxSafely<AppNotification>(notificationsBoxName);
    _sessionsBox = await _openBoxSafely<TimedCheckSession>(sessionsBoxName);
    _preferencesBox = await _openBoxSafely<String>(preferencesBoxName);
  }

  Future<Box<T>> _openBoxSafely<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      debugPrint('[StorageService] Error opening Hive box "$boxName": $e. Deleting and recreating box.');
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (delErr) {
        debugPrint('[StorageService] Error deleting Hive box "$boxName": $delErr');
      }
      return await Hive.openBox<T>(boxName);
    }
  }

  // User operations
  Future<void> saveUser(UserModel user) async {
    await _usersBox.put(user.uid, user);
  }

  UserModel? getUser(String uid) {
    return _usersBox.get(uid);
  }

  Future<void> deleteUser(String uid) async {
    await _usersBox.delete(uid);
  }

  // Heartbeat data operations
  Future<void> saveHeartbeatData(HeartbeatData data) async {
    await _heartbeatBox.put(data.id, data);
  }

  List<HeartbeatData> getAllHeartbeatData() {
    return _heartbeatBox.values.toList();
  }

  List<HeartbeatData> getHeartbeatDataByUserId(String userId) {
    final allData = _heartbeatBox.values.toList();
    return allData.where((data) => data.userId == userId).toList();
  }

  List<HeartbeatData> getHeartbeatDataByDateRange(
      DateTime startDate, DateTime endDate) {
    final allData = _heartbeatBox.values.toList();
    return allData
        .where((data) =>
            data.timestamp.isAfter(startDate) &&
            data.timestamp.isBefore(endDate))
        .toList();
  }

  Future<void> deleteHeartbeatData(String id) async {
    await _heartbeatBox.delete(id);
  }

  // Device operations
  Future<void> saveDevice(BluetoothDeviceModel device) async {
    await _devicesBox.put(device.id, device);
  }

  List<BluetoothDeviceModel> getAllDevices() {
    return _devicesBox.values.toList();
  }

  List<BluetoothDeviceModel> getSavedDevices() {
    return _devicesBox.values.where((device) => device.isSaved).toList();
  }

  BluetoothDeviceModel? getDevice(String id) {
    return _devicesBox.get(id);
  }

  Future<void> deleteDevice(String id) async {
    await _devicesBox.delete(id);
  }

  Future<void> updateDevice(BluetoothDeviceModel device) async {
    await _devicesBox.put(device.id, device);
  }

  // Notification operations
  Future<void> saveNotification(AppNotification notification) async {
    await _notificationsBox.put(notification.id, notification);
  }

  List<AppNotification> getAllNotifications() {
    final notifications = _notificationsBox.values.toList();
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  List<AppNotification> getUnreadNotifications() {
    return getAllNotifications().where((n) => !n.isRead).toList();
  }

  List<AppNotification> getImportantNotifications() {
    return getAllNotifications()
        .where((n) => n.isImportant || n.type == 'alert')
        .toList();
  }

  Future<void> markNotificationAsRead(String id) async {
    final notification = _notificationsBox.get(id);
    if (notification != null) {
      await _notificationsBox.put(
        id,
        notification.copyWith(isRead: true),
      );
    }
  }

  Future<void> deleteNotification(String id) async {
    await _notificationsBox.delete(id);
  }

  // Session operations
  Future<void> saveSession(TimedCheckSession session) async {
    await _sessionsBox.put(session.id, session);
  }

  List<TimedCheckSession> getAllSessions() {
    return _sessionsBox.values.toList();
  }

  List<TimedCheckSession> getSessionsByUserId(String userId) {
    return _sessionsBox.values
        .where((session) => session.userId == userId)
        .toList();
  }

  TimedCheckSession? getSession(String id) {
    return _sessionsBox.get(id);
  }

  Future<void> updateSession(TimedCheckSession session) async {
    await _sessionsBox.put(session.id, session);
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
  }

  // Preferences operations
  Future<void> setPreference(String key, String value) async {
    await _preferencesBox.put(key, value);
  }

  String? getPreference(String key) {
    return _preferencesBox.get(key);
  }

  Future<void> deletePreference(String key) async {
    await _preferencesBox.delete(key);
  }

  // ECG recordings storage
  List<ECGRecording> getECGRecordings() {
    final rawJson = _preferencesBox.get('ecg_recordings');
    if (rawJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson);
      return decoded.map((item) => ECGRecording.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveECGRecording(ECGRecording recording) async {
    final list = getECGRecordings();
    list.insert(0, recording);
    final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
    await _preferencesBox.put('ecg_recordings', encoded);
  }

  Future<void> deleteECGRecording(String id) async {
    final list = getECGRecordings();
    list.removeWhere((r) => r.id == id);
    final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
    await _preferencesBox.put('ecg_recordings', encoded);
  }

  // ── AI Inference result log ──────────────────────────────────────────────

  /// Persist a single inference result to the day's log.
  Future<void> saveInferenceResult(DateTime timestamp, EcgInferenceResult result) async {
    if (result.isError) return;
    final existing = _getRawInferenceResults();
    existing.add({
      'timestamp': timestamp.toIso8601String(),
      'label': result.label,
      'confidence': result.confidence,
      'labelIndex': result.labelIndex,
      'isAbnormal': result.isAbnormal,
    });
    // Keep only last 200 results to prevent unbounded growth
    final trimmed = existing.length > 200
        ? existing.sublist(existing.length - 200)
        : existing;
    await _preferencesBox.put('inference_log', jsonEncode(trimmed));
  }

  List<Map<String, dynamic>> _getRawInferenceResults() {
    final raw = _preferencesBox.get('inference_log');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  /// Retrieve all inference results recorded today.
  List<Map<String, dynamic>> getTodayInferenceResults() {
    final today = DateTime.now();
    return _getRawInferenceResults().where((r) {
      try {
        final ts = DateTime.parse(r['timestamp'] as String);
        return ts.year == today.year &&
            ts.month == today.month &&
            ts.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // ── Chat History operations ───────────────────────────────────────────────

  /// Retrieve all saved AI chat sessions.
  List<Map<String, dynamic>> getSavedChats() {
    final rawJson = _preferencesBox.get('ai_chat_history');
    if (rawJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save the updated list of chat sessions.
  Future<void> saveChats(List<Map<String, dynamic>> chats) async {
    final encoded = jsonEncode(chats);
    await _preferencesBox.put('ai_chat_history', encoded);
  }

  // ── Daily summary tracking ───────────────────────────────────────────────

  String? getLastDailySummaryDate() {
    return _preferencesBox.get('last_daily_summary_date');
  }

  Future<void> setLastDailySummaryDate(String dateStr) async {
    await _preferencesBox.put('last_daily_summary_date', dateStr);
  }

  Future<void> clearAllData() async {
    await _usersBox.clear();
    await _heartbeatBox.clear();
    await _devicesBox.clear();
    await _notificationsBox.clear();
    await _sessionsBox.clear();
    await _preferencesBox.clear();
  }
}
