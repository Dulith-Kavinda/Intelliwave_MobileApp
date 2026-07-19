import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bluetooth_device_model.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

/// Thrown when the user tries to scan with Bluetooth turned off.
class BluetoothOffException implements Exception {
  const BluetoothOffException();
  @override
  String toString() => 'BluetoothOffException';
}

class BluetoothService {
  // ─── Simulator constants ──────────────────────────────────────────────────
  static const String simulatorId   = 'SIMULATOR_ECG_01';
  static const String simulatorName = 'Simulated ECG Monitor';

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
  // Gap event stream — fires the count of lost packets when a gap is detected
  final StreamController<int> _gapEventController =
      StreamController<int>.broadcast();

  Stream<BluetoothDeviceModel> get deviceStream    => _deviceController.stream;
  Stream<int>                  get heartRateStream => _heartRateController.stream;
  Stream<List<int>>            get ecgDataStream   => _ecgDataController.stream;
  Stream<bool>   get connectionStatusStream        => _connectionStatusController.stream;
  Stream<String>               get ecgErrorStream  => _ecgErrorController.stream;
  Stream<List<int>>            get rawDataStream   => _rawDataController.stream;
  /// Emits the number of lost packets each time a BLE packet gap is detected.
  Stream<int>                  get gapEventStream  => _gapEventController.stream;

  // ─── State ────────────────────────────────────────────────────────────────
  final List<BluetoothDeviceModel> _connectedDevices = [];
  BluetoothDeviceModel? _currentDevice;
  bool _isHM10Device = false;

  // Deduplication and packet gap detection state
  int? _lastPacketCount;
  int _lostPackets = 0;

  // Sliding window for dynamic sample rate and heart rate calculation
  final List<int> _recentEcgSamples = [];
  final List<DateTime> _recentSampleTimes = [];
  double _actualSampleRate = 250.0;
  int _hrCalcCounter = 0;

  double get actualSampleRate => _actualSampleRate;

  /// True when the currently connected "device" is the built-in ECG simulator.
  /// Used by the graph widget to skip DC-bias removal (simulator is already AC-coupled).
  bool get isSimulatorDevice => _isSimulatorConnected;

  // ─── Specific Device Filtering Config ──────────────────────────────────────
  /// Set to true to filter out generic HM-10 modules and only show specific devices.
  bool showOnlySpecificDevices = false;

  /// Specific device name keywords to scan and display.
  List<String> targetDeviceKeywords = [
    'intelliwave',
    'edr-ecg',
  ];

  StreamSubscription? _ecgCharacteristicSubscription;
  StreamSubscription? _scanSubscription;

