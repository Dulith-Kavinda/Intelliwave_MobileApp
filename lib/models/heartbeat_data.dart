import 'package:hive/hive.dart';

part 'heartbeat_data.g.dart';

@HiveType(typeId: 2)
class HeartbeatData {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String userId;
  
  @HiveField(2)
  final int heartRate; // in BPM
  
  @HiveField(3)
  final DateTime timestamp;
  
  @HiveField(4)
  final String deviceId;
  
  @HiveField(5)
  final String status; // 'good', 'normal', 'poor'
  
  @HiveField(6)
  final double? oxygenLevel; // SpO2 percentage
  
  @HiveField(7)
  final double? systolic; // Blood pressure systolic
  
  @HiveField(8)
  final double? diastolic; // Blood pressure diastolic
  
  @HiveField(9)
  final List<int> ecgData; // Raw ECG data points

  HeartbeatData({
    required this.id,
    required this.userId,
    required this.heartRate,
    required this.timestamp,
    required this.deviceId,
    required this.status,
    this.oxygenLevel,
    this.systolic,
    this.diastolic,
    this.ecgData = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'heartRate': heartRate,
      'timestamp': timestamp,
      'deviceId': deviceId,
      'status': status,
      'oxygenLevel': oxygenLevel,
      'systolic': systolic,
      'diastolic': diastolic,
      'ecgData': ecgData,
    };
  }

  factory HeartbeatData.fromMap(Map<String, dynamic> map) {
    return HeartbeatData(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      heartRate: map['heartRate'] ?? 0,
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      deviceId: map['deviceId'] ?? '',
      status: map['status'] ?? 'normal',
      oxygenLevel: map['oxygenLevel']?.toDouble(),
      systolic: map['systolic']?.toDouble(),
      diastolic: map['diastolic']?.toDouble(),
      ecgData: List<int>.from(map['ecgData'] ?? []),
    );
  }

  String getStatusEmoji() {
    switch (status) {
      case 'good':
        return '✅';
      case 'normal':
        return '⚠️';
      case 'poor':
        return '🔴';
      default:
        return '❓';
    }
  }

  HeartbeatData copyWith({
    String? id,
    String? userId,
    int? heartRate,
    DateTime? timestamp,
    String? deviceId,
    String? status,
    double? oxygenLevel,
    double? systolic,
    double? diastolic,
    List<int>? ecgData,
  }) {
    return HeartbeatData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      heartRate: heartRate ?? this.heartRate,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      oxygenLevel: oxygenLevel ?? this.oxygenLevel,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      ecgData: ecgData ?? this.ecgData,
    );
  }
}
