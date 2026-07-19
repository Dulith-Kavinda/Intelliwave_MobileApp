import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'dart:async';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      // Initialize timezone data
      tz_data.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // onDidReceiveLocalNotification was removed in flutter_local_notifications v18
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Create notification channels for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important health notifications',
        importance: Importance.high,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('[NotificationService] Failed to initialize notifications: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription:
          'This channel is used for important health notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription:
          'This channel is used for important health notifications',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Health-related notification helpers
  Future<void> showHeartbeatAlert({
    required int heartRate,
    required String status,
  }) async {
    String title = 'Heart Rate Alert';
    String body = 'Your heart rate is $heartRate BPM - Status: $status';

    if (heartRate > 100) {
      title = '⚠️ High Heart Rate Alert';
      body = 'Your heart rate is $heartRate BPM. Please relax and rest.';
    } else if (heartRate < 60) {
      title = '⚠️ Low Heart Rate Alert';
      body = 'Your heart rate is $heartRate BPM. Please check your health.';
    }

    await showNotification(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      payload: 'heartbeat_alert',
    );
  }

  Future<void> showDeviceConnectionAlert({
    required String deviceName,
    required bool isConnected,
  }) async {
    await showNotification(
      id: DateTime.now().millisecond,
      title: isConnected ? '✅ Device Connected' : '❌ Device Disconnected',
      body:
          '$deviceName ${isConnected ? 'connected successfully' : 'disconnected'}',
      payload: 'device_alert',
    );
  }

  /// Show an ECG AI anomaly notification when the model detects a non-normal
  /// rhythm with confidence above the configured threshold.
  ///
  /// Uses a stable notification ID (2001) so repeated alerts replace the
  /// previous one instead of stacking in the notification tray.
  Future<void> showEcgAnomalyAlert({
    required String label,
    required double confidence,
  }) async {
    final confidencePct = (confidence * 100).toStringAsFixed(0);

    String title;
    String body;

    switch (label) {
      case 'MI':
        title = '🚨 Myocardial Infarction Alert (MI)';
        body = 'Possible Myocardial Infarction pattern detected ($confidencePct% confidence). '
            'Please seek immediate medical evaluation!';
        break;
      case 'STTC':
        title = '⚠️ ST/T Segment Change (STTC)';
        body = 'Possible ST/T segment change / Ischemia detected ($confidencePct% confidence). '
            'Consult your physician for evaluation.';
        break;
      case 'CD':
        title = '⚡ Conduction Disturbance (CD)';
        body = 'Possible Conduction Disturbance / Heart block pattern detected ($confidencePct% confidence). '
            'Medical evaluation recommended.';
        break;
      case 'HYP':
        title = '🫀 Cardiac Hypertrophy (HYP)';
        body = 'Possible Ventricular Hypertrophy pattern detected ($confidencePct% confidence). '
            'Please consult a cardiologist.';
        break;
      default:
        title = '⚠️ ECG Anomaly Detected';
        body = 'AI detected possible $label ($confidencePct% confidence). '
            'Please consult a doctor for confirmation.';
    }

    await showNotification(
      id: 2001, // stable ECG-anomaly notification ID
      title: title,
      body: body,
      payload: 'ecg_anomaly',
    );
  }

  /// Show the daily AI health summary notification.
  /// Uses a stable ID (3001) so it replaces itself each day rather than stacking.
  Future<void> showDailyHealthSummary({
    required String summaryText,
  }) async {
    await showNotification(
      id: 3001,
      title: '📊 Your Daily Heart Health Summary',
      body: summaryText,
      payload: 'daily_summary',
    );
  }
}

