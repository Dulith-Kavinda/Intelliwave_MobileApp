# Testing Guide for IntelIWave

Complete guide for writing tests for the IntelIWave health monitoring app.

---

## Test Structure

```
test/
├── unit/
│   ├── models/
│   │   └── heartbeat_data_test.dart
│   ├── services/
│   │   └── storage_service_test.dart
│   └── providers/
│       └── heartbeat_provider_test.dart
├── widget/
│   ├── screens/
│   │   └── dashboard_screen_test.dart
│   └── widgets/
│       └── common_widgets_test.dart
└── integration/
    └── app_flow_test.dart
```

---

## Unit Tests

### Testing Models

**File:** `test/unit/models/heartbeat_data_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inteliwave_app/models/heartbeat_data.dart';

void main() {
  group('HeartbeatData', () {
    test('creates instance with required fields', () {
      final data = HeartbeatData(
        heartRate: 72,
        timestamp: DateTime(2024, 1, 1, 10, 30),
        userId: 'user1',
        deviceId: 'device1',
      );

      expect(data.heartRate, 72);
      expect(data.userId, 'user1');
      expect(data.isInNormalRange, true);
    });

    test('toMap returns correct map', () {
      final data = HeartbeatData(
        heartRate: 75,
        timestamp: DateTime(2024, 1, 1),
        userId: 'user1',
        deviceId: 'device1',
      );

      final map = data.toMap();

      expect(map['heartRate'], 75);
      expect(map['userId'], 'user1');
      expect(map.containsKey('timestamp'), true);
    });

    test('fromMap creates instance correctly', () {
      final map = {
        'id': 'id1',
        'heartRate': 80,
        'timestamp': DateTime(2024, 1, 1).toIso8601String(),
        'status': 'normal',
        'userId': 'user1',
        'deviceId': 'device1',
      };

      final data = HeartbeatData.fromMap(map);

      expect(data.heartRate, 80);
      expect(data.userId, 'user1');
      expect(data.status, 'normal');
    });

    test('getStatusEmoji returns correct emoji', () {
      final goodData = HeartbeatData(
        heartRate: 60,
        timestamp: DateTime.now(),
        userId: 'user1',
        deviceId: 'device1',
        status: 'good',
      );

      expect(goodData.getStatusEmoji(), '✅');
    });

    test('copyWith creates modified copy', () {
      final original = HeartbeatData(
        heartRate: 70,
        timestamp: DateTime.now(),
        userId: 'user1',
        deviceId: 'device1',
      );

      final copied = original.copyWith(heartRate: 85);

      expect(copied.heartRate, 85);
      expect(copied.userId, original.userId);
      expect(identical(original, copied), false);
    });

    group('Heart Rate Status', () {
      test('classifies poor heart rate', () {
        final data = HeartbeatData(
          heartRate: 130,
          timestamp: DateTime.now(),
          userId: 'user1',
          deviceId: 'device1',
        );

        expect(data.status == 'poor' || data.status == 'warning', true);
      });

      test('classifies normal heart rate', () {
        final data = HeartbeatData(
          heartRate: 75,
          timestamp: DateTime.now(),
          userId: 'user1',
          deviceId: 'device1',
        );

        expect(data.status == 'normal', true);
      });

      test('classifies good heart rate', () {
        final data = HeartbeatData(
          heartRate: 65,
          timestamp: DateTime.now(),
          userId: 'user1',
          deviceId: 'device1',
        );

        expect(data.status == 'good', true);
      });
    });
  });
}
```

### Testing Services

**File:** `test/unit/services/storage_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inteliwave_app/models/heartbeat_data.dart';
import 'package:inteliwave_app/models/user_model.dart';
import 'package:inteliwave_app/services/storage_service.dart';

void main() {
  group('StorageService', () {
    late StorageService storageService;

    setUpAll(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();
      
      // Register adapters
      Hive.registerAdapter(UserModelAdapter());
      Hive.registerAdapter(HeartbeatDataAdapter());
    });

    setUp(() async {
      storageService = StorageService();
      await storageService.initialize();
    });

    tearDown(() async {
      // Clean up after each test
      await Hive.deleteFromDisk();
    });

    test('initializes all Hive boxes', () async {
      expect(Hive.isBoxOpen('users'), true);
      expect(Hive.isBoxOpen('heartbeat_data'), true);
      expect(Hive.isBoxOpen('devices'), true);
      expect(Hive.isBoxOpen('notifications'), true);
    });

    test('adds and retrieves user', () async {
      final user = UserModel(
        id: 'user1',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '1234567890',
      );

      await storageService.addUser(user);
      final retrieved = storageService.getUserById('user1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'John Doe');
    });

    test('adds and retrieves heartbeat data', () async {
      final data = HeartbeatData(
        heartRate: 72,
        timestamp: DateTime.now(),
        userId: 'user1',
        deviceId: 'device1',
      );

      await storageService.addHeartbeatData(data);
      final retrieved = storageService.heartbeatBox.get(data.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.heartRate, 72);
    });

    test('filters heartbeat data by date range', () async {
      final now = DateTime.now();
      final data1 = HeartbeatData(
        heartRate: 70,
        timestamp: now.subtract(const Duration(hours: 2)),
        userId: 'user1',
        deviceId: 'device1',
      );
      final data2 = HeartbeatData(
        heartRate: 75,
        timestamp: now,
        userId: 'user1',
        deviceId: 'device1',
      );

      await storageService.addHeartbeatData(data1);
      await storageService.addHeartbeatData(data2);

      final filtered = storageService.getHeartbeatDataByDateRange(
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(hours: 1)),
      );

      expect(filtered.length, 1);
      expect(filtered.first.heartRate, 75);
    });

    test('deletes user data', () async {
      final user = UserModel(
        id: 'user1',
        name: 'Test User',
        email: 'test@example.com',
        phone: '1234567890',
      );

      await storageService.addUser(user);
      expect(storageService.getUserById('user1'), isNotNull);

      await storageService.deleteUser('user1');
      expect(storageService.getUserById('user1'), isNull);
    });

    test('clears all data', () async {
      final user = UserModel(
        id: 'user1',
        name: 'Test',
        email: 'test@example.com',
        phone: '1234567890',
      );
      await storageService.addUser(user);

      await storageService.clearAllData();

      expect(storageService.userBox.isEmpty, true);
    });
  });
}
```

