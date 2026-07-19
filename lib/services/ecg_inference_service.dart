import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:pytorch_lite/pigeon.dart';
import '../models/ecg_inference_result.dart';
import '../utils/service_locator.dart';

// ─── Inference parameters ─────────────────────────────────────────────────────
//
// PTB-XL PyTorch ECG classifier (ecg_resnet_lite.ptl) with custom per-class thresholds.
//
//   • NORM  : 0.31 (Normal ECG)
//   • MI    : 0.12 (Myocardial Infarction)
//   • STTC  : 0.29 (ST/T Segment Change)
//   • CD    : 0.40 (Conduction Disturbance)
//   • HYP   : 0.21 (Hypertrophy)
//
// ─────────────────────────────────────────────────────────────────────────────

/// Service that classifies ECG windows using PyTorch Mobile with per-class thresholding.
class EcgInferenceService {
  // ── Config ─────────────────────────────────────────────────────────────────

  /// Number of ECG samples per inference window (10 s @ 500 Hz).
  static const int windowLength = 5000;

  /// Default notification threshold fallback.
  static const double defaultConfidenceThreshold = 0.30;

  /// Ordered output class labels matching model output head.
  static const List<String> classLabels = [
    'NORM', // index 0 — Normal ECG
    'MI',   // index 1 — Myocardial Infarction
    'STTC', // index 2 — ST/T Segment Change
    'CD',   // index 3 — Conduction Disturbance
    'HYP',  // index 4 — Hypertrophy
  ];

  /// Per-class decision thresholds provided for this model.
  static const Map<String, double> classThresholds = {
    'NORM': 0.31,
    'MI':   0.12,
    'STTC': 0.29,
    'CD':   0.40,
    'HYP':  0.21,
  };

  /// Display titles for each class.
  static const Map<String, String> classDisplayNames = {
    'NORM': 'Normal Rhythm (NORM)',
    'MI':   'Myocardial Infarction (MI)',
    'STTC': 'ST/T Segment Change (STTC)',
    'CD':   'Conduction Disturbance (CD)',
    'HYP':  'Cardiac Hypertrophy (HYP)',
  };

  /// Index that represents the "NORM" class.
  static const int normalLabelIndex = 0;

  // ── State ──────────────────────────────────────────────────────────────────
  bool                 _isModelLoaded = false;
  bool                 _usingPyTorchModel = false;
  ClassificationModel? _pytorchModel;
  String?              _modelError;

  bool    get isModelLoaded      => _isModelLoaded;
  bool    get usingPyTorchModel  => _usingPyTorchModel;
  String? get modelError         => _modelError;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Initialise the ECG classifier (tries PyTorch Lite first, falls back to rule engine).
  Future<void> initialize() async {
    if (_isModelLoaded) return;
    
    try {
      _pytorchModel = await PytorchLite.loadClassificationModel(
        "assets/models/ecg_resnet_lite.ptl",
        1,
        5000,
        5,
        ensureMatchingNumberOfClasses: false,
      );
      _usingPyTorchModel = true;
      _isModelLoaded = true;
      _modelError = null;
      debugPrint('[EcgInferenceService] PyTorch model (ecg_resnet_lite.ptl) loaded with custom thresholds.');
    } catch (e, st) {
      _usingPyTorchModel = false;
      _isModelLoaded = true;
      _modelError = e.toString();
      debugPrint('[EcgInferenceService] PyTorch model native init info: $e\n$st. Using rule engine.');
    }
  }

  // ── Inference ──────────────────────────────────────────────────────────────

