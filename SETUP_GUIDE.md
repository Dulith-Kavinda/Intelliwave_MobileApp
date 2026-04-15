# IntelIWave - Heart Rate Monitoring App

A modern Flutter application for monitoring and analyzing heart rate data from Bluetooth devices.

## Features

### 1. Authentication & Registration
- Email/Password login
- Google Sign-In integration
- Comprehensive registration with health metrics (weight, height, blood group, etc.)
- Profile picture support

### 2. Dashboard
- Real-time  heart rate display with animated pulse effect
- Heart rate trend graphs
- Statistics (Average, Max, Min BPM)
- Device connection status
- Quick access to timed health check

### 3. Device Scanner & Connection
- Bluetooth device scanning
- Connect/Disconnect functionality
- Display signal strength
- Save frequently used devices

### 4. History & Analytics
- View past heart rate readings with timestamps
- Filter data by date range
- Detailed ECG graphs for historical data
- Share history as PDF
- Data persistence on device

### 5. Timed Health Check Session
- Set custom duration (1, 5, 10, 15, 30 minutes)
- Continuous heart rate monitoring
- Automatic AI analysis upon completion
- Health condition assessment

### 6. Notifications
- Real-time health alerts
- Device connection notifications
- Important notifications highlighted in red
- Notification history with archiving

### 7. Settings
- Theme selection (Light, Dark, System)
- Notification preferences
- Heart rate alert customization
- App version and build information

### 8. User Profile
- View and edit personal information
- Change password
- Update profile picture
- Delete account option
- Logout functionality

## Project Structure

```
lib/
├── models/
│   ├── user_model.dart
│   ├── heartbeat_data.dart
│   ├── bluetooth_device_model.dart
│   ├── notification_model.dart
│   ├── timed_check_session.dart
│   └── index.dart
├── services/
│   ├── auth_service.dart
│   ├── bluetooth_service.dart
│   ├── storage_service.dart
│   ├── notification_service.dart
│   └── index.dart
├── providers/
│   ├── auth_provider.dart
│   ├── bluetooth_provider.dart
│   ├── heartbeat_provider.dart
│   ├── notification_provider.dart
│   ├── settings_provider.dart
│   ├── timed_check_provider.dart
│   └── index.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── registration_screen.dart
│   │   └── index.dart
│   ├── main/
│   │   ├── dashboard_screen.dart
│   │   ├── device_scanner_screen.dart
│   │   ├── history_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── notifications_screen.dart
│   │   ├── timed_check_screen.dart
│   │   └── index.dart
│   ├── home_screen.dart
│   └── index.dart
├── widgets/
│   ├── common_widgets.dart
│   └── index.dart
├── constants/
│   ├── app_theme.dart
│   └── index.dart
├── utils/
│   ├── routes.dart
│   ├── service_locator.dart
│   └── index.dart
├── supabase_options.dart
└── main.dart
```

## Getting Started

