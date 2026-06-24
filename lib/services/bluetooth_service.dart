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

  final List<BluetoothDeviceModel> _connectedDevices = [];
  BluetoothDeviceModel? _currentDevice;
  StreamSubscription? _ecgCharacteristicSubscription;
  StreamSubscription? _scanSubscription;
  Timer? _simulationTimer;

  BluetoothDeviceModel? get currentDevice => _currentDevice;
  List<BluetoothDeviceModel> get connectedDevices => _connectedDevices;

  Future<void> initialize() async {
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      _ecgErrorController.add(
          'Some Bluetooth permissions were denied. Scanning may not work.');
    }
  }

  Future<bool> isBluetoothOn() async {
    return await FlutterBluePlus.adapterState.first ==
        BluetoothAdapterState.on;
  }

  Future<void> startScan() async {
    try {
      // Inject simulated device for UI testing and verification
      final simulatedDevice = BluetoothDeviceModel(
        id: 'SIMULATED_ECG_001',
        name: 'Simulated ECG Device (Demo)',
        macAddress: '00:11:22:33:44:55',
        isConnected: false,
        lastConnected: DateTime.now(),
        signalStrength: -45,
        deviceType: 'heartbeat',
        isSaved: false,
      );
      _deviceController.add(simulatedDevice);

      // Stop any existing scan first
      await FlutterBluePlus.stopScan();

      final Set<String> seenIds = {'SIMULATED_ECG_001'};

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final deviceId = result.device.remoteId.str;
          // Avoid duplicates
          if (seenIds.contains(deviceId)) continue;

          // Show ALL named devices (earbuds, bands, sensors, etc.)
          final name = result.device.platformName;
          if (name.isNotEmpty) {
            seenIds.add(deviceId);

            final deviceType = _detectDeviceType(name);
            final device = BluetoothDeviceModel(
              id: deviceId,
              name: name,
              macAddress: deviceId,
              isConnected: false,
              lastConnected: DateTime.now(),
              signalStrength: result.rssi,
              deviceType: deviceType,
              isSaved: false,
            );

            _deviceController.add(device);
          }
        }
      }, onError: (error) {
        _ecgErrorController.add('Scan error: $error');
      });
    } catch (e) {
      throw Exception('Bluetooth scan error: $e');
    }
  }

  /// Determine device type from name for better UX display
  String _detectDeviceType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('heart') || lower.contains('ecg')) return 'heartbeat';
    if (lower.contains('band') || lower.contains('watch') ||
        lower.contains('fit')) return 'fitness';
    if (lower.contains('ear') || lower.contains('bud') ||
        lower.contains('pod') || lower.contains('headphone') ||
        lower.contains('airpod') || lower.contains('galaxy buds') ||
        lower.contains('jabra') || lower.contains('jbl')) return 'audio';
    return 'generic';
  }

  Future<void> stopScan() async {
    try {
      _scanSubscription?.cancel();
      _scanSubscription = null;
      await FlutterBluePlus.stopScan();
    } catch (e) {
      throw Exception('Failed to stop scan: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    try {
      if (device.id == 'SIMULATED_ECG_001') {
        _startSimulation(device);
        return;
      }
      final bluetoothDevice =
          BluetoothDevice(remoteId: DeviceIdentifier(device.id));

      // Connect with auto-reconnect
      await bluetoothDevice.connect(autoConnect: false);

      _currentDevice = device.copyWith(isConnected: true);
      if (!_connectedDevices.any((d) => d.id == device.id)) {
        _connectedDevices.add(_currentDevice!);
      }

      _deviceController.add(_currentDevice!);
      _connectionStatusController.add(true);

      // Listen for disconnection
      bluetoothDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _currentDevice = null;
          _connectionStatusController.add(false);
        }
      });

      // Discover services for data characteristics
      await _discoverServices(bluetoothDevice);
    } catch (e) {
      _ecgErrorController.add('Connection failed: $e');
      _connectionStatusController.add(false);
      throw Exception('Connection failed: $e');
    }
  }

  Future<void> disconnectDevice() async {
    if (_currentDevice != null) {
      if (_currentDevice!.id == 'SIMULATED_ECG_001') {
        _simulationTimer?.cancel();
        _simulationTimer = null;
        _connectedDevices.removeWhere((d) => d.id == _currentDevice!.id);
        _currentDevice = null;
        _connectionStatusController.add(false);
        return;
      }
      try {
        final bluetoothDevice =
            BluetoothDevice(remoteId: DeviceIdentifier(_currentDevice!.id));
        await bluetoothDevice.disconnect();

        _ecgCharacteristicSubscription?.cancel();
        _ecgCharacteristicSubscription = null;

        _connectedDevices.removeWhere((d) => d.id == _currentDevice!.id);
        _currentDevice = null;

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

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          try {
            final uuid = characteristic.uuid.toString().toLowerCase();

            // Heart Rate Measurement (0x2A37)
            if (uuid.contains('2a37') || uuid.contains('heart')) {
              if (characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                await characteristic.setNotifyValue(true);
                // Use onValueReceived (flutter_blue_plus v1.35+)
                characteristic.onValueReceived.listen((value) {
                  if (value.isNotEmpty) {
                    final heartRate = _parseHeartRate(value);
                    _heartRateController.add(heartRate);
                  }
                }, onError: (error) {
                  _ecgErrorController.add('Error reading heart rate: $error');
                });
              }
            }

            // ECG / custom waveform characteristics
            if (uuid.contains('2a65') ||
                uuid.contains('ecg') ||
                uuid.contains('wave')) {
              if (characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                await characteristic.setNotifyValue(true);

                _ecgCharacteristicSubscription?.cancel();
                _ecgCharacteristicSubscription =
                    characteristic.onValueReceived.listen(
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
              }
            }
          } catch (e) {
            // Skip characteristics that fail
            continue;
          }
        }
      }
    } catch (e) {
      _ecgErrorController.add('Service discovery error: $e');
      // Don't rethrow — connection is still valid even if service discovery fails
    }
  }

  List<int> _parseECGData(List<int> value) {
    try {
      List<int> ecgSamples = [];

      if (value.length > 1) {
        int startIndex = 0;
        if (value[0] < 128) {
          startIndex = 1;
        }

        for (int i = startIndex; i < value.length - 1; i += 2) {
          int sample = (value[i] | (value[i + 1] << 8));
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
      return [];
    }
  }

  int _parseHeartRate(List<int> value) {
    // BLE Heart Rate profile: flags in byte 0, BPM in byte 1 (or bytes 1-2 for 16-bit)
    if (value.isEmpty) return 0;
    final flags = value[0];
    final is16Bit = (flags & 0x01) != 0;
    if (is16Bit && value.length >= 3) {
      return value[1] | (value[2] << 8);
    } else if (value.length >= 2) {
      return value[1];
    }
    return value[0];
  }

  void _startSimulation(BluetoothDeviceModel device) {
    _simulationTimer?.cancel();

    _currentDevice = device.copyWith(isConnected: true);
    if (!_connectedDevices.any((d) => d.id == device.id)) {
      _connectedDevices.add(_currentDevice!);
    }

    _deviceController.add(_currentDevice!);
    _connectionStatusController.add(true);

    // Textbook human ECG cycle (200 samples) containing clear P, Q, R, S, T waves
    const List<int> simulatedEcgPattern = [
      100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
      100, 102, 104, 107, 109, 111, 112, 114, 115, 116, 117, 118, 118, 118, 118, 117, 116, 115, 114, 112,
      111, 109, 107, 104, 102, 100, 100, 100, 100, 100, 100, 100, 100, 100, 90, 80, 95, 110, 140, 190,
      245, 255, 210, 150, 90, 50, 30, 20, 45, 70, 90, 98, 100, 100, 100, 100, 100, 100, 100, 100,
      100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 102, 104, 107, 109,
      111, 113, 115, 117, 119, 121, 122, 124, 126, 127, 128, 130, 131, 132, 133, 133, 134, 134, 135, 135,
      135, 135, 135, 134, 134, 133, 133, 132, 131, 130, 128, 127, 126, 124, 122, 121, 119, 117, 115, 113,
      111, 109, 107, 104, 102, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
      100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
      100, 100, 100, 100, 100, 100, 100, 100, 100, 100
    ];

    int simulationIndex = 0;
    int heartRateTick = 0;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentDevice == null) {
        timer.cancel();
        return;
      }

      // Stream a chunk of 20 samples to simulate a 200Hz sample rate
      List<int> chunk = [];
      for (int i = 0; i < 20; i++) {
        chunk.add(simulatedEcgPattern[simulationIndex]);
        simulationIndex = (simulationIndex + 1) % simulatedEcgPattern.length;
      }
      _ecgDataController.add(chunk);

      // Stream heart rate every 1 second (10 ticks of 100ms)
      heartRateTick++;
      if (heartRateTick >= 10) {
        heartRateTick = 0;
        final mockHeartRate = 70 + (DateTime.now().second % 6);
        _heartRateController.add(mockHeartRate);
      }
    });
  }

  void dispose() {
    _simulationTimer?.cancel();
    _scanSubscription?.cancel();
    _ecgCharacteristicSubscription?.cancel();
    _deviceController.close();
    _heartRateController.close();
    _ecgDataController.close();
    _connectionStatusController.close();
    _ecgErrorController.close();
  }
}
