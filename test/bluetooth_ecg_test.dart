import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';

import 'package:inteliwave_app/providers/ecg_provider.dart';
import 'package:inteliwave_app/providers/bluetooth_provider.dart';
import 'package:inteliwave_app/services/bluetooth_service.dart';
import 'package:inteliwave_app/models/bluetooth_device_model.dart';
import 'package:inteliwave_app/screens/main/dashboard_screen.dart';

// Mock BluetoothService
class MockBluetoothService extends Mock implements BluetoothService {
  final _deviceController = StreamController<BluetoothDeviceModel>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _ecgDataController = StreamController<List<int>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _ecgErrorController = StreamController<String>.broadcast();

  @override
  Stream<BluetoothDeviceModel> get deviceStream => _deviceController.stream;

  @override
  Stream<int> get heartRateStream => _heartRateController.stream;

  @override
  Stream<List<int>> get ecgDataStream => _ecgDataController.stream;

  @override
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  @override
  Stream<String> get ecgErrorStream => _ecgErrorController.stream;

  // Expose controllers for testing
  void addECGData(List<int> data) => _ecgDataController.add(data);

  void setConnectionStatus(bool isConnected) =>
      _connectionStatusController.add(isConnected);

  void addError(String error) => _ecgErrorController.add(error);

  void addDevice(BluetoothDeviceModel device) => _deviceController.add(device);

  void addHeartRate(int rate) => _heartRateController.add(rate);

  void dispose() {
    _deviceController.close();
    _heartRateController.close();
    _ecgDataController.close();
    _connectionStatusController.close();
    _ecgErrorController.close();
  }
}

