import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bluetooth_device_model.dart';
import 'dart:async';
import 'dart:convert';

/// Thrown when the user tries to scan with Bluetooth turned off.
class BluetoothOffException implements Exception {
  const BluetoothOffException();
  @override
  String toString() => 'BluetoothOffException';
}

class BluetoothService {
  // ─── HM-10 UART over BLE UUIDs ────────────────────────────────────────────
  // These are the fixed UUIDs used by the HM-10 / MLT-BT05 module family.
  static const String hm10ServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String hm10CharUuid    = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // ─── Standard BLE Heart Rate Profile UUIDs (fallback for other sensors) ───
  static const String hrServiceUuid   = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String hrCharUuid      = '00002a37-0000-1000-8000-00805f9b34fb';

  // ─── Stream controllers ───────────────────────────────────────────────────
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
  // Raw byte stream — useful for debugging what the HM-10 sends
  final StreamController<List<int>> _rawDataController =
      StreamController<List<int>>.broadcast();

  Stream<BluetoothDeviceModel> get deviceStream    => _deviceController.stream;
  Stream<int>                  get heartRateStream => _heartRateController.stream;
  Stream<List<int>>            get ecgDataStream   => _ecgDataController.stream;
  Stream<bool>   get connectionStatusStream        => _connectionStatusController.stream;
  Stream<String>               get ecgErrorStream  => _ecgErrorController.stream;
  Stream<List<int>>            get rawDataStream   => _rawDataController.stream;

  // ─── State ────────────────────────────────────────────────────────────────
  final List<BluetoothDeviceModel> _connectedDevices = [];
  BluetoothDeviceModel? _currentDevice;
  bool _isHM10Device = false;

  StreamSubscription? _ecgCharacteristicSubscription;
  StreamSubscription? _scanSubscription;

  // Buffer for accumulating partial BLE serial packets (HM-10 MTU = 20 bytes)
  final List<int> _serialBuffer = [];

  BluetoothDeviceModel?      get currentDevice    => _currentDevice;
  List<BluetoothDeviceModel> get connectedDevices => _connectedDevices;
  bool                       get isHM10Device     => _isHM10Device;

  // ─── Initialise ───────────────────────────────────────────────────────────
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

  // ─── Scan ─────────────────────────────────────────────────────────────────
  Future<void> startScan() async {
    // ── Guard: Bluetooth must be ON before scanning ────────────────────────
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw const BluetoothOffException();
    }

