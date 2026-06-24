import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/heartbeat_data.dart';
import '../models/bluetooth_device_model.dart';
import '../models/notification_model.dart';
import '../models/timed_check_session.dart';
import '../models/ecg_recording_model.dart';

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

    // Register adapters
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(HeartbeatDataAdapter());
    Hive.registerAdapter(BluetoothDeviceModelAdapter());
    Hive.registerAdapter(AppNotificationAdapter());
    Hive.registerAdapter(TimedCheckSessionAdapter());

    // Open boxes
    _usersBox = await Hive.openBox<UserModel>(usersBoxName);
    _heartbeatBox = await Hive.openBox<HeartbeatData>(heartbeatBoxName);
    _devicesBox = await Hive.openBox<BluetoothDeviceModel>(devicesBoxName);
    _notificationsBox = await Hive.openBox<AppNotification>(notificationsBoxName);
    _sessionsBox = await Hive.openBox<TimedCheckSession>(sessionsBoxName);
    _preferencesBox = await Hive.openBox<String>(preferencesBoxName);
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

  Future<void> clearAllData() async {
    await _usersBox.clear();
    await _heartbeatBox.clear();
    await _devicesBox.clear();
    await _notificationsBox.clear();
    await _sessionsBox.clear();
    await _preferencesBox.clear();
  }
}
