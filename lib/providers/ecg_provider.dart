import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/ecg_inference_service.dart';
import '../models/ecg_inference_result.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../utils/service_locator.dart';
import 'dart:async';

class ECGProvider extends ChangeNotifier {
  final BluetoothService _bluetoothService;

  final List<int> _ecgData = [];
  String? _errorMessage;
  bool _isConnected    = false;
  bool _hasDataError   = false;
  bool _pendingNotify  = false; // true when new data arrived but UI not yet updated

  late StreamSubscription<List<int>> _ecgDataSubscription;
  late StreamSubscription<String>    _ecgErrorSubscription;

  // ── Display throttle ──────────────────────────────────────────────────────
  // BLE ECG data can arrive at ~100 Hz. Rebuilding the widget tree at that
  // rate wastes CPU and causes jank. We cap UI updates to 30 Hz (≈33 ms).
  static const Duration _uiRefreshInterval = Duration(milliseconds: 33);
  Timer? _uiRefreshTimer;

  // Maximum raw samples kept in memory (5000 pts @ 500 Hz ≈ 10 seconds)
  static const int maxDataPoints = 5000;

  // ── AI Inference buffer ───────────────────────────────────────────────────
  // Accumulates incoming ECG integers until a full inference window is ready.
  // We use a shorter window (500 samples = 1 s @ 500 Hz) for live monitoring
  // so abnormal conditions are detected and notified within ~1 second.
  // The full 5000-sample window is used only for saved recordings.
  static const int _liveInferenceWindow = 500;
  final List<int> _inferenceBuffer = [];
  bool _isRunningInference = false;
  EcgInferenceResult? _latestInferenceResult;

  // Direct list access — no allocation overhead from unmodifiable copy
  List<int>            get ecgData              => _ecgData;
  String?              get errorMessage         => _errorMessage;
  bool                 get isConnected          => _isConnected;
  bool                 get hasDataError         => _hasDataError;
  bool                 get isRunningInference   => _isRunningInference;
  EcgInferenceResult?  get latestInferenceResult => _latestInferenceResult;

  ECGProvider(this._bluetoothService) {
    _setupListeners();
  }

  void _setupListeners() {
    // Receive ECG data at BLE rate but notify UI at capped rate
    _ecgDataSubscription = _bluetoothService.ecgDataStream.listen(
      _handleECGData,
      onError: (error) {
        _errorMessage = 'Error receiving ECG data: $error';
        _hasDataError = true;
        _flushNotify(); // errors always notify immediately
      },
    );

    // Error stream — always notify immediately
    _ecgErrorSubscription = _bluetoothService.ecgErrorStream.listen(
      (error) {
        if (error.isEmpty) return; // blank errors are just "clear" signals
        _errorMessage = error;
        _hasDataError = true;
        _flushNotify();
      },
    );

    // Connection state — always notify immediately
    _bluetoothService.connectionStatusStream.listen(
      (isConnected) {
        _isConnected = isConnected;
        _latestInferenceResult = null; // Reset inference result on connection change
        if (!isConnected) {
          _ecgData.clear();
          _inferenceBuffer.clear();
          _errorMessage  = null;
          _hasDataError  = false;
          _pendingNotify = false;
          _uiRefreshTimer?.cancel();
          _uiRefreshTimer = null;
        }
        _flushNotify();
      },
    );
  }

  void _handleECGData(List<int> data) {
    if (data.isEmpty) return;

    _ecgData.addAll(data);

    // Ring-buffer: keep only most recent samples
    if (_ecgData.length > maxDataPoints) {
      _ecgData.removeRange(0, _ecgData.length - maxDataPoints);
    }
    // ── Inference buffer: accumulate for auto-monitoring ──────────────────
    _inferenceBuffer.addAll(data);
    if (_inferenceBuffer.length >= _liveInferenceWindow) {
      _inferenceBuffer.clear();
      // If we have enough history (5000 points = 10s @ 500Hz), run inference
      if (_ecgData.length >= maxDataPoints) {
        final window = _ecgData.map((v) => v.toDouble()).toList();
        _runLiveInference(window);
      }
    }
    // Clear error on successful data
    if (_hasDataError) {
      _hasDataError  = false;
      _errorMessage  = null;
    }

    // Schedule a throttled UI update
    _scheduleNotify();
  }

