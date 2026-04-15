import 'package:hive/hive.dart';

part 'timed_check_session.g.dart';

@HiveType(typeId: 5)
class TimedCheckSession {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String userId;
  
  @HiveField(2)
  final DateTime startTime;
  
  @HiveField(3)
  final DateTime endTime;
  
  @HiveField(4)
  final int durationMinutes;
  
  @HiveField(5)
  final String status; // 'ongoing', 'completed', 'paused'
  
  @HiveField(6)
  final List<String> heartbeatDataIds; // References to HeartbeatData
  
  @HiveField(7)
  final String? aiAnalysis; // AI analysis result
  
  @HiveField(8)
  final String? healthCondition; // Final health condition determined by AI
  
  @HiveField(9)
  final DateTime createdAt;

  TimedCheckSession({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    this.heartbeatDataIds = const [],
    this.aiAnalysis,
    this.healthCondition,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'status': status,
      'heartbeatDataIds': heartbeatDataIds,
      'aiAnalysis': aiAnalysis,
      'healthCondition': healthCondition,
      'createdAt': createdAt,
    };
  }

  factory TimedCheckSession.fromMap(Map<String, dynamic> map) {
    return TimedCheckSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      startTime: map['startTime']?.toDate() ?? DateTime.now(),
      endTime: map['endTime']?.toDate() ?? DateTime.now(),
      durationMinutes: map['durationMinutes'] ?? 0,
      status: map['status'] ?? 'ongoing',
      heartbeatDataIds: List<String>.from(map['heartbeatDataIds'] ?? []),
      aiAnalysis: map['aiAnalysis'],
      healthCondition: map['healthCondition'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  TimedCheckSession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    String? status,
    List<String>? heartbeatDataIds,
    String? aiAnalysis,
    String? healthCondition,
    DateTime? createdAt,
  }) {
    return TimedCheckSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      heartbeatDataIds: heartbeatDataIds ?? this.heartbeatDataIds,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      healthCondition: healthCondition ?? this.healthCondition,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isOngoing => status == 'ongoing';
  
  int get remainingMinutes {
    final remaining = endTime.difference(DateTime.now()).inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  double get progressPercentage {
    final total = durationMinutes;
    final elapsed = startTime.difference(DateTime.now()).inMinutes.abs();
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
