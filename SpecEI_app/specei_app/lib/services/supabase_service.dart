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
      // Build data map with required fields
      final Map<String, dynamic> data = {
        'firebase_uid': firebaseUid,
        'email': email,
        'full_name': fullName,
      };

      // Add phone number if provided
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
  Future<void> updateUserProfile(
    String firebaseUid,
    Map<String, dynamic> data,
  ) async {
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
}
