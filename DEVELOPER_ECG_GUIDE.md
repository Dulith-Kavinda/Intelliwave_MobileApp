# Live ECG Graph - Developer Implementation Guide

## Architecture Overview

The Live ECG Graph implementation follows the provider pattern architecture used throughout the IntelIWave app.

```
┌─────────────────────────────────────────────┐
│         Bluetooth Device (Hardware)         │
│              (ECG Monitor/Band)             │
└────────────────────┬────────────────────────┘
                     │
                     │ BLE Data
                     ▼
┌─────────────────────────────────────────────┐
│          BluetoothService                    │
│  - _parseECGData(List<int> value)           │
│  - Stream ecgDataStream                      │
│  - Stream connectionStatusStream             │
│  - Stream ecgErrorStream                     │
└────────────────────┬────────────────────────┘
                     │
                     │ Streams
                     ▼
┌─────────────────────────────────────────────┐
│            ECGProvider                       │
│  - List<int> _ecgData (buffer)              │
│  - bool _isConnected                        │
│  - bool _hasDataError                       │
│  - Manages data state & notifies            │
└────────────────────┬────────────────────────┘
                     │
                     │ Consumer2 with BluetoothProvider
                     ▼
┌─────────────────────────────────────────────┐
│         LiveECGGraphWidget                   │
│  - Renders graph with fl_chart              │
│  - Shows device/error states                │
│  - Fullscreen navigation                    │
└─────────────────────────────────────────────┘
```

## File Structure

```
lib/
├── providers/
│   ├── ecg_provider.dart          (NEW)
│   ├── bluetooth_provider.dart    (UPDATED)
│   └── index.dart                 (UPDATED)
├── services/
│   ├── bluetooth_service.dart     (UPDATED)
│   └── index.dart
├── widgets/
│   ├── live_ecg_graph_widget.dart (NEW)
│   ├── common_widgets.dart
│   └── index.dart                 (UPDATED)
├── screens/
│   └── main/
│       └── dashboard_screen.dart  (UPDATED)
├── main.dart                      (UPDATED)
└── lib_constants/
    └── app_theme.dart
```

## Component Details

### 1. ECG Provider (`lib/providers/ecg_provider.dart`)

**Purpose**: Manages ECG data state and streams

**Key Properties**:
- `_ecgData`: List<int> - Circular buffer storing ECG samples
- `_isConnected`: bool - Device connection status
- `_hasDataError`: bool - Error state flag
- `_errorMessage`: String? - Specific error details

**Key Methods**:
- `_setupListeners()` - Subscribes to Bluetooth service streams
- `_handleECGData(List<int> data)` - Processes incoming ECG data
- `clearData()` - Resets ECG buffer
- `clearError()` - Clears error state

**Stream Subscriptions**:
- `ecgDataStream` - Receives raw ECG samples
- `ecgErrorStream` - Receives error messages
- `connectionStatusStream` - Tracks device connection

### 2. Bluetooth Service Updates (`lib/services/bluetooth_service.dart`)

**New Stream Controllers**:
```dart
final StreamController<List<int>> _ecgDataController = 
    StreamController<List<int>>.broadcast();
final StreamController<bool> _connectionStatusController = 
    StreamController<bool>.broadcast();
final StreamController<String> _ecgErrorController = 
    StreamController<String>.broadcast();
```

**New Methods**:
- `_parseECGData(List<int> value)`: Converts raw BLE data to ECG samples
  - Skips flags byte if present
  - Parses 16-bit samples
  - Normalizes values to 0-255 range
  - Returns List<int> of ECG data points

**Updated Methods**:
- `connectToDevice()` - Now notifies connection status
- `disconnectDevice()` - Cancels subscriptions and notifies disconnection
- `_discoverServices()` - Enhanced to detect and subscribe to ECG characteristics

**BLE Characteristic Detection**:
- UUID patterns: '2a65', 'ecg', 'wave', or any notify/indicate characteristic
- Attempts to enable notifications for all potential ECG characteristics
- Gracefully skips characteristics that don't support notifications

### 3. Live ECG Graph Widget (`lib/widgets/live_ecg_graph_widget.dart`)

**LiveECGGraphWidget Class**:

