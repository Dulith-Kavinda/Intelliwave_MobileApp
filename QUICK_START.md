# IntelIWave - Quick Start Guide

## Quick Command Reference

### Install Dependencies
```bash
flutter clean
flutter pub get
```

### Generate Code (Hive Adapters)
```bash
# One-time generation
flutter pub run build_runner build

# Continuous watch mode during development
flutter pub run build_runner watch
```

### Run the App
```bash
# Debug mode
flutter run

# Release mode
flutter run --release

# Specific device
flutter devices
flutter run -d <device_id>
```

### Build for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Firebase Setup Checklist

- [ ] Create Supabase project at https://app.supabase.com
- [ ] Get Project URL and Anon Key from Settings → API
- [ ] Update `lib/supabase_options.dart` with credentials
- [ ] Run SQL schema scripts from SUPABASE_SETUP.md
- [ ] Enable Email/Password authentication
- [ ] Optional: Enable Google Sign-In
- [ ] Test authentication flow

## Bluetooth Device Setup

### Supported Devices
- Heart Rate Monitors with BLE (Bluetooth Low Energy)
- Smartwatches with heart rate sensors
- Fitness trackers

### Testing Devices
- Polar H10/H9
- Garmin devices
- Apple Watch
- Fitbit devices

### Device Connection Flow
1. User opens Device Scanner
2. App scans for nearby Bluetooth devices
3. User selects device from list
4. App connects and discovers services
5. App subscribes to heart rate characteristic (UUID: 2A37)

## Troubleshooting

### App Won't Start
```bash
# Clean build
flutter clean
flutter pub get
flutter pub run build_runner build
flutter run
```

### Bluetooth Issues
- Check Android permissions in AndroidManifest.xml
- Check iOS permissions in Info.plist
- Ensure Bluetooth is enabled on device
- Try scanning at closer range

### Firebase Connection Issues
- Verify internet connectivity
- Check Firebase configuration
- Verify security rules allow operations
- Check firebaseDebugTag in Logcat (Android)

### Hive Database Issues
- Clear app data: `flutter run --replace`
- Invalidate Hive boxes: `await Hive.deleteBoxFromDisk('box_name')`
- Rebuild adapters: `flutter pub run build_runner build --delete-conflicting-outputs`

## Important Directories

| Directory | Purpose |
|-----------|---------|
| `lib/models/` | Data models with Hive adapters |
| `lib/services/` | Business logic (Auth, BT, Storage) |
| `lib/providers/` | State management (Provider) |
| `lib/screens/` | UI screens and pages |
| `lib/widgets/` | Reusable UI components |
| `lib/constants/` | App-wide constants and themes |
| `lib/utils/` | Routes, service locator, helpers |

## Adding a New Screen

1. Create new file in `lib/screens/main/new_screen.dart`
2. Add import to `lib/screens/main/index.dart`
3. Add route in `lib/utils/routes.dart`
4. Connect navigation in `HomeScreen` or other screens

## Adding a New Provider

1. Create new file in `lib/providers/new_provider.dart`
2. Extend `ChangeNotifier`
3. Add to `lib/providers/index.dart`
4. Register in `setupServiceLocator()` if needed
5. Add to providers list in `main.dart`

## Data Models & Hive

### Creating New Hive Model
1. Create model in `lib/models/`
2. Add `@HiveType()` and `@HiveField()` annotations
3. Create factory from map and toMap method
4. Register adapter in `StorageService.initialize()`
5. Run `flutter pub run build_runner build`

### Available Hive Box Names
- `users` - UserModel
- `heartbeat_data` - HeartbeatData
- `devices` - BluetoothDeviceModel
- `notifications` - AppNotification
- `timed_sessions` - TimedCheckSession
- `preferences` - String key-value pairs

## Common Tasks

### Get Current User
```dart
final authProvider = context.read<AuthProvider>();
final user = authProvider.currentUserModel;
```

### Load Heartbeat Data
```dart
final provider = context.read<HeartbeatProvider>();
await provider.loadHeartbeatData(userId);
```

### Connect to Bluetooth Device
```dart
final btProvider = context.read<BluetoothProvider>();
await btProvider.connectToDevice(device);
```

### Show Notification
```dart
final notifService = NotificationService();
await notifService.showNotification(
  id: 1,
  title: 'Title',
  body: 'Message',
);
```

###  Start Timed Check
```dart
final timedProvider = context.read<TimedCheckProvider>();
await timedProvider.startTimedCheck(
  userId: uid,
  durationMinutes: 5,
);
```

## Performance Tips

1. **Use const constructors** where possible
2. **Lazy load data** - only fetch when needed
3. **Cache data** - use Provider for caching
4. **Optimize images** - use cached_network_image
5. **Monitor Firestore** - avoid excessive reads
6. **Test on real devices** - emulators don't have Bluetooth

## Debugging

### Enable Debug Logging
```bash
flutter run -v

# Filter for specific tag
flutter run -v 2>&1 | grep "YourTag"
```

### Hot Reload vs Hot Restart
```bash
# Hot Reload (Ctrl+S) - Fast, keeps state
# Hot Restart (Ctrl+Shift+F5) - Slower, clears state
# Full Rebuild (flutter run) - Slowest, clears everything
```

### Dart DevTools
```bash
flutter pub global activate devtools
devtools

# Or through IDE
# Android Studio: Tools > Dart > Open DevTools
```

## Security Considerations

1. **Never commit** Firebase keys or secrets
2. **Use Firebase Security Rules** to protect data
3. **Validate** all user inputs on backend
4. **Hash passwords** - Firebase Auth handles this
5. **Secure Bluetooth** - Validate device connections
6. **Encrypt sensitive data** - Use platform-specific secure storage
7. **HIPAA Compliance** - This app handles health data

## Deployment Checklist

Before releasing to app stores:

- [ ] Update version in pubspec.yaml
- [ ] Test on multiple devices
- [ ] Test Bluetooth with real devices
- [ ] Optimize release build
- [ ] Update app icons and splash screen
- [ ] Create app store listings
- [ ] Test Firebase in production
- [ ] Set up Firebase security rules
- [ ] Configure FCM for notifications
- [ ] Review HIPAA/GDPR compliance
- [ ] Set up app analytics
- [ ] Create privacy policy
- [ ] Create terms of service
- [ ] Test error handling
- [ ] Performance profiling
- [ ] Accessibility review

## Useful Links

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [Flutter Blue Plus](https://pub.dev/packages/flutter_blue_plus)
- [Hive Database](https://pub.dev/packages/hive)
- [FL Chart](https://pub.dev/packages/fl_chart)

## Support & Resources

- **Community**: Flutter Community Slack
- **Issues**: GitHub Issues
- **Documentation**: See SETUP_GUIDE.md
- **Examples**: Check screens/ folder