### Prerequisites
- Flutter SDK (3.11.3 or higher)
- Dart SDK
- Supabase project (https://supabase.com)
- Android/iOS development setup

### Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Generate Hive adapters:**
   ```bash
   flutter pub run build_runner build
   ```

3. **Configure Supabase:**
   - Create a Supabase project at https://app.supabase.com
   - Get your Project URL and Anon Key from Settings → API
   - Update `lib/supabase_options.dart` with your credentials
   - Run the SQL schema scripts from SUPABASE_SETUP.md
   - Enable Google Sign-In provider (optional)

4. **Run the app:**
   ```bash
   flutter run
   ```

## Dependencies

### State Management
- Provider: ^6.4.0

### Backend & Storage
- Supabase Flutter: ^2.5.0
- Google Sign-In: ^6.2.0
- Hive: ^2.2.3 (Local database)

### Bluetooth
- Flutter Blue Plus: ^1.31.11

### UI/UX
- FL Chart: ^0.68.0 (Heart rate charts)
- Cached Network Image: ^3.4.1

### Notifications
- Flutter Local Notifications: ^17.1.2

### Utilities
- Intl: ^0.20.1 (Date/Time formatting)
- UUID: ^4.0.0 (Unique IDs)
- Connectivity Plus: ^6.0.0
- Permission Handler: ^11.4.4
- Image Picker: ^1.1.2
- PDF Generation: ^3.12.0

## Key Features Implementation

### Real-time Heart Rate Monitoring
- Connects to Bluetooth heart rate devices
- Displays animated pulse visualization
- Streams continuous heart rate data
- Stores data locally with Hive

### Data Persistence
- Hive for fast, local storage
- Firestore for cloud synchronization
- Automatic backup and sync

### AI Integration (Ready for Implementation)
- Placeholder for ML-based health analysis
- Timed session analysis
- Health recommendations

### Theme Support
- Light theme
- Dark theme
- System default theme
- Dynamic switching without app restart

## Configuration

### Supabase Setup

1. Create a Supabase project at https://app.supabase.com
2. Get your Project URL and Anon Key from Settings → API
3. Update `lib/supabase_options.dart`:
   ```dart
   static const String url = 'https://your-project-id.supabase.co';
   static const String anonKey = 'your-anon-key-here';
   ```
4. Run SQL schema scripts from `SUPABASE_SETUP.md`
5. Enable authentication providers (Email/Password, Google Sign-In optional)

**See SUPABASE_SETUP.md for detailed setup instructions.**

### Bluetooth Permissions

The app requires the following permissions:
- **Android**: BLUETOOTH, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION
- **iOS**: NSBluetoothPeripheralUsageDescription, NSLocationWhenInUseUsageDescription

These are configured in the respective platform-specific files.

## Running the App

```bash
# Development
flutter run

# Release build
flutter build apk --release
flutter build ios --release

# With specific device
flutter run -d <device_id>
```

## Testing

The app includes sample data for:
- Dashboard heart rate data
- Mock history entries
- Device scanning

Replace these with real device data for production use.

## Platform Support

- ✅ Android (API level 21+)
- ✅ iOS (12.0+)
- ⏳ Web (Firebase only, limited Bluetooth support)

## Future Enhancements

1. **AI Health Analysis**
   - Integrate ML models for health assessment
   - Predictive health analytics
   - Personalized recommendations

2. **Export Features**
   - PDF report generation
   - CSV export
   - Email sharing

3. **Wearable Integration**
   - Apple Watch support
   - Wear OS support

4. **Advanced Analytics**
   - Heart rate variability tracking
   - Stress level detection
   - Sleep monitoring

5. **Social Features**
   - Share health achievements
   - Health challenges
   - Doctor consultation integration

## Contributing

To contribute to this project:

1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and support, please contact: support@inteliwave.com

## Notes

- This app collects sensitive health data - ensure you comply with HIPAA and local health data regulations
- Heart rate data should be validated by professional medical equipment before making health decisions
- The AI analysis feature is a placeholder and should be implemented with proper medical validation
- Always test Bluetooth connectivity on target devices before deployment

## Development Tips

1. **Hive Code Generation:**
   - Run `flutter pub run build_runner watch` for continuous generation during development
   - If you add new Hive models, regenerate adapters

2. **Supabase Testing:**
   - Use Supabase Dashboard for SQL query testing
   - Test Row Level Security (RLS) policies before deployment
   - Monitor realtime subscriptions in the dashboard

3. **Bluetooth Testing:**
   - Use official Bluetooth testing devices or simulators
   - Test with actual BLE heart rate monitors for accuracy

4. **Performance:**
   - Profile the app using DevTools
   - Monitor Supabase queries via dashboard analytics
   - Add database indexes as needed (examples in SUPABASE_SETUP.md)
   - Optimize Hive queries for large datasets

---

**Version:** 1.0.0  
**Last Updated:** 2026-04-16
