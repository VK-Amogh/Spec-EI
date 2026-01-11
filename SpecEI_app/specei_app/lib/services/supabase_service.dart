import 'dart:typed_data';
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

      await _client.from('users').upsert(data, onConflict: 'firebase_uid');
    } catch (e) {
      throw 'Failed to create or update user profile: $e';
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

  /// Check if email already exists in the database
  Future<bool> emailExists(String email) async {
    try {
      final response = await _client.rpc(
        'check_email_exists',
        params: {
          'email_to_check': email.trim().toLowerCase(),
        }, // Ensure strict lowercase to match typical norms
      );
      return response as bool;
    } catch (e) {
      return false;
    }
  }

  /// Check if phone number already exists in the database
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

  /// Get user by phone number
  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    try {
      // 1. Sanitize the input number
      final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (sanitized.isEmpty) return null;

      // 2. Try matching based on common phone number lengths (9-12 digits)
      final allUsers = await _client.from('users').select();
      for (final user in allUsers) {
        final dbPhoneRaw = user['phone_number'] as String?;
        if (dbPhoneRaw == null || dbPhoneRaw.isEmpty) continue;

        final dbPhoneSanitized = dbPhoneRaw.replaceAll(RegExp(r'[^0-9]'), '');

        // Match if one ends with the other (to handle dial codes vs local numbers)
        if (dbPhoneSanitized == sanitized ||
            (sanitized.length >= 10 && dbPhoneSanitized.endsWith(sanitized)) ||
            (dbPhoneSanitized.length >= 10 &&
                sanitized.endsWith(dbPhoneSanitized))) {
          return user;
        }
      }

      return null;
    } catch (e) {
      print('Error in getUserByPhone: $e');
      return null;
    }
  }

  /// Get user by email address
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Store temporary verification record before full registration
  Future<void> storeVerificationStatus({
    required String email,
    required bool emailVerified,
    bool? phoneVerified,
    String? phoneNumber,
  }) async {
    try {
      final data = {
        'email': email.toLowerCase().trim(),
        'email_verified': emailVerified,
        'phone_verified': phoneVerified ?? false,
        'phone_number': phoneNumber,
        'verified_at': DateTime.now().toIso8601String(),
      };

      // Upsert to update if exists, insert if not
      await _client
          .from('pending_verifications')
          .upsert(data, onConflict: 'email');
    } catch (e) {
      // Silently fail - don't block registration flow
      print('Failed to store verification status: $e');
    }
  }

  /// Update email verification status
  Future<void> updateEmailVerification(String email, bool verified) async {
    try {
      await _client.from('pending_verifications').upsert({
        'email': email.toLowerCase().trim(),
        'email_verified': verified,
        'verified_at': DateTime.now().toIso8601String(),
      }, onConflict: 'email');
    } catch (e) {
      print('Failed to update email verification: $e');
    }
  }

  /// Update phone verification status
  Future<void> updatePhoneVerification(
    String email,
    String phoneNumber,
    bool verified,
  ) async {
    try {
      await _client.from('pending_verifications').upsert({
        'email': email.toLowerCase().trim(),
        'phone_number': phoneNumber,
        'phone_verified': verified,
        'verified_at': DateTime.now().toIso8601String(),
      }, onConflict: 'email');
    } catch (e) {
      print('Failed to update phone verification: $e');
    }
  }

  /// Store password reset request
  Future<void> storePasswordResetRequest({
    required String identifier,
    required String type,
    String? email,
    String? phoneNumber,
    required String code,
  }) async {
    try {
      // First, invalidate any previous active codes for this identifier
      await _client
          .from('password_resets')
          .update({'is_verified': true})
          .eq('identifier', identifier)
          .eq('is_verified', false);

      await _client.from('password_resets').insert({
        'identifier': identifier,
        'email': email,
        'phone_number': phoneNumber,
        'type': type,
        'code': code,
        'requested_at': DateTime.now().toIso8601String(),
        'is_verified': false,
      });
    } catch (e) {
      // Silently fail if table doesn't exist yet, but log for debug
      print('Note: Failed to store reset request: $e');
    }
  }

  /// Get the latest valid reset code for an identifier
  Future<String?> getLatestResetCode(String identifier) async {
    try {
      final response = await _client
          .from('password_resets')
          .select('code')
          .eq('identifier', identifier)
          .eq('is_verified', false)
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['code'] as String?;
    } catch (e) {
      print('Error getting reset code: $e');
      return null;
    }
  }

  /// Verify reset code
  Future<bool> verifyResetCode(String identifier, String code) async {
    try {
      final response = await _client
          .from('password_resets')
          .select()
          .eq('identifier', identifier)
          .eq('code', code)
          .eq('is_verified', false)
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Mark as used/verified
        await _client
            .from('password_resets')
            .update({'is_verified': true})
            .eq('id', response['id']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Delete pending verification after successful registration
  Future<void> clearPendingVerification(String email) async {
    try {
      await _client
          .from('pending_verifications')
          .delete()
          .eq('email', email.toLowerCase().trim());
    } catch (e) {
      print('Failed to clear pending verification: $e');
    }
  }

  // ==================== REMINDERS ====================

  /// Create a reminder
  Future<Map<String, dynamic>?> createReminder({
    required String firebaseUid,
    required String title,
    required DateTime reminderDateTime,
  }) async {
    try {
      final response = await _client
          .from('reminders')
          .insert({
            'user_id': firebaseUid,
            'title': title,
            'reminder_datetime': reminderDateTime.toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'is_completed': false,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      print('Failed to create reminder: $e');
      return null;
    }
  }

  /// Get all reminders for a user
  Future<List<Map<String, dynamic>>> getReminders(String firebaseUid) async {
    try {
      final response = await _client
          .from('reminders')
          .select()
          .eq('user_id', firebaseUid)
          .eq('is_completed', false)
          .order('reminder_datetime', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to get reminders: $e');
      return [];
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _client.from('reminders').delete().eq('id', reminderId);
    } catch (e) {
      print('Failed to delete reminder: $e');
    }
  }

  /// Mark reminder as completed
  Future<void> completeReminder(String reminderId) async {
    try {
      await _client
          .from('reminders')
          .update({'is_completed': true})
          .eq('id', reminderId);
    } catch (e) {
      print('Failed to complete reminder: $e');
    }
  }

  // ==================== NOTES ====================

  /// Create a note
  Future<Map<String, dynamic>?> createNote({
    required String firebaseUid,
    required String title,
    required String content,
  }) async {
    try {
      final response = await _client
          .from('notes')
          .insert({
            'user_id': firebaseUid,
            'title': title,
            'content': content,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      print('Failed to create note: $e');
      return null;
    }
  }

  /// Get all notes for a user
  Future<List<Map<String, dynamic>>> getNotes(String firebaseUid) async {
    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('user_id', firebaseUid)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to get notes: $e');
      return [];
    }
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      await _client.from('notes').delete().eq('id', noteId);
    } catch (e) {
      print('Failed to delete note: $e');
    }
  }

  // ==================== FOCUS SESSIONS ====================

  /// Create a focus session
  Future<Map<String, dynamic>?> createFocusSession({
    required String firebaseUid,
    required int durationMinutes,
    String? sessionType,
  }) async {
    try {
      final response = await _client
          .from('focus_sessions')
          .insert({
            'user_id': firebaseUid,
            'duration_minutes': durationMinutes,
            'session_type': sessionType ?? 'timed',
            'started_at': DateTime.now().toIso8601String(),
            'is_completed': false,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      print('Failed to create focus session: $e');
      return null;
    }
  }

  /// Complete a focus session
  Future<void> completeFocusSession(String sessionId, int actualMinutes) async {
    try {
      await _client
          .from('focus_sessions')
          .update({
            'is_completed': true,
            'ended_at': DateTime.now().toIso8601String(),
            'actual_minutes': actualMinutes,
          })
          .eq('id', sessionId);
    } catch (e) {
      print('Failed to complete focus session: $e');
    }
  }

  /// Get focus sessions for a user
  Future<List<Map<String, dynamic>>> getFocusSessions(
    String firebaseUid,
  ) async {
    try {
      final response = await _client
          .from('focus_sessions')
          .select()
          .eq('user_id', firebaseUid)
          .order('started_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to get focus sessions: $e');
      return [];
    }
  }

  // ==================== MEDIA ====================

  /// Save media metadata
  Future<Map<String, dynamic>?> saveMedia({
    required String firebaseUid,
    required String mediaType,
    String? filePath,
    String? fileUrl,
    int? durationSeconds,
  }) async {
    try {
      final response = await _client
          .from('media')
          .insert({
            'user_id': firebaseUid,
            'media_type': mediaType,
            'file_path': filePath,
            'file_url': fileUrl,
            'duration_seconds': durationSeconds,
            'captured_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      print('Failed to save media: $e');
      return null;
    }
  }

  /// Get all media for a user
  /// Throws on error to distinguish from empty results
  Future<List<Map<String, dynamic>>> getMedia(String firebaseUid) async {
    try {
      final response = await _client
          .from('media')
          .select()
          .eq('user_id', firebaseUid)
          .order('captured_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to get media: $e');
      rethrow; // Rethrow so caller knows fetch failed vs empty
    }
  }

  /// Delete media
  Future<void> deleteMedia(String mediaId) async {
    try {
      // Get file path first
      final data = await _client
          .from('media')
          .select('file_path')
          .eq('id', mediaId)
          .single();
      final filePath = data['file_path'] as String?;

      // Delete metadata
      await _client.from('media').delete().eq('id', mediaId);

      // Delete file from storage if path exists
      if (filePath != null) {
        await _client.storage.from('media-files').remove([filePath]);
      }
    } catch (e) {
      print('Failed to delete media: $e');
    }
  }

  // ==================== STORAGE ====================

  /// Upload file to storage bucket and get public URL
  Future<String?> uploadMediaFile({
    required String userId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    try {
      final path = '$userId/$fileName';

      // Convert to Uint8List if needed
      final Uint8List bytes = fileBytes is Uint8List
          ? fileBytes
          : Uint8List.fromList(fileBytes);

      print('Uploading to media-files bucket: $path (${bytes.length} bytes)');

      await _client.storage
          .from('media-files')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      // Get public URL
      final publicUrl = _client.storage.from('media-files').getPublicUrl(path);
      print('Upload successful! URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Failed to upload media file: $e');
      return null;
    }
  }

  /// Save media with file upload
  Future<Map<String, dynamic>?> saveMediaWithFile({
    required String firebaseUid,
    required String mediaType,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? transcription,
    int? durationSeconds,
  }) async {
    try {
      print('📤 Starting media upload: $fileName (${fileBytes.length} bytes)');
      print('   User ID: $firebaseUid');
      print('   Type: $mediaType, MIME: $mimeType');

      // Upload file first
      final fileUrl = await uploadMediaFile(
        userId: firebaseUid,
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
      );

      if (fileUrl == null) {
        print('❌ File upload failed - fileUrl is null');
        throw Exception('File upload failed');
      }

      print('✅ File uploaded successfully: $fileUrl');

      // Save metadata to database
      print('💾 Saving metadata to database...');
      final response = await _client
          .from('media')
          .insert({
            'user_id': firebaseUid,
            'media_type': mediaType,
            'file_path': '$firebaseUid/$fileName',
            'file_url': fileUrl,
            'file_name': fileName,
            'transcription': transcription,
            'duration_seconds': durationSeconds,
            'captured_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      print('✅ Media saved to database! ID: ${response['id']}');
      return response;
    } catch (e) {
      print('❌ Failed to save media with file: $e');
      return null;
    }
  }

  /// Update media transcription
  Future<void> updateMediaTranscription(
    String mediaId,
    String transcription,
  ) async {
    try {
      await _client
          .from('media')
          .update({'transcription': transcription})
          .eq('id', mediaId);
    } catch (e) {
      print('Failed to update transcription: $e');
    }
  }

  /// Update media AI description
  Future<void> updateMediaAIDescription(
    String mediaId,
    String aiDescription,
  ) async {
    try {
      await _client
          .from('media')
          .update({'ai_description': aiDescription})
          .eq('id', mediaId);
    } catch (e) {
      print('Failed to update AI description: $e');
    }
  }

  /// Search media by AI description content
  /// Uses PostgreSQL full-text search for better performance
  Future<List<Map<String, dynamic>>> searchMediaByDescription(
    String firebaseUid,
    String searchQuery,
  ) async {
    try {
      // Use ilike for simple text matching
      // For better performance with large datasets, consider using
      // PostgreSQL full-text search with to_tsvector/to_tsquery
      final response = await _client
          .from('media')
          .select()
          .eq('user_id', firebaseUid)
          .or(
            'ai_description.ilike.%$searchQuery%,transcription.ilike.%$searchQuery%',
          )
          .order('captured_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to search media: $e');
      return [];
    }
  }

  // ==================== MEMORY METADATA ====================

  /// Save transcript for a media item
  Future<Map<String, dynamic>?> saveTranscript({
    required String mediaId,
    required String fullText,
    String language = 'en',
    double? confidence,
  }) async {
    try {
      final response = await _client
          .from('transcripts')
          .insert({
            'media_id': mediaId,
            'full_text': fullText,
            'language': language,
            'confidence': confidence,
            'word_count': fullText.split(' ').length,
          })
          .select()
          .single();
      print('✅ Transcript saved for media $mediaId');
      return response;
    } catch (e) {
      print('Failed to save transcript: $e');
      return null;
    }
  }

  /// Get transcript for a media item
  Future<Map<String, dynamic>?> getTranscript(String mediaId) async {
    try {
      final response = await _client
          .from('transcripts')
          .select()
          .eq('media_id', mediaId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Failed to get transcript: $e');
      return null;
    }
  }

  /// Save detected object for a media item
  Future<Map<String, dynamic>?> saveDetectedObject({
    required String mediaId,
    required String
    objectType, // 'person', 'object', 'text', 'place', 'animal', 'brand', 'activity'
    required String label,
    double? confidence,
    double? timestampSeconds,
    Map<String, dynamic>? boundingBox,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client
          .from('detected_objects')
          .insert({
            'media_id': mediaId,
            'object_type': objectType,
            'label': label,
            'confidence': confidence,
            'timestamp_seconds': timestampSeconds,
            'bounding_box': boundingBox,
            'metadata': metadata,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      print('Failed to save detected object: $e');
      return null;
    }
  }

  /// Get all detected objects for a media item
  Future<List<Map<String, dynamic>>> getDetectedObjects(String mediaId) async {
    try {
      final response = await _client
          .from('detected_objects')
          .select()
          .eq('media_id', mediaId)
          .order('timestamp_seconds', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to get detected objects: $e');
      return [];
    }
  }

  /// Find the LATEST confirmed sighting of a specific object (Layer 3 Memory)
  Future<Map<String, dynamic>?> findLatestObjectDetection(
    String userId,
    String objectLabel,
  ) async {
    try {
      // 1. Find media IDs for this user
      // Note: This is a bit inefficient without a JOIN or denormalized user_id on detected_objects
      // Ideally detected_objects should have user_id, or we do a join.
      // Doing a join:
      final response = await _client
          .from('detected_objects')
          .select('*, media!inner(*)') // Inner join to filter by user
          .eq('label', objectLabel)
          .eq('media.user_id', userId)
          .order('created_at', ascending: false) // Latest first
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Failed to find latest object detection: $e');
      return null;
    }
  }

  /// Semantic search across all memory metadata
  /// Searches ai_description, transcripts, and detected objects
  Future<List<Map<String, dynamic>>> searchMemory(
    String firebaseUid,
    String query,
  ) async {
    try {
      // Try using the RPC function first (if schema is applied)
      final response = await _client.rpc(
        'search_memory',
        params: {'p_user_id': firebaseUid, 'p_query': query},
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('RPC search_memory failed (schema may not be applied): $e');
      // Fallback to basic search
      return searchMediaByDescription(firebaseUid, query);
    }
  }

  /// Create an event from analyzed media
  Future<Map<String, dynamic>?> createEvent({
    required String userId,
    required String title,
    String? summary,
    required DateTime startTime,
    DateTime? endTime,
    String eventType = 'memory',
    int importance = 5,
    String? location,
    List<String>? tags,
  }) async {
    try {
      final response = await _client
          .from('events')
          .insert({
            'user_id': userId,
            'title': title,
            'summary': summary,
            'start_time': startTime.toIso8601String(),
            'end_time': endTime?.toIso8601String(),
            'event_type': eventType,
            'importance': importance,
            'location': location,
            'tags': tags,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      print('Failed to create event: $e');
      return null;
    }
  }

  /// Link media to an event
  Future<void> linkMediaToEvent(
    String eventId,
    String mediaId, {
    String role = 'primary',
  }) async {
    try {
      await _client.from('event_media').insert({
        'event_id': eventId,
        'media_id': mediaId,
        'role': role,
      });
    } catch (e) {
      print('Failed to link media to event: $e');
    }
  }

  /// Get events for a user
  Future<List<Map<String, dynamic>>> getEvents(String userId) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Failed to get events: $e');
      return [];
    }
  }
}
