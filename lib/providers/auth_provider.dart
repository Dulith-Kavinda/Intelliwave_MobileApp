import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final StorageService _storageService;

  User? _currentUser;
  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider(this._authService, this._storageService) {
    _authService.authStateChanges().listen((authState) {
      _currentUser = authState.session?.user;
      if (_currentUser != null) {
        _loadUserModelFromLocalStorage();
      } else {
        _currentUserModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModelFromLocalStorage() async {
    try {
      if (_currentUser != null) {
        _currentUserModel = _storageService.getUser(_currentUser!.id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user model: $e');
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required DateTime birthday,
    required double weight,
    required double height,
    required String bloodGroup,
    required String phoneNumber,
    required String address,
    required String gender,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userModel = UserModel(
          uid: response.user!.id,
          email: email,
          name: name,
          birthday: birthday,
          weight: weight,
          height: height,
          bloodGroup: bloodGroup,
          phoneNumber: phoneNumber,
          address: address,
          gender: gender,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Save to local storage only (Hive)
        await _storageService.saveUser(userModel);

        _currentUserModel = userModel;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signInWithGoogle();
      if (response != null && response.user != null) {
        final user = response.user;
        
        // Check if user exists in local storage
        var userModel = _storageService.getUser(user!.id);
        
        if (userModel == null) {
          // Create new user in local storage only
          userModel = UserModel(
            uid: user.id,
            email: user.email ?? '',
            name: user.userMetadata?['name'] ?? 'User',
            birthday: DateTime.now(),
            weight: 0,
            height: 0,
            bloodGroup: '',
            phoneNumber: '',
            address: '',
            gender: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _storageService.saveUser(userModel);
        }
        
        _currentUserModel = userModel;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required DateTime birthday,
    required double weight,
    required double height,
    required String bloodGroup,
    required String phoneNumber,
    required String address,
    required String gender,
    String? profilePictureUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUserModel != null) {
        final updatedUser = _currentUserModel!.copyWith(
          name: name,
          birthday: birthday,
          weight: weight,
          height: height,
          bloodGroup: bloodGroup,
          phoneNumber: phoneNumber,
          address: address,
          gender: gender,
          profilePictureUrl: profilePictureUrl,
          updatedAt: DateTime.now(),
        );

        // Save to local storage only (Hive)
        await _storageService.saveUser(updatedUser);
        _currentUserModel = updatedUser;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _authService.updatePassword(newPassword);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_currentUserModel != null) {
        // Delete from local storage only (Hive)
        await _storageService.deleteUser(_currentUserModel!.uid);
      }

      _currentUserModel = null;
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _currentUserModel = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
