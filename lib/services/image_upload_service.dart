import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ImageUploadService {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }

  /// Upload image to Supabase Storage
  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final fileName = 'profile_$userId.jpg';
      final filePath = 'profile_pictures/$fileName';

      // Delete old image if exists
      try {
        await _supabase.storage
            .from('profile_pictures')
            .remove([fileName]);
      } catch (e) {
        // File might not exist, ignore
      }

      // Upload new image
      await _supabase.storage
          .from('profile_pictures')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('profile_pictures')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete profile image
  Future<void> deleteProfileImage(String userId) async {
    try {
      final fileName = 'profile_$userId.jpg';
      await _supabase.storage
          .from('profile_pictures')
          .remove([fileName]);
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}
