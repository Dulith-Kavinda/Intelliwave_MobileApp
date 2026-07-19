import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../models/bluetooth_device_model.dart';
import 'dart:async';

class BluetoothProvider extends ChangeNotifier {
  final BluetoothService _bluetoothService;

  bool _isScanning      = false;
  bool _isBluetoothOff  = false; // true when scan was attempted with BT off
  List<BluetoothDeviceModel> _availableDevices = [];
  BluetoothDeviceModel? _connectedDevice;
  bool _isConnecting    = false;
  String? _errorMessage;
  int _currentHeartRate = 0;

  // Raw BLE bytes for the debug panel — capped at 50 entries
  final List<List<int>> _rawDataLog = [];
  static const int _maxRawLogEntries = 50;

  // ── Throttle control ───────────────────────────────────────────────────────
  // Raw data packets arrive at ~100 Hz; the debug panel only needs 5 Hz.
  static const Duration _rawLogRefreshInterval = Duration(milliseconds: 200);
  Timer? _rawLogTimer;
  bool   _rawLogPendingNotify = false;

  StreamSubscription? _rawDataSub;

  bool   get isScanning      => _isScanning;
  bool   get isBluetoothOff  => _isBluetoothOff;
  List<BluetoothDeviceModel> get availableDevices {
    final list = List<BluetoothDeviceModel>.from(_availableDevices);
    if (_connectedDevice != null) {
      list.removeWhere((d) => d.id == _connectedDevice!.id);
      list.insert(0, _connectedDevice!);
    }
    return list;
  }
  BluetoothDeviceModel? get connectedDevice       => _connectedDevice;
  bool   get isConnected     => _connectedDevice != null;
  bool   get isConnecting    => _isConnecting;
  String? get errorMessage   => _errorMessage;
  int    get currentHeartRate => _currentHeartRate;
  bool   get isHM10Device    => _bluetoothService.isHM10Device;
  List<List<int>> get rawDataLog => List.unmodifiable(_rawDataLog);


  BluetoothProvider(this._bluetoothService) {
    _setupListeners();
  }

  void _setupListeners() {
    // Device scan results — notify immediately for responsive UI
    _bluetoothService.deviceStream.listen((device) {
      final idx = _availableDevices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _availableDevices[idx] = device;
      } else {
        _availableDevices.add(device);
      }
      // Sort: HM-10 first, then by signal strength
      _availableDevices.sort((a, b) {
        if (a.deviceType == 'hm10' && b.deviceType != 'hm10') return -1;
        if (b.deviceType == 'hm10' && a.deviceType != 'hm10') return 1;
        return b.signalStrength.compareTo(a.signalStrength);
      });
      notifyListeners();
    });

    // Heart rate — notify immediately (low frequency from device)
    _bluetoothService.heartRateStream.listen((heartRate) {
      _currentHeartRate = heartRate;
      notifyListeners();
    });

    // Connection changes — notify immediately
    _bluetoothService.connectionStatusStream.listen((isConnected) {
      if (!isConnected) {
        _connectedDevice  = null;
        _currentHeartRate = 0;
        _rawDataLog.clear();
        _rawLogPendingNotify = false;
        _rawLogTimer?.cancel();
        _rawLogTimer = null;
      } else if (_connectedDevice == null) {
        _connectedDevice = _bluetoothService.currentDevice ??
            BluetoothDeviceModel(
              id: 'unknown',
              name: 'Heart Monitor',
              macAddress: '00:00:00:00:00:00',
              isConnected: true,
              lastConnected: DateTime.now(),
              signalStrength: -50,
              deviceType: 'hm10',
              isSaved: false,
            );
      }
      notifyListeners();
    });

    // Raw HM-10 bytes — throttled to 5 Hz for debug panel
    _rawDataSub = _bluetoothService.rawDataStream.listen((bytes) {
      _rawDataLog.add(List<int>.from(bytes));
      if (_rawDataLog.length > _maxRawLogEntries) {
        _rawDataLog.removeAt(0);
      }
      _scheduleRawLogNotify();
    });
  }

  /// One-shot timer: coalesces raw log updates into max 5 Hz notifications.
  void _scheduleRawLogNotify() {
    _rawLogPendingNotify = true;
    if (_rawLogTimer != null) return;

    _rawLogTimer = Timer(_rawLogRefreshInterval, () {
      _rawLogTimer = null;
      if (_rawLogPendingNotify) {
        _rawLogPendingNotify = false;
        notifyListeners();
      }
    });
  }

  Future<void> initialize() async {
    try {
      await _bluetoothService.initialize();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    _isScanning      = true;
    _isBluetoothOff  = false;
    _availableDevices.clear();
    _errorMessage    = null;
    notifyListeners();

    try {
      await _bluetoothService.startScan();
      await Future.delayed(const Duration(seconds: 15));
      _isScanning = false;
      notifyListeners();
    } on BluetoothOffException {
      // BT is off — set the flag, UI will show the turn-on dialog
      _isBluetoothOff = true;
      _isScanning     = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isScanning   = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await _bluetoothService.stopScan();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bluetoothService.connectToDevice(device);
      _connectedDevice = device.copyWith(isConnected: true);
      _isConnecting    = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await _bluetoothService.disconnectDevice();
      _connectedDevice  = null;
      _currentHeartRate = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearBluetoothOffFlag() {
    _isBluetoothOff = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _rawLogTimer?.cancel();
    _rawDataSub?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }
}