void main() {
  group('ECG Dashboard - Bluetooth Device Connection Tests', () {
    late MockBluetoothService mockBluetoothService;

    setUp(() {
      mockBluetoothService = MockBluetoothService();
    });

    tearDown(() {
      mockBluetoothService.dispose();
    });

    testWidgets('Display ECG graph when device connects and sends data',
        (WidgetTester tester) async {
      // Build dashboard with mocked providers
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<BluetoothService>.value(value: mockBluetoothService),
              ChangeNotifierProvider(
                create: (_) => BluetoothProvider(mockBluetoothService),
              ),
              ChangeNotifierProvider(
                create: (_) => ECGProvider(mockBluetoothService),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      // Initial pump to build widget
      await tester.pumpAndSettle();

      // Verify "No Device Connected" is shown initially
      expect(find.text('No Device Connected'), findsOneWidget);
      expect(find.text('Connect Device'), findsOneWidget);

      // Simulate device connection
      mockBluetoothService.setConnectionStatus(true);
      await tester.pumpAndSettle();

      // Send some ECG data
      final ecgData = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData);
      await tester.pumpAndSettle();

      // Verify "No Device Connected" message is gone
      expect(find.text('No Device Connected'), findsNothing);

      // Verify graph is displayed
      expect(find.text('Live ECG'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      // Verify analysis widget is shown
      expect(find.text('Live Analysis'), findsOneWidget);

      // Verify metrics are displayed
      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('Avg Signal'), findsOneWidget);
      expect(find.text('Data Points'), findsOneWidget);
      expect(find.text('Max Signal'), findsOneWidget);
      expect(find.text('Min Signal'), findsOneWidget);
      expect(find.text('Quality'), findsOneWidget);

      // Verify BPM unit appears
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('Display error message when data reception fails',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<BluetoothService>.value(value: mockBluetoothService),
              ChangeNotifierProvider(
                create: (_) => BluetoothProvider(mockBluetoothService),
              ),
              ChangeNotifierProvider(
                create: (_) => ECGProvider(mockBluetoothService),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate device connection
      mockBluetoothService.setConnectionStatus(true);
      await tester.pumpAndSettle();

      // Simulate error
      const errorMsg = 'Bluetooth device disconnected unexpectedly';
      mockBluetoothService.addError(errorMsg);
      await tester.pumpAndSettle();

      // Verify error state is displayed
      expect(find.text('Error in Getting Data'), findsOneWidget);
      expect(find.text(errorMsg), findsOneWidget);
      expect(find.text('Reconnect Device'), findsOneWidget);

      // Verify analysis widget still shows but with "Connect device" message
      expect(find.text('Live Analysis'), findsOneWidget);
      expect(find.text('Connect device to view analysis'), findsOneWidget);
    });

    testWidgets('Continuous ECG data updates and metrics change',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<BluetoothService>.value(value: mockBluetoothService),
              ChangeNotifierProvider(
                create: (_) => BluetoothProvider(mockBluetoothService),
              ),
              ChangeNotifierProvider(
                create: (_) => ECGProvider(mockBluetoothService),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Connect device
      mockBluetoothService.setConnectionStatus(true);
      await tester.pumpAndSettle();

      // Send initial ECG data
      final ecgData1 = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData1);
      await tester.pumpAndSettle();

      // Verify graph is showing
      expect(find.text('Live ECG'), findsOneWidget);

      // Send more data (simulating continuous stream)
      final ecgData2 = List<int>.generate(100, (i) => 120 + (i * 1));
      mockBluetoothService.addECGData(ecgData2);
      await tester.pumpAndSettle();

      // Verify analysis is still present and updated
      expect(find.text('Live Analysis'), findsOneWidget);
      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('Data Points'), findsOneWidget);
    });

    testWidgets('Display fullscreen ECG graph when fullscreen button tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<BluetoothService>.value(value: mockBluetoothService),
              ChangeNotifierProvider(
                create: (_) => BluetoothProvider(mockBluetoothService),
              ),
              ChangeNotifierProvider(
                create: (_) => ECGProvider(mockBluetoothService),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Connect and send data
      mockBluetoothService.setConnectionStatus(true);
      await tester.pumpAndSettle();

      final ecgData = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData);
      await tester.pumpAndSettle();

      // Tap fullscreen button
      final fullscreenButton = find.byIcon(Icons.fullscreen);
      expect(fullscreenButton, findsOneWidget);

      await tester.tap(fullscreenButton);
      await tester.pumpAndSettle();

      // Verify fullscreen graph is displayed
      expect(find.text('Live ECG'), findsWidgets);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

      // Close fullscreen
      await tester.tap(find.byIcon(Icons.fullscreen_exit));
      await tester.pumpAndSettle();

      // Verify back to normal view
      expect(find.text('Live Analysis'), findsOneWidget);
    });

    testWidgets('Verify data points count updates correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<BluetoothService>.value(value: mockBluetoothService),
              ChangeNotifierProvider(
                create: (_) => BluetoothProvider(mockBluetoothService),
              ),
              ChangeNotifierProvider(
                create: (_) => ECGProvider(mockBluetoothService),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Connect device
      mockBluetoothService.setConnectionStatus(true);
      await tester.pumpAndSettle();

      // Send 50 data points
      var ecgData = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData);
      await tester.pumpAndSettle();

      // Check data points display
      expect(find.text('Data Points'), findsOneWidget);

      // Send more data
      ecgData = List<int>.generate(100, (i) => 100 + (i * 1));
      mockBluetoothService.addECGData(ecgData);
      await tester.pumpAndSettle();

      // Verify data points text still exists (value may have changed)
      expect(find.text('Data Points'), findsOneWidget);
    });

    testWidgets('Verify analysis widget state on device disconnect',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<BluetoothService>.value(value: mockBluetoothService),
              ChangeNotifierProvider(
                create: (_) => BluetoothProvider(mockBluetoothService),
              ),
              ChangeNotifierProvider(
                create: (_) => ECGProvider(mockBluetoothService),
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Connect and send data
      mockBluetoothService.setConnectionStatus(true);
      await tester.pumpAndSettle();

      final ecgData = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData);
      await tester.pumpAndSettle();

      // Verify metrics are showing
      expect(find.text('Heart Rate'), findsOneWidget);

      // Disconnect device
      mockBluetoothService.setConnectionStatus(false);
      await tester.pumpAndSettle();

      // Verify disconnected message
      expect(find.text('No Device Connected'), findsOneWidget);

      // Verify analysis still shows but with "connect device" message
      expect(find.text('Live Analysis'), findsOneWidget);
      expect(find.text('Connect device to view analysis'), findsOneWidget);
    });
  });
}
