import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'supabase_service.dart';

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
    if (_userId == null) return;

    try {
      // Load reminders
      final remindersData = await _supabaseService.getReminders(_userId!);
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

      // Load media
      final mediaData = await _supabaseService.getMedia(_userId!);
      _mediaItems.clear();
      print('📦 Loading ${mediaData.length} media items from database');
      for (final data in mediaData) {
        final aiDesc = data['ai_description'];
        if (aiDesc != null && aiDesc.toString().isNotEmpty) {
          print(
            '  ✅ ${data['id']}: has AI description (${aiDesc.toString().length} chars)',
          );
        } else {
          print('  ⚠️ ${data['id']}: NO AI description');
        }
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

      notifyListeners();
    } catch (e) {
      print('Error loading from database: $e');
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
  Future<MediaItem?> addMediaWithFile({
    required MediaType type,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? transcription,
    Duration? duration,
  }) async {
    if (_userId == null) return null;

    try {
      // Upload to Supabase storage and save metadata
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
        final media = MediaItem(
          id: result['id'].toString(),
          type: type,
          filePath: result['file_path'],
          fileUrl: result['file_url'],
          transcription: result['transcription'],
          capturedAt: DateTime.parse(result['captured_at']),
          duration: result['duration_seconds'] != null
              ? Duration(seconds: result['duration_seconds'])
              : null,
        );
        _mediaItems.insert(0, media);
        notifyListeners();
        return media;
      }
    } catch (e) {
      print('Failed to add media with file: $e');
    }
    return null;
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
        print('Supabase media delete failed: $e');
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
  final MediaType type;
  final String? filePath;
  final String? fileUrl;
  final String? transcription;
  final String? aiDescription;
  final DateTime capturedAt;
  final Duration? duration;

  MediaItem({
    required this.id,
    required this.type,
    this.filePath,
    this.fileUrl,
    this.transcription,
    this.aiDescription,
    DateTime? capturedAt,
    this.duration,
  }) : capturedAt = capturedAt ?? DateTime.now();

  String get formattedTime {
    final hour = capturedAt.hour.toString().padLeft(2, '0');
    final minute = capturedAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

enum MediaType { photo, video, audio }
