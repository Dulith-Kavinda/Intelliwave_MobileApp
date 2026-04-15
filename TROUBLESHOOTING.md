# Development Troubleshooting Guide

## Common Build Issues

### Issue: "Build failed" immediately after clone
```
Error: No pubspec.lock file
```
**Solution:**
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Unhandled Exception: MissingPluginException"
```
MissingPluginException(No implementation found for method on channel...)
```
**Cause:** Platform-specific plugins not built for your target platform
**Solution:**
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: "Unable to Locate plugin" (Firebase)
**Solution:**
1. Verify CocoaPods installed (iOS): `sudo gem install cocoapods`
2. Clear pod cache: `cd ios && rm -rf Pods Podfile.lock && cd ..`
3. Rebuild: `flutter clean && flutter pub get && flutter run`

---

## Bluetooth Connection Issues

### Issue: "No devices found" in Device Scanner
**Checklist:**
- [ ] Bluetooth is enabled on device
- [ ] Bluetooth device is powered on and nearby
- [ ] App has Bluetooth permissions granted
- [ ] Using Android 6.0+ or iOS 13.0+

**For Android:**
```
Check AndroidManifest.xml has:
- android.permission.BLUETOOTH
- android.permission.BLUETOOTH_ADMIN
- android.permission.BLUETOOTH_SCAN (Android 12+)
- android.permission.BLUETOOTH_CONNECT (Android 12+)
```

**For iOS:**
```
Check Info.plist has:
- NSBluetoothAlwaysUsageDescription
- NSBluetoothPeripheralUsageDescription
```

### Issue: "Permission denied" for Bluetooth
**Solution:**
```dart
// Permission request is automatic in BluetoothService.initialize()
// Ensure permissions are declared in manifest/plist
await bluetoothService.initialize();
```

### Issue: Heart rate reads as 0 or incorrect values
**Cause:** Incorrect BLE characteristic parsing
**Current Implementation:** Reads byte[1] as BPM
**Solution:** Modify `_parseHeartRate()` in `lib/services/bluetooth_service.dart`
```dart
// Example for different device types
int _parseHeartRate(List<int> data) {
  if (data.isEmpty) return 0;
  
  // Standard Heart Rate Profile (GATTĀ 0x2A37)
  int flags = data[0];
  int offset = 1;
  
  if ((flags & 0x80) != 0) {
    // 16-bit heart rate (little endian)
    return (data[offset + 1] << 8) | data[offset];
  } else {
    // 8-bit heart rate
    return data[offset];
  }
}
```

### Issue: Device disconnects randomly
**Solutions:**
1. Reduce scan frequency
2. Increase connection timeout
3. Handle reconnection in `BluetoothService`
4. Update BLE library: `flutter pub upgrade flutter_blue_plus`

---

## Firebase Connection Issues

### Issue: "Firebase not initialized" error
```
[Firebase/Core] I-COR000001 Firebase SDK version 8.x.x started in X seconds
```
**Solution:** Move Firebase initialization before creating providers:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Then setup providers
  runApp(const MyApp());
}
```

### Issue: "PERMISSION_DENIED" from Firestore
```
The caller does not have permission to execute the specified operation
```
**Solution:** Update Firestore security rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userID} {
      allow read, write: if request.auth.uid == userID;
    }
    match /heartbeat_data/{docID} {
      allow read, write: if request.auth.uid == resource.data.userId;
    }
  }
}
```

### Issue: Authentication fails silently
**Check:**
1. Verify Firebase project ID in `firebase_options.dart`
2. Enable Email/Password auth in Firebase Console
3. Enable Google Sign-In provider
4. Check Android SHA-1 fingerprint for Google auth:
   ```bash
   ./gradlew signingReport  # From android/ directory
   ```

### Issue: "PlatformException(NotInitialized...)" on cold start
**Solution:** Add proper initialization sequence in main.dart:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  setupServiceLocator();
  await storageService.initialize();
  await bluetoothService.initialize();
  runApp(const MyApp());
}
```

---

## State Management Issues

### Issue: Provider returns null unexpectedly
**Common Causes:**
1. Provider not in MultiProvider
2. Accessing before initialization
3. Disposed provider being accessed

**Debug:**
```dart
// In any screen
final provider = context.read<your_provider>();
print('Provider: $provider');
print('Data: ${provider.data}');
```

### Issue: "Tried to call notifyListeners on an uninitialized ChangeNotifier"
**Solution:** Initialize in correct place:
```dart
// ❌ Wrong - don't call in constructor
MyProvider() {
  loadData(); // This calls notifyListeners
}

// ✅ Correct - lazy initialize or use FutureBuilder
MyProvider() {
  _init();
}

Future<void> _init() async {
  await loadData();
}
```

### Issue: Widget not rebuilding on provider change
**Solution:** Use proper widget type:
```dart
// ❌ Wrong
class MyWidget extends StatelessWidget {
  @override
  Widget build(context) {
    final data = context.read<MyProvider>().data; // Won't rebuild
    return Text(data);
  }
}

