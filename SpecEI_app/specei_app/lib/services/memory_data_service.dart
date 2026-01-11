import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'supabase_service.dart';
import 'media_analysis_service.dart';
import '../core/logger.dart';

/// Shared data service for managing reminders, notes, and media
/// Used across Home and Memory tabs
/// Syncs with Supabase for persistence
class MemoryDataService extends ChangeNotifier {
  static final MemoryDataService _instance = MemoryDataService._internal();
  factory MemoryDataService() => _instance;
  MemoryDataService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Reminders
  final List<ReminderItem> _reminders = [];
  List<ReminderItem> get reminders => List.unmodifiable(_reminders);

  // Notes
  final List<NoteItem> _notes = [];
  List<NoteItem> get notes => List.unmodifiable(_notes);

  // Focus sessions
  final List<FocusSession> _focusSessions = [];
  List<FocusSession> get focusSessions => List.unmodifiable(_focusSessions);

  // Captured media (photos, videos, audio)
  final List<MediaItem> _mediaItems = [];
  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);

  // Check if there's any content
  bool get hasContent =>
      _reminders.isNotEmpty ||
      _notes.isNotEmpty ||
      _mediaItems.isNotEmpty ||
      _focusSessions.isNotEmpty;

  // ==================== LOAD FROM DATABASE ====================

  /// Load all user data from Supabase
  Future<void> loadFromDatabase() async {
    AppLogger.debug('loadFromDatabase() called');
    AppLogger.debug('User: ${AppLogger.maskUserId(_userId)}');

    if (_userId == null) {
      AppLogger.warning('No user logged in - cannot load data');
      return;
    }

    AppLogger.info('User authenticated, fetching data...');

    try {
      // Load reminders
      final remindersData = await _supabaseService.getReminders(_userId!);
      AppLogger.debug('Found ${remindersData.length} reminders');
      _reminders.clear();
      for (final data in remindersData) {
        _reminders.add(
          ReminderItem(
            id: data['id'].toString(),
            title: data['title'] ?? '',
            dateTime: DateTime.parse(data['reminder_datetime']),
            createdAt: DateTime.parse(data['created_at']),
          ),
        );
      }

      // Load notes
      final notesData = await _supabaseService.getNotes(_userId!);
      AppLogger.debug('Found ${notesData.length} notes');
      _notes.clear();
      for (final data in notesData) {
        _notes.add(
          NoteItem(
            id: data['id'].toString(),
            title: data['title'] ?? '',
            content: data['content'] ?? '',
            createdAt: DateTime.parse(data['created_at']),
          ),
        );
      }

      // Load focus sessions
      final sessionsData = await _supabaseService.getFocusSessions(_userId!);
      AppLogger.debug('Found ${sessionsData.length} focus sessions');
      _focusSessions.clear();
      for (final data in sessionsData) {
        _focusSessions.add(
          FocusSession(
            id: data['id'].toString(),
            durationMinutes: data['duration_minutes'] ?? 0,
            sessionType: data['session_type'] ?? 'timed',
            startedAt: DateTime.parse(data['started_at']),
            isCompleted: data['is_completed'] ?? false,
          ),
        );
      }

      // Load media - separate try-catch to handle media errors independently
      try {
        final mediaData = await _supabaseService.getMedia(_userId!);
        AppLogger.debug('Loading ${mediaData.length} media items');

        // preserve local items that are currently uploading
        final localItems = _mediaItems.where((m) => m.isLocal).toList();

        // Clear and add server data
        _mediaItems.clear();
        for (final data in mediaData) {
          _mediaItems.add(
            MediaItem(
              id: data['id'].toString(),
              type: MediaType.values.firstWhere(
                (t) => t.name == data['media_type'],
                orElse: () => MediaType.photo,
              ),
              filePath: data['file_path'],
              fileUrl:
                  data['file_url'], // This was missing - required for audio playback!
              transcription: data['transcription'],
              aiDescription: data['ai_description'],
              capturedAt: DateTime.parse(data['captured_at']),
              duration: data['duration_seconds'] != null
                  ? Duration(seconds: data['duration_seconds'])
                  : null,
            ),
          );
        }

        // Re-add local items
        if (localItems.isNotEmpty) {
          AppLogger.debug('Preserving ${localItems.length} local items');
          // Filter out any local items that might have been synced (though IDs should differ)
          // We rely on the fact that synced items get replaced with server IDs
          _mediaItems.addAll(localItems);
        }

        // Sort by capturedAt (newest first)
        _mediaItems.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      } catch (mediaError) {
        AppLogger.warning('Failed to fetch media: $mediaError');
        AppLogger.debug(
          'Preserving ${_mediaItems.length} items, scheduling retry',
        );
        // Schedule a retry after 3 seconds on media fetch failure
        Future.delayed(const Duration(seconds: 3), () {
          if (_userId != null) {
            AppLogger.debug('Retrying media fetch');
            loadFromDatabase();
          }
        });
      }

      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Error loading from database', e, stackTrace);
      // Don't clear data on error - preserve any local items
    }
  }

  // ==================== REMINDERS ====================

  // Get today's reminders
  List<ReminderItem> get todayReminders {
    final now = DateTime.now();
    return _reminders
        .where(
          (r) =>
              r.dateTime.year == now.year &&
              r.dateTime.month == now.month &&
              r.dateTime.day == now.day,
        )
        .toList();
  }

  // Get tomorrow's reminders
  List<ReminderItem> get tomorrowReminders {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _reminders
        .where(
          (r) =>
              r.dateTime.year == tomorrow.year &&
              r.dateTime.month == tomorrow.month &&
              r.dateTime.day == tomorrow.day,
        )
        .toList();
  }

  // Get upcoming reminders (more than 1 day away)
  List<ReminderItem> get upcomingReminders {
    final dayAfterTomorrow = DateTime.now().add(const Duration(days: 2));
    return _reminders
        .where((r) => r.dateTime.isAfter(dayAfterTomorrow))
        .toList();
  }

  // Add a reminder (saves locally first, then syncs to Supabase)
  Future<void> addReminder(ReminderItem reminder) async {
    // Always add locally first for instant UI update
    _reminders.add(reminder);
    _reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    notifyListeners();

    // Try to sync to Supabase in background
    if (_userId != null) {
      try {
        await _supabaseService.createReminder(
          firebaseUid: _userId!,
          title: reminder.title,
          reminderDateTime: reminder.dateTime,
        );
      } catch (e) {
        print('Supabase sync failed (will retry later): $e');
      }
    }
  }

  // Remove reminder
  Future<void> removeReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
    try {
      await _supabaseService.deleteReminder(id);
    } catch (e) {
      print('Failed to delete from Supabase: $e');
    }
  }

  // ==================== NOTES ====================

  // Add a note (saves locally first, then syncs to Supabase)
  Future<void> addNote(NoteItem note) async {
    // Always add locally first for instant UI update
    _notes.insert(0, note);
    notifyListeners();

    // Try to sync to Supabase in background
    if (_userId != null) {
      try {
        await _supabaseService.createNote(
          firebaseUid: _userId!,
          title: note.title,
          content: note.content,
        );
      } catch (e) {
        print('Supabase sync failed (will retry later): $e');
      }
    }
  }

  // Remove note
  Future<void> removeNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    try {
      await _supabaseService.deleteNote(id);
    } catch (e) {
      print('Failed to delete from Supabase: $e');
    }
  }

  // ==================== FOCUS SESSIONS ====================

  // Add focus session (saves to Supabase)
  Future<FocusSession?> startFocusSession(
    int durationMinutes,
    String sessionType,
  ) async {
    if (_userId == null) return null;

    try {
      final result = await _supabaseService.createFocusSession(
        firebaseUid: _userId!,
        durationMinutes: durationMinutes,
        sessionType: sessionType,
      );

      if (result != null) {
        final session = FocusSession(
          id: result['id'].toString(),
          durationMinutes: durationMinutes,
          sessionType: sessionType,
          startedAt: DateTime.now(),
          isCompleted: false,
        );
        _focusSessions.insert(0, session);
        notifyListeners();
        return session;
      }
    } catch (e) {
      print('Error starting focus session: $e');
    }
    return null;
  }

  // Complete focus session
  Future<void> completeFocusSession(String id, int actualMinutes) async {
    await _supabaseService.completeFocusSession(id, actualMinutes);
    final index = _focusSessions.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _focusSessions[index] = _focusSessions[index].copyWith(isCompleted: true);
      notifyListeners();
    }
  }

  // ==================== MEDIA ====================

  // Add media item (saves to Supabase)
  Future<void> addMedia(MediaItem media) async {
    // Add locally first for instant UI
    _mediaItems.insert(0, media);
    notifyListeners();

    // Sync to Supabase
    if (_userId != null) {
      try {
        await _supabaseService.saveMedia(
          firebaseUid: _userId!,
          mediaType: media.type.name,
          filePath: media.filePath,
          durationSeconds: media.duration?.inSeconds,
        );
      } catch (e) {
        print('Supabase media sync failed: $e');
      }
    }
  }

  // Add media with file upload to storage bucket
  // LOCAL-FIRST APPROACH: Add to UI immediately, then sync to Supabase
  Future<MediaItem?> addMediaWithFile({
    required MediaType type,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? transcription,
    Duration? duration,
  }) async {
    if (_userId == null) {
      AppLogger.warning('addMediaWithFile: No user logged in');
      return null;
    }

    // Create a temporary local media item for INSTANT UI feedback
    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final localMedia = MediaItem(
      id: tempId,
      type: type,
      filePath: fileName,
      fileUrl: null, // Will be updated after upload
      transcription: transcription,
      capturedAt: DateTime.now(),
      duration: duration,
      localBytes: fileBytes, // Store bytes for local preview
    );

    // Add to local list IMMEDIATELY for instant UI
    _mediaItems.insert(0, localMedia);
    notifyListeners();
    AppLogger.debug('Added local media: ${type.name}');

    MediaItem finalMedia = localMedia;

    // Now try to upload to Supabase in background
    try {
      final result = await _supabaseService.saveMediaWithFile(
        firebaseUid: _userId!,
        mediaType: type.name,
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
        transcription: transcription,
        durationSeconds: duration?.inSeconds,
      );

      if (result != null) {
        // Update the local item with server data
        final index = _mediaItems.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          final serverMedia = MediaItem(
            id: result['id'].toString(),
            type: type,
            filePath: result['file_path'],
            fileUrl: result['file_url'],
            transcription: result['transcription'],
            capturedAt: DateTime.parse(result['captured_at']),
            duration: result['duration_seconds'] != null
                ? Duration(seconds: result['duration_seconds'])
                : null,
            // Keep localBytes for speed in analysis if needed?
            // Actually, serverMedia replaces localMedia, so localBytes might be lost?
            // We should pass localBytes to serverMedia if we want analysis to use it!
            localBytes: fileBytes,
          );
          _mediaItems[index] = serverMedia;
          notifyListeners();
          AppLogger.debug('Media synced to server');

          finalMedia = serverMedia;
        }
      }
    } catch (e) {
      AppLogger.warning('Supabase sync failed (keeping local): $e');
      // Keep the local item even if sync fails - user still sees their media
    }

    // 🚀 AUTO-TRIGGER AI ANALYSIS (ALWAYS)
    // Runs in background - we don't await it here to keep UI snappy
    // Now works even if upload failed, because MediaAnalysisService accepts localBytes!
    _triggerAutoAnalysis(finalMedia);

    // Return the item
    return finalMedia;
  }

  /// Auto-trigger AI analysis for newly saved media
  /// Runs in background without blocking UI
  Future<void> _triggerAutoAnalysis(MediaItem media) async {
    try {
      AppLogger.debug('Auto-triggering AI analysis for ${media.type.name}');

      final analysisService = MediaAnalysisService();
      final description = await analysisService.analyzeAndStoreDescription(
        media,
      );

      if (description != null) {
        AppLogger.debug('AI analysis complete');

        // Update local item with AI description
        final index = _mediaItems.indexWhere((m) => m.id == media.id);
        if (index != -1) {
          // Create updated media item with AI description
          final updatedMedia = MediaItem(
            id: media.id,
            type: media.type,
            filePath: media.filePath,
            fileUrl: media.fileUrl,
            transcription: media.transcription,
            aiDescription: description,
            capturedAt: media.capturedAt,
            duration: media.duration,
          );
          _mediaItems[index] = updatedMedia;
          notifyListeners();
        }
      } else {
        AppLogger.debug('AI analysis returned no description');
      }
    } catch (e) {
      AppLogger.error('Auto-analysis failed', e);
      // Don't fail silently - the media is still saved, just without AI analysis
    }
  }

  // Remove media item
  Future<void> removeMedia(String id) async {
    // Remove locally first
    _mediaItems.removeWhere((m) => m.id == id);
    notifyListeners();

    // Delete from Supabase
    if (_userId != null) {
      try {
        await _supabaseService.deleteMedia(id);
      } catch (e) {
        AppLogger.error('Supabase media delete failed', e);
      }
    }
  }
}

