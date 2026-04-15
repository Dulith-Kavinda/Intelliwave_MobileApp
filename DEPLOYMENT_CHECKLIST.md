# IntelIWave Deployment Checklist

## Mobile-First Architecture with Supabase

This guide walks through deploying IntelIWave with mobile-first data storage and Supabase cloud services.

---

## Phase 1: Supabase Project Setup (5-10 minutes)

### 1.1 Create Supabase Project

- [ ] Go to https://app.supabase.com
- [ ] Click **New Project**
- [ ] Enter:
  - **Project name**: `inteliwave`
  - **Database password**: Choose a strong password
  - **Region**: Select region closest to users
- [ ] Wait for provisioning (usually 1-2 minutes)

### 1.2 Get API Credentials

- [ ] In Supabase Console, go to **Settings → API**
- [ ] Copy:
  - **Project URL**: `https://your-project-id.supabase.co`
  - **Anon Key**: (The public API key)
- [ ] Note these down - you'll need them next

### 1.3 Create Database Schema

- [ ] Go to **SQL Editor** in Supabase Console
- [ ] Create new query
- [ ] Copy this SQL:

```sql
-- Create notifications table (the only cloud table)
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title VARCHAR NOT NULL,
  message TEXT,
  type VARCHAR DEFAULT 'info',
  is_read BOOLEAN DEFAULT FALSE,
  is_important BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) 
  WHERE is_read = FALSE;

-- Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only see their own notifications
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own notifications" ON notifications
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own notifications" ON notifications
  FOR DELETE USING (auth.uid()::text = user_id);

-- Enable Realtime for multi-device sync
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

- [ ] Run the query
- [ ] Verify table created in **Tables** section

### 1.4 Enable Authentication

- [ ] Go to **Authentication → Providers**
- [ ] **Email Provider**:
  - [ ] Click **Email**
  - [ ] Toggle **Enable Email provider** ON
  - [ ] Keep other settings default
  - [ ] Click **Save**

- [ ] **Google Sign-In (Optional)**:
  - [ ] Go to https://console.cloud.google.com
  - [ ] Create OAuth 2.0 Client ID for Web app
  - [ ] Copy **Client ID** and **Client Secret**
  - [ ] In Supabase, click **Google** provider
  - [ ] Paste credentials
  - [ ] Add redirect: `https://your-project-id.supabase.co/auth/v1/callback`
  - [ ] Click **Save**

---

## Phase 2: Configure Flutter App (5 minutes)

### 2.1 Update Configuration

- [ ] Open `lib/supabase_options.dart`
- [ ] Replace:
  ```dart
  static const String url = 'https://your-project-id.supabase.co';
  static const String anonKey = 'your-anon-key-here';
  ```
  with your actual credentials from Step 1.2

### 2.2 Verify Code Changes

All code has already been updated! Verify these files exist and are correct:

- [ ] `lib/main.dart` - Supabase initialization ✅
- [ ] `lib/services/auth_service.dart` - Supabase Auth ✅
- [ ] `lib/providers/auth_provider.dart` - Mobile-first (local only) ✅
- [ ] `lib/providers/notification_provider.dart` - Cloud sync ✅
- [ ] `lib/models/notification_model.dart` - Dual format support ✅
- [ ] `pubspec.yaml` - Supabase dependency ✅

### 2.3 Get Dependencies

```bash
cd path/to/inteliwave_app
flutter pub get
```

Expected output:
```
Running "flutter pub get" in inteliwave_app...
Resolving dependencies... (should include supabase_flutter)
Downloaded X packages in Y seconds
```

---

## Phase 3: Test Locally (15-30 minutes)

### 3.1 Android Testing

```bash
flutter run -d chrome  # or any Android device
```

Or use Android Studio:
- [ ] Open project in Android Studio
- [ ] Click **Run** → Select device
- [ ] Wait for build and installation

### 3.2 Test Authentication Flow

In the app:

1. **Sign Up Test**:
   - [ ] Click **Sign Up**
   - [ ] Enter email: `test@example.com`
   - [ ] Enter password: `TestPassword123!`
   - [ ] Click **Create Account**
   - [ ] Verify no error (email verify is optional)
   - [ ] Check that profile appears locally

2. **Sign In Test**:
   - [ ] Click **Sign Out** (if you created account)
   - [ ] Click **Sign In**
   - [ ] Enter same email/password
   - [ ] Verify login successful
   - [ ] Verify app loads without internet (offline mode)

