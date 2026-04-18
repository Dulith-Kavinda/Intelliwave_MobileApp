import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../models/bluetooth_device_model.dart';

class BluetoothProvider extends ChangeNotifier {
  final BluetoothService _bluetoothService;

  bool _isScanning = false;
  List<BluetoothDeviceModel> _availableDevices = [];
  BluetoothDeviceModel? _connectedDevice;
  bool _isConnecting = false;
  String? _errorMessage;
  int _currentHeartRate = 0;

  bool get isScanning => _isScanning;
  List<BluetoothDeviceModel> get availableDevices => _availableDevices;
  BluetoothDeviceModel? get connectedDevice => _connectedDevice;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  int get currentHeartRate => _currentHeartRate;

  BluetoothProvider(this._bluetoothService) {
    _setupListeners();
  }

  void _setupListeners() {
    _bluetoothService.deviceStream.listen((device) {
      // Check if device already exists
      final existingIndex =
          _availableDevices.indexWhere((d) => d.id == device.id);

      if (existingIndex != -1) {
        _availableDevices[existingIndex] = device;
      } else {
        _availableDevices.add(device);
      }
      notifyListeners();
    });

    _bluetoothService.heartRateStream.listen((heartRate) {
      _currentHeartRate = heartRate;
      notifyListeners();
    });

    _bluetoothService.connectionStatusStream.listen((isConnected) {
      if (!isConnected) {
        _connectedDevice = null;
        _currentHeartRate = 0;
      }
      notifyListeners();
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
    _isScanning = true;
    _availableDevices.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      await _bluetoothService.startScan();
      // Scan runs for 10 seconds, then automatically stops
      await Future.delayed(const Duration(seconds: 10));
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isScanning = false;
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
      _isConnecting = false;
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
      _connectedDevice = null;
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

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
}
