# Supabase Setup Guide - Mobile-First Architecture

This guide explains how to set up Supabase for IntelIWave with a **mobile-first architecture**:

- ✅ **User Data**: Stored LOCALLY on mobile (Hive)
- ✅ **Notifications**: Stored in Supabase cloud
- ✅ **Authentication**: Handled by Supabase Auth
- ✅ **Heart Rate Data**: Stored LOCALLY on mobile (Hive)
- ✅ **Bluetooth Devices**: Stored LOCALLY on mobile (Hive)
- ✅ **Timed Sessions**: Stored LOCALLY on mobile (Hive)

## Table of Contents

1. [Supabase Project Setup](#supabase-project-setup)
2. [Database Schema](#database-schema)
3. [Authentication Setup](#authentication-setup)
4. [Troubleshooting](#troubleshooting)
5. [Common Tasks](#common-tasks)
6. [Performance Optimization](#performance-optimization)
7. [Security Best Practices](#security-best-practices)
8. [Next Steps](#next-steps)

---

## Supabase Project Setup

### Create Supabase Project

1. Go to https://app.supabase.com
2. Click **New Project**
3. Enter project name: `inteliwave`
4. Set a strong database password
5. Choose region closest to your users
6. Click **Create New Project**
7. Wait for provisioning (usually 1-2 minutes)

### Get API Credentials

1. Go to **Settings → API**
2. Copy the following:
   - **Project URL**: `https://your-project-id.supabase.co`
   - **Anon Key**: (Public key for client-side usage)

3. Update `lib/supabase_options.dart`:
   ```dart
   static const String url = 'https://your-project-id.supabase.co';
   static const String anonKey = 'your-anon-key-here';
   ```

---

## Database Schema

Inteliwave stores **ONLY notifications** in the Supabase cloud database for backup and cross-device access. All user health data, device information, and session data remain **exclusively on the user's mobile device** in Hive for privacy, performance, and offline-first experience.

### Create Notifications Table

Go to **Supabase Console → SQL Editor** and run:

```sql
-- Create notifications table (the only required cloud table)
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

-- Create indexes for fast queries
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

-- Enable Realtime (for multi-device sync)
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

### Why Only Notifications in Cloud?

**Local Storage (Hive)** advantages for user data:
- ✅ **Faster**: No network latency, instant access
- ✅ **Offline**: All features work without internet
- ✅ **Privacy**: Personal health data stays on device
- ✅ **Free**: Unlimited local storage
- ✅ **Simpler**: No backend sync complexity

**Cloud Storage (Supabase)** advantages for notifications:
- ✅ **Backup**: Important alerts preserved across app uninstalls
- ✅ **Multi-device**: Users can see notifications on different devices
- ✅ **Real-time**: Sync notifications across devices instantly
- ✅ **Server-sent**: Backend can trigger important notifications

### Data Storage Reference

| Component | Storage | Sync | Offline |
|-----------|---------|------|---------|
| **User Profile** | Hive (Local) | None | ✅ Yes |
| **Heart Rate Data** | Hive (Local) | None | ✅ Yes |
| **Bluetooth Devices** | Hive (Local) | None | ✅ Yes |
| **Session History** | Hive (Local) | None | ✅ Yes |
| **Notifications** | Hive (Local) + Supabase | Auto sync | ✅ Yes |

---

## Authentication Setup

Supabase handles user authentication using email/password and Google Sign-In. User profile data is NOT stored in Supabase database—only authentication tokens are used.

### Enable Email/Password Authentication

1. Go to **Supabase Console → Authentication → Providers**
2. Click **Email** provider
3. Toggle **Enable Email provider**
4. Enable **Confirm email** (recommended for security)
5. Click **Save**

### Enable Google Sign-In (Optional)

1. Go to **Supabase Console → Authentication → Providers**
2. Click **Google** provider
3. Enter your Google Cloud credentials:
   - Go to https://console.cloud.google.com
   - Create OAuth 2.0 Client ID (Web app)
   - Copy **Client ID** and **Client Secret**
4. Paste into Supabase Google provider settings
5. Add Redirect URI: `https://your-project-id.supabase.co/auth/v1/callback`
6. Click **Save**

### How Authentication Works (Mobile-First)

1. **User Signs Up**:
   - Email/password sent to Supabase Auth
   - Supabase returns JWT token + user ID
   - User profile saved **LOCALLY** in Hive only (not in Supabase)
   - App stores JWT in secure storage

2. **User Signs In**:
   - Email/password sent to Supabase Auth
   - Supabase returns JWT token
   - App loads user profile from **local Hive** (not from cloud)
   - User profile syncs if missing locally

3. **User Changes Profile**:
   - Changes saved to **local Hive only** (no Supabase sync)
   - No network call required

4. **User Logs Out**:
   - JWT token cleared
   - Local Hive data remains (can be viewed offline)
   - User must re-login to access account

### Authentication Code Flow

```dart
// Sign Up: Create auth user, save profile LOCALLY
Future<void> signUp({
  required String email,
  required String password,
  required String fullName,
}) async {
  // Auth with Supabase
  final response = await _authService.signUpWithEmail(email, password);
  
  // Save profile LOCALLY ONLY
  final userModel = UserModel(
    uid: response.user!.id,
    email: email,
    fullName: fullName,
  );
  await _storageService.saveUser(userModel);
}

// Sign In: Auth with Supabase, load profile from LOCAL
Future<void> signIn({
  required String email,
  required String password,
}) async {
  // Auth with Supabase
  final response = await _authService.signInWithEmail(email, password);
  
  // Load profile from LOCAL Hive
  final userModel = await _storageService.getUser(response.user!.id);
  
  // If missing, create from auth response
  if (userModel == null) {
    await _storageService.saveUser(UserModel(
      uid: response.user!.id,
      email: response.user!.email!,
    ));
  }
}

// Update Profile: Save to LOCAL Hive only
Future<void> updateProfile(UserModel userModel) async {
  // NO Supabase sync - purely local
  await _storageService.saveUser(userModel);
}
```

---

## Troubleshooting

### Authentication Issues

**Problem**: "Invalid API key"
- **Solution**: Check `supabase_options.dart` - ensure URL and key are correct
- Get fresh keys from Settings → API

**Problem**: "Unauthorized user"
- **Solution**: Ensure Row Level Security (RLS) policies are correct
- Check that `auth.uid()` matches `user_id` in your policies

### Database Connection Issues

**Problem**: "Connection refused"
- **Solution**: 
  - Verify Supabase project is running
  - Check internet connectivity
  - Ensure URL is correct

**Problem**: "Table does not exist"
- **Solution**: Run all SQL scripts in SQL Editor
- Verify table names match queries

### Google Sign-In Issues

**Problem**: "Redirect URI mismatch"
- **Solution**: 
  - Check redirect URI in Google Cloud Console matches Supabase
  - Format: `https://your-project-id.supabase.co/auth/v1/callback`

**Problem**: "Invalid client ID"
- **Solution**: Verify Client ID and Secret in Supabase Google provider config

### Row Level Security Issues

**Problem**: "New row violates row-level security policy"
- **Solution**:
  - Check if `uid` matches current user's ID
  - Verify RLS policies are correctly set
  - Ensure `uid = auth.uid()` in INSERT policies

---

## Common Tasks

### Sync Notifications from Supabase to Local

```dart
// Load notifications from cloud into local Hive storage
Future<void> syncNotificationsFromCloud() async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  final response = await supabase
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  // Save to Hive (storage_service handles this)
  for (var notification in response) {
    await storageService.saveNotification(
      NotificationModel.fromMap(notification)
    );
  }
}
```

### Create Local Notification (Stays in Hive Only)

```dart
// For app-generated notifications (health alerts, reminders)
final notification = NotificationModel(
  id: Uuid().v4(),
  title: 'Heart Rate Alert',
  message: 'Your heart rate is elevated',
  type: 'warning',
  isImportant: true,
  timestamp: DateTime.now(),
);

// Save ONLY to local Hive
await storageService.saveNotification(notification);

// Optionally sync to cloud if it's important
if (notification.isImportant) {
  await supabase
      .from('notifications')
      .insert(notification.toMap());
}
```

### Push Important Notification to Cloud

```dart
// Only important/server-triggered notifications go to cloud
Future<void> pushNotificationToCloud(NotificationModel notification) async {
  final supabase = Supabase.instance.client;
  
  await supabase
      .from('notifications')
      .insert({
        'id': notification.id,
        'user_id': supabase.auth.currentUser!.id,
        'title': notification.title,
        'message': notification.message,
        'type': notification.type,
        'is_important': notification.isImportant,
      });
}
```

### Subscribe to Real-time Notifications (Multi-device Sync)

```dart
// Get instant updates when notifications are sent from server
final subscription = supabase
    .from('notifications')
    .on(RealtimeListenTypes.postgresChanges,
        event: 'INSERT',
        schema: 'public',
        table: 'notifications')
    .subscribe((payload) {
      final notification = NotificationModel.fromMap(payload.newRecord);
      
      // Save to local Hive
      storageService.saveNotification(notification);
      
      // Show local notification alert
      notificationService.showNotification(notification);
      
      // Update UI
      updateUI();
    });

// Clean up when done
await supabase.removeSubscription(subscription);
```

### Delete User Account (Local Only)

```dart
// Delete from local storage
await storageService.deleteUser(userId);
await storageService.deleteAllUserData(userId);

// Delete from cloud (notifications associated with user)
await supabase
    .from('notifications')
    .delete()
    .eq('user_id', userId);

// Delete from auth
await supabase.auth.admin.deleteUser(userId);
```

---

## Performance Optimization

### Query Only Unread Notifications

```dart
// Efficient queries using indexes
final unreadNotifications = await supabase
    .from('notifications')
    .select()
    .eq('user_id', userId)
    .eq('is_read', false)
    .order('created_at', ascending: false)
    .limit(50);
```

### Pagination for Old Notifications

```dart
final pageSize = 20;
final page = 0;

final notifications = await supabase
    .from('notifications')
    .select()
    .eq('user_id', userId)
    .order('created_at', ascending: false)
    .range(page * pageSize, (page + 1) * pageSize - 1);
```

### Local-First Query Performance

```dart
// ✅ BEST: Query local Hive (instant response)
final notifications = await storageService.getNotifications(userId);

// ✅ GOOD: Query cloud then cache results locally
final cloudNotifications = await supabase
    .from('notifications')
    .select()
    .eq('user_id', userId);

for (var notification in cloudNotifications) {
  await storageService.saveNotification(NotificationModel.fromMap(notification));
}

// ❌ AVOID: Always querying cloud for everyday use
```


---

## Security Best Practices

1. **Never expose Service Role Key** in client code
2. **Always use Anon Key** for client-side operations
3. **Enable Row Level Security** on all tables
4. **Validate data** server-side (RLS policies)
5. **Use environment variables** for sensitive config

Example `.env`:

```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

Then use in code:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load();
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
}
```

---

## Next Steps

1. ✅ Create Supabase project at https://app.supabase.com
2. ✅ Get API credentials (URL + Anon Key)
3. ✅ Update `lib/supabase_options.dart` with credentials
4. ✅ Run SQL schema (create notifications table)
5. ✅ Enable authentication providers (Email, Google)
6. ✅ Test authentication flow
7. ✅ Implement notification sync in `notification_provider.dart`
8. ✅ Run `flutter pub get`
9. ✅ Test app startup on Android/iOS

### Timeline

- **5 minutes**: Create Supabase project + get credentials
- **2 minutes**: Update configuration file
- **3 minutes**: Run SQL script
- **5 minutes**: Enable authentication
- **10 minutes**: Test authentication flow
- **15 minutes**: Implement notification sync
- **5 minutes**: Run and test app

---

## Useful Links

- Supabase Docs: https://supabase.com/docs
- Flutter Supabase: https://pub.dev/packages/supabase_flutter
- Supabase Auth: https://supabase.com/docs/guides/auth
- Supabase Realtime: https://supabase.com/docs/guides/realtime
- Supabase SSL Modes: https://supabase.com/docs/guides/database/connecting-to-postgres
