# Supabase User Profile Implementation Guide

This guide explains how the updated IntelIWave app saves user account and profile details to Supabase database.

## Overview

The app now stores user profiles in **both Supabase (cloud) and Hive (local)**:
- **Supabase**: Cloud storage for backup, recovery, and cross-device access
- **Hive**: Local storage for offline access and performance
- **Automatic Sync**: Changes sync automatically between cloud and local storage

## Architecture

```
User Actions
    ↓
AuthProvider (Management)
    ↓
├─→ UserProfileService (Supabase operations)
├─→ StorageService (Local Hive operations)
└─→ AuthService (Authentication)
```

## New Components

### 1. UserProfileService (`lib/services/user_profile_service.dart`)

Handles all Supabase database operations for user profiles.

**Key Methods:**
- `saveUserProfile(UserModel user)` - Create or update profile in Supabase
- `updateUserProfile(...)` - Update specific profile fields
- `getUserProfile(userId)` - Fetch profile from Supabase
- `userProfileExists(userId)` - Check if profile exists
- `deleteUserProfile(userId)` - Delete profile from Supabase
- `uploadProfilePicture(...)` - Upload profile picture to storage
- `deleteProfilePicture(...)` - Delete profile picture

### 2. Updated AuthProvider (`lib/providers/auth_provider.dart`)

Enhanced to handle cloud-local synchronization.

**Sign Up Flow:**
1. Create user in Supabase Auth
2. Save profile to Supabase (cloud)
3. Save profile to Hive (local)

**Sign In Flow:**
1. Authenticate with Supabase Auth
2. Fetch profile from Supabase
3. Sync to local Hive if missing
4. Or sync local to Supabase if only exists locally

**Update Profile Flow:**
1. Update profile in Supabase
2. Update profile in Hive
3. Keep both in sync

**Delete Account:**
1. Delete profile from Supabase
2. Delete profile from Hive
3. Sign out user

## Setup Instructions

### 1. Create Supabase Tables

Run this SQL in **Supabase Console → SQL Editor**:

```sql
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL,
  birthday TIMESTAMP NOT NULL,
  weight NUMERIC,
  height NUMERIC,
  blood_group VARCHAR,
  phone_number VARCHAR,
  profile_picture_url VARCHAR,
  address VARCHAR,
  gender VARCHAR,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid()::text = id);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid()::text = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid()::text = id);

CREATE POLICY "Users can delete own profile" ON users
  FOR DELETE USING (auth.uid()::text = id);

-- Create storage bucket for profile pictures
INSERT INTO storage.buckets (id, name, public) 
VALUES ('profile_pictures', 'profile_pictures', true)
ON CONFLICT DO NOTHING;

-- Storage RLS policies
CREATE POLICY "Users can upload profile picture" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'profile_pictures' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete profile picture" ON storage.objects
  FOR DELETE USING (bucket_id = 'profile_pictures' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Profile pictures public" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile_pictures');
```

### 2. Verify Dependencies

Ensure `pubspec.yaml` has these packages:

```yaml
dependencies:
  supabase_flutter: ^2.0.0 or higher
  hive_flutter: ^1.1.0 or higher
  provider: ^6.0.0 or higher
  get_it: ^7.0.0 or higher
```

### 3. Build and Run

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

## Usage Examples

### Sign Up with Profile

```dart
final authProvider = context.read<AuthProvider>();

await authProvider.signUp(
  email: 'user@example.com',
  password: 'securePassword123',
  name: 'John Doe',
  birthday: DateTime(1990, 5, 15),
  weight: 75.5,
  height: 180.0,
  bloodGroup: 'O+',
  phoneNumber: '+1234567890',
  address: '123 Main St, City',
  gender: 'Male',
);
```

The profile is automatically saved to both Supabase and Hive.

### Update Profile

```dart
await authProvider.updateUserProfile(
  name: 'Jane Doe',
  birthday: DateTime(1990, 5, 15),
  weight: 68.0,
  height: 165.0,
  bloodGroup: 'A+',
  phoneNumber: '+1234567890',
  address: '456 Oak Ave, City',
  gender: 'Female',
);
```

Changes sync automatically to both Supabase and Hive.

### Upload Profile Picture

```dart
final userProfileService = getIt<UserProfileService>();

// Upload from file bytes
final publicUrl = await userProfileService.uploadProfilePicture(
  userId: _currentUser!.id,
  fileBytes: imageBytes,
  fileName: 'profile_picture.jpg',
);

// Update profile with picture URL
await updateUserProfile(
  // ... other fields ...
  profilePictureUrl: publicUrl,
);
```

