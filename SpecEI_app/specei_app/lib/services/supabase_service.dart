import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Database Service
/// Handles user profile storage in PostgreSQL
class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Create user profile after registration
  Future<void> createUserProfile({
    required String firebaseUid,
    required String email,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'firebase_uid': firebaseUid,
        'email': email,
        'full_name': fullName,
      };
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        data['phone_number'] = phoneNumber;
      }
      await _client.from('users').insert(data);
    } catch (e) {
      throw 'Failed to create user profile: $e';
    }
  }

  /// Get user profile by Firebase UID
  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();
      return response;
    } catch (e) {
      throw 'Failed to get user profile: $e';
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(String firebaseUid, Map<String, dynamic> data) async {
    try {
      await _client.from('users').update(data).eq('firebase_uid', firebaseUid);
    } catch (e) {
      throw 'Failed to update user profile: $e';
    }
  }

  /// Check if user profile exists
  Future<bool> userProfileExists(String firebaseUid) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if email already exists
  Future<bool> emailExists(String email) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if phone number already exists
  Future<bool> phoneExists(String phoneNumber) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('phone_number', phoneNumber.trim())
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Update email verification status
  Future<void> updateEmailVerification(String firebaseUid, bool isVerified) async {
    try {
      await _client
          .from('users')
          .update({'email_verified': isVerified})
          .eq('firebase_uid', firebaseUid);
    } catch (e) {
      throw 'Failed to update email verification: $e';
    }
  }

  /// Update phone verification status
  Future<void> updatePhoneVerification(String firebaseUid, bool isVerified) async {
    try {
      await _client
          .from('users')
          .update({'phone_verified': isVerified})
          .eq('firebase_uid', firebaseUid);
    } catch (e) {
      throw 'Failed to update phone verification: $e';
    }
  }
}
