/// Result returned by [EcgInferenceService.runInference].
///
/// On success: [isError] = false, [label] = predicted class, [confidence] is in [0,1].
/// On failure: [isError] = true, [label] = 'Unknown', [errorMessage] = reason.
class EcgInferenceResult {
  /// Predicted class label (e.g. "Normal", "Atrial Fibrillation").
  final String label;

  /// Confidence of the predicted class (softmax probability), in [0, 1].
  final double confidence;

  /// Index of the predicted class in [EcgInferenceService.classLabels].
  final int labelIndex;

  /// True if inference failed (model not loaded, native error, etc.).
  final bool isError;

  /// Human-readable error reason when [isError] is true.
  final String? errorMessage;

  const EcgInferenceResult({
    required this.label,
    required this.confidence,
    required this.labelIndex,
    this.isError = false,
    this.errorMessage,
  });

  /// Creates a successful result.
  factory EcgInferenceResult.success({
    required String label,
    required double confidence,
    required int labelIndex,
  }) {
    return EcgInferenceResult(
      label: label,
      confidence: confidence,
      labelIndex: labelIndex,
      isError: false,
    );
  }

  /// Creates a failed/error result.
  factory EcgInferenceResult.error(String message) {
    return EcgInferenceResult(
      label: 'Unknown',
      confidence: 0.0,
      labelIndex: -1,
      isError: true,
      errorMessage: message,
    );
  }

  /// True when the prediction is NOT the normal class (index 0).
  /// Left BBB and Right BBB ARE abnormal cardiac conditions and WILL trigger health alerts.
  bool get isAbnormal => !isError && labelIndex != 0;

  /// Returns the display label — shows the actual detected condition including Left/Right BBB.
  String get displayLabel => label;

  @override
  String toString() =>
      'EcgInferenceResult(label: $label, '
      'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
      'isError: $isError'
      '${isError ? ", error: $errorMessage" : ""})';
}
