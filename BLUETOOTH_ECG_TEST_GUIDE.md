# Bluetooth ECG Test - Complete Guide

## Overview
This test suite (`bluetooth_ecg_test.dart`) validates that the InteliWave app correctly handles Bluetooth device connections and ECG data streaming, including UI updates and metric calculations.

## What Gets Tested

### 1. **Device Connection & Data Display**
- ✅ Initial state shows "No Device Connected"
- ✅ When device connects, ECG graph displays
- ✅ When ECG data arrives, graph visualization updates
- ✅ Analysis metrics appear below the graph

### 2. **Error Handling**
- ✅ Error state displays when data reception fails
- ✅ Error message is shown to user
- ✅ "Reconnect Device" button appears
- ✅ Analysis widget gracefully shows "Connect device to view analysis"

### 3. **Continuous Data Streaming**
- ✅ Multiple data updates are handled correctly
- ✅ Metrics recalculate with new data
- ✅ UI updates reactively to data changes

### 4. **Fullscreen Mode**
- ✅ Fullscreen button navigates to fullscreen view
- ✅ Fullscreen exit button returns to dashboard
- ✅ Graph displays correctly in both modes

### 5. **Metric Calculations**
- ✅ Heart Rate estimation updates
- ✅ Data points count increments
- ✅ Average signal calculates correctly
- ✅ All metrics display with proper units

### 6. **State Transitions**
- ✅ Connected → Disconnected transitions work
- ✅ UI elements appear/disappear correctly
- ✅ Analysis widget shows appropriate message

## Running the Tests

### Run all Bluetooth ECG tests:
```bash
flutter test test/bluetooth_ecg_test.dart
```

### Run a specific test:
```bash
flutter test test/bluetooth_ecg_test.dart -k "Display ECG graph when device connects"
```

### Run with verbose output:
```bash
flutter test test/bluetooth_ecg_test.dart -v
```

### Run all tests in the project:
```bash
flutter test
```

## Test Structure

Each test follows this pattern:

```dart
testWidgets('Test Description', (WidgetTester tester) async {
  // 1. Setup: Create widget tree with mocked services
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        // Mocked BluetoothService
        // BluetoothProvider
        // ECGProvider
      ],
      child: const MyApp(),
    ),
  );

  // 2. Initialize the app
  await tester.pumpAndSettle();

  // 3. Simulate user actions or device events
  mockBluetoothService.setConnectionStatus(true);
  mockBluetoothService.addECGData([...]);

  // 4. Verify expected UI changes
  expect(find.text('Live ECG'), findsOneWidget);
});
```

## Available Test Cases

### Test 1: Display ECG graph when device connects and sends data
**What it tests:**
- Device connection simulation
- ECG data streaming
- Graph and analysis widget visibility
- Metric display

**Expected behavior:**
- Graph shows "Live" indicator
- All 6 metrics are visible (Heart Rate, Avg Signal, Data Points, Max Signal, Min Signal, Quality)

---

### Test 2: Display error message when data reception fails
**What it tests:**
- Error state handling
- Error message display
- UI graceful degradation
- Analysis widget fallback

**Expected behavior:**
- Shows "Error in Getting Data"
- Displays error message
- "Reconnect Device" button appears
- Analysis widget shows "Connect device to view analysis"

---

### Test 3: Continuous ECG data updates and metrics change
**What it tests:**
- Streaming data handling
- Multiple data batches
- Real-time metric updates

**Expected behavior:**
- Graph remains visible during updates
- Metrics recalculate with new data
- No UI crashes with rapid updates

---

### Test 4: Display fullscreen ECG graph when fullscreen button tapped
**What it tests:**
- Navigation to fullscreen view
- Fullscreen exit functionality
- Graph rendering in different contexts

**Expected behavior:**
- Fullscreen icon opens full-screen view
- Exit button returns to dashboard
- Graph displays correctly in both modes

---

### Test 5: Verify data points count updates correctly
**What it tests:**
- Data accumulation
- Metric calculation accuracy
- Counter updates

**Expected behavior:**
- Data Points metric appears
- Count updates with new data
- Proper unit display (pts)

---

### Test 6: Verify analysis widget hides when device disconnects
**What it tests:**
- State transition handling
- Widget UI adaptation
- Graceful disconnection

**Expected behavior:**
- Disconnected message appears
- Analysis widget shows fallback message
- "Connect Device" button is visible

---

## Mock BluetoothService API

The `MockBluetoothService` provides the following methods for testing:

```dart
// Set connection status
mockBluetoothService.setConnectionStatus(true);  // Connected
mockBluetoothService.setConnectionStatus(false); // Disconnected

// Send ECG data
final ecgData = List<int>.generate(50, (i) => 100 + (i * 2));
mockBluetoothService.addECGData(ecgData);

// Simulate error
mockBluetoothService.addError('Error message');

// Add a device
mockBluetoothService.addDevice(deviceModel);

// Add heart rate data
mockBluetoothService.addHeartRate(72);

// Clean up
mockBluetoothService.dispose();
```

## Understanding ECG Data

In tests, ECG data is simulated as:
- **List<int>**: Values between 0-255 representing raw sensor readings
- **Typical range**: 100-150 (baseline + variations)
- **Data points per test**: 50-100+ samples
- **Real device**: Sends 200+ samples per second

## Metric Calculations Explained

The analysis widget calculates:

1. **Heart Rate (BPM)**
   - Estimation: `(dataPoints / 200 * 60)`
   - Assumes ~200 samples per heartbeat
   - Real app would use peak detection

2. **Average Signal**
   - `sum(ecgData) / ecgData.length`
   - Shows baseline ECG value

3. **Data Points**
   - Total number of samples received
   - Indicates data collection duration

4. **Max/Min Signal**
   - Peak and trough values
   - Shows signal amplitude range

5. **Signal Quality**
   - Based on variance: `variance / 1000 * 100`
   - Higher values = more variation = better signal

## Troubleshooting

### Test fails with "No provider found"
**Solution:** Ensure all required providers are in MultiProvider:
```dart
MultiProvider(
  providers: [
    Provider<BluetoothService>.value(value: mockBluetoothService),
    ChangeNotifierProvider(create: (_) => BluetoothProvider(...)),
    ChangeNotifierProvider(create: (_) => ECGProvider(...)),
  ],
  child: const MyApp(),
)
```

### Test fails with "Element not found"
**Solution:** Add `await tester.pumpAndSettle();` after state changes to let widgets rebuild.

### "Can't find ')' to match" errors
**Solution:** These are code syntax errors in the widget files, not test issues. Run:
```bash
flutter analyze
```

## Best Practices for This Test

1. ✅ Always call `tester.pumpAndSettle()` after state changes
2. ✅ Use `expect(find.xxx, findsOneWidget)` to verify single instances
3. ✅ Use `expect(find.xxx, findsWidgets)` for multiple instances
4. ✅ Call `mockBluetoothService.dispose()` in tearDown
5. ✅ Generate realistic ECG data patterns
6. ✅ Test both happy path and error scenarios

## Integration with CI/CD

Add to your GitHub Actions or CI pipeline:

```yaml
- name: Run Flutter Tests
  run: flutter test test/bluetooth_ecg_test.dart
```

## Future Test Enhancements

Potential additions:
- [ ] Test with maximum data points (500+)
- [ ] Test rapid connection/disconnection cycles
- [ ] Test memory usage with large datasets
- [ ] Test battery efficiency metrics
- [ ] Test data persistence across app restarts
- [ ] Performance benchmarking