**Parameters**:
```dart
final List<int> ecgData              // Raw ECG data points
final bool isConnected               // Device connection status
final bool hasError                  // Error state flag
final String? errorMessage           // Error details
final VoidCallback? onFullscreen     // Fullscreen callback
final bool isFullscreen              // True when in fullscreen mode
```

**Building Methods**:
- `_buildGraphCard()` - Renders the main graph display
- `_buildDisabledState()` - Shows when device not connected
- `_buildErrorState()` - Shows error message
- `_generateChartSpots()` - Converts ECG data to FlSpot for fl_chart

**Graph Configuration**:
```dart
- Display points: Last 100 points from buffer
- Value normalization: (value / 255.0) * 100
- Grid lines: 0.5 stroke width
- Intervals: 20 units horizontal, 10 vertical
- Line width: 2 pixels
- Area fill: Primary color at 10% opacity
- Dot size: 3 pixels (shown only if < 20 points)
```

**FullscreenECGGraph Class**:
- Scaffold wrapper for fullscreen display
- Full viewport height graph
- Close button in AppBar

### 4. Dashboard Integration (`lib/screens/main/dashboard_screen.dart`)

**Position**: After Current Heart Rate section

**Consumer Usage**:
```dart
Consumer2<BluetoothProvider, ECGProvider>(
  builder: (context, btProvider, ecgProvider, _) {
    return LiveECGGraphWidget(
      ecgData: ecgProvider.ecgData,
      isConnected: ecgProvider.isConnected,
      hasError: ecgProvider.hasDataError,
      errorMessage: ecgProvider.errorMessage,
      onFullscreen: () { /* Navigate to fullscreen */ },
    );
  },
)
```

**State Management**:
- Uses Consumer2 to access both Bluetooth and ECG providers
- Automatically rebuilds when either provider updates
- Passes all necessary state to widget

## Data Flow & State Management

### 1. Device Connection Flow
```
BluetoothProvider.connectToDevice()
  ↓
BluetoothService.connectToDevice()
  ↓
_discoverServices() - finds ECG characteristics
  ↓
setNotifyValue(true) - enables notifications
  ↓
BluetoothService emits connectionStatusController.add(true)
  ↓
ECGProvider listens and updates _isConnected = true
  ↓
LiveECGGraphWidget rebuilds with graph display
```

### 2. ECG Data Reception Flow
```
Bluetooth Device sends BLE characteristic value
  ↓
BluetoothService._parseECGData() processes raw data
  ↓
ecgDataController.add(parsedData)
  ↓
ECGProvider._handleECGData() receives and buffers
  ↓
_ecgData.addAll(data); notifyListeners()
  ↓
LiveECGGraphWidget rebuilds with new data
  ↓
_generateChartSpots() converts to FlSpot
  ↓
LineChart renders updated graph
```

### 3. Error Handling Flow
```
BluetoothService detects error (parsing, stream error, etc)
  ↓
ecgErrorController.add(errorMessage)
  ↓
ECGProvider listens and updates:
  - _hasDataError = true
  - _errorMessage = message
  - notifyListeners()
  ↓
LiveECGGraphWidget rebuilds
  ↓
_buildErrorState() renders error UI
```

## Customization Guide

### Adjusting Data Buffer Size
```dart
// In ECGProvider class
static const int maxDataPoints = 500;  // Change this value
```

### Changing Graph Display Points
```dart
// In LiveECGGraphWidget._generateChartSpots()
final displayPoints = ecgData.length > 100 
    ? ecgData.sublist(ecgData.length - 100)  // Change 100
    : ecgData;
```

### Modifying Graph Colors
```dart
// In LiveECGGraphWidget._buildGraphCard()
LineChartBarData(
  color: AppColors.primary,  // Change to custom color
  dotData: FlDotData(
    getDotPainter: (spot, percent, barData, index) {
      return FlDotCirclePainter(
        color: AppColors.primary,  // Dot color
      );
    },
  ),
  belowBarData: BarAreaData(
    color: AppColors.primary.withOpacity(0.1),  // Fill opacity
  ),
)
```

