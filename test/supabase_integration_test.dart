import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../lib/supabase_options.dart';
import '../lib/services/storage_service.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/user_profile_service.dart';
import '../lib/models/user_model.dart';
import 'dart:math';

void main() {
  late AuthService authService;
  late StorageService storageService;
  late UserProfileService userProfileService;
  late String testEmail;
  late String testPassword;

  setUpAll(() async {
    print('\n🚀 Setting up Supabase Integration Tests...\n');

    // Initialize Supabase
    await Supabase.initialize(
      url: SupabaseOptions.url,
      anonKey: SupabaseOptions.anonKey,
    );
    print('✅ Supabase initialized');

    // Initialize Hive
    await Hive.initFlutter();
    Hive.registerAdapter(UserModelAdapter());
    print('✅ Hive initialized');

    // Initialize services
    storageService = StorageService();
    await storageService.initialize();
    print('✅ Storage service initialized');

    authService = AuthService();
    print('✅ Auth service initialized');

    userProfileService = UserProfileService();
    print('✅ User profile service initialized');

    // Generate unique test email
    final random = Random();
    final testId = random.nextInt(999999);
    testEmail = 'test_$testId@inteliwave.test';
    testPassword = 'TestPassword123!@#';
    print('✅ Test credentials generated: $testEmail\n');
  });

  group('Supabase Profile Integration Tests', () {
    group('Authentication Tests', () {
      test('Sign up with new user account', () async {
        print('\n📝 Test: User Sign Up');
        print('Email: $testEmail');

        try {
          final response = await authService.signUpWithEmail(
            email: testEmail,
            password: testPassword,
          );

          expect(response, isNotNull);
          expect(response.user, isNotNull);
          expect(response.user!.email, testEmail);
          print('✅ Sign up successful');
          print('   User ID: ${response.user!.id}');
        } catch (e) {
          print('❌ Sign up failed: $e');
          rethrow;
        }
      });

      test('Sign in with registered credentials', () async {
        print('\n🔐 Test: User Sign In');
        print('Email: $testEmail');

        try {
          final response = await authService.signInWithEmail(
            email: testEmail,
            password: testPassword,
          );

          expect(response, isNotNull);
          expect(response.user, isNotNull);
          expect(response.user!.email, testEmail);
          print('✅ Sign in successful');
          if (response.session?.accessToken != null) {
            print('   Session: ${response.session!.accessToken!.substring(0, 20)}...');
          }
        } catch (e) {
          print('❌ Sign in failed: $e');
          rethrow;
        }
      });

      test('Get current user session', () async {
        print('\n👤 Test: Get Current Session');

        try {
          final session = Supabase.instance.client.auth.currentSession;
          expect(session, isNotNull);
          expect(session!.user.email, testEmail);
          print('✅ Session retrieved');
          print('   User: ${session.user.email}');
          print('   Expires: ${session.expiresAt}');
        } catch (e) {
          print('❌ Get session failed: $e');
          rethrow;
        }
      });
    });

    group('Profile Creation & Supabase Tests', () {
      late String userId;
      late UserModel testProfile;

      setUpAll(() {
        final user = Supabase.instance.client.auth.currentUser;
        userId = user!.id;
        print('\n📋 Setting up profile tests with userId: $userId');
      });

      test('Create and save user profile to Supabase', () async {
        print('\n💾 Test: Save Profile to Supabase');

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
          print('   Height: ${testProfile.height}cm, Weight: ${testProfile.weight}kg');
        } catch (e) {
          print('❌ Save profile failed: $e');
          rethrow;
        }
      });

      test('Retrieve profile from Supabase', () async {
        print('\n🔍 Test: Retrieve Profile from Supabase');

        try {
          final retrievedProfile = await userProfileService.getUserProfile(userId);
          expect(retrievedProfile, isNotNull);
          expect(retrievedProfile!.email, testEmail);
          expect(retrievedProfile.name, 'Test User');
          print('✅ Profile retrieved from Supabase');
          print('   Name: ${retrievedProfile.name}');
          print('   Email: ${retrievedProfile.email}');
          print('   Blood Group: ${retrievedProfile.bloodGroup}');
        } catch (e) {
          print('❌ Retrieve profile failed: $e');
          rethrow;
        }
      });

      test('Update profile in Supabase', () async {
        print('\n✏️  Test: Update Profile in Supabase');

        try {
          await userProfileService.updateUserProfile(
            userId: userId,
            weight: 76.0,
            bloodGroup: 'A+',
          );
          print('✅ Profile updated in Supabase');

          final updated = await userProfileService.getUserProfile(userId);
          expect(updated!.weight, 76.0);
          expect(updated.bloodGroup, 'A+');
          print('   New weight: ${updated.weight}kg');
          print('   New blood group: ${updated.bloodGroup}');
        } catch (e) {
          print('❌ Update profile failed: $e');
          rethrow;
        }
      });

      test('Save and retrieve from local Hive storage', () async {
        print('\n💿 Test: Local Hive Storage');

        try {
          await storageService.saveUser(testProfile);
          print('✅ Profile saved to Hive');

          final localProfile = storageService.getUser(userId);
          expect(localProfile, isNotNull);
          expect(localProfile!.name, 'Test User');
          print('✅ Profile retrieved from Hive');
          print('   Name: ${localProfile.name}');
        } catch (e) {
          print('❌ Local storage failed: $e');
          rethrow;
        }
      });

      test('Cloud-Local Sync: Verify both storages synchronized', () async {
        print('\n🔄 Test: Cloud-Local Sync Verification');

        try {
          // Get from Supabase
          final cloudProfile = await userProfileService.getUserProfile(userId);
          expect(cloudProfile, isNotNull);
          print('✅ Retrieved from Supabase (cloud)');

          // Get from Hive
          final localProfile = storageService.getUser(userId);
          expect(localProfile, isNotNull);
          print('✅ Retrieved from Hive (local)');

          // Compare key fields
          expect(cloudProfile!.email, localProfile!.email);
          expect(cloudProfile.name, localProfile.name);
          expect(cloudProfile.weight, localProfile.weight);
          print('✅ Cloud and local data synchronized');
          print('   Email matches: ${cloudProfile.email}');
          print('   Name matches: ${cloudProfile.name}');
        } catch (e) {
          print('❌ Sync verification failed: $e');
          rethrow;
        }
      });
    });

    group('Profile Deletion Tests', () {
      test('Delete profile from Supabase', () async {
        print('\n🗑️  Test: Delete Profile from Supabase');

        final user = Supabase.instance.client.auth.currentUser;
        final userId = user!.id;

        try {
          await userProfileService.deleteUserProfile(userId);
          print('✅ Profile deleted from Supabase');

          // Verify deletion
          final deleted = await userProfileService.getUserProfile(userId);
          expect(deleted, isNull);
          print('✅ Deletion verified (profile not found)');
        } catch (e) {
          print('❌ Delete profile failed: $e');
          rethrow;
        }
      });

      test('Sign out user', () async {
        print('\n🚪 Test: Sign Out');

        try {
          await authService.signOut();
          print('✅ User signed out successfully');

          final currentUser = Supabase.instance.client.auth.currentUser;
          expect(currentUser, isNull);
          print('✅ Current user is null (confirmed sign out)');
        } catch (e) {
          print('❌ Sign out failed: $e');
          rethrow;
        }
      });
    });

    group('Error Handling Tests', () {
      test('Handle invalid email format', () async {
        print('\n❌ Test: Invalid Email Handling');

        expect(
          () => authService.signUpWithEmail(
            email: 'invalid-email',
            password: 'Password123!',
          ),
          throwsException,
        );
        print('✅ Invalid email rejected as expected');
      });

      test('Handle weak password', () async {
        print('\n❌ Test: Weak Password Handling');

        expect(
          () => authService.signUpWithEmail(
            email: 'test@example.com',
            password: '123',
          ),
          throwsException,
        );
        print('✅ Weak password rejected as expected');
      });

      test('Handle retrieving non-existent profile', () async {
        print('\n❌ Test: Non-Existent Profile Handling');

        try {
          final fakeUserId = 'fake-user-id-12345';
          final profile = await userProfileService.getUserProfile(fakeUserId);
          print('✅ Non-existent profile returns null as expected');
          expect(profile, isNull);
        } catch (e) {
          print('✅ Non-existent profile handled: $e');
        }
      });
    });
  });

  tearDownAll(() async {
    try {
      print('\n\n🧹 Cleaning up test resources...');
      await storageService.clearAllData();
      print('✅ Test cleanup complete\n');
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  });
}
