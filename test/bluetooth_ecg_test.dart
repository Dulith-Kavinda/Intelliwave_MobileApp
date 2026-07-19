import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';
import 'package:get_it/get_it.dart';

import 'package:inteliwave_app/providers/ecg_provider.dart';
import 'package:inteliwave_app/providers/bluetooth_provider.dart';
import 'package:inteliwave_app/services/bluetooth_service.dart';
import 'package:inteliwave_app/services/storage_service.dart';
import 'package:inteliwave_app/models/bluetooth_device_model.dart';
import 'package:inteliwave_app/models/ecg_recording_model.dart';
import 'package:inteliwave_app/screens/main/dashboard_screen.dart';
import 'package:inteliwave_app/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:inteliwave_app/models/user_model.dart';

// Mock BluetoothService
class MockBluetoothService extends Mock implements BluetoothService {
  final _deviceController = StreamController<BluetoothDeviceModel>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _ecgDataController = StreamController<List<int>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _ecgErrorController = StreamController<String>.broadcast();
  final _rawDataController = StreamController<List<int>>.broadcast();

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

  @override
  Stream<List<int>> get rawDataStream => _rawDataController.stream;

  @override
  bool get isHM10Device => false;

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
    _rawDataController.close();
  }
}

// Mock StorageService
class MockStorageService extends Mock implements StorageService {
  @override
  List<ECGRecording> getECGRecordings() => [];

  @override
  Future<void> saveECGRecording(ECGRecording recording) async {}
}

void main() {
  group('ECG Dashboard - Bluetooth Device Connection Tests', () {
    late MockBluetoothService mockBluetoothService;
    late FakeAuthProvider mockAuthProvider;

    setUp(() {
      mockBluetoothService = MockBluetoothService();
      mockAuthProvider = FakeAuthProvider();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<StorageService>()) {
        getIt.unregister<StorageService>();
      }
      if (getIt.isRegistered<BluetoothService>()) {
        getIt.unregister<BluetoothService>();
      }
      getIt.registerSingleton<StorageService>(MockStorageService());
      getIt.registerSingleton<BluetoothService>(mockBluetoothService);
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
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      // Initial pump to build widget
      await tester.pumpAndSettle();

      // Verify Dashboard screen is displayed
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Quick Access'), findsOneWidget);

      // Simulate device connection
      mockBluetoothService.setConnectionStatus(true);
      mockBluetoothService.addHeartRate(75);
      await tester.pumpAndSettle();

      // Send some ECG data
      final ecgData = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData);
      await tester.pumpAndSettle();

      // Verify graph is displayed
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify metrics are displayed
      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('Signal Quality'), findsOneWidget);

      // Verify BPM unit appears
      expect(find.textContaining('BPM'), findsOneWidget);
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
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
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
      expect(find.text('Signal Error'), findsOneWidget);
      expect(find.text(errorMsg), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
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
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
            ],
            child: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Connect device
      mockBluetoothService.setConnectionStatus(true);
      mockBluetoothService.addHeartRate(72);
      await tester.pumpAndSettle();

      // Send initial ECG data
      final ecgData1 = List<int>.generate(50, (i) => 100 + (i * 2));
      mockBluetoothService.addECGData(ecgData1);
      await tester.pumpAndSettle();

      // Verify graph is showing
      expect(find.byType(CustomPaint), findsWidgets);

      // Send more data (simulating continuous stream)
      final ecgData2 = List<int>.generate(100, (i) => 120 + (i * 1));
      mockBluetoothService.addECGData(ecgData2);
      mockBluetoothService.addHeartRate(78);
      await tester.pumpAndSettle();

      // Verify metrics section is still present
      expect(find.text('Heart Rate'), findsOneWidget);
    });

    testWidgets('Display fullscreen ECG graph when fullscreen button tapped',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BluetoothService>.value(value: mockBluetoothService),
            ChangeNotifierProvider(
              create: (_) => BluetoothProvider(mockBluetoothService),
            ),
            ChangeNotifierProvider(
              create: (_) => ECGProvider(mockBluetoothService),
            ),
            ChangeNotifierProvider<AuthProvider>.value(
              value: mockAuthProvider,
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
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
      final fullscreenButton = find.byIcon(Icons.open_in_full);
      expect(fullscreenButton, findsOneWidget);

      await tester.tap(fullscreenButton);
      await tester.pumpAndSettle();

      // Verify fullscreen graph is displayed
      expect(find.text('Live ECG Analysis Terminal'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);

      // Close fullscreen
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      // Verify back to normal view
      expect(find.text('Heart Rate'), findsOneWidget);
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
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
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

      // Verify disconnected message in status bar
      expect(find.textContaining('No Device Connected'), findsOneWidget);

      // Verify metrics are still shown
      expect(find.text('Heart Rate'), findsOneWidget);
    });
  });
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get currentUserModel => null;

  @override
  supabase.User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