  /// Run inference on a single ECG window using per-class thresholds.
  Future<EcgInferenceResult> runInference(List<double> ecgWindow, {double? sampleRate}) async {
    if (!_isModelLoaded) {
      return EcgInferenceResult.error('Model not initialised. Call initialize() first.');
    }

    if (ecgWindow.length < 1000) {
      return EcgInferenceResult.error(
        'Window too short: expected at least 1000 samples, got ${ecgWindow.length}.',
      );
    }

    final double fs = sampleRate ?? bluetoothService.actualSampleRate;

    List<double> inputWindow = ecgWindow;
    if (ecgWindow.length < 5000) {
      final padded = List<double>.from(ecgWindow);
      final lastVal = padded.isNotEmpty ? padded.last : 128.0;
      while (padded.length < 5000) {
        padded.add(lastVal);
      }
      inputWindow = padded;
    }

    final limit = math.min(windowLength, inputWindow.length);
    final rawSamples = inputWindow.sublist(0, limit);

    // Try PyTorch model inference if loaded
    if (_usingPyTorchModel && _pytorchModel != null) {
      try {
        final normalizedInput = _zScore(rawSamples);
        final prediction = await ModelApi().getPredictionCustom(
          0, // model index
          normalizedInput,
          [1, 1, limit],
          "float32",
        );

        if (prediction != null && prediction.isNotEmpty) {
          int winnerIdx = 0;
          double winnerProb = 0.0;
          double maxRelativeRatio = -1.0;

          // Per-class threshold evaluation
          for (int i = 0; i < prediction.length && i < classLabels.length; i++) {
            final prob = (prediction[i] as num).toDouble();
            final label = classLabels[i];
            final threshold = classThresholds[label] ?? 0.30;
            final relativeRatio = prob / threshold;

            // Prioritise abnormal classes (i != 0) that exceed their threshold
            if (i > 0 && prob >= threshold) {
              if (relativeRatio > maxRelativeRatio) {
                maxRelativeRatio = relativeRatio;
                winnerIdx = i;
                winnerProb = prob;
              }
            }
          }

          // If no abnormal class exceeded its threshold, default to NORM or highest relative score
          if (maxRelativeRatio < 1.0) {
            final normProb = (prediction[0] as num).toDouble();
            final normThreshold = classThresholds['NORM'] ?? 0.31;

            if (normProb >= normThreshold) {
              winnerIdx = 0;
              winnerProb = normProb;
            } else {
              // Pick overall highest probability class as fallback
              for (int i = 0; i < prediction.length && i < classLabels.length; i++) {
                final prob = (prediction[i] as num).toDouble();
                if (prob > winnerProb) {
                  winnerProb = prob;
                  winnerIdx = i;
                }
              }
            }
          }

          final label = classLabels[winnerIdx];

          return EcgInferenceResult.success(
            label: label,
            confidence: winnerProb,
            labelIndex: winnerIdx,
          );
        }
      } catch (e) {
        debugPrint('[EcgInferenceService] PyTorch execution error ($e). Falling back to rule engine.');
      }
    }

    try {
      // Fallback: Run classification on a background isolate
      final result = await compute(_classifyWindow, {
        'window': rawSamples,
        'sampleRate': fs,
      });
      return result;
    } catch (e, stack) {
      debugPrint('[EcgInferenceService] Inference error: $e\n$stack');
      return EcgInferenceResult.error('Classification failed: $e');
    }
  }

  /// Convenience: chunk a long recording into windows and majority-vote.
  Future<EcgInferenceResult> runInferenceOnRecording(List<double> samples, {double? sampleRate}) async {
    if (samples.length < 1000) {
      return EcgInferenceResult.error(
        'Recording too short for AI analysis (minimum 1000 samples required).',
      );
    }

    final double fs = sampleRate ?? bluetoothService.actualSampleRate;
    final results = <EcgInferenceResult>[];

    if (samples.length < windowLength) {
      final result = await runInference(samples, sampleRate: fs);
      if (!result.isError) results.add(result);
    } else {
      int start = 0;
      while (start + windowLength <= samples.length) {
        final window = samples.sublist(start, start + windowLength);
        final result = await runInference(window, sampleRate: fs);
        if (!result.isError) results.add(result);
        start += windowLength;
      }
      if (samples.length - start >= 1000) {
        final window = samples.sublist(start);
        final result = await runInference(window, sampleRate: fs);
        if (!result.isError) results.add(result);
      }
    }

    if (results.isEmpty) {
      return EcgInferenceResult.error('All windows failed inference.');
    }

    final voteCounts     = List<int>.filled(classLabels.length, 0);
    final confidenceSums = List<double>.filled(classLabels.length, 0.0);

    for (final r in results) {
      if (r.labelIndex >= 0 && r.labelIndex < classLabels.length) {
        voteCounts[r.labelIndex]++;
        confidenceSums[r.labelIndex] += r.confidence;
      }
    }

    int winnerIdx = 0;
    for (int i = 1; i < classLabels.length; i++) {
      if (voteCounts[i] > voteCounts[winnerIdx]) winnerIdx = i;
    }

    final avgConfidence = voteCounts[winnerIdx] > 0
        ? confidenceSums[winnerIdx] / voteCounts[winnerIdx]
        : 0.0;

    return EcgInferenceResult.success(
      label:      classLabels[winnerIdx],
      confidence: avgConfidence,
      labelIndex: winnerIdx,
    );
  }
}

// ── Isolate-safe rule-based classifier fallback ────────────────────────────────