### Adjusting Grid Appearance
```dart
// In _buildGraphCard()
gridData: FlGridData(
  show: true,
  horizontalInterval: 20,  // Y-axis interval
  verticalInterval: 10,    // X-axis interval
)
```

### Changing Graph Height
```dart
// In dashboard_screen.dart
SizedBox(
  height: isFullscreen 
    ? MediaQuery.of(context).size.height - 120 
    : 250,  // Change this value
)
```

## ECG Data Parsing

### Current Implementation
The `_parseECGData()` method handles BLE data format:

```dart
List<int> _parseECGData(List<int> value) {
  // Format assumed: [flags_byte | sample1_low | sample1_high | ...]
  // Or: [sample1 | sample2 | sample3 | ...]
  
  List<int> ecgSamples = [];
  int startIndex = value[0] < 128 ? 1 : 0;  // Skip flags if present
  
  for (int i = startIndex; i < value.length - 1; i += 2) {
    int sample = (value[i] | (value[i + 1] << 8));
    if (sample > 255) sample = sample & 0xFF;
    ecgSamples.add(sample);
  }
  
  return ecgSamples;
}
```

### Customizing for Your Device

**If your device uses different format:**

1. **Single-byte samples**:
   ```dart
   // Just return the values as-is
   return value.sublist(startIndex);
   ```

2. **Different byte order** (little-endian vs big-endian):
   ```dart
   // Big-endian: MSB first
   int sample = (value[i] << 8) | value[i + 1];
   ```

3. **Scaling/normalization**:
   ```dart
   // If values are outside 0-255 range
   int normalized = ((sample - minValue) / (maxValue - minValue) * 255).toInt();
   ```

## Debugging Tips

### Enable Debug Logging
Add to Bluetooth service:
```dart
print('ECG Data received: $data');
print('Parsed samples: $ecgSamples');
print('Buffer size: ${_ecgData.length}');
```

### Monitor Provider State
In dashboard:
```dart
Consumer<ECGProvider>(
  builder: (context, ecgProvider, _) {
    print('ECG Data: ${ecgProvider.ecgData.length} points');
    print('Connected: ${ecgProvider.isConnected}');
    print('Error: ${ecgProvider.errorMessage}');
    // ... rest of widget
  },
)
```

### Test Error Scenarios
```dart
// Manually trigger error for testing
ecgProvider.errorMessage = 'Test error message';
ecgProvider.hasDataError = true;
ecgProvider.notifyListeners();
```

## Performance Considerations

1. **Data Buffer**: Max 500 points prevents excessive memory usage
2. **UI Updates**: Provider pattern ensures efficient rebuilds
3. **Chart Rendering**: Display only 100 points for smooth animation
4. **Stream Subscription**: Properly unsubscribe in dispose()
5. **Characteristic Detection**: Checks multiple UUID patterns efficiently

## Testing Checklist

- [ ] Device connects and shows ECG graph
- [ ] Live data updates in real-time
- [ ] Graph displays correctly on different screen sizes
- [ ] Fullscreen mode works and displays full graph
- [ ] Device disconnection shows "No Device Connected" state
- [ ] Connection error shows proper error message
- [ ] Reconnect button navigates to device scanner
- [ ] Data buffer doesn't cause memory issues
- [ ] App survives device disconnection gracefully
- [ ] Multiple reconnections work correctly

## Known Limitations

1. **BLE Characteristic Auto-Detection**: Generic approach may not work with all custom ECG devices
2. **Data Format**: Assumes standard 16-bit samples or single-byte values
3. **Buffer Size**: Fixed at 500 points (configurable but not dynamic)
4. **No Recording**: Current version doesn't persist ECG data by default
5. **Single Device**: Designed for one connected device at a time

## Future Enhancement Ideas

1. **Multi-device support** - Display multiple device streams
2. **Data recording** - Save ECG sessions to storage
3. **Pattern detection** - Identify arrhythmias automatically
4. **Comparison view** - Show multiple sessions side-by-side
5. **Export functionality** - Save as CSV or image
6. **Real-time analysis** - Calculate HRV, frequency analysis
7. **Calibration tools** - Adjust display for device-specific data formats
8. **Audio alerts** - Notify on abnormal patterns

---

**Questions?** Review the main implementation files or check the inline code comments for more details.
