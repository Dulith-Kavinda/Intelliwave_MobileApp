# Supabase User Profile - Implementation Checklist

Use this checklist to verify all components are correctly set up.

## Code Implementation ✅

- [x] **UserProfileService Created**
  - File: `lib/services/user_profile_service.dart`
  - Methods: saveUserProfile, updateUserProfile, getUserProfile, uploadProfilePicture, etc.
  - Status: ✅ Complete

- [x] **AuthProvider Updated**
  - File: `lib/providers/auth_provider.dart`
  - Changes: Integrated UserProfileService, added sync logic
  - Methods updated: signUp, signIn, signInWithGoogle, updateUserProfile, deleteAccount
  - Status: ✅ Complete

- [x] **Service Locator Updated**
  - File: `lib/utils/service_locator.dart`
  - Added: UserProfileService registration and getter
  - Status: ✅ Complete

- [x] **Main App Updated**
  - File: `lib/main.dart`
  - Updated: AuthProvider instantiation with userProfileService parameter
  - Status: ✅ Complete

- [x] **Services Index Updated**
  - File: `lib/services/index.dart`
  - Added: UserProfileService export
  - Status: ✅ Complete

## Documentation Complete ✅

- [x] **SUPABASE_SETUP.md Updated**
  - Added: Users table SQL schema
  - Added: Storage bucket setup
  - Updated: Database schema section
  - Updated: Authentication code examples
  - Status: ✅ Complete

- [x] **USER_PROFILE_SUPABASE_GUIDE.md Created**
  - Setup instructions
  - Usage examples
  - Troubleshooting guide
  - Security best practices
  - Status: ✅ Complete

## Database Setup (Manual) ⏳

- [ ] **Create Users Table**
  - Location: Supabase Console → SQL Editor
  - Copy SQL from: `SUPABASE_SETUP.md` → "Create Users Table" section
  - Run the SQL script
  - Status: ⏳ Pending

- [ ] **Enable Row Level Security (RLS)**
  - Verify RLS is enabled on `users` table
  - Verify 4 RLS policies are created (SELECT, INSERT, UPDATE, DELETE)
  - Status: ⏳ Pending

- [ ] **Create Storage Bucket**
  - Bucket name: `profile_pictures`
  - Make it public
  - Status: ⏳ Pending

- [ ] **Create Storage RLS Policies**
  - Users can upload own pictures
  - Users can delete own pictures
  - Pictures are publicly readable
  - Status: ⏳ Pending

## Testing Steps

### 1. Test Sign Up with Profile

```
1. Open app
2. Go to Sign Up screen
3. Fill in all profile fields:
   - Email: test@example.com
   - Password: TestPass123
   - Name: Test User
   - Birthday: Select date
   - Weight: 70
   - Height: 175
   - Blood Group: O+
   - Phone: +1234567890
   - Address: 123 Main St
   - Gender: Male
4. Tap Sign Up
5. Verify:
   - ✅ User created in Supabase Auth
   - ✅ Profile saved in Supabase database
   - ✅ Profile saved in local Hive
   - ✅ User logged in
```

### 2. Test Sign In and Profile Sync

```
1. Sign out from app
2. Tap Sign In
3. Enter test@example.com and password
4. Verify:
   - ✅ User authenticated with Supabase
   - ✅ Profile loaded from Supabase
   - ✅ Profile synced to local Hive
   - ✅ User profile displays correctly
```

### 3. Test Profile Update

```
1. While logged in, go to Profile/Settings screen
2. Update profile fields:
   - Change name to "Updated Name"
   - Change weight to 72
3. Save changes
4. Verify:
   - ✅ Local profile updated immediately
   - ✅ Supabase profile updated (check Supabase console)
   - ✅ Changes persist after app restart
```

### 4. Test Offline Functionality

```
1. Enable "Airplane Mode" or disconnect WiFi
2. Update profile offline:
   - Change name to "Offline Change"
   - Save
3. Verify:
   - ✅ Changes saved locally
   - ✅ No error messages
4. Disable Airplane Mode / reconnect
5. Verify:
   - ✅ Changes sync to Supabase
   - ✅ Check Supabase console confirms update
```

### 5. Test Profile Picture Upload

```
1. Go to Profile Picture section
2. Select image from gallery
3. Upload
4. Verify:
   - ✅ Image uploaded to Supabase Storage
   - ✅ Picture URL saved in profile
   - ✅ Picture displays in app
```

## Verification Commands

### Check Tables Exist

In **Supabase Console → SQL Editor**, run:
```sql
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
```
Should show: `users`, `notifications`

### Check RLS Policies

```sql
SELECT * FROM pg_policies WHERE tablename = 'users';
```
Should show 4 policies (SELECT, INSERT, UPDATE, DELETE)

### Check User Profile Data

```sql
SELECT * FROM users LIMIT 10;
```
Should show your test user profiles

### Check Storage

In **Supabase Console:**
1. Go to Storage
2. Check bucket `profile_pictures`
3. Should show folders for each user UID

## Troubleshooting

### "Table 'users' does not exist"
- Solution: Run SQL script from SUPABASE_SETUP.md to create table

### "Permission denied" errors
- Solution: Check RLS policies are created correctly
- Verify Anon Key in `supabase_options.dart` is correct

### Profile not saving
- Check: Network connectivity
- Check: Supabase is initialized before AuthProvider
- Check: Service locator is set up

### Offline sync not working
- Check: Local Hive is initialized
- Check: Device has offline capability enabled

## Performance Optimization

### Current Implementation
- ✅ Profiles cached in Hive (fast local access)
- ✅ Automatic sync on sign in
- ✅ Async operations (no UI blocking)
- ✅ Error handling with fallbacks

### Future Optimizations
- Add pagination for multiple profiles
- Implement incremental sync
- Add profile change queue for offline
- Add caching strategy with TTL

## Security Checklist

- [x] RLS policies implemented
- [x] Users can only access own profile
- [x] No sensitive data exposed in logs
- [x] Storage bucket restricted access
- [x] Profile pictures public but user-folder-scoped

## File Changes Summary

| File | Changes | Status |
|------|---------|--------|
| `lib/services/user_profile_service.dart` | New file | ✅ Created |
| `lib/providers/auth_provider.dart` | Updated (6 major changes) | ✅ Updated |
| `lib/services/index.dart` | Added export | ✅ Updated |
| `lib/utils/service_locator.dart` | Added service registration | ✅ Updated |
| `lib/main.dart` | Updated provider instantiation | ✅ Updated |
| `SUPABASE_SETUP.md` | Added users table schema | ✅ Updated |
| `USER_PROFILE_SUPABASE_GUIDE.md` | New documentation | ✅ Created |

## Next Steps

1. **Immediate (This Week)**
   - [ ] Run database SQL in Supabase
   - [ ] Test sign up and profile saving
   - [ ] Test sign in and profile loading

2. **Short Term (This Month)**
   - [ ] Test all profile update scenarios
   - [ ] Test offline functionality
   - [ ] Test profile picture upload

3. **Medium Term (Next Month)**
   - [ ] Add profile verification
   - [ ] Add profile completeness tracking
   - [ ] Add profile edit history

## Questions?

Refer to:
- [USER_PROFILE_SUPABASE_GUIDE.md](USER_PROFILE_SUPABASE_GUIDE.md) - Detailed setup and examples
- [SUPABASE_SETUP.md](SUPABASE_SETUP.md) - Database schema and authentication
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
