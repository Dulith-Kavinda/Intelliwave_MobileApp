import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 4)
class AppNotification {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String message;
  
  @HiveField(3)
  final DateTime timestamp;
  
  @HiveField(4)
  final String type; // 'warning', 'info', 'alert', 'success'
  
  @HiveField(5)
  final bool isRead;
  
  @HiveField(6)
  final bool isImportant;
  
  @HiveField(7)
  final String? relatedId; // Reference to heartbeat data or session

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.isRead,
    required this.isImportant,
    this.relatedId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'type': type,
      'isRead': isRead,
      'isImportant': isImportant,
      'relatedId': relatedId,
    };
  }

  /// Convert to Supabase format (snake_case)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'created_at': timestamp.toIso8601String(),
      'type': type,
      'is_read': isRead,
      'is_important': isImportant,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    // Handle both Hive format (camelCase) and Supabase format (snake_case)
    DateTime? timestamp;
    
    if (map['timestamp'] != null) {
      // Hive format or already a DateTime
      if (map['timestamp'] is DateTime) {
        timestamp = map['timestamp'] as DateTime;
      } else if (map['timestamp'] is String) {
        timestamp = DateTime.tryParse(map['timestamp'] as String);
      }
    }
    
    if (map['created_at'] != null && timestamp == null) {
      // Supabase format
      if (map['created_at'] is String) {
        timestamp = DateTime.tryParse(map['created_at'] as String);
      }
    }

    return AppNotification(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: timestamp ?? DateTime.now(),
      type: map['type'] ?? 'info',
      isRead: map['isRead'] ?? map['is_read'] ?? false,
      isImportant: map['isImportant'] ?? map['is_important'] ?? false,
      relatedId: map['relatedId'] ?? map['related_id'],
    );
  }

  String getColor() {
    switch (type) {
      case 'warning':
        return '#FF9800';
      case 'alert':
      case 'important':
        return '#F44336';
      case 'success':
        return '#4CAF50';
      case 'info':
      default:
        return '#2196F3';
    }
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    String? type,
    bool? isRead,
    bool? isImportant,
    String? relatedId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isImportant: isImportant ?? this.isImportant,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
