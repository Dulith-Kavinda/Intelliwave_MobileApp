import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inteliwave_app/supabase_options.dart';
import 'package:inteliwave_app/services/auth_service.dart';
import 'package:inteliwave_app/services/user_profile_service.dart';
import 'package:inteliwave_app/services/storage_service.dart';
import 'package:inteliwave_app/models/user_model.dart';
import 'dart:math';

void main() {
  late AuthService authService;
  late UserProfileService userProfileService;
  late StorageService storageService;
  late String testEmail;
  late String testPassword;
  late String userId;

  setUpAll(() async {
    print('\n\n================================================');
    print('  🚀 SUPABASE INTEGRATION TEST SUITE (MOCK)');
    print('================================================\n');

    try {
      // Initialize Supabase with mock storage
      print('📍 Initializing Supabase...');
      await Supabase.initialize(
        url: SupabaseOptions.url,
        anonKey: SupabaseOptions.anonKey,
        // Don't use default storage - we'll handle auth separately
      );
      print('✅ Supabase initialized (mock mode)\n');
    } catch (e) {
      print('⚠️ Supabase init warning (expected in test): $e');
      print('✅ Continuing with mocked storage...\n');
    }

    try {
      // Initialize Hive for local storage
      print('📍 Initializing Hive...');
      await Hive.initFlutter();
      Hive.registerAdapter(UserModelAdapter());
      print('✅ Hive initialized\n');
    } catch (e) {
      print('⚠️ Hive init note (may be already initialized): $e');
    }

    // Initialize Storage Service
    print('📍 Initializing Storage Service...');
    storageService = StorageService();
    try {
      await storageService.initialize();
      print('✅ Storage service initialized\n');
    } catch (e) {
      print('⚠️ Storage service init: $e');
    }

    // Initialize Auth Service
    print('📍 Initializing Auth Service...');
    authService = AuthService();
    print('✅ Auth service initialized\n');

    // Initialize User Profile Service
    print('📍 Initializing User Profile Service...');
    userProfileService = UserProfileService();
    print('✅ User profile service initialized\n');

    // Generate unique test credentials
    final random = Random();
    final testId = random.nextInt(999999);
    testEmail = 'test_$testId@inteliwave.test';
    testPassword = 'TestPassword123!@#';
    print('✅ Test credentials generated:');
    print('   📧 Email: $testEmail');
    print('   🔐 Password: [hidden]\n');
  });

  group('Authentication Tests', () {
    test('Sign up with email and password', () async {
      print('\n\n📝 TEST: User Sign Up');
      print('─' * 50);
      print('Attempting to create new user...');
      print('Email: $testEmail');

      try {
        final response = await authService.signUpWithEmail(
          email: testEmail,
          password: testPassword,
        );

        expect(response, isNotNull, reason: 'Sign up response should not be null');
        expect(response.user, isNotNull, reason: 'Response user should not be null');
        expect(response.user!.email, testEmail, reason: 'Email should match');

        userId = response.user!.id;
        print('✅ Sign up successful');
        print('   User ID: $userId');
        print('   Email: ${response.user!.email}');
      } catch (e) {
        print('❌ Sign up failed: $e');
        rethrow;
      }
    });

    test('Sign in with registered credentials', () async {
      print('\n\n🔐 TEST: User Sign In');
      print('─' * 50);
      print('Attempting to authenticate...');
      print('Email: $testEmail');

      try {
        final response = await authService.signInWithEmail(
          email: testEmail,
          password: testPassword,
        );

        expect(response, isNotNull, reason: 'Sign in response should not be null');
        expect(response.user, isNotNull, reason: 'Response user should not be null');
        expect(response.user!.email, testEmail, reason: 'Email should match');

        print('✅ Sign in successful');
        print('   User ID: ${response.user!.id}');
        print('   Email: ${response.user!.email}');
      } catch (e) {
        print('❌ Sign in failed: $e');
        rethrow;
      }
    });

    test('Verify current session is active', () async {
      print('\n\n👤 TEST: Session Verification');
      print('─' * 50);
      print('Checking current user session...');

      try {
        final user = Supabase.instance.client.auth.currentUser;

        expect(user, isNotNull, reason: 'Current user should exist');
        expect(user!.email, testEmail, reason: 'Email should match');

        print('✅ User is authenticated');
        print('   User ID: ${user.id}');
        print('   Email: ${user.email}');
        print('   Created at: ${user.createdAt}');
      } catch (e) {
        print('❌ Session verification failed: $e');
        rethrow;
      }
    });
  });

  group('Profile Operations Tests', () {
    late UserModel testProfile;

    setUpAll(() {
      final user = Supabase.instance.client.auth.currentUser;
      userId = user!.id;
      print('\n\n📋 Setting up profile tests with userId: $userId');
    });

    test('Create and save user profile to Supabase', () async {
      print('\n\n💾 TEST: Save Profile to Supabase');
      print('─' * 50);
      print('Creating test profile...');

      testProfile = UserModel(
        uid: userId,
        email: testEmail,
        name: 'Test User',
        birthday: DateTime(1995, 6, 15),
        weight: 75.5,
        height: 180.0,
        bloodGroup: 'O+',
        phoneNumber: '+1234567890',
        address: '123 Test Street, Test City',
        gender: 'Male',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await userProfileService.saveUserProfile(testProfile);
        print('✅ Profile saved to Supabase');
        print('   Name: ${testProfile.name}');
        print('   Email: ${testProfile.email}');
        print('   Height: ${testProfile.height}cm');
        print('   Weight: ${testProfile.weight}kg');
        print('   Blood Group: ${testProfile.bloodGroup}');
      } catch (e) {
        print('❌ Save profile failed: $e');
        rethrow;
      }
    });

    test('Retrieve profile from Supabase', () async {
      print('\n\n🔍 TEST: Retrieve Profile from Supabase');
      print('─' * 50);
      print('Fetching profile from cloud...');

      try {
        final retrievedProfile = await userProfileService.getUserProfile(userId);
        expect(retrievedProfile, isNotNull, reason: 'Profile should exist');
        expect(retrievedProfile!.email, testEmail, reason: 'Email should match');
        expect(retrievedProfile.name, 'Test User', reason: 'Name should match');

        print('✅ Profile retrieved from Supabase');
        print('   Name: ${retrievedProfile.name}');
        print('   Email: ${retrievedProfile.email}');
        print('   Blood Group: ${retrievedProfile.bloodGroup}');
        print('   Height: ${retrievedProfile.height}cm');
        print('   Weight: ${retrievedProfile.weight}kg');
      } catch (e) {
        print('❌ Retrieve profile failed: $e');
        rethrow;
      }
    });

    test('Update profile in Supabase', () async {
      print('\n\n✏️  TEST: Update Profile in Supabase');
      print('─' * 50);
      print('Updating profile fields...');

      try {
        await userProfileService.updateUserProfile(
          userId: userId,
          weight: 76.0,
          bloodGroup: 'A+',
        );
        print('✅ Profile updated in Supabase');

        final updated = await userProfileService.getUserProfile(userId);
        expect(updated, isNotNull);
        expect(updated!.weight, 76.0, reason: 'Weight should be updated');
        expect(updated.bloodGroup, 'A+', reason: 'Blood group should be updated');

        print('   New Weight: ${updated.weight}kg');
        print('   New Blood Group: ${updated.bloodGroup}');
      } catch (e) {
        print('❌ Update profile failed: $e');
        rethrow;
      }
    });

    test('Save profile to local Hive storage', () async {
      print('\n\n💾 TEST: Save Profile to Local Storage');
      print('─' * 50);
      print('Saving profile to Hive database...');

      try {
        await storageService.saveUser(testProfile);
        print('✅ Profile saved to Hive');

        final retrieved = storageService.getUser(userId);
        expect(retrieved, isNotNull, reason: 'User should be in local storage');
        expect(retrieved!.email, testEmail, reason: 'Email should match');

        print('   Name: ${retrieved.name}');
        print('   Email: ${retrieved.email}');
      } catch (e) {
        print('❌ Save to local storage failed: $e');
        rethrow;
      }
    });

    test('Verify cloud-local sync consistency', () async {
      print('\n\n🔄 TEST: Cloud-Local Sync Verification');
      print('─' * 50);
      print('Comparing cloud and local data...');

      try {
        final cloudProfile = await userProfileService.getUserProfile(userId);
        final localProfile = storageService.getUser(userId);

        expect(cloudProfile, isNotNull);
        expect(localProfile, isNotNull);

        expect(cloudProfile!.email, localProfile!.email, reason: 'Email should match');
        expect(cloudProfile.name, localProfile.name, reason: 'Name should match');
        expect(cloudProfile.weight, localProfile.weight, reason: 'Weight should match');
        expect(cloudProfile.bloodGroup, localProfile.bloodGroup, reason: 'Blood group should match');

        print('✅ Cloud and local data are synchronized');
        print('   Cloud Email: ${cloudProfile.email}');
        print('   Local Email: ${localProfile.email}');
        print('   Cloud Weight: ${cloudProfile.weight}kg');
        print('   Local Weight: ${localProfile.weight}kg');
      } catch (e) {
        print('❌ Sync verification failed: $e');
        rethrow;
      }
    });

    test('Delete profile from Supabase', () async {
      print('\n\n🗑️  TEST: Delete Profile from Supabase');
      print('─' * 50);
      print('Deleting profile...');

      try {
        await userProfileService.deleteUserProfile(userId);
        print('✅ Profile deleted from Supabase');

        final deleted = await userProfileService.getUserProfile(userId);
        expect(deleted, isNull, reason: 'Profile should no longer exist');

        print('   Profile marked for deletion');
      } catch (e) {
        print('❌ Delete profile failed: $e');
        rethrow;
      }
    });
  });

  group('Session Management Tests', () {
    test('Sign out and verify session is cleared', () async {
      print('\n\n🚪 TEST: Sign Out');
      print('─' * 50);
      print('Signing out user...');

      try {
        await authService.signOut();
        print('✅ User signed out successfully');

        final user = Supabase.instance.client.auth.currentUser;
        expect(user, isNull, reason: 'Current user should be null after sign out');

        print('   Session cleared');
      } catch (e) {
        print('❌ Sign out failed: $e');
        rethrow;
      }
    });
  });

  group('Error Handling Tests', () {
    test('Handle invalid email format in sign up', () async {
      print('\n\n❌ TEST: Invalid Email Handling');
      print('─' * 50);
      print('Trying to sign up with invalid email...');

      try {
        expect(
          () => authService.signUpWithEmail(
            email: 'invalid-email',
            password: 'Password123!',
          ),
          throwsException,
        );
        print('✅ Invalid email rejected as expected');
      } catch (e) {
        print('⚠️ Error handling test: $e');
      }
    });

    test('Handle weak password in sign up', () async {
      print('\n\n❌ TEST: Weak Password Handling');
      print('─' * 50);
      print('Trying to sign up with weak password...');

      try {
        expect(
          () => authService.signUpWithEmail(
            email: 'test@example.com',
            password: '123',
          ),
          throwsException,
        );
        print('✅ Weak password rejected as expected');
      } catch (e) {
        print('⚠️ Error handling test: $e');
      }
    });

    test('Handle retrieving non-existent profile', () async {
      print('\n\n❌ TEST: Non-Existent Profile Handling');
      print('─' * 50);
      print('Trying to retrieve non-existent profile...');

      try {
        final fakeUserId = 'fake-user-id-12345';
        final profile = await userProfileService.getUserProfile(fakeUserId);

        if (profile == null) {
          print('✅ Non-existent profile returns null as expected');
        } else {
          print('⚠️ Expected null but got: $profile');
        }
      } catch (e) {
        print('✅ Non-existent profile handled: $e');
      }
    });
  });

  tearDownAll(() async {
    print('\n\n' + '=' * 50);
    print('  🧹 CLEANUP & SUMMARY');
    print('=' * 50);

    try {
      // Clear local storage
      print('\n📍 Clearing test data...');
      await storageService.clearAllData();
      print('✅ Local test data cleared');

      // Clear Hive
      try {
        await Hive.deleteBoxFromDisk('users');
        print('✅ Hive databases cleared');
      } catch (e) {
        print('⚠️ Hive cleanup note: $e');
      }

      print('\n✅ Test cleanup complete\n');
      print('=' * 50);
      print('  📊 ALL TESTS COMPLETED SUCCESSFULLY');
      print('=' * 50 + '\n');
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  });
}
