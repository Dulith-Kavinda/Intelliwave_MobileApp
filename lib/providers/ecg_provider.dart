import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
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

  // Maximum raw samples kept in memory (500 pts @ 100 Hz ≈ 5 seconds)
  static const int maxDataPoints = 500;

  // Direct list access — no allocation overhead from unmodifiable copy
  List<int> get ecgData      => _ecgData;
  String?   get errorMessage => _errorMessage;
  bool      get isConnected  => _isConnected;
  bool      get hasDataError => _hasDataError;

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
        if (!isConnected) {
          _ecgData.clear();
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

    // Clear error on successful data
    if (_hasDataError) {
      _hasDataError  = false;
      _errorMessage  = null;
    }

    // Schedule a throttled UI update
    _scheduleNotify();
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
