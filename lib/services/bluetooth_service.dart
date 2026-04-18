import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bluetooth_device_model.dart';
import 'dart:async';

class BluetoothService {
  final StreamController<BluetoothDeviceModel> _deviceController =
      StreamController<BluetoothDeviceModel>.broadcast();
  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();
  final StreamController<List<int>> _ecgDataController =
      StreamController<List<int>>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  final StreamController<String> _ecgErrorController =
      StreamController<String>.broadcast();

  Stream<BluetoothDeviceModel> get deviceStream => _deviceController.stream;
  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<List<int>> get ecgDataStream => _ecgDataController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<String> get ecgErrorStream => _ecgErrorController.stream;

  List<BluetoothDeviceModel> _connectedDevices = [];
  BluetoothDeviceModel? _currentDevice;
  StreamSubscription? _ecgCharacteristicSubscription;

  Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check if all permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);
    if (allGranted) {
      // Permissions granted
    }
  }

  Future<void> startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) {
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
      await FlutterBluePlus.stopScan();
    } catch (e) {
      throw Exception('Failed to stop scan: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    try {
      final bluetoothDevice = BluetoothDevice(remoteId: DeviceIdentifier(device.id));

      await bluetoothDevice.connect();

      _currentDevice = device;

      _deviceController.add(device);

      // Notify connection status
      _connectionStatusController.add(true);

      // Discover services
      await _discoverServices(bluetoothDevice);
    } catch (e) {
      _ecgErrorController.add('Connection failed: $e');
      _connectionStatusController.add(false);
      throw Exception('Connection failed: $e');
    }
  }

  Future<void> disconnectDevice() async {
    if (_currentDevice != null) {
      try {
        final bluetoothDevice = BluetoothDevice(remoteId: DeviceIdentifier(_currentDevice!.id));
        await bluetoothDevice.disconnect();

        // Cancel ECG subscription
        _ecgCharacteristicSubscription?.cancel();

        _currentDevice = null;

        // Notify disconnection status
        _connectionStatusController.add(false);
      } catch (e) {
        _ecgErrorController.add('Disconnection error: $e');
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
          try {
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
              }, onError: (error) {
                _ecgErrorController.add('Error reading heart rate: $error');
              });
            }

            // Subscribe to ECG data characteristic
            // Common UUIDs for ECG: 2a65 (Body Sensor Location), or custom UUIDs
            if (characteristic.uuid.toString().toLowerCase().contains('2a65') ||
                characteristic.uuid.toString().toLowerCase().contains('ecg') ||
                characteristic.uuid.toString().toLowerCase().contains('wave') ||
                characteristic.properties.notify ||
                characteristic.properties.indicate) {
              // Try to enable notifications/indications
              try {
                if (characteristic.properties.notify) {
                  await characteristic.setNotifyValue(true);
                }
                if (characteristic.properties.indicate) {
                  await characteristic.setNotifyValue(true);
                }

                _ecgCharacteristicSubscription?.cancel();
                _ecgCharacteristicSubscription = characteristic.value.listen(
                  (value) {
                    if (value.isNotEmpty) {
                      try {
                        final ecgData = _parseECGData(value);
                        if (ecgData.isNotEmpty) {
                          _ecgDataController.add(ecgData);
                        }
                      } catch (e) {
                        _ecgErrorController.add('Error parsing ECG data: $e');
                      }
                    }
                  },
                  onError: (error) {
                    _ecgErrorController.add('Error receiving ECG data: $error');
                  },
                );
              } catch (e) {
                // If this characteristic doesn't support notifications, skip it
                continue;
              }
            }
          } catch (e) {
            // Continue to next characteristic if this one fails
            continue;
          }
        }
      }
    } catch (e) {
      _ecgErrorController.add('Service discovery error: $e');
      throw Exception('Service discovery error: $e');
    }
  }

  List<int> _parseECGData(List<int> value) {
    // Parse ECG data from BLE characteristics
    // This is a generic parser - adjust based on your device's BLE protocol
    // Most devices send raw ECG samples as a series of integers
    
    try {
      // If the first byte is a flags byte, skip it
      List<int> ecgSamples = [];
      
      if (value.length > 1) {
        // Assume format: [flags_byte, sample1_low, sample1_high, sample2_low, sample2_high, ...]
        // or [sample1, sample2, sample3, ...]
        
        int startIndex = 0;
        // Skip flags byte if present
        if (value[0] < 128) {
          startIndex = 1;
        }
        
        // Parse 16-bit samples
        for (int i = startIndex; i < value.length - 1; i += 2) {
          int sample = (value[i] | (value[i + 1] << 8));
          // Normalize to 0-255 range if needed
          if (sample > 255) {
            sample = sample & 0xFF;
          }
          ecgSamples.add(sample);
        }
      } else if (value.length == 1) {
        ecgSamples.add(value[0]);
      }
      
      return ecgSamples;
    } catch (e) {
      // If parsing fails, return empty list
      return [];
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
    _ecgCharacteristicSubscription?.cancel();
    _deviceController.close();
    _heartRateController.close();
    _ecgDataController.close();
    _connectionStatusController.close();
    _ecgErrorController.close();
  }
}