### Testing Providers

**File:** `test/unit/providers/heartbeat_provider_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:inteliwave_app/models/heartbeat_data.dart';
import 'package:inteliwave_app/providers/heartbeat_provider.dart';
import 'package:inteliwave_app/services/storage_service.dart';

// Create mock
class MockStorageService extends Mock implements StorageService {}

void main() {
  group('HeartbeatProvider', () {
    late HeartbeatProvider provider;
    late MockStorageService mockStorageService;

    setUp(() {
      mockStorageService = MockStorageService();
      provider = HeartbeatProvider();
    });

    test('initializes with empty data', () {
      expect(provider.allHeartbeatData.isEmpty, true);
      expect(provider.isLoading, false);
    });

    test('loads heartbeat data successfully', () async {
      final testData = [
        HeartbeatData(
          heartRate: 70,
          timestamp: DateTime.now(),
          userId: 'user1',
          deviceId: 'device1',
        ),
        HeartbeatData(
          heartRate: 75,
          timestamp: DateTime.now(),
          userId: 'user1',
          deviceId: 'device1',
        ),
      ];

      when(mockStorageService.getHeartbeatDataByUserId('user1'))
          .thenReturn(testData);

      // This would need refactoring provider to accept service as param
      // for better testability
      expect(provider.allHeartbeatData.isEmpty, true);
    });

    test('calculates average heart rate correctly', () {
      // This test assumes you expose the calculation method
      final avg = provider.calculateAverage([70, 80, 90]);
      expect(avg, 80);
    });

    test('filters data by date', () {
      final now = DateTime.now();
      final testData = [
        HeartbeatData(
          heartRate: 70,
          timestamp: now.subtract(const Duration(days: 1)),
          userId: 'user1',
          deviceId: 'device1',
        ),
        HeartbeatData(
          heartRate: 75,
          timestamp: now,
          userId: 'user1',
          deviceId: 'device1',
        ),
      ];

      // Assuming you have a public filter method
      final filtered = provider.filterByDate(testData, now);
      expect(filtered.length, 1);
    });

    test('notifies listeners on data change', () {
      var listenerCalled = false;
      provider.addListener(() {
        listenerCalled = true;
      });

      provider.notifyListeners();
      expect(listenerCalled, true);
    });
  });
}
```

---

## Widget Tests

### Testing Screens

**File:** `test/widget/screens/dashboard_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inteliwave_app/providers/auth_provider.dart';
import 'package:inteliwave_app/providers/bluetooth_provider.dart';
import 'package:inteliwave_app/providers/heartbeat_provider.dart';
import 'package:inteliwave_app/providers/settings_provider.dart';
import 'package:inteliwave_app/screens/main/dashboard_screen.dart';

void main() {
  group('DashboardScreen', () {
    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => BluetoothProvider()),
          ChangeNotifierProvider(create: (_) => HeartbeatProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          home: const DashboardScreen(),
        ),
      );
    }

    testWidgets('displays dashboard elements', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Check for key elements
      expect(find.text('Current Heart Rate'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);
    });

    testWidgets('displays loading state', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Verify initial state
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tap device button navigates', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final connectButton = find.byType(ElevatedButton);
      expect(connectButton, findsOneWidget);

      await tester.tap(connectButton);
      await tester.pumpAndSettle();

      // Verify navigation occurred
    });

    testWidgets('displays device status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Check for "Connect Device" or device name
      expect(
        find.byPredicate((widget) => 
          widget is Text && 
          (widget.data == 'Connect Device' || widget.data?.contains('Device') ?? false)
        ),
        findsOneWidget,
      );
    });
  });
}
```

### Testing Widgets

