import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Authentication Service
/// Handles all authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // GoogleSignIn is only supported on mobile platforms
  GoogleSignIn? _googleSignIn;

  AuthService() {
    // Only initialize GoogleSignIn on supported platforms
    if (!_isDesktopPlatform) {
      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    }
  }

  bool get _isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Create account with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      debugPrint('Attempting to create user with email: $email');
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('User created successfully: ${result.user?.uid}');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('Firebase signup error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected signup error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    // Check if running on desktop - Google Sign-In not supported
    if (_isDesktopPlatform) {
      throw 'Google Sign-In is not available on desktop. Please use email/password login, or run the app on Android/iOS.';
    }

    if (_googleSignIn == null) {
      throw 'Google Sign-In is not available on this platform.';
    }

    try {
      debugPrint('Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        debugPrint('Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Signing in to Firebase with Google credential...');
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Send password reset via phone (starts phone verification)
  Future<void> sendPasswordResetPhone(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
        },
        verificationFailed: (FirebaseException e) {
          onError(_handleAuthException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Change password (requires re-authentication)
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      if (user.email == null) throw 'User has no email';

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update display name
  Future<void> updateDisplayName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      await user.updateDisplayName(name);
    } on FirebaseException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    await _auth.signOut();
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseException e) {
    debugPrint('Auth exception code: ${e.code}, message: ${e.message}');
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'internal-error':
        return 'Firebase configuration error. Please check your internet connection and try again.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
