import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/user_profile_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final StorageService _storageService;
  final UserProfileService _userProfileService;

  User? _currentUser;
  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider(this._authService, this._storageService, this._userProfileService) {
    _isLoading = true;
    _initializeAuth();
    // Listen for auth state changes AFTER initialization
    _setupAuthListener();
  }

  Future<void> _initializeAuth() async {
    try {
      // Check if there's an existing session
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user != null) {
        _currentUser = session!.user;
        try {
          await _loadUserModel();
        } catch (e) {
          // Profile loading failed, but user is still authenticated
        }
      }
    } catch (e) {
      // Initialization error, continue gracefully
      _currentUser = null;
      _currentUserModel = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupAuthListener() {
    // Set up auth state listener for future changes ONLY
    // Don't use the initial state from the listener
    try {
      _authService.authStateChanges().listen(
        (authState) {
          final newUser = authState.session?.user;
          
          // Only update if there's actually a change
          if (newUser?.id != _currentUser?.id) {
            _currentUser = newUser;
            
            if (_currentUser != null) {
              _loadUserModel();
            } else {
              _currentUserModel = null;
            }
            
            notifyListeners();
          }
        },
        onError: (error) {
          // Listening error, ignore
        },
      );
    } catch (e) {
      // Listening setup failed, that's okay
    }
  }

  /// Load user model from Supabase first, then fallback to local storage
  Future<void> _loadUserModel() async {
    try {
      if (_currentUser != null) {
        // Try to load from Supabase first
        _currentUserModel = await _userProfileService.getUserProfile(_currentUser!.id);
        
        // If not found in Supabase, try local storage
        if (_currentUserModel == null) {
          _currentUserModel = _storageService.getUser(_currentUser!.id);
          
          // If found in local storage but not in Supabase, sync to Supabase
          if (_currentUserModel != null) {
            try {
              await _userProfileService.saveUserProfile(_currentUserModel!);
            } catch (e) {
              // Ignore sync errors
            }
          }
        } else {
          // Also sync to local storage for offline access
          if (_currentUserModel != null) {
            try {
              await _storageService.saveUser(_currentUserModel!);
            } catch (e) {
              // Ignore sync errors
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      // Don't throw, just log silently if profile loading fails
      // The user is still authenticated even without a full profile
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
        _currentUser = response.user;
        
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

        // Save to both Supabase and local storage
        await _userProfileService.saveUserProfile(userModel);
        await _storageService.saveUser(userModel);

        _currentUserModel = userModel;
        
        _isLoading = false;
        notifyListeners();
      }
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
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      
      // Set current user immediately from response
      _currentUser = response.user;
      
      // Wait a moment for session to be established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify the session is still there
      final verifySession = Supabase.instance.client.auth.currentSession;
      if (verifySession?.user == null) {
        throw Exception('Session was not established. Please try again.');
      }
      
      // Try to load profile, but don't fail if it doesn't exist
      if (_currentUser != null) {
        try {
          await _loadUserModel();
        } catch (profileError) {
          // Profile might not exist yet, that's okay
          // Just set a minimal user model
          _currentUserModel = UserModel(
            uid: _currentUser!.id,
            email: _currentUser!.email ?? email,
            name: email.split('@')[0],
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
        }
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _currentUser = null;
      _currentUserModel = null;
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
        _currentUser = user;
        
        // Check if user exists in Supabase first
        var userModel = await _userProfileService.getUserProfile(user!.id);
        
        // If not in Supabase, check local storage
        if (userModel == null) {
          userModel = _storageService.getUser(user.id);
        }
        
        if (userModel == null) {
          // Create new user in both Supabase and local storage
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

          await _userProfileService.saveUserProfile(userModel);
          await _storageService.saveUser(userModel);
        } else {
          // Ensure profile is in both places
          await _userProfileService.saveUserProfile(userModel);
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

        // Save to both Supabase and local storage
        await _userProfileService.saveUserProfile(updatedUser);
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
        // Delete from both Supabase and local storage
        await _userProfileService.deleteUserProfile(_currentUserModel!.uid);
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