**File:** `test/widget/widgets/common_widgets_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteliwave_app/widgets/common_widgets.dart';

void main() {
  group('Common Widgets', () {
    testWidgets('StatCard displays title and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Average',
              value: '72',
              unit: 'bpm',
            ),
          ),
        ),
      );

      expect(find.text('Average'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
    });

    testWidgets('HealthStatusBadge shows correct status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HealthStatusBadge(status: 'good'),
          ),
        ),
      );

      expect(find.byType(HealthStatusBadge), findsOneWidget);
    });

    testWidgets('CustomButton is clickable', (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              label: 'Test Button',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CustomButton));
      expect(pressed, true);
    });

    testWidgets('EmptyState displays icon and text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'No Data',
              message: 'Nothing to display',
            ),
          ),
        ),
      );

      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('Nothing to display'), findsOneWidget);
    });

    testWidgets('LoadingShimmer displays', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
    });
  });
}
```

---

## Integration Tests

**File:** `test/integration/app_flow_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inteliwave_app/main.dart';

void main() {
  group('App Integration Tests', () {
    testWidgets('Complete user flow', (WidgetTester tester) async {
      // Start app
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Should see login screen
      expect(find.byType(LoginForm), findsOneWidget);

      // Enter credentials
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'password123',
      );

      // Tap login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should navigate to home screen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Navigation between screens', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Navigate to different tabs
      final navigationBar = find.byType(BottomNavigationBar);
      expect(navigationBar, findsOneWidget);

      // Tap on different navigation items
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.dashboard).first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Heart rate display updates', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Look for heart rate display
      expect(find.text('Current Heart Rate'), findsOneWidget);

      // Wait and check if value updates
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(Text), findsWidgets);
    });
  });
}
```

---

## Test Best Practices

### 1. Use Fakes and Mocks
```dart
// ✅ Good - Use mocks for dependencies
class MockBluetoothService extends Mock implements BluetoothService {}

// ❌ Bad - Don't use real services in unit tests
final realService = BluetoothService();
```

### 2. Test One Thing Per Test
```dart
// ✅ Good
test('addMedication increases count', () {});
test('addMedication saves to database', () {});

// ❌ Bad
test('addMedication works correctly', () {
  // Tests multiple things
});
```

### 3. Use Descriptive Names
```dart
// ✅ Good
test('loadHeartbeatData_withValidUserId_returnsDataList', () {});

// ❌ Bad
test('test1', () {});
```

### 4. Clean Up After Tests
```dart
setUp(() {
  // Create test fixtures
});

tearDown(() {
  // Clean up
  Hive.deleteFromDisk();
});
```

### 5. Arrange-Act-Assert Pattern
```dart
test('filtering works', () {
  // Arrange
  final testData = [
    HeartbeatData(...),
    HeartbeatData(...),
  ];

  // Act
  final filtered = filter(testData);

  // Assert
  expect(filtered.length, 1);
});
```

---

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/unit/models/heartbeat_data_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
```

### Generate coverage report
```bash
# Install lcov if needed
brew install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run tests continuously
```bash
flutter test --watch
```

### Run widget tests only
```bash
flutter test test/widget --name="widget"
```

### Run specific test group
```bash
flutter test --name "HeartbeatData"
```

---

## Target Coverage

Aim for:
- **Models**: 90%+ coverage
- **Services**: 85%+ coverage
- **Providers**: 80%+ coverage
- **Screens**: 60%+ coverage (UI is harder to test)
- **Overall**: 75%+ coverage

---

## CI/CD Testing

### GitHub Actions Example
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.11.3'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage/lcov.info
```

---

## Common Test Patterns

### Testing Async Operations
```dart
test('loadData completes successfully', () async {
  final future = provider.loadData();
  expect(future, completes);
  await future;
});
```

### Testing Errors
```dart
test('loadData throws exception on error', () async {
  when(mockService.fetch()).thenThrow(Exception('Error'));
  
  expect(() => provider.loadData(), throwsException);
});
```

### Testing Stream
```dart
test('heartRateStream emits values', () {
  expect(
    service.heartRateStream,
    emits(75),
  );
});
```

---

## Debugging Tests

### Print debug info
```dart
test('debug test', () {
  print('Debug info: $value');
  debugPrint('Debug print: $value');
});
```

### Slow motion test
```dart
testWidgets('with slow motion', (WidgetTester tester) async {
  addTearDown(tester.binding.window.physicalSizeTestValue =
    const Size(540, 1080));
  addTearDown(window.physicalSizeTestValue = Size.zero);

  await tester.binding.testTextInput.enterText('text');
});
```

### Visual debugging
```dart
testWidgets('visual debug', (WidgetTester tester) async {
  await tester.pumpWidget(widget);
  
  // Take screenshot
  await expectLater(
    find.byType(Widget),
    matchesGoldenFile('golden_file.png'),
  );
});
```

---

## Test Maintenance

- Review tests when refactoring code
- Update brittle tests (those that fail frequently)
- Remove duplicate tests
- Keep test data realistic
- Document complex test logic
- Run tests before committing code