    try {
      await FlutterBluePlus.stopScan();

      final Set<String> seenIds = <String>{};

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final deviceId = result.device.remoteId.str;
          if (seenIds.contains(deviceId)) continue;

          final name = result.device.platformName;
          if (name.isEmpty) continue; // skip unnamed devices

          final deviceType = _detectDeviceType(name);

          // ── Filter: only show HM-10 / UART-BLE devices ──────────────────
          // All other device types (earbuds, watches, phones, fitness bands)
          // are silently ignored — they will never appear in the UI.
          if (deviceType != 'hm10') continue;

          seenIds.add(deviceId);
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
      }, onError: (error) {
        _ecgErrorController.add('Scan error: $error');
      });
    } catch (e) {
      throw Exception('Bluetooth scan error: $e');
    }
  }


  /// Detect device type — HM-10 module names come first.
  String _detectDeviceType(String name) {
    final lower = name.toLowerCase();
    // HM-10 / clones
    if (lower.contains('hm') ||
        lower.contains('hmsoft') ||
        lower.contains('mlt-bt') ||
        lower.contains('cc41') ||
        lower.contains('jdy') ||
        lower.contains('at-09') ||
        lower.contains('ble') ||
        lower.contains('uart')) {
      return 'hm10';
    }
    if (lower.contains('heart') || lower.contains('ecg'))  { return 'heartbeat'; }
    if (lower.contains('band')  || lower.contains('watch') ||
        lower.contains('fit'))                              { return 'fitness'; }
    if (lower.contains('ear')   || lower.contains('bud')   ||
        lower.contains('pod')   || lower.contains('headphone') ||
        lower.contains('airpod')|| lower.contains('jabra') ||
        lower.contains('jbl'))                              { return 'audio'; }
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

  // ─── Connect ──────────────────────────────────────────────────────────────
  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    try {
      final bluetoothDevice =
          BluetoothDevice(remoteId: DeviceIdentifier(device.id));

      await bluetoothDevice.connect(autoConnect: false);

      _currentDevice   = device.copyWith(isConnected: true);
      _isHM10Device    = device.deviceType == 'hm10';
      _serialBuffer.clear();

      if (!_connectedDevices.any((d) => d.id == device.id)) {
        _connectedDevices.add(_currentDevice!);
      }

      _deviceController.add(_currentDevice!);
      _connectionStatusController.add(true);

      // Watch for disconnection
      bluetoothDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _currentDevice  = null;
          _isHM10Device   = false;
          _serialBuffer.clear();
          _connectionStatusController.add(false);
        }
      });

      // Discover GATT services
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
        final bluetoothDevice =
            BluetoothDevice(remoteId: DeviceIdentifier(_currentDevice!.id));
        await bluetoothDevice.disconnect();

        _ecgCharacteristicSubscription?.cancel();
        _ecgCharacteristicSubscription = null;

        _connectedDevices.removeWhere((d) => d.id == _currentDevice!.id);
        _currentDevice  = null;
        _isHM10Device   = false;
        _serialBuffer.clear();

        _connectionStatusController.add(false);
      } catch (e) {
        _ecgErrorController.add('Disconnection error: $e');
        throw Exception('Disconnection failed: $e');
      }
    }
  }

  // ─── GATT service discovery ───────────────────────────────────────────────
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();

      bool hm10Found = false;

      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        // ── HM-10 UART service (FFE0) ─────────────────────────────────────
        if (serviceUuid.contains('ffe0') || serviceUuid == hm10ServiceUuid) {
          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid.contains('ffe1') || charUuid == hm10CharUuid) {
              await _subscribeHM10Characteristic(char);
              hm10Found = true;
              _ecgErrorController.add(''); // clear any previous errors
              break;
            }
          }
        }
      }

      // ── Fallback: standard BLE Heart Rate + custom ECG UUIDs ──────────────
      if (!hm10Found) {
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            try {
              final uuid = characteristic.uuid.toString().toLowerCase();

              // Heart Rate Measurement (0x2A37)
              if (uuid.contains('2a37') || uuid.contains('heart')) {
                if (characteristic.properties.notify ||
                    characteristic.properties.indicate) {
                  await characteristic.setNotifyValue(true);
                  characteristic.onValueReceived.listen((value) {
                    if (value.isNotEmpty) {
                      _heartRateController.add(_parseHeartRate(value));
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
                      _ecgErrorController
                          .add('Error receiving ECG data: $error');
                    },
                  );
                }
              }
            } catch (e) {
              continue; // skip failing characteristics
            }
          }
        }
      }
    } catch (e) {
      _ecgErrorController.add('Service discovery error: $e');
    }
  }

  // ─── HM-10 characteristic subscription ───────────────────────────────────
  Future<void> _subscribeHM10Characteristic(
      BluetoothCharacteristic char) async {
    if (char.properties.notify || char.properties.indicate) {
      await char.setNotifyValue(true);
    }

    _ecgCharacteristicSubscription?.cancel();
    _ecgCharacteristicSubscription = char.onValueReceived.listen(
      (value) {
        if (value.isEmpty) return;

        // Forward raw bytes for debugging
        _rawDataController.add(List<int>.from(value));

        // Accumulate bytes in serial buffer (HM-10 sends max 20 bytes/packet)
        _serialBuffer.addAll(value);

        // Try to parse complete packets from buffer
        _processSerialBuffer();
      },
      onError: (error) {
        _ecgErrorController.add('HM-10 data error: $error');
      },
    );
  }

  // ─── Serial buffer processor ──────────────────────────────────────────────
  /// Drains `_serialBuffer`, trying to parse complete data frames.
  /// Supports three wire formats in priority order:
  ///
  ///  1. **Binary packet**  `[0xAA][HIGH][LOW][CS]` — 4-byte frame where
  ///     CS = (0xAA ^ HIGH ^ LOW) & 0xFF. ECG sample = (HIGH << 8) | LOW.
  ///
  ///  2. **CSV text line** terminated by `\n` — e.g.
  ///     `"BPM:72,ECG:512\n"` or `"72,512\n"` or just `"512\n"`.
  ///
  ///  3. **Raw byte fallback** — single bytes treated directly as ECG samples.
  ///
  void _processSerialBuffer() {
    while (_serialBuffer.isNotEmpty) {
      // ── Format 1: binary packet header 0xAA ────────────────────────────
      final headerIndex = _serialBuffer.indexOf(0xAA);
      if (headerIndex != -1) {
        // Remove garbage bytes before header
        if (headerIndex > 0) {
          _serialBuffer.removeRange(0, headerIndex);
        }
        // Need 4 bytes: [0xAA][H][L][CS]
        if (_serialBuffer.length < 4) break; // wait for more

        final high = _serialBuffer[1];
        final low  = _serialBuffer[2];
        final cs   = _serialBuffer[3];
        final expectedCs = (0xAA ^ high ^ low) & 0xFF;

        if (cs == expectedCs) {
          final sample = (high << 8) | low;
          _ecgDataController.add([sample]);
          _serialBuffer.removeRange(0, 4);
          continue;
        } else {
          // Bad checksum — skip this byte and resync
          _serialBuffer.removeAt(0);
          continue;
        }
      }

      // ── Format 2: CSV text line ─────────────────────────────────────────
      final newlineIndex = _serialBuffer.indexOf(0x0A); // '\n'
      if (newlineIndex != -1) {
        final lineBytes = _serialBuffer.sublist(0, newlineIndex);
        _serialBuffer.removeRange(0, newlineIndex + 1);

        try {
          final line = utf8.decode(lineBytes).trim();
          _parseCSVLine(line);
        } catch (_) {
          // Not valid UTF-8, treat as raw bytes
          for (final b in lineBytes) {
            _ecgDataController.add([b]);
          }
        }
        continue;
      }

      // ── Format 3: raw single-byte fallback ─────────────────────────────
      // If buffer has data but no 0xAA header or newline, emit bytes directly.
      // Keep up to 20 bytes buffered in case a header is on its way.
      if (_serialBuffer.length > 20) {
        final byte = _serialBuffer.removeAt(0);
        _ecgDataController.add([byte]);
      } else {
        break; // wait for more data
      }
    }
  }

  /// Parse a CSV line such as:
  ///   - `"BPM:72,ECG:512"` or `"72,512"` → heart rate + ECG
  ///   - `"BPM:72"`          → heart rate only
  ///   - `"512"`             → ECG only
  void _parseCSVLine(String line) {
    if (line.isEmpty) return;

    int? heartRate;
    int? ecgSample;

    // Named fields: BPM:xx, ECG:xx, HR:xx
    final bpmMatch = RegExp(r'(?:BPM|HR):(\d+)', caseSensitive: false)
        .firstMatch(line);
    final ecgMatch = RegExp(r'ECG:(\d+)', caseSensitive: false)
        .firstMatch(line);

    if (bpmMatch != null) heartRate = int.tryParse(bpmMatch.group(1)!);
    if (ecgMatch != null) ecgSample = int.tryParse(ecgMatch.group(1)!);

    // Positional CSV fallback: first=HR, second=ECG
    if (heartRate == null && ecgSample == null) {
      final parts = line.split(',');
      if (parts.length >= 2) {
        heartRate = int.tryParse(parts[0].trim());
        ecgSample = int.tryParse(parts[1].trim());
      } else if (parts.length == 1) {
        ecgSample = int.tryParse(parts[0].trim());
      }
    }

    if (heartRate != null && heartRate > 20 && heartRate < 250) {
      _heartRateController.add(heartRate);
    }
    if (ecgSample != null) {
      _ecgDataController.add([ecgSample]);
    }
  }

  // ─── Standard parsers (kept for non-HM10 sensors) ────────────────────────
  List<int> _parseECGData(List<int> value) {
    try {
      List<int> ecgSamples = [];
      if (value.length > 1) {
        int startIndex = value[0] < 128 ? 1 : 0;
        for (int i = startIndex; i < value.length - 1; i += 2) {
          int sample = value[i] | (value[i + 1] << 8);
          if (sample > 255) sample = sample & 0xFF;
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
    if (value.isEmpty) return 0;
    final flags = value[0];
    final is16Bit = (flags & 0x01) != 0;
    if (is16Bit && value.length >= 3) return value[1] | (value[2] << 8);
    if (value.length >= 2) return value[1];
    return value[0];
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────
  void dispose() {
    _scanSubscription?.cancel();
    _ecgCharacteristicSubscription?.cancel();
    _deviceController.close();
    _heartRateController.close();
    _ecgDataController.close();
    _connectionStatusController.close();
    _ecgErrorController.close();
    _rawDataController.close();
  }
}