  /// Run live inference on a completed window and optionally notify the user.
  Future<void> _runLiveInference(List<double> window) async {
    if (_isRunningInference) return; // skip if previous inference still running
    _isRunningInference = true;

    try {
      final inferenceService = ecgInferenceService;
      if (!inferenceService.isModelLoaded) return;

      final result = await inferenceService.runInference(window);
      _latestInferenceResult = result;

      if (!result.isError) {
        // Persist result to daily log for summary service
        storageService.saveInferenceResult(DateTime.now(), result);

        // Fire anomaly notification if:
        //  • predicted class is non-Normal
        //  • confidence exceeds the threshold
        //  • notifications are enabled in settings
        final threshold = EcgInferenceService.classThresholds[result.label] ?? 0.30;
        if (result.isAbnormal && result.confidence >= threshold) {
          // Build condition-specific title and message
          String alertTitle;
          String alertMessage;
          final confPct = (result.confidence * 100).toStringAsFixed(0);
          switch (result.label) {
            case 'MI':
              alertTitle = '🚨 Myocardial Infarction Alert (MI)';
              alertMessage = 'Possible Myocardial Infarction pattern detected ($confPct% confidence). Seek immediate medical evaluation!';
              break;
            case 'STTC':
              alertTitle = '⚠️ ST/T Change Detected (STTC)';
              alertMessage = 'Possible ST/T segment change / Ischemia pattern detected ($confPct% confidence). Consult a physician.';
              break;
            case 'CD':
              alertTitle = '⚡ Conduction Disturbance (CD)';
              alertMessage = 'Possible Conduction Disturbance / Heart block pattern detected ($confPct% confidence). Medical check recommended.';
              break;
            case 'HYP':
              alertTitle = '🫀 Cardiac Hypertrophy (HYP)';
              alertMessage = 'Possible Ventricular Hypertrophy pattern detected ($confPct% confidence). Consult a cardiologist.';
              break;
            default:
              alertTitle = '⚠️ ECG Anomaly Detected (${result.label})';
              alertMessage = 'AI detected possible ${result.label} ($confPct% confidence). Please consult a doctor for evaluation.';
          }

          final notification = AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: alertTitle,
            message: alertMessage,
            timestamp: DateTime.now(),
            type: 'alert',
            isRead: false,
            isImportant: true,
          );

          // Save in mobile notification page
          try {
            getIt<NotificationProvider>().addNotification(notification);
          } catch (e) {
            storageService.saveNotification(notification);
          }

          final notificationsEnabled =
              storageService.getPreference('notifications_enabled') != 'false';
          if (notificationsEnabled) {
            notificationService.showEcgAnomalyAlert(
              label:      result.label,
              confidence: result.confidence,
            );
          }
        }
      }

      // Throttled UI notify so the badge/indicator updates
      _scheduleNotify();
    } finally {
      _isRunningInference = false;
    }
  }

  /// Marks a pending notify and starts the 30 Hz timer if not already running.
  void _scheduleNotify() {
    _pendingNotify = true;
    if (_uiRefreshTimer != null) return; // timer already ticking

    _uiRefreshTimer = Timer(_uiRefreshInterval, () {
      _uiRefreshTimer = null;
      if (_pendingNotify) {
        _pendingNotify = false;
        notifyListeners();
      }
    });
  }

  /// Immediately flush a notify (for errors / connection changes).
  void _flushNotify() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
    _pendingNotify  = false;
    notifyListeners();
  }

  void clearData() {
    _ecgData.clear();
    _inferenceBuffer.clear();
    _latestInferenceResult = null;
    _errorMessage  = null;
    _hasDataError  = false;
    _flushNotify();
  }

  void clearError() {
    _errorMessage  = null;
    _hasDataError  = false;
    _flushNotify();
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _ecgDataSubscription.cancel();
    _ecgErrorSubscription.cancel();
    super.dispose();
  }
}
