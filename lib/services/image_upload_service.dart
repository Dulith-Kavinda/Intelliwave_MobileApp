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
      // 1. Delete all existing images in the user's directory to avoid clutter
      try {
        final existingFiles = await _supabase.storage
            .from('profile_pictures')
            .list(path: userId);
        
        if (existingFiles.isNotEmpty) {
          final pathsToDelete = existingFiles
              .map((file) => '$userId/${file.name}')
              .toList();
          await _supabase.storage
              .from('profile_pictures')
              .remove(pathsToDelete);
        }
      } catch (_) {
        // Ignore listing/deletion errors and proceed with upload
      }

      // 2. Upload new image with a unique timestamped filename to bypass caching
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$userId/$fileName';

      await _supabase.storage
          .from('profile_pictures')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '0', upsert: true),
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
      final existingFiles = await _supabase.storage
          .from('profile_pictures')
          .list(path: userId);
      
      if (existingFiles.isNotEmpty) {
        final pathsToDelete = existingFiles
            .map((file) => '$userId/${file.name}')
            .toList();
        await _supabase.storage
            .from('profile_pictures')
            .remove(pathsToDelete);
      }
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}