// ✅ Correct
class MyWidget extends StatelessWidget {
  @override
  Widget build(context) {
    final data = context.watch<MyProvider>().data; // Will rebuild
    return Text(data);
  }
}
```

---

## Database Issues

### Issue: "Hive box not registered"
```
HiveError: Box not found. Did you forget to call Hive.registerAdapter()?
```
**Solution:** Run build_runner:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Hive data persists when it shouldn't
**Solution:** Manual clear:
```dart
// In StorageService or anywhere
await Hive.deleteBoxFromDisk('box_name');

// Clear all
await Hive.deleteFromDisk();
```

### Issue: Hive adapter version mismatch
**Solution:**
1. Edit `lib/models/user_model.dart` to change typeId
2. Or clear existing adapters:
```bash
flutter pub run build_runner clean
flutter pub run build_runner build
```

### Issue: Local storage not syncing with Firestore
**Current Architecture:** Hive is primary, Firestore is secondary
**To sync manually:**
```dart
// In AuthProvider
Future<void> updateUserProfile(UserModel user) async {
  // Update local
  await storageService.addUser(user);
  
  // Update remote
  await _firebaseAuth.currentUser?.updateDisplayName(user.name);
  await _firestore.collection('users').doc(user.id).set(user.toMap());
  
  notifyListeners();
}
```

---

## Performance Issues

### Issue: "jank" or stuttering in UI
**Causes:** Heavy computation on main thread
**Solutions:**
```dart
// Use compute() for heavy work
import 'dart:isolate';

final result = await compute(heavyComputation, inputData);

static int heavyComputation(int input) {
  // Do expensive work here
  return result;
}
```

### Issue: Memory usage grows over time
**Cause:** StreamControllers not closed
**Check:**
```dart
class BluetoothService {
  late StreamController<BluetoothDevice> _deviceStream;
  late StreamController<int> _heartRateStream;
  
  @override
  void dispose() {
    _deviceStream.close();
    _heartRateStream.close();
  }
}
```

### Issue: App slow after loading lots of history
**Solution:** Implement pagination:
```dart
Future<List<HeartbeatData>> loadHeartbeatDataPaginated(
  String userId, {
  required int page,
  int pageSize = 20,
}) async {
  final allData = await storageService.getHeartbeatDataByUserId(userId);
  final start = page * pageSize;
  final end = min(start + pageSize, allData.length);
  return allData.sublist(start, end);
}
```

---

## Hot Reload Issues

### Issue: Hot Reload fails with "StateError"
**Solution:** Use Hot Restart or Full Rebuild
```bash
# Hot Reload fails
r  # Try again

# Fallback to Hot Restart
Shift+Ctrl+F5

# Last resort - Full rebuild
flutter run
```

### Issue: Provider data resets on hot reload
**Expected behavior:** State resets on hot reload
**To preserve state:**
1. Reload from Hive on provider init
2. Use HotReloadViz to debug

---

## Testing Issues

### Issue: Widget test fails with "No Material widget found"
**Solution:**
```dart
testWidgets('My test', (WidgetTester tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MyProvider()),
      ],
      child: MaterialApp(
        home: MyWidget(),
      ),
    ),
  );
  // Test code...
});
```

### Issue: Integration test times out
**Solution:** Increase timeout:
```dart
testWidgets(
  'My integration test',
  (WidgetTester tester) async {
    // ...
  },
  timeout: const Timeout(Duration(seconds: 30)), // Increase from default 30
);
```

---

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Flutter/core" plugin not found | Plugins not built | flutter clean && flutter pub get |
| "RESOURCE_NOT_FOUND" Firebase | Wrong Project ID | Check firebase_options.dart |
| "Bad state: Stream has already been listened to" | Double stream subscribe | Check StreamController usage |
| "type '_InternalLinkedHashMap' is not a type" | JSON parsing error | Use model.fromMap() factory |
| "PlatformException(sign_in_failed)" | Google auth issue | Check SHA-1 fingerprint |
| "Unable to locate Dart Plugin" | IDE indexing issue | Restart IDE and flutter clean |

---

## Quick Fixes

```bash
# When everything breaks
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run

# If Firestore permissions error
# Update security rules (see Firebase issues section)

# If Bluetooth not working
# Check manifest/plist permissions (see Bluetooth issues section)

# If IDE not recognizing code
# Restart IDE and rebuild: flutter clean && flutter pub get

# If hot reload stuck
# Use Ctrl+Shift+F5 for hot restart

# If app won't install (iOS)
cd ios && rm -rf Pods Podfile.lock && cd ..
flutter run
```

## Getting Help

1. **Check Logs:**
   ```bash
   flutter run -v 2>&1 | head -100
   ```

2. **Check Firestore Logs:**
   - Firebase Console → Firestore → Logs

3. **Check Device Logs (Android):**
   ```bash
   adb logcat | grep Flutter
   ```

4. **Check Console Logs (iOS):**
   - Xcode → Console tab in debugger

5. **Community Resources:**
   - Flutter Community Slack
   - Stack Overflow [flutter] tag
   - GitHub Issues

---

## Prevention Tips

✅ **Always commit** pubspec.lock
✅ **Test on real devices** regularly
✅ **Monitor Firestore usage** to avoid quota issues
✅ **Update packages regularly** with `flutter upgrade` and `flutter pub upgrade`
✅ **Use `.gitignore`** (already included) to exclude build artifacts
✅ **Document** any custom BLE parsing for your device
✅ **Keep backups** of firebase_options.dart and secrets
