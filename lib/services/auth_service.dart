import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // ─── Email Auth ────────────────────────────────────────────────────────────

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ─── Social Auth (Browser OAuth) ───────────────────────────────────────────

  /// Opens the system browser for Google OAuth (PKCE flow).
  /// Returns true if the browser was launched successfully.
  /// The actual session arrives asynchronously via [authStateChanges].
  Future<bool> signInWithGoogle() async {
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.inteliwaveapp://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return launched;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Google Sign In failed: ${e.toString()}');
    }
  }

  /// Apple Sign-In uses native credential flow (no Firebase needed).
  /// Returns an AuthResponse on success, or null if user cancels.
  Future<AuthResponse?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null; // User cancelled — not an error
      }
      throw Exception('Apple Sign In failed: ${e.message}');
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Apple Sign In failed: ${e.toString()}');
    }
  }

  /// Opens the system browser for Facebook OAuth (PKCE flow).
  /// The actual session arrives asynchronously via [authStateChanges].
  Future<bool> signInWithFacebook() async {
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'com.example.inteliwaveapp://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return launched;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Facebook Sign In failed: ${e.toString()}');
    }
  }

  // ─── Session / User ────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }

  // ─── Error Handling ────────────────────────────────────────────────────────

  String _handleAuthException(AuthException e) {
    if (e.message.toLowerCase().contains('rate') ||
        e.message.toLowerCase().contains('too many') ||
        e.code == 'over_email_send_rate_limit' ||
        e.code == 'over_request_rate_limit') {
      return 'Too many login attempts. Please wait a few minutes before trying again.';
    }

    switch (e.code) {
      case 'weak_password':
        return 'The password provided is too weak.';
      case 'user_already_exists':
        return 'The account already exists for that email.';
      case 'invalid_email':
        return 'The email address is not valid.';
      case 'user_not_found':
        return 'No user found for that email.';
      case 'invalid_grant':
        return 'Wrong password provided for that user.';
      case 'invalid_credentials':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}