/// Classify a single ECG window using clinical rules mapping to [NORM, MI, STTC, CD, HYP].
EcgInferenceResult _classifyWindow(Map<String, dynamic> args) {
  final List<double> window = args['window'] as List<double>;
  final double sampleRate = args['sampleRate'] as double;

  final normalized = _zScore(window);
  final std = _std(window);

  if (std < 3.0) {
    return EcgInferenceResult.error('No ECG signal detected (flat line).');
  }

  final refractoryPeriod = (0.27 * sampleRate).round().clamp(15, 150);
  final peaks = _detectRPeaks(normalized, refractoryPeriod: refractoryPeriod);

  if (peaks.length < 2) {
    return EcgInferenceResult.success(
      label: 'NORM',
      confidence: 0.55,
      labelIndex: 0,
    );
  }

  // ── 3. RR intervals & heart rate ────────────────────────────────────────────
  final rrIntervals = <double>[];
  for (int i = 1; i < peaks.length; i++) {
    rrIntervals.add((peaks[i] - peaks[i - 1]) / sampleRate); // seconds
  }

  final meanRR   = _mean(rrIntervals);
  final stdRR    = _std(rrIntervals);
  final heartRate = meanRR > 0 ? (60.0 / meanRR).round() : 0;

  // Coefficient of variation of RR intervals (%) — rhythm regularity
  final rrCV = meanRR > 0 ? (stdRR / meanRR) * 100.0 : 0.0;

  // ── 4. Classification rules ─────────────────────────────────────────────────
  //
  //  Priority order (highest specificity first):
  //   A. Atrial Fibrillation  — high RR variability (CV > 25%) + rapid rate
  //   B. Premature Beat        — moderate RR variability (CV 15-25%)
  //   C. Left/Right BBB        — normal rhythm but wide QRS (detected by peak width)
  //   D. Normal                — everything else

  // A. High variability / ischemia indicator -> STTC / MI
  if (rrCV > 25.0 && heartRate >= 90) {
    final confidence = _clamp(0.60 + (rrCV - 25.0) / 100.0, 0.60, 0.92);
    return EcgInferenceResult.success(
      label: 'STTC',
      confidence: confidence,
      labelIndex: 2,
    );
  }

  // B. Moderate variability -> MI / STTC
  if (rrCV > 15.0) {
    final confidence = _clamp(0.60 + (rrCV - 15.0) / 80.0, 0.60, 0.88);
    return EcgInferenceResult.success(
      label: 'MI',
      confidence: confidence,
      labelIndex: 1,
    );
  }

  // C. Conduction Disturbance — wide QRS
  final avgPeakWidth = _averagePeakWidth(normalized, peaks);
  final avgPeakWidthSec = avgPeakWidth / sampleRate;

  if (avgPeakWidthSec > 0.14) { // wide QRS ~ > 140 ms
    return EcgInferenceResult.success(
      label: 'CD',
      confidence: _clamp(0.62 + (avgPeakWidthSec - 0.028) / 0.08, 0.62, 0.88),
      labelIndex: 3,
    );
  }

  // D. Normal (NORM)
  final confidence = _clamp(0.78 + (1.0 - rrCV / 15.0) * 0.14, 0.78, 0.95);
  return EcgInferenceResult.success(
    label: 'NORM',
    confidence: confidence,
    labelIndex: 0,
  );
}

// ── Signal processing helpers ─────────────────────────────────────────────────

List<double> _zScore(List<double> w) {
  if (w.isEmpty) return w;
  final m = _mean(w);
  final s = _std(w);
  if (s < 1e-8) return List<double>.filled(w.length, 0.0);
  return w.map((v) => (v - m) / s).toList();
}

double _mean(List<double> v) {
  if (v.isEmpty) return 0.0;
  return v.reduce((a, b) => a + b) / v.length;
}

double _std(List<double> v) {
  if (v.length < 2) return 0.0;
  final m = _mean(v);
  final variance = v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length;
  return math.sqrt(variance);
}

double _clamp(double v, double min, double max) =>
    v < min ? min : (v > max ? max : v);

/// Simple R-peak detector: threshold crossing with refractory period.
List<int> _detectRPeaks(List<double> signal, {double threshold = 1.2, required int refractoryPeriod}) {
  final peaks = <int>[];
  int lastPeak = -refractoryPeriod;
  bool above = false;
  double localMax = -1e9;
  int localMaxIdx = 0;

  for (int i = 0; i < signal.length; i++) {
    if (signal[i] > threshold) {
      if (!above) {
        above = true;
        localMax = signal[i];
        localMaxIdx = i;
      } else if (signal[i] > localMax) {
        localMax = signal[i];
        localMaxIdx = i;
      }
    } else {
      if (above && (localMaxIdx - lastPeak) >= refractoryPeriod) {
        peaks.add(localMaxIdx);
        lastPeak = localMaxIdx;
      }
      above = false;
    }
  }
  return peaks;
}

/// Estimate average width of QRS complexes (in samples) around detected peaks.
double _averagePeakWidth(List<double> signal, List<int> peaks, {double threshold = 0.5}) {
  if (peaks.isEmpty) return 0.0;
  final widths = <double>[];
  for (final p in peaks) {
    int left = p, right = p;
    while (left > 0 && signal[left] > threshold) {
      left--;
    }
    while (right < signal.length - 1 && signal[right] > threshold) {
      right++;
    }
    widths.add((right - left).toDouble());
  }
  return _mean(widths);
}


