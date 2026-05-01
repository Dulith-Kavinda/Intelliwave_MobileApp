/// Test ECG data - represents a typical human heart rhythm
/// Values are in millivolts (mV), normalized for display
class TestECGData {
  static const List<double> ecgValues = [
    0.0, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.5,
    1.7, 1.8, 1.9, 1.95, 1.98, 2.0, 1.98, 1.95, 1.9, 1.8,
    1.7, 1.5, 1.3, 1.1, 0.9, 0.7, 0.5, 0.3, 0.2, 0.1,
    0.0, -0.1, -0.2, -0.3, -0.5, -0.7, -0.9, -1.1, -1.3, -1.5,
    -1.7, -1.8, -1.9, -1.95, -1.98, -2.0, -1.98, -1.95, -1.9, -1.8,
    -1.7, -1.5, -1.3, -1.1, -0.9, -0.7, -0.5, -0.3, -0.2, -0.1,
    0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.28, 0.25, 0.2,
    0.15, 0.1, 0.05, 0.0, -0.05, -0.1, -0.15, -0.2, -0.15, -0.1,
    -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.1, 0.15, 0.25, 0.35,
    0.5, 0.65, 0.8, 0.9, 0.95, 0.98, 1.0, 0.98, 0.95, 0.9,
    0.8, 0.65, 0.5, 0.35, 0.25, 0.15, 0.1, 0.05, 0.0, -0.05,
    -0.1, -0.15, -0.2, -0.25, -0.3, -0.35, -0.4, -0.35, -0.3, -0.25,
    -0.2, -0.15, -0.1, -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  ];

  /// Sampling rate in Hz (samples per second)
  static const int samplingRate = 250; // 250 Hz is typical for ECG devices

  /// Duration of the test data in seconds
  static const double durationInSeconds = 2.4; // 160 samples at 250 Hz

  /// Get a continuous stream of ECG values (loops automatically)
  static List<double> getExtendedData(int sampleCount) {
    final extended = <double>[];
    for (int i = 0; i < sampleCount; i++) {
      extended.add(ecgValues[i % ecgValues.length]);
    }
    return extended;
  }

  /// Get time axis values in seconds
  static List<double> getTimeAxis(int sampleCount) {
    final timeAxis = <double>[];
    for (int i = 0; i < sampleCount; i++) {
      timeAxis.add(i / samplingRate);
    }
    return timeAxis;
  }

  /// Calculate heart rate from the test data (typical BPM)
  static int getTypicalHeartRate() => 72; // beats per minute

  /// Get realistic health metrics
  static Map<String, dynamic> getHealthMetrics() {
    return {
      'heartRate': 72, // BPM
      'heartRateVariability': 45, // ms
      'systolic': 120, // mmHg
      'diastolic': 80, // mmHg
      'oxygen': 98, // %
      'quality': 'Excellent', // Signal quality
    };
  }
}