### Check User Profile

```dart
final userProfileService = getIt<UserProfileService>();

// Fetch from Supabase
final profile = await userProfileService.getUserProfile(userId);

// Check if exists
final exists = await userProfileService.userProfileExists(userId);
```

## Data Sync Strategy

### Offline-First Sync

1. **When Online**: Changes sync constantly to Supabase
2. **When Offline**: Changes saved to Hive, synced when online
3. **On Sign In**: 
   - If profile in Supabase → sync to local
   - If only in local → sync to Supabase
   - Network error → use local copy

### Conflict Resolution

If data differs between Supabase and Hive:
- **Updated timestamp**: Use the most recently updated version
- **Sign In**: Supabase version is authoritative (cloud backup is primary)
- **After Update**: Both are immediately synced

## Security Considerations

### Row Level Security (RLS)

All tables have RLS enabled:
- Users can only access **their own** profile
- Policies checked automatically by Supabase
- No user "hacking" other profiles

### Best Practices

1. **Never expose Service Key**: Only use Anon Key in app
2. **Validate Inputs**: Always validate profile data on client
3. **Use HTTPS**: All Supabase communication is encrypted
4. **Secure Auth**: Use strong passwords (minimum 8 characters)
5. **Limit Requests**: Implement rate limiting if needed

## Troubleshooting

### "Profile not saving to Supabase"

**Check:**
1. Supabase table exists with correct schema:
   ```bash
   SELECT * FROM users LIMIT 1;
   ```
2. Anon Key in `supabase_options.dart` is correct
3. User is authenticated (`authProvider.isAuthenticated == true`)
4. Network connectivity is working

### "Profile syncing issues"

**Solutions:**
1. Clear local Hive cache: Remove app data from device settings
2. Reinstall the app
3. Check RLS policies in Supabase console:
   ```sql
   SELECT * FROM auth.roles;
   ```

### "Upload profile picture fails"

**Check:**
1. Storage bucket `profile_pictures` exists
2. User has permission to upload (storage RLS policies)
3. File size < 50MB (Supabase file limit)
4. Image format is supported (JPG, PNG, WebP, GIF)

## Data Fields Stored

The user profile stores the following fields in Supabase:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | TEXT | ✅ | Matches Supabase Auth UID |
| `email` | VARCHAR | ✅ | Unique, from Auth |
| `name` | VARCHAR | ✅ | Full name |
| `birthday` | TIMESTAMP | ✅ | Date of birth |
| `weight` | NUMERIC | ❌ | Weight in kg |
| `height` | NUMERIC | ❌ | Height in cm |
| `blood_group` | VARCHAR | ❌ | Blood type (O+, A-, etc.) |
| `phone_number` | VARCHAR | ❌ | Contact number |
| `profile_picture_url` | VARCHAR | ❌ | Supabase Storage URL |
| `address` | VARCHAR | ❌ | Street address |
| `gender` | VARCHAR | ❌ | Gender |
| `created_at` | TIMESTAMP | Auto | Account creation time |
| `updated_at` | TIMESTAMP | Auto | Last update time |

## Migration from Local-Only Storage

If you had existing users with profiles only in Hive:

1. **User signs in**: App checks Supabase
2. **Not found in Supabase**: App uploads local profile automatically
3. **Profile now backed up**: Synced to cloud

No manual migration needed—it's automatic!

## Performance Tips

1. **Cache Profiles**: Profiles are cached locally in Hive
2. **Batch Updates**: Update multiple fields at once
3. **Lazy Load**: Only fetch profiles when needed
4. **Pagination**: For multiple users, use limit/offset

Example batch update:
```dart
await userProfileService.updateUserProfile(
  userId: currentUser.id,
  name: 'New Name',
  weight: 70.0,
  height: 175.0,
  phoneNumber: '+1234567890',
);
```

## What's Next?

To further enhance the app:

1. **Profile Verification**: Add email confirmation
2. **Profile Completeness Score**: Track which fields are filled
3. **Profile History**: Keep audit trail of changes
4. **Two-Factor Authentication**: Add 2FA for security
5. **Profile Sharing**: Allow sharing profile data with contacts

## Support

For issues or questions:
1. Check the [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for detailed setup
2. Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
3. Check Supabase console logs: **Supabase → Logs → Database**
4. Monitor network requests in app debugger
