# Supabase Functionality Test Suite

This directory contains comprehensive test scripts to verify that Supabase functionality works correctly, even without UI rendering.

## 📋 Test Files

### 1. `test/supabase_integration_test.dart`
**Full Integration Test Suite** - Complete verification of all Supabase features using Flutter's testing framework.

**Features tested:**
- ✅ User authentication (sign up, sign in, session management)
- ✅ Profile creation and saving to Supabase
- ✅ Profile retrieval from Supabase
- ✅ Profile updates
- ✅ Local storage (Hive) operations
- ✅ Cloud-local sync verification
- ✅ Profile deletion
- ✅ Error handling

**Run command:**
```bash
flutter test test/supabase_integration_test.dart -v
```

### 2. `lib/test_verification.dart`
**Standalone Verification Script** - Simple test app that runs without UI and prints detailed results.

**Perfect for:**
- Quick verification without complex test runner
- Clear console output
- Easy debugging
- CI/CD pipelines

**Run command:**
```bash
flutter run -t lib/test_verification.dart
```

## 🚀 Quick Start

### Prerequisites
```bash
# Get dependencies
flutter pub get

# Set up Hive adapters (if needed)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Option 1: Run Full Integration Tests (Recommended)
```bash
# Run with verbose output
flutter test test/supabase_integration_test.dart -v

# Run specific test group
flutter test test/supabase_integration_test.dart -k "Profile Creation" -v
```

### Option 2: Run Verification Script
```bash
# Run the standalone verification app
flutter run -t lib/test_verification.dart

# Redirect output to file for later review
flutter run -t lib/test_verification.dart > test_results.txt 2>&1
```

## 📊 Expected Output

When tests pass, you should see:

```
============================================================
SUPABASE FUNCTIONALITY TEST
============================================================

📡 Initializing Supabase...
✅ Supabase initialized

🔧 Setting up services...
✅ Services configured

💾 Initializing local storage...
✅ Storage initialized

TEST 1: User Sign Up
----------------------------------------
✅ Sign up successful
   Email: test_verification@inteliwave.test
   User ID: abc123def456...

TEST 2: Create User Profile
----------------------------------------
✅ Profile saved to Supabase
   Name: Test Verification User
   Email: test_verification@inteliwave.test
   Height: 175.0cm
   Weight: 72.5kg

...

============================================================
✅ ALL TESTS COMPLETED SUCCESSFULLY
============================================================

Summary:
  ✅ User authentication (sign up, sign in)
  ✅ Profile creation in Supabase
  ✅ Profile retrieval from Supabase
  ✅ Profile updates in Supabase
  ✅ Local storage (Hive) working
  ✅ Cloud-local sync verified
  ✅ Profile deletion
  ✅ Session management
```

## 🔍 Test Coverage

| Feature | Test | Status |
|---------|------|--------|
| Sign Up | Creates new user account | ✅ Tested |
| Sign In | Retrieves existing user session | ✅ Tested |
| Session | Verifies current session | ✅ Tested |
| Save Profile | Stores profile in Supabase | ✅ Tested |
| Get Profile | Retrieves profile from Supabase | ✅ Tested |
| Update Profile | Updates profile fields | ✅ Tested |
| Local Storage | Saves/retrieves from Hive | ✅ Tested |
| Sync | Verifies cloud-local sync | ✅ Tested |
| Delete | Removes profile from Supabase | ✅ Tested |
| Sign Out | Clears user session | ✅ Tested |
| Error Handling | Handles invalid inputs | ✅ Tested |

## 🐛 Troubleshooting

### Test fails with "Supabase not initialized"
- Check `supabase_options.dart` has correct URL and key
- Verify internet connection
- Ensure Supabase project is active

### "User already exists" error
- This is expected if running tests multiple times
- Test will sign in existing user instead
- To reset: delete user from Supabase console

### Hive storage errors
- Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- Clear app cache: `flutter clean`

### Connection timeout
- Check Supabase project URL is correct
- Verify anon key is valid
- Check network connectivity

## 📈 Continuous Testing

For automated testing in CI/CD:

```bash
# Run all tests with coverage
flutter test test/supabase_integration_test.dart --coverage

# Generate coverage report
pub global activate coverage
pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

## 🔐 Security Notes

- Test credentials are hardcoded in tests (only for testing)
- Tests use public anon key (OK for testing)
- Tests create real database records (use test Supabase project)
- Clean up test data after running tests

## 📝 Adding New Tests

To add more test cases:

1. **Integration Tests** - Add to `test/supabase_integration_test.dart`:
   ```dart
   test('Your test name', () async {
     print('\n📝 Test: Your test name');
     // Your test code
     expect(result, expectedValue);
     print('✅ Test passed');
   });
   ```

2. **Verification Script** - Add to test function in `lib/test_verification.dart`:
   ```dart
   print('TEST X: Your test name');
   print('-' * 40);
   // Your test code
   print('✅ Test result\n');
   ```

## 🎯 Next Steps

After verifying tests pass:

1. ✅ All Supabase integration works correctly
2. ✅ Cloud-local sync is functional
3. ✅ Error handling is robust
4. Next: Deploy to physical device to test UI rendering
5. Next: Run user acceptance tests

---

**Last Updated:** 2026-04-16  
**Test Status:** Ready for use  
**Supabase Integration:** Verified
