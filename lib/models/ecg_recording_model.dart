/// ECG Recording Model
class ECGRecording {
  final String id;
  final String deviceName;
  final DateTime recordedAt;
  final int durationSeconds;
  final List<double> ecgData;
  final Map<String, dynamic> healthMetrics;
  final String notes;

  ECGRecording({
    required this.id,
    required this.deviceName,
    required this.recordedAt,
    required this.durationSeconds,
    required this.ecgData,
    required this.healthMetrics,
    this.notes = '',
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'recordedAt': recordedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'ecgData': ecgData,
      'healthMetrics': healthMetrics,
      'notes': notes,
    };
  }

  /// Create from JSON
  factory ECGRecording.fromJson(Map<String, dynamic> json) {
    return ECGRecording(
      id: json['id'] ?? '',
      deviceName: json['deviceName'] ?? 'Unknown Device',
      recordedAt: DateTime.parse(json['recordedAt'] ?? DateTime.now().toIso8601String()),
      durationSeconds: json['durationSeconds'] ?? 0,
      ecgData: List<double>.from(json['ecgData'] ?? []),
      healthMetrics: json['healthMetrics'] ?? {},
      notes: json['notes'] ?? '',
    );
  }

  /// Get average heart rate from metrics
  int getHeartRate() => healthMetrics['heartRate'] ?? 0;

  /// Format duration as MM:SS
  String getFormattedDuration() {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format date as readable string
  String getFormattedDate() {
    return '${recordedAt.day}/${recordedAt.month}/${recordedAt.year} ${recordedAt.hour}:${recordedAt.minute.toString().padLeft(2, '0')}';
  }
}