3. **Sign In Offline**:
   - [ ] Turn off internet
   - [ ] Check that all health data still loads (local storage)
   - [ ] Turn internet back on
   - [ ] Verify no sync errors

4. **Notifications Test**:
   - [ ] Create a test notification (if app has feature)
   - [ ] Check that it appears locally
   - [ ] Go to Supabase Console → **notifications** table
   - [ ] Verify important notifications appear there

### 3.3 Check No Errors

In terminal, verify:

```bash
flutter analyze
```

Should show no errors (warnings are OK for now)

---

## Phase 4: Prepare for Release (Optional)

### 4.1 Update App Icons

Replace these files:
- [ ] `android/app/src/main/res/mipmap-*/ic_launcher.png`
- [ ] `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- [ ] `web/favicon.png`
- [ ] `web/icons/*`

### 4.2 Update App Name

**Android:**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application android:label="IntelIWave">
```

**iOS:**
```
<!-- ios/Runner/Info.plist -->
<key>CFBundleName</key>
<string>IntelIWave</string>
```

### 4.3 Version Number

**Android:**
```gradle
// android/app/build.gradle
android {
  defaultConfig {
    versionCode 1
    versionName "1.0.0"
  }
}
```

**iOS:**
```plist
<!-- ios/Runner/Info.plist -->
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
```

---

## Phase 5: Deploy to App Stores (Advanced)

### 5.1 Google Play Store

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

Then upload to Play Store Console.

### 5.2 Apple App Store

```bash
flutter build ios --release
```

Use Xcode or Transporter to submit.

### 5.3 Web (Optional)

```bash
flutter build web --release
```

Deploy to any web hosting.

---

## Architecture Overview

### Data Storage

```
┌─────────────────────────────────────────┐
│         IntelIWave Flutter App          │
├─────────────────────────────────────────┤
│                                         │
│  Local Storage (Hive - Mobile Only)    │
│  ├─ User Profiles                       │
│  ├─ Heart Rate Data                     │
│  ├─ Bluetooth Devices                   │
│  └─ Session History                     │
│                                         │
│  +                                      │
│                                         │
│  Cloud Storage (Supabase - Sync)       │
│  ├─ Authentication (Supabase Auth)      │
│  └─ Notifications (Optional Backup)     │
│                                         │
└─────────────────────────────────────────┘
```

**Key Points:**
- ✅ All health data STAYS ON DEVICE
- ✅ Works completely offline
- ✅ Notifications optional sync to cloud
- ✅ No user data in cloud storage
- ✅ Fast performance (no network latency)

### Authentication Flow

```
1. User Enters Credentials
         ↓
2. Supabase Auth Verifies
         ↓
3. App Gets JWT Token
         ↓
4. Load Profile from Local Hive
   (or create new if first login)
         ↓
5. Notifications Sync from Cloud
         ↓
6. App Ready - Works Offline! ✅
```

### Notification Sync

```
App Creates Alert
    ↓
Saved to Local Hive (instant)
    ↓
If Important:
  ↓
  Push to Supabase
    ↓
  Cloud Backup ✅
    ↓
  Other Devices Get Real-time Update
```

---

## Troubleshooting

### App Crashes on Startup

**Check:**
1. `supabase_options.dart` has correct URL and key
2. Supabase project is active (check console)
3. Run `flutter clean && flutter pub get`

### Authentication Fails

**Check:**
1. Email provider enabled in Supabase
2. Internet connection (first login needs it)
3. Supabase URL and key correct
4. No typos in email/password

### Notifications Don't Appear

**Check:**
1. Notifications table exists in Supabase
2. RLS policies enabled
3. App is authenticated (sign in first)
4. Check Supabase Console → notifications table

### Offline Mode Issues

**Check:**
1. Hive storage initialized (should be automatic)
2. User profile saved locally after first login
3. Bluetooth service running
4. No app force-close between offline tests

---

## Support Resources

- **Supabase Docs**: https://supabase.com/docs
- **Flutter Supabase**: https://pub.dev/packages/supabase_flutter
- **Hive Storage**: https://pub.dev/packages/hive
- **Flutter Docs**: https://flutter.dev/docs
- **Provider State**: https://pub.dev/packages/provider

---

## Summary

✅ You now have:
- Mobile-first Flutter app with offline capabilities
- Supabase authentication (email + OAuth)
- Local-only user data (no cloud lock-in)
- Optional cloud notifications backup
- Real-time multi-device sync (for notifications)

🚀 Ready to deploy when you complete all checklist items!