class ReminderItem {
  final String id;
  final String title;
  final DateTime dateTime;
  final DateTime createdAt;

  ReminderItem({
    required this.id,
    required this.title,
    required this.dateTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedTime {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int get daysAway {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return reminderDate.difference(today).inDays;
  }
}

class NoteItem {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class FocusSession {
  final String id;
  final int durationMinutes;
  final String sessionType;
  final DateTime startedAt;
  final bool isCompleted;

  FocusSession({
    required this.id,
    required this.durationMinutes,
    required this.sessionType,
    required this.startedAt,
    this.isCompleted = false,
  });

  String get formattedTime {
    final hour = startedAt.hour.toString().padLeft(2, '0');
    final minute = startedAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  FocusSession copyWith({bool? isCompleted}) {
    return FocusSession(
      id: id,
      durationMinutes: durationMinutes,
      sessionType: sessionType,
      startedAt: startedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class MediaItem {
  final String id;
  final String userId; // Added for server sync
  final MediaType type;
  final String? filePath;
  final String? fileUrl;
  final String? transcription;
  final String? aiDescription;
  final DateTime capturedAt;
  final Duration? duration;
  final List<int>? localBytes; // For local preview before Supabase upload

  MediaItem({
    required this.id,
    this.userId = 'unknown', // Default to unknown if not provided
    required this.type,
    this.filePath,
    this.fileUrl,
    this.transcription,
    this.aiDescription,
    DateTime? capturedAt,
    this.duration,
    this.localBytes,
  }) : capturedAt = capturedAt ?? DateTime.now();

  String get formattedTime {
    final hour = capturedAt.hour.toString().padLeft(2, '0');
    final minute = capturedAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Check if this is a local-only item (not yet synced to server)
  bool get isLocal => id.startsWith('local_');

  // Check if we can display this item
  bool get hasDisplayableContent =>
      fileUrl != null || (localBytes != null && localBytes!.isNotEmpty);
}

enum MediaType { photo, video, audio }
