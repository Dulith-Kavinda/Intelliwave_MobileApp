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

  // True when a browser OAuth flow has been launched and we are waiting
  // for the deep-link callback to complete.
  bool _isSocialAuthPending = false;

  User? get currentUser => _currentUser;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  bool get isSocialAuthPending => _isSocialAuthPending;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Profile is complete only when all required health/contact fields are filled.
  bool get isProfileComplete =>
      _currentUserModel != null && _currentUserModel!.isComplete;

  AuthProvider(
      this._authService, this._storageService, this._userProfileService) {
    _isLoading = true;
    _initializeAuth();
    _setupAuthListener();
  }

  // ─── Initialization ────────────────────────────────────────────────────────

  Future<void> _initializeAuth() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user != null) {
        _currentUser = session!.user;
        // Instant local cache hit
        _currentUserModel = _storageService.getUser(_currentUser!.id);
      }
    } catch (_) {
      _currentUser = null;
      _currentUserModel = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Non-blocking cloud sync
    if (_currentUser != null) {
      _refreshFromSupabaseBackground();
    }
  }

  Future<void> _refreshFromSupabaseBackground() async {
    try {
      final cloudModel =
          await _userProfileService.getUserProfile(_currentUser!.id);
      if (cloudModel != null) {
        _currentUserModel = cloudModel;
        try {
          await _storageService.saveUser(cloudModel);
        } catch (_) {}
        notifyListeners();
      }
    } catch (_) {
      // Network failure — local cache still shown
    }
  }

  /// Auth state listener — handles deep-link OAuth callbacks automatically.
  Future<void> _setupAuthListener() async {
    try {
      _authService.authStateChanges().listen(
        (authState) async {
          final newUser = authState.session?.user;
          final event = authState.event;

          debugPrint('Auth event: $event | user: ${newUser?.email}');

          if (newUser?.id != _currentUser?.id) {
            _currentUser = newUser;
            _isSocialAuthPending = false;

            if (_currentUser != null) {
              // Load local cache immediately for fast UI response
              _currentUserModel = _storageService.getUser(_currentUser!.id);
              notifyListeners();

              // Check cloud for existing profile
              _handleNewAuthUser(_currentUser!);
            } else {
              _currentUserModel = null;
              notifyListeners();
            }
          } else if (event == AuthChangeEvent.signedIn &&
              _isSocialAuthPending) {
            // Same user signed in again (e.g., token refresh after deep link)
            _isSocialAuthPending = false;
            notifyListeners();
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  /// Called when a new authenticated user is detected.
  /// Loads their profile if it exists; otherwise leaves model null so
  /// [isProfileComplete] is false and the profile setup screen shows.
  Future<void> _handleNewAuthUser(User user) async {
    try {
      var userModel = await _userProfileService.getUserProfile(user.id);

      if (userModel == null) {
        // Also check local cache (e.g., offline scenario)
        userModel = _storageService.getUser(user.id);
      }

      if (userModel != null) {
        // Existing user — sync both directions
        _currentUserModel = userModel;
        try {
          await _storageService.saveUser(userModel);
        } catch (_) {}
      } else {
        // Brand new social user — leave _currentUserModel = null
        // so isProfileComplete = false → CompleteProfileScreen shows.
        _currentUserModel = null;
      }

      notifyListeners();
    } catch (_) {
      // Ignore errors; _currentUserModel remains as loaded from local cache
    }
  }

  // ─── Public refresh ────────────────────────────────────────────────────────

  Future<void> refreshUserProfile() async {
    if (_currentUser == null) return;
    try {
      final cloudModel =
          await _userProfileService.getUserProfile(_currentUser!.id);
      if (cloudModel != null) {
        _currentUserModel = cloudModel;
        try {
          await _storageService.saveUser(cloudModel);
        } catch (_) {}
        notifyListeners();
      }
    } catch (_) {}
  }

  // ─── Email Auth ────────────────────────────────────────────────────────────

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

      _currentUser = response.user;

      await Future.delayed(const Duration(milliseconds: 300));

      final verifySession = Supabase.instance.client.auth.currentSession;
      if (verifySession?.user == null) {
        throw Exception('Session was not established. Please try again.');
      }

      if (_currentUser != null) {
        try {
          final cloudModel =
              await _userProfileService.getUserProfile(_currentUser!.id);
          _currentUserModel =
              cloudModel ?? _storageService.getUser(_currentUser!.id);
          if (_currentUserModel != null) {
            await _storageService.saveUser(_currentUserModel!);
          }
        } catch (_) {}
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

  // ─── Social Auth (Browser OAuth) ───────────────────────────────────────────

  /// Launches the browser for Google OAuth.
  /// Session is received asynchronously via the auth state listener.
  /// Caller should NOT navigate manually — AppHome handles it reactively.
  Future<void> signInWithGoogle() async {
    _errorMessage = null;
    _isSocialAuthPending = true;
    notifyListeners();

    try {
      final launched = await _authService.signInWithGoogle();
      if (!launched) {
        // Browser failed to open
        _isSocialAuthPending = false;
        _errorMessage = 'Could not open Google Sign-In. Please try again.';
        notifyListeners();
      }
      // If launched successfully, we just wait for the deep-link callback.
    } catch (e) {
      _errorMessage = e.toString();
      _isSocialAuthPending = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Apple Sign-In (native). Session is returned directly.
  Future<void> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signInWithApple();
      if (response != null && response.user != null) {
        _currentUser = response.user;
        await _handleNewAuthUser(_currentUser!);
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

  /// Launches the browser for Facebook OAuth.
  /// Session is received asynchronously via the auth state listener.
  Future<void> signInWithFacebook() async {
    _errorMessage = null;
    _isSocialAuthPending = true;
    notifyListeners();

    try {
      final launched = await _authService.signInWithFacebook();
      if (!launched) {
        _isSocialAuthPending = false;
        _errorMessage = 'Could not open Facebook Sign-In. Please try again.';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isSocialAuthPending = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Profile Updates ───────────────────────────────────────────────────────

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
    _errorMessage = null;
    notifyListeners();

    try {
      // Build model — use currentUserModel if it exists, or create from scratch
      final base = _currentUserModel ??
          UserModel(
            uid: _currentUser!.id,
            email: _currentUser?.email ?? '',
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

      final updatedUser = base.copyWith(
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

      await _userProfileService.saveUserProfile(updatedUser);
      await _storageService.saveUser(updatedUser);
      _currentUserModel = updatedUser;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
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
      _isSocialAuthPending = false;
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
