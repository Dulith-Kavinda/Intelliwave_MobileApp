import 'package:flutter_test/flutter_test.dart';
import 'package:inteliwave_app/services/bluetooth_service.dart';
import 'dart:async';

void main() {
  group('BluetoothService Binary Packet Parsing Tests', () {
    late BluetoothService service;

    setUp(() {
      service = BluetoothService();
    });

    test('Parses 14-byte binary frame correctly (SYNC1 0xAA, SYNC2 0x55)', () async {
      final samplesReceived = <int>[];
      final subscription = service.ecgDataStream.listen((chunk) {
        samplesReceived.addAll(chunk);
      });

      // Construct a 14-byte frame with packetCounter = 10 and 5 samples: [100, -200, 300, -400, 500]
      final int counter = 10;
      final sampleValues = [100, -200, 300, -400, 500];

      final packet = <int>[0xAA, 0x55, counter];
      int sum = counter;

      for (final val in sampleValues) {
        final unsignedVal = val < 0 ? val + 65536 : val;
        final lo = unsignedVal & 0xFF;
        final hi = (unsignedVal >> 8) & 0xFF;
        packet.add(lo);
        packet.add(hi);
        sum = (sum + lo + hi) & 0xFF;
      }
      packet.add(sum); // Checksum at index 13

      expect(packet.length, 14);

      // Feed packet into service
      service.processRawBytes(packet);

      // Wait brief moment for async microtask / stream emission
      await Future.delayed(Duration.zero);

      expect(samplesReceived, equals(sampleValues));

      await subscription.cancel();
    });

    test('Parses split BLE packets over multiple chunks', () async {
      final samplesReceived = <int>[];
      final subscription = service.ecgDataStream.listen((chunk) {
        samplesReceived.addAll(chunk);
      });

      final int counter = 11;
      final sampleValues = [15, -30, 45, -60, 75];

      final packet = <int>[0xAA, 0x55, counter];
      int sum = counter;

      for (final val in sampleValues) {
        final unsignedVal = val < 0 ? val + 65536 : val;
        final lo = unsignedVal & 0xFF;
        final hi = (unsignedVal >> 8) & 0xFF;
        packet.add(lo);
        packet.add(hi);
        sum = (sum + lo + hi) & 0xFF;
      }
      packet.add(sum);

      // Send first 8 bytes
      service.processRawBytes(packet.sublist(0, 8));
      await Future.delayed(Duration.zero);
      expect(samplesReceived.length, 0); // Not enough bytes yet

      // Send remaining 6 bytes
      service.processRawBytes(packet.sublist(8));
      await Future.delayed(Duration.zero);
      expect(samplesReceived, equals(sampleValues));

      await subscription.cancel();
    });
  });
}