  // ─── Simulator state ──────────────────────────────────────────────────────
  Timer?  _simulatorTimer;
  int     _simIndex = 0;
  bool    _isSimulatorConnected = false;

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
    try {
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
    } catch (e) {
      debugPrint('[BluetoothService] Permission request failed: $e');
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

      // ── Inject the virtual simulator device after a short delay ───────────
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_deviceController.isClosed) {
          _deviceController.add(BluetoothDeviceModel(
            id: simulatorId,
            name: simulatorName,
            macAddress: simulatorId,
            isConnected: false,
            lastConnected: DateTime.now(),
            signalStrength: -45, // fixed "strong" RSSI for the simulator
            deviceType: 'hm10',
            isSaved: false,
          ));
        }
      });

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

    final isSpecificDevice = targetDeviceKeywords.any((keyword) => lower.contains(keyword));

    if (showOnlySpecificDevices) {
      if (isSpecificDevice) {
        return 'hm10';
      }
      return 'generic'; // Ignore everything else
    }

    // HM-10 / clones standard detection
    if (isSpecificDevice ||
        lower.contains('hm') ||
        lower.contains('hmsoft') ||
        lower.contains('mlt-bt') ||
        lower.contains('bt05') ||
        lower.contains('bt-05') ||
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
    // ── Simulator path — no real BLE interaction ───────────────────────────
    if (device.id == simulatorId) {
      _stopSimulation();
      _currentDevice   = device.copyWith(isConnected: true);
      _isHM10Device    = true;
      _isSimulatorConnected = true;
      _serialBuffer.clear();
      _recentEcgSamples.clear();
      _recentSampleTimes.clear();
      _actualSampleRate = 250.0;
      _hrCalcCounter = 0;
      _lastPacketCount = null;
      _lostPackets = 0;

      if (!_connectedDevices.any((d) => d.id == device.id)) {
        _connectedDevices.add(_currentDevice!);
      }
      _deviceController.add(_currentDevice!);
      _connectionStatusController.add(true);
      _ecgErrorController.add(''); // clear any previous errors
      _startSimulation();
      return;
    }

    // ── Real BLE path ──────────────────────────────────────────────────────
    try {
      final bluetoothDevice =
          BluetoothDevice(remoteId: DeviceIdentifier(device.id));

      await bluetoothDevice.connect(autoConnect: false);

      _currentDevice   = device.copyWith(isConnected: true);
      _isHM10Device    = device.deviceType == 'hm10';
      _serialBuffer.clear();
      _recentEcgSamples.clear();
      _recentSampleTimes.clear();
      _actualSampleRate = 250.0;
      _hrCalcCounter = 0;
      _lastPacketCount = null;
      _lostPackets = 0;

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
          _recentEcgSamples.clear();
          _recentSampleTimes.clear();
          _actualSampleRate = 250.0;
          _hrCalcCounter = 0;
          _lastPacketCount = null;
          _lostPackets = 0;
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
      // ── Simulator disconnect ─────────────────────────────────────────────
      if (_isSimulatorConnected) {
        _stopSimulation();
        _connectedDevices.removeWhere((d) => d.id == simulatorId);
        _currentDevice        = null;
        _isHM10Device         = false;
        _isSimulatorConnected = false;
        _recentEcgSamples.clear();
        _recentSampleTimes.clear();
        _actualSampleRate = 250.0;
        _hrCalcCounter = 0;
        _connectionStatusController.add(false);
        return;
      }

      // ── Real BLE disconnect ──────────────────────────────────────────────
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
        _recentEcgSamples.clear();
        _recentSampleTimes.clear();
        _actualSampleRate = 250.0;
        _hrCalcCounter = 0;
        _lastPacketCount = null;
        _lostPackets = 0;

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

  @visibleForTesting
  void processRawBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _rawDataController.add(List<int>.from(bytes));
    _serialBuffer.addAll(bytes);
    _processSerialBuffer();
  }

  // ─── Serial buffer processor ──────────────────────────────────────────────
  /// Drains `_serialBuffer`, trying to parse complete data frames.
  void _processSerialBuffer() {
    while (_serialBuffer.isNotEmpty) {
      final headerIndex = _serialBuffer.indexOf(0xAA);
      final newlineIndex = _serialBuffer.indexOf(0x0A); // '\n'

      // ── Priority 1: Binary packet header 0xAA ────────────────────────────
      // If 0xAA appears at or before a newline (or if there is no newline),
      // attempt binary frame parsing first. This prevents byte value 10 (0x0A)
      // inside binary packet counters or sample data from being misinterpreted as CSV newlines.
      if (headerIndex != -1 && (newlineIndex == -1 || headerIndex < newlineIndex)) {
        // Drop any junk bytes before the binary header
        if (headerIndex > 0) {
          _serialBuffer.removeRange(0, headerIndex);
        }

        // Need at least 2 bytes to check secondary header byte (0x55 vs 4-byte frame)
        if (_serialBuffer.length < 2) break; // wait for more bytes

        // Check 14-byte frame format: [0xAA][0x55][counter][s0_lo][s0_hi]...[s4_lo][s4_hi][checksum]
        if (_serialBuffer[1] == 0x55) {
          const frameLen = 14;
          if (_serialBuffer.length < frameLen) break; // wait for complete 14-byte frame

          final packetCounter = _serialBuffer[2];
          int sum = packetCounter;
          for (int i = 3; i < 13; i++) {
            sum = (sum + _serialBuffer[i]) & 0xFF;
          }
          final expectedCs = sum;
          final actualCs = _serialBuffer[13];

          if (actualCs == expectedCs) {
            _detectGaps(packetCounter);

            // Extract 5 x 16-bit signed samples (little-endian)
            for (int i = 0; i < 5; i++) {
              final lo = _serialBuffer[3 + i * 2];
              final hi = _serialBuffer[3 + i * 2 + 1];
              final rawVal = (hi << 8) | lo;
              final sample = rawVal >= 32768 ? rawVal - 65536 : rawVal;
              _emitEcgSample(sample);
            }

            _serialBuffer.removeRange(0, frameLen);
            continue;
          } else {
            // Bad checksum — skip header byte and resync
            _serialBuffer.removeAt(0);
            continue;
          }
        } else {
          // Legacy 4-byte frame: [0xAA][H][L][CS]
          if (_serialBuffer.length < 4) break; // wait for more bytes

          final high = _serialBuffer[1];
          final low  = _serialBuffer[2];
          final cs   = _serialBuffer[3];
          final expectedCs = (0xAA ^ high ^ low) & 0xFF;

          if (cs == expectedCs) {
            final sample = (high << 8) | low;
            _emitEcgSample(sample);
            _serialBuffer.removeRange(0, 4);
            continue;
          } else {
            // Bad checksum — skip this byte and resync
            _serialBuffer.removeAt(0);
            continue;
          }
        }
      }

      // ── Priority 2: CSV text line (newline-terminated) ────────────────────
      if (newlineIndex != -1) {
        final lineBytes = _serialBuffer.sublist(0, newlineIndex);
        _serialBuffer.removeRange(0, newlineIndex + 1);
        try {
          final line = utf8.decode(lineBytes).trim();
          if (line.isNotEmpty) _parseCSVLine(line);
        } catch (_) {
          // Not valid UTF-8 — treat remaining bytes as raw ECG samples
          for (final b in lineBytes) {
            _emitEcgSample(b);
          }
        }
        continue;
      }

      // ── Priority 3: raw single-byte fallback ──────────────────────────────
      // Buffer has data but no newline and no valid binary header within reach.
      // Keep up to 64 bytes buffered in case a newline or header is on its way.
      if (_serialBuffer.length > 64) {
        final byte = _serialBuffer.removeAt(0);
        _emitEcgSample(byte);
      } else {
        break; // wait for more data
      }
    }
  }


  void _detectGaps(int packetCount) {
    if (_lastPacketCount != null) {
      final gap = packetCount - _lastPacketCount! - 1;
      // Only flag gaps of 3+ missed packets as real data loss.
      // Gaps of 1-2 packets are normal BLE connection-interval jitter and
      // should not break the drawn waveform with a gap marker.
      if (gap >= 3) {
        _lostPackets += gap;
        debugPrint('  [gap] lost $gap packet(s) (${gap * 5} samples) between packet $_lastPacketCount and $packetCount. Total lost packets: $_lostPackets');
        _gapEventController.add(gap);
      } else if (gap > 0) {
        _lostPackets += gap;
        debugPrint('  [jitter] minor gap of $gap packet(s) — suppressed from graph marker');
      }
    }
    _lastPacketCount = packetCount;
  }

  /// Parse a CSV line such as:
  ///   - `"packetCount,v0,v1,v2,v3,v4"` (new firmware packet format)
  ///   - `"BPM:72,ECG:512"` or `"72,512"` → heart rate + ECG (legacy format)
  ///   - `"BPM:72"`          → heart rate only
  ///   - `"512"`             → ECG only
  void _parseCSVLine(String line) {
    if (line.isEmpty) return;

    final parts = line.split(',');

    // Check if it's the new firmware packet format: packetCount,v0,v1,v2,v3,v4
    if (parts.length >= 6) {
      try {
        final packetCount = int.parse(parts[0].trim());
        
        // Prevent duplicate packet processing
        if (_lastPacketCount != null && packetCount == _lastPacketCount) {
          return;
        }

        final values = parts.sublist(1).map((v) => int.parse(v.trim())).toList();

        _detectGaps(packetCount);

        for (final val in values) {
          _emitEcgSample(val);
        }
        return;
      } catch (_) {
        // Fall back to legacy parsing if format conversion fails
      }
    }

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
      _emitEcgSample(ecgSample);
    }
  }

  void _emitEcgSample(int val) {
    _ecgDataController.add([val]);

    final now = DateTime.now();
    _recentEcgSamples.add(val);
    _recentSampleTimes.add(now);

    if (_recentEcgSamples.length > 1000) {
      final removeCount = _recentEcgSamples.length - 1000;
      _recentEcgSamples.removeRange(0, removeCount);
      _recentSampleTimes.removeRange(0, removeCount);
    }

    if (_recentSampleTimes.length >= 100) {
      final duration = _recentSampleTimes.last.difference(_recentSampleTimes.first).inMilliseconds / 1000.0;
      if (duration > 0.5) {
        _actualSampleRate = (_recentSampleTimes.length - 1) / duration;
      }
    }

    _calculateHeartRateFromEcg();
  }

  void _calculateHeartRateFromEcg() {
    _hrCalcCounter++;
    if (_hrCalcCounter < 100) return;
    _hrCalcCounter = 0;

    if (_recentEcgSamples.length < 300) return;

    double sum = 0;
    for (final v in _recentEcgSamples) {
      sum += v;
    }
    final mean = sum / _recentEcgSamples.length;

    double varianceSum = 0;
    for (final v in _recentEcgSamples) {
      varianceSum += (v - mean) * (v - mean);
    }
    final std = math.sqrt(varianceSum / _recentEcgSamples.length);

    if (std < 5.0) {
      _heartRateController.add(0);
      return;
    }

    final refractorySamples = (0.27 * _actualSampleRate).round().clamp(15, 150);
    final thresholdVal = mean + 1.2 * std;

    final peaks = <int>[];
    int lastPeakIdx = -refractorySamples;
    bool above = false;
    double localMax = -1e9;
    int localMaxIdx = 0;

    for (int i = 0; i < _recentEcgSamples.length; i++) {
      final val = _recentEcgSamples[i].toDouble();
      if (val > thresholdVal) {
        if (!above) {
          above = true;
          localMax = val;
          localMaxIdx = i;
        } else if (val > localMax) {
          localMax = val;
          localMaxIdx = i;
        }
      } else {
        if (above && (localMaxIdx - lastPeakIdx) >= refractorySamples) {
          peaks.add(localMaxIdx);
          lastPeakIdx = localMaxIdx;
        }
        above = false;
      }
    }

    if (peaks.length >= 2) {
      final intervals = <double>[];
      for (int i = 1; i < peaks.length; i++) {
        intervals.add((peaks[i] - peaks[i - 1]) / _actualSampleRate);
      }
      final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      if (meanInterval > 0) {
        final bpm = (60.0 / meanInterval).round();
        if (bpm >= 30 && bpm <= 220) {
          _heartRateController.add(bpm);
        } else {
          _heartRateController.add(0);
        }
      }
    } else {
      _heartRateController.add(0);
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

  // ─── Simulator engine ─────────────────────────────────────────────────────
  /// Real ECG waveform — one full multi-beat strip captured at 250 Hz.
  /// The simulator loops through this buffer indefinitely.
  static final List<int> _simWaveform = [
    -20,-21,-22,-21,-20,-20,-20,-20,-20,-18,-18,-17,-18,-17,-16,-15,-16,-16,-15,-13,
    -12,-13,-13,-12,-11,-10,-10,-11,-11,-10,-9,-9,-10,-10,-9,-7,-8,-9,-8,-8,
    -8,-8,-8,-7,-7,-7,-7,-8,-8,-7,-6,-7,-7,-7,-7,-5,-6,-6,-5,-5,
    -4,-5,-5,-4,-3,-2,-2,-2,0,1,3,3,4,7,11,12,10,7,5,4,
    2,0,-2,-3,-5,-6,-8,-10,-10,-9,-9,-9,-9,-8,-8,-7,-7,-7,-7,-6,
    -6,-6,-6,-5,-5,-6,-10,-11,-4,14,40,75,115,149,165,155,118,63,8,-27,
    -37,-34,-27,-19,-15,-14,-16,-18,-18,-16,-14,-12,-10,-8,-7,-8,-9,-10,-9,-9,
    -11,-12,-8,-2,5,7,5,1,-1,2,9,17,21,23,23,24,24,25,27,29,
    29,29,28,26,25,25,25,25,23,18,15,12,9,7,2,-3,-7,-11,-13,-14,
    -17,-21,-25,-25,-21,-15,-13,-13,-14,-15,-16,-18,-18,-17,-16,-16,-16,-15,-14,-14,
    -14,-14,-13,-11,-9,-9,-9,-10,-11,-11,-11,-11,-10,-10,-9,-8,-7,-5,-4,-5,
    -5,-5,-5,-5,-5,-7,-10,-10,-7,-4,-4,-5,-5,-5,-4,-3,-5,-8,-9,-7,
    -2,0,0,-1,-2,-3,-2,0,2,2,0,1,4,10,15,15,12,9,6,5,
    5,3,0,-4,-9,-12,-9,-5,-2,-2,-3,-6,-6,-3,-1,-3,-10,-15,-13,-7,
    -3,-4,-7,-6,-5,-6,-7,-8,-6,1,19,45,81,120,149,158,141,100,51,6,
    -20,-26,-23,-17,-12,-9,-10,-11,-12,-13,-15,-15,-15,-12,-10,-8,-8,-8,-7,-6,
    -5,-5,-5,-4,-3,-2,-1,2,4,7,8,9,11,13,15,17,18,20,21,21,
    22,25,27,29,27,24,21,19,18,16,14,10,5,1,-1,-4,-7,-10,-12,-16,
    -19,-19,-18,-17,-17,-19,-21,-21,-21,-19,-18,-19,-19,-19,-19,-18,-19,-18,-16,-14,
    -14,-14,-15,-13,-12,-11,-13,-13,-12,-11,-13,-14,-14,-11,-8,-8,-8,-9,-9,-9,
    -9,-10,-10,-9,-8,-8,-9,-10,-10,-9,-9,-10,-11,-12,-11,-10,-8,-7,-7,-8,
    -9,-8,-7,-7,-7,-7,-5,-2,0,0,-1,-1,1,5,9,11,9,6,3,1,
    -1,-3,-5,-7,-8,-9,-10,-10,-10,-10,-10,-10,-10,-9,-8,-8,-9,-11,-11,-10,
    -8,-7,-7,-6,-7,-9,-13,-13,-8,8,31,63,101,131,147,138,105,60,13,-20,
    -31,-30,-23,-15,-11,-10,-14,-17,-16,-12,-10,-10,-11,-11,-12,-12,-12,-10,-8,-5,
    -6,-6,-5,-2,0,1,2,2,4,8,12,12,14,15,17,19,20,22,25,25,
    25,23,22,23,25,25,21,18,18,17,14,8,3,1,-2,-6,-10,-13,-15,-18,
    -18,-19,-20,-19,-19,-20,-22,-24,-21,-19,-17,-17,-17,-17,-17,-17,-18,-17,-15,-13,
    -12,-12,-13,-15,-15,-13,-11,-9,-9,-8,-9,-9,-9,-8,-8,-9,-10,-9,-8,-7,
    -8,-9,-8,-7,-6,-6,-7,-8,-8,-6,-5,-7,-9,-8,-7,-6,-6,-7,-6,-5,
    -5,-5,-4,-3,-2,-1,-2,-1,0,3,7,9,9,8,5,2,0,-2,-3,-4,
    -5,-8,-9,-9,-9,-9,-9,-9,-8,-7,-7,-7,-8,-8,-8,-8,-8,-7,-6,-5,
    -5,-8,-11,-12,-9,5,26,57,95,131,153,151,124,75,23,-18,-34,-30,-22,-15,
    -10,-8,-9,-10,-11,-12,-13,-13,-12,-9,-8,-8,-8,-8,-6,-5,-4,-3,-1,0,
    0,1,2,5,8,9,10,12,14,16,19,21,22,25,27,28,27,27,27,27,
    26,24,20,19,17,14,11,7,3,0,-3,-7,-11,-13,-15,-17,-17,-18,-19,-18,
    -19,-21,-21,-21,-19,-19,-19,-18,-18,-18,-18,-18,-17,-15,-14,-14,-15,-14,-13,-12,
    -12,-12,-12,-12,-10,-10,-10,-9,-8,-7,-7,-8,-9,-8,-7,-8,-8,-8,-8,-7,
    -7,-7,-7,-6,-6,-6,-6,-6,-6,-5,-5,-6,-6,-6,-5,-5,-4,-3,-2,-1,
    0,0,1,2,4,6,8,10,10,8,5,2,1,0,0,-2,-5,-7,-8,-8,
    -9,-9,-9,-8,-8,-8,-8,-8,-6,-4,-5,-6,-7,-6,-5,-5,-7,-8,-9,-9,
    -4,12,38,73,114,147,163,156,121,68,13,-25,-35,-30,-22,-17,-15,-14,-14,-13,
    -14,-14,-13,-12,-11,-10,-10,-10,-8,-7,-7,-7,-7,-4,-2,-1,0,2,3,6,
    7,8,10,13,16,18,19,22,24,24,24,23,23,25,26,25,24,23,22,21,
    19,16,13,10,5,0,-5,-7,-10,-12,-14,-16,-18,-19,-19,-20,-19,-19,-19,-19,
    -18,-19,-18,-17,-16,-18,-19,-18,-16,-15,-14,-14,-15,-15,-13,-11,-11,-11,-10,-9,
    -9,-10,-10,-9,-9,-9,-10,-9,-8,-7,-7,-8,-6,-5,-5,-6,-7,-6,-5,-5,
    -5,-6,-6,-3,-3,-4,-6,-8,-6,-5,-4,-4,-5,-6,-5,-4,-3,0,1,2,
    2,2,4,8,9,9,7,6,3,1,0,-1,-2,-4,-6,-8,-11,-12,-10,-8,
    -6,-6,-7,-8,-8,-5,-4,-5,-7,-7,-5,-4,-5,-5,-4,-4,-7,-9,-1,19,
    46,79,119,153,169,160,119,62,4,-33,-42,-32,-19,-13,-11,-10,-9,-9,-13,-18,
    -20,-19,-17,-15,-14,-14,-13,-13,-11,-9,-8,-6,-4,-2,0,1,-2,-3,-2,2,
    6,10,14,16,19,19,20,22,23,24,25,25,24,24,24,23,21,19,16,13,
    8,4,1,-1,-4,-10,-14,-16,-17,-18,-21,-23,-24,-21,-20,-20,-21,-23,-22,-21,
    -19,-19,-20,-20,-20,-21,-21,-20,-18,-16,-16,-16,-15,-15,-14,-13,-12,-12,-10,-9,
    -9,-9,-10,-9,-8,-8,-9,-8,-7,-6,-6,-7,-5,-3,-3,-5,-8,-8,-7,-6,
    -7,-7,-6,-4,-3,-3,-4,-3,-2,-2,-2,-2,-2,-1,0,0,1,2,4,7,
    9,10,10,9,7,5,2,0,-1,-2,-5,-6,-7,-7,-8,-10,-10,-9,-8,-8,
    -9,-9,-8,-7,-7,-7,-7,-6,-4,-5,-6,-8,-11,-12,-9,4,27,59,100,140,
    166,169,142,88,29,-20,-39,-35,-26,-18,-14,-12,-11,-11,-11,-12,-13,-12,-11,-11,
    -11,-10,-8,-6,-5,-6,-6,-4,-2,-1,0,1,4,6,8,9,10,13,15,19,
    20,22,25,27,28,28,27,27,29,29,28,26,24,21,18,14,11,7,3,1,
    -3,-8,-11,-14,-16,-17,-18,-20,-21,-22,-23,-24,-24,-22,-22,-23,-23,-21,-19,-18,
    -18,-20,-19,-18,-17,-17,-17,-15,-14,-12,-12,-13,-12,-10,-10,-10,-10,-10,-9,-9,
    -10,-11,-11,-9,-7,-6,-6,-5,-4,-4,-4,-5,-5,-5,-4,-5,-6,-6,-6,-6,
    -6,-6,-6,-6,-6,-6,-7,-7,-6,-4,-3,-2,-2,-1,1,2,4,6,9,10,
    8,6,4,3,2,1,-3,-5,-6,-7,-7,-8,-6,-6,-5,-6,-6,-6,-5,-5,
    -5,-5,-5,-4,-4,-4,-5,-5,-4,-4,-7,-10,-9,3,24,54,93,136,169,180,
    160,113,54,1,-29,-35,-29,-21,-14,-11,-12,-15,-16,-16,-16,-16,-16,-16,-14,-13,
    -13,-13,-11,-9,-8,-7,-7,-6,-4,-2,-1,-1,2,5,7,8,10,13,16,19,
    21,23,25,26,27,27,26,26,26,25,23,20,19,17,13,9,5,2,-1,-4,
    -8,-12,-15,-16,-18,-20,-20,-21,-21,-21,-21,-22,-21,-21,-20,-20,-20,-20,-20,-19,
    -18,-17,-15,-14,-14,-14,-15,-14,-12,-12,-12,-12,-11,-11,-10,-10,-11,-11,-10,-9,
    -8,-8,-7,-7,-7,-8,-9,-9,-8,-7,-8,-8,-8,-7,-7,-7,-8,-7,-7,-7,
    -8,-9,-8,-7,-6,-6,-6,-6,-6,-6,-5,-5,-3,-2,-1,-1,0,1,4,7,
    8,8,7,5,3,0,-2,-2,-3,-4,-6,-9,-10,-9,-9,-9,-10,-10,-9,-9,
    -9,-9,-8,-8,-7,-8,-8,-8,-7,-7,-8,-8,-10,-10,-4,12,38,74,116,153,
    173,168,134,80,23,-20,-36,-34,-26,-18,-12,-12,-14,-16,-18,-18,-18,-17,-16,-16,
    -15,-14,-13,-11,-10,-10,-9,-8,-6,-5,-4,-3,-1,2,3,5,6,9,12,15,
    17,18,20,22,24,26,26,27,27,26,24,23,22,21,18,15,11,7,4,0,
    -4,-7,-10,-12,-15,-18,-21,-22,-22,-21,-21,-22,-21,-20,-20,-21,-20,-19,-18,-17,
    -18,-18,-18,-17,-16,-16,-16,-16,-15,-14,-14,-14,-13,-13,-13,-13,-11,-11,-10,-10,
    -11,-11,-10,-9,-9,-10,-10,-10,-9,-9,-9,-9,-9,-8,-8,-8,-8,-8,-7,-7,
    -8,-8,-7,-7,-7,-7,-8,-7,-6,-6,-7,-6,-6,-5,-4,-5,-4,-2,0,1,
    2,2,3,6,9,11,11,11,9,7,4,2,2,2,1,-2,-5,-6,-6,-6,
    -7,-7,-5,-4,-4,-5,-5,-4,-4,-4,-4,-4,-3,-2,-2,-2,-4,-5,-6,-7,
    3,25,56,96,136,165,174,155,111,54,1,-28,-33,-26,-17,-11,-8,-9,-10,-12,
    -13,-14,-14,-13,-12,-12,-12,-10,-9,-8,-8,-7,-5,-2,-1,0,1,3,5,7,
    9,10,12,14,16,18,20,23,26,28,28,29,30,30,29,28,27,27,26,25,
    22,18,15,10,6,2,-2,-5,-8,-11,-13,-15,-17,-17,-18,-19,-20,-19,-18,-18,
    -18,-18,-17,-17,-17,-17,-15,-14,-13,-12,-12,-12,-12,-11,-11,-11,-10,-10,-9,-7,
    -7,-8,-7,-6,-6,-7,-7,-7,-6,-7,-7,-7,-7,-6,-6,-6,-7,-6,-6,-6,
    -7,-7,-6,-6,-6,-7,-7,-7,-6,-6,-7,-6,-5,-4,-4,-5,-5,-4,-3,-2,
    -2,-2,-1,1,2,2,3,7,10,12,11,9,7,5,3,2,0,-1,-2,-4,
    -7,-8,-9,-9,-9,-9,-9,-8,-7,-7,-7,-6,-6,-5,-5,-5,-6,-5,-4,-6,
    -9,-13,-12,0,23,54,93,134,162,168,143,92,34,-16,-38,-38,-29,-19,-12,-10,
    -11,-13,-13,-13,-14,-14,-14,-13,-11,-11,-11,-11,-10,-8,-6,-5,-4,-3,-1,1,
    1,2,5,7,9,9,10,13,16,18,20,21,24,26,26,26,25,26,25,24,
    21,18,17,14,11,6,1,-2,-5,-8,-12,-16,-18,-19,-21,-23,-24,-24,-24,-25,
    -25,-26,-25,-23,-23,-24,-23,-22,-21,-20,-21,-20,-18,-17,-16,-16,-17,-16,-14,-14,
    -15,-15,-14,-12,-11,-12,-12,-10,-10,-10,-11,-11,-10,-9,-9,-9,-10,-9,-8,-7,
    -8,-9,-8,-8,-8,-9,-10,-10,-9,-9,-9,-9,-8,-7,-7,-8,-8,-6,-5,-4,
    -4,-3,-2,-1,0,0,2,6,9,9,6,3,2,0,-2,-3,-4,-5,-6,-7,
    -9,-10,-10,-9,-9,-10,-10,-10,-9,-9,-9,-9,-8,-7,-7,-7,-8,-7,-7,-9,
    -12,-14,-7,12,40,74,116,152,170,163,124,66,8,-31,-41,-37,-29,-19,-14,-13,
    -15,-16,-17,-18,-18,-18,-17,-15,-14,-13,-12,-12,-10,-9,-7,-7,-6,-5,-3,-1,
    0,1,3,6,8,9,12,15,19,20,21,23,25,26,27,26,25,25,24,23,
    21,18,16,13,9,5,1,-3,-5,-9,-11,-14,-16,-18,-20,-22,-23,-22,-21,-21,
    -22,-23,-22,-21,-21,-20,-20,-19,-18,-18,-18,-18,-17,-16,-15,-16,-15,-14,-12,-11,
    -12,-12,-11,-9,-9,-10,-10,-7,-7,-7,-8,-8,-7,-7,-7,-8,-8,-7,-7,-7,
    -8,-9,-8,-7,-7,-7,-7,-6,-6,-6,-8,-7,-7,-6,-6,-7,-7,-6,-5,-5,
    -5,-5,-4,-2,-2,-1,0,1,3,4,6,8,9,8,
  ];

  /// Starts the simulation timer.  Emits 5 samples every 20 ms → 250 Hz.
  void _startSimulation() {
    _simIndex = 0;
    _simulatorTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!_isSimulatorConnected) return;
      const samplesPerTick = 5;
      for (int i = 0; i < samplesPerTick; i++) {
        final sample = _simWaveform[_simIndex % _simWaveform.length];
        _simIndex = (_simIndex + 1) % _simWaveform.length;
        _emitEcgSample(sample);
      }
    });
  }

  /// Stops the simulation timer.
  void _stopSimulation() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    _isSimulatorConnected = false;
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────
  void dispose() {
    _stopSimulation();
    _scanSubscription?.cancel();
    _ecgCharacteristicSubscription?.cancel();
    _deviceController.close();
    _heartRateController.close();
    _ecgDataController.close();
    _connectionStatusController.close();
    _ecgErrorController.close();
    _rawDataController.close();
    _gapEventController.close();
  }
}
