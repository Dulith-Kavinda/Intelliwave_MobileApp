import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import 'dart:async';

class ECGProvider extends ChangeNotifier {
  final BluetoothService _bluetoothService;

  final List<int> _ecgData = [];
  String? _errorMessage;
  bool _isConnected = false;
  bool _hasDataError = false;
  late StreamSubscription<List<int>> _ecgDataSubscription;
  late StreamSubscription<String> _ecgErrorSubscription;

  // Maximum number of data points to keep in memory
  static const int maxDataPoints = 500;

  List<int> get ecgData => List.unmodifiable(_ecgData);
  String? get errorMessage => _errorMessage;
  bool get isConnected => _isConnected;
  bool get hasDataError => _hasDataError;

  ECGProvider(this._bluetoothService) {
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to ECG data stream
    _ecgDataSubscription = _bluetoothService.ecgDataStream.listen(
      (data) {
        _handleECGData(data);
      },
      onError: (error) {
        _errorMessage = 'Error receiving ECG data: $error';
        _hasDataError = true;
        notifyListeners();
      },
    );

    // Listen to ECG error stream
    _ecgErrorSubscription = _bluetoothService.ecgErrorStream.listen(
      (error) {
        _errorMessage = error;
        _hasDataError = true;
        notifyListeners();
      },
    );

    // Listen to connection status
    _bluetoothService.connectionStatusStream.listen(
      (isConnected) {
        _isConnected = isConnected;
        if (!isConnected) {
          _ecgData.clear();
          _errorMessage = null;
          _hasDataError = false;
        }
        notifyListeners();
      },
    );
  }

  void _handleECGData(List<int> data) {
    if (data.isEmpty) return;

    _ecgData.addAll(data);

    // Keep only the most recent maxDataPoints
    if (_ecgData.length > maxDataPoints) {
      _ecgData.removeRange(0, _ecgData.length - maxDataPoints);
    }

    // Clear error state when we successfully receive data
    if (_hasDataError) {
      _hasDataError = false;
      _errorMessage = null;
    }

    notifyListeners();
  }

  void clearData() {
    _ecgData.clear();
    _errorMessage = null;
    _hasDataError = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _hasDataError = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ecgDataSubscription.cancel();
    _ecgErrorSubscription.cancel();
    super.dispose();
  }
}
