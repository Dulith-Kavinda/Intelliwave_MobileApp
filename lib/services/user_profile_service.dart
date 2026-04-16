import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/user_model.dart';

class UserProfileService {
  final _supabase = Supabase.instance.client;

  /// Save user profile to Supabase
  Future<void> saveUserProfile(UserModel user) async {
    try {
      await _supabase.from('users').upsert(
        {
          'id': user.uid,
          'email': user.email,
          'name': user.name,
          'birthday': user.birthday.toIso8601String(),
          'weight': user.weight,
          'height': user.height,
          'blood_group': user.bloodGroup,
          'phone_number': user.phoneNumber,
          'profile_picture_url': user.profilePictureUrl,
          'address': user.address,
          'gender': user.gender,
          'created_at': user.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );
    } catch (e) {
      throw Exception('Failed to save user profile: $e');
    }
  }

  /// Update specific user profile fields
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phoneNumber,
    String? address,
    String? profilePictureUrl,
    double? weight,
    double? height,
    String? bloodGroup,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (address != null) updates['address'] = address;
      if (profilePictureUrl != null) updates['profile_picture_url'] = profilePictureUrl;
      if (weight != null) updates['weight'] = weight;
      if (height != null) updates['height'] = height;
      if (bloodGroup != null) updates['blood_group'] = bloodGroup;

      await _supabase.from('users').update(updates).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Get user profile from Supabase
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return _mapToUserModel(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows found
        return null;
      }
      throw Exception('Failed to fetch user profile: $e');
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Check if user profile exists in Supabase
  Future<bool> userProfileExists(String userId) async {
    try {
      final response =
          await _supabase.from('users').select('id').eq('id', userId);
      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check user profile existence: $e');
    }
  }

  /// Delete user profile from Supabase (cascade delete via DB triggers)
  Future<void> deleteUserProfile(String userId) async {
    try {
      await _supabase.from('users').delete().eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete user profile: $e');
    }
  }

  /// Upload profile picture to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadProfilePicture({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final filePath = 'profile_pictures/$userId/$fileName';

      await _supabase.storage.from('profile_pictures').uploadBinary(
            filePath,
            Uint8List.fromList(fileBytes),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('profile_pictures').getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  /// Delete profile picture from Supabase Storage
  Future<void> deleteProfilePicture({
    required String userId,
    required String fileName,
  }) async {
    try {
      final filePath = 'profile_pictures/$userId/$fileName';
      await _supabase.storage.from('profile_pictures').remove([filePath]);
    } catch (e) {
      throw Exception('Failed to delete profile picture: $e');
    }
  }

  /// Helper method to convert Supabase response to UserModel
  UserModel _mapToUserModel(Map<String, dynamic> data) {
    return UserModel(
      uid: data['id'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      birthday: data['birthday'] != null
          ? DateTime.parse(data['birthday'])
          : DateTime.now(),
      weight: (data['weight'] ?? 0).toDouble(),
      height: (data['height'] ?? 0).toDouble(),
      bloodGroup: data['blood_group'] ?? '',
      phoneNumber: data['phone_number'] ?? '',
      profilePictureUrl: data['profile_picture_url'],
      address: data['address'] ?? '',
      gender: data['gender'] ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : DateTime.now(),
    );
  }
}
