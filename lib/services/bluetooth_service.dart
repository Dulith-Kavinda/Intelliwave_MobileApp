import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bluetooth_device_model.dart';
import 'dart:async';

class BluetoothService {
  late FlutterBluePlus flutterBlue;
  final StreamController<BluetoothDeviceModel> _deviceController =
      StreamController<BluetoothDeviceModel>.broadcast();
  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();

  Stream<BluetoothDeviceModel> get deviceStream => _deviceController.stream;
  Stream<int> get heartRateStream => _heartRateController.stream;

  List<BluetoothDeviceModel> _connectedDevices = [];
  BluetoothDeviceModel? _currentDevice;

  BluetoothService() {
    flutterBlue = FlutterBluePlus.instance;
  }

  Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (status.isGranted) {
      // Permissions granted
    }
  }

  Future<void> startScan() async {
    try {
      flutterBlue.startScan(timeout: const Duration(seconds: 10));

      flutterBlue.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.platformName.isNotEmpty &&
              (result.device.platformName.toLowerCase().contains('heart') ||
                  result.device.platformName.toLowerCase().contains('fitness') ||
                  result.device.platformName.toLowerCase().contains('band'))) {
            final device = BluetoothDeviceModel(
              id: result.device.id.id,
              name: result.device.platformName,
              macAddress: result.device.id.id,
              isConnected: false,
              lastConnected: DateTime.now(),
              signalStrength: result.rssi,
              deviceType: 'heartbeat',
              isSaved: false,
            );

            _deviceController.add(device);
          }
        }
      });
    } catch (e) {
      throw Exception('Bluetooth scan error: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await flutterBlue.stopScan();
    } catch (e) {
      throw Exception('Failed to stop scan: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    try {
      final bluetoothDevice = BluetoothDevice(id: DeviceIdentifier(device.id));

      await bluetoothDevice.connect();

      _currentDevice = device.copyWith(
        isConnected: true,
        lastConnected: DateTime.now(),
      );

      _connectedDevices.add(_currentDevice!);
      _deviceController.add(_currentDevice!);

      // Discover services
      await _discoverServices(bluetoothDevice);
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  Future<void> disconnectDevice() async {
    if (_currentDevice != null) {
      try {
        final bluetoothDevice =
            BluetoothDevice(id: DeviceIdentifier(_currentDevice!.id));
        await bluetoothDevice.disconnect();

        _currentDevice = _currentDevice!.copyWith(isConnected: false);
        _deviceController.add(_currentDevice!);

        _connectedDevices.removeWhere((d) => d.id == _currentDevice!.id);
      } catch (e) {
        throw Exception('Disconnection failed: $e');
      }
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      // Process services and characteristics
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Subscribe to heart rate notification characteristic
          if (characteristic.uuid.toString().toLowerCase().contains('2a37') ||
              characteristic.uuid.toString().toLowerCase().contains('heart')) {
            await characteristic.setNotifyValue(true);

            characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                // Parse heart rate from BLE data
                // Typically BPM is in the first byte
                final heartRate = _parseHeartRate(value);
                _heartRateController.add(heartRate);
              }
            });
          }
        }
      }
    } catch (e) {
      throw Exception('Service discovery error: $e');
    }
  }

  int _parseHeartRate(List<int> value) {
    // This is a basic parser - adjust based on your device's BLE protocol
    // Most heart rate monitors send BPM in the first byte after the flags
    if (value.length > 1) {
      return value[1];
    } else if (value.isNotEmpty) {
      return value[0];
    }
    return 0;
  }

  BluetoothDeviceModel? get currentDevice => _currentDevice;

  List<BluetoothDeviceModel> get connectedDevices => _connectedDevices;

  void dispose() {
    _deviceController.close();
    _heartRateController.close();
  }
}
