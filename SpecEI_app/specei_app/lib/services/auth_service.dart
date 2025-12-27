import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

/// Firebase Authentication Service
/// Handles all authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseService _supabaseService = SupabaseService();

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
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Create account with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
      // 1. Check if email exists in our database
      final exists = await _supabaseService.emailExists(email);
      if (!exists) {
        debugPrint(
          'Mock OTP: No account found for $email, simulating success.',
        );
        await Future.delayed(const Duration(seconds: 1));
        return;
      }

      // 2. Generate and store the request in the database
      final userData = await _supabaseService.getUserByEmail(email.trim());
      final phoneNumber = userData?['phone_number'] as String?;

      final code = _generateOTP();
      await _supabaseService.storePasswordResetRequest(
        identifier: email.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber,
        type: 'email',
        code: code,
      );

      // 3. Send actual Firebase password reset email
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password Reset: Email sent to $email via Firebase');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Send password reset code to phone
  Future<void> sendPasswordResetPhone(String phoneNumber) async {
    try {
      // 1. Sanitize phone number for lookups
      final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // 2. Check if phone exists and get user details
      final user = await _supabaseService.getUserByPhone(sanitized);

      // MOCK OTP LOGIC: If user not found, we still simulate success for security
      // (preventing user enumeration) and to satisfy the "Mock OTP" request.
      if (user == null) {
        debugPrint(
          'Mock OTP: No account found for $phoneNumber, simulating success.',
        );
        // We simulate a delay to feel real
        await Future.delayed(const Duration(seconds: 1));
        return;
      }

      final email = user['email'] as String?;
      final dbPhone = user['phone_number'] as String? ?? phoneNumber;

      // 3. Generate and store the request in the database
      final code = _generateOTP();
      await _supabaseService.storePasswordResetRequest(
        identifier: phoneNumber.trim(),
        email: email,
        phoneNumber: dbPhone,
        type: 'phone',
        code: code,
      );

      // 4. Trigger mock SMS delivery
      debugPrint('SUCCESS: mobile number saved to Supabase database.');
      debugPrint(
        'ACTION: Sending reset password code ($code) as SMS to: $phoneNumber',
      );
      debugPrint('Linked Email: $email');

      // We don't call verifyPhoneNumber here because we want to use our custom OTP screen
      // with the code stored in Supabase.
    } catch (e) {
      debugPrint('Error in sendPasswordResetPhone: $e');
      // Always rethrow unexpected errors, but we handled user-not-found above
      rethrow;
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
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update display name
  Future<void> updateDisplayName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      await user.updateDisplayName(name);
    } on FirebaseAuthException catch (e) {
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
  String _handleAuthException(FirebaseAuthException e) {
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
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  /// Generate a 6-digit OTP code for password reset
  String _generateOTP() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    return random.substring(random.length - 6);
  }
}
