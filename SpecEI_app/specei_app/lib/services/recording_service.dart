import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'memory_data_service.dart';
import 'supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Service for handling audio and video recording with Supabase storage
class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SupabaseService _supabaseService = SupabaseService();
  final MemoryDataService _memoryService = MemoryDataService();

  bool _isRecordingAudio = false;
  DateTime? _recordingStartTime;
  StreamSubscription<RecordState>? _recordStateSubscription;

  // Audio data buffer for web recording
  List<int> _audioBuffer = [];

  bool get isRecordingAudio => _isRecordingAudio;

  Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Check if recording is supported
  bool get isRecordingSupported => true; // record package supports web

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      if (kDebugMode) print('Permission check failed: $e');
      return false;
    }
  }

  /// Request camera permission (placeholder for now)
  Future<bool> requestCameraPermission() async {
    return true; // Camera handled separately via image_picker
  }

  /// Start audio recording
  Future<bool> startAudioRecording() async {
    try {
      // Check permission
      if (!await requestMicrophonePermission()) {
        if (kDebugMode) print('Microphone permission denied');
        return false;
      }

      // Check if already recording
      if (_isRecordingAudio) {
        return false;
      }

      // Clear previous buffer
      _audioBuffer = [];

      // Configure recording for web (opus/webm format)
      const config = RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // Start recording - path can be empty for web blob recording
      await _recorder.start(config, path: '');

      _recordingStartTime = DateTime.now();
      _isRecordingAudio = true;

      if (kDebugMode) print('Audio recording started');
      return true;
    } catch (e) {
      if (kDebugMode) print('Error starting audio recording: $e');
      return false;
    }
  }

  /// Stop audio recording and save to Supabase
  Future<RecordedMemory?> stopAudioRecording() async {
    try {
      if (!_isRecordingAudio) {
        return null;
      }

      final duration = recordingDuration;

      // Stop recording and get the path/blob URL
      final path = await _recorder.stop();

      _isRecordingAudio = false;
      final recordingTime = _recordingStartTime ?? DateTime.now();
      _recordingStartTime = null;

      if (path == null) {
        if (kDebugMode) print('Recording returned null path');
        return null;
      }

      if (kDebugMode) print('Recording stopped, path: $path');

      // Create a recorded memory entry
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Determine file extension and mime type
      String extension = 'm4a';
      String mimeType = 'audio/mp4';
      if (kIsWeb) {
        extension = 'webm';
        mimeType = 'audio/webm';
      } else if (path.endsWith('.aac')) {
        extension = 'aac';
        mimeType = 'audio/aac';
      }

      final fileName = 'audio_$timestamp.$extension';

      // Try to save to Supabase (if user is logged in)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Read file bytes
          Uint8List? fileBytes;
          if (kIsWeb) {
            // On web, path is a blob URL
            final response = await http.get(Uri.parse(path));
            fileBytes = response.bodyBytes;
          } else {
            // On mobile/desktop, read from file
            fileBytes = await XFile(path).readAsBytes();
          }

          // Upload to Supabase Storage
          await _memoryService.addMediaWithFile(
            type: MediaType.audio,
            fileName: fileName,
            fileBytes: fileBytes,
            mimeType: mimeType,
            duration: duration,
          );
        } catch (e) {
          if (kDebugMode) print('Failed to save to Supabase: $e');
        }
      }

      return RecordedMemory(
        type: MemoryType.audio,
        filePath: path,
        timestamp: recordingTime,
        title: 'Voice Note',
        duration: duration,
      );
    } catch (e) {
      if (kDebugMode) print('Error stopping audio recording: $e');
      _isRecordingAudio = false;
      return null;
    }
  }

  /// Stop audio recording and return file bytes for transcription
  Future<({Uint8List bytes, String fileName})?>
  stopRecordingForTranscription() async {
    try {
      if (!_isRecordingAudio) return null;

      // Stop recording and get the path/blob URL
      final path = await _recorder.stop();
      _isRecordingAudio = false;
      _recordingStartTime = null;

      if (path == null) return null;

      // Determine file extension/mime
      String extension = 'm4a';
      if (kIsWeb) {
        extension = 'webm';
      } else if (path.endsWith('.aac')) {
        extension = 'aac';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_$timestamp.$extension';

      // Read file bytes
      Uint8List? fileBytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        fileBytes = response.bodyBytes;
      } else {
        fileBytes = await XFile(path).readAsBytes();
      }

      return (bytes: fileBytes, fileName: fileName);
    } catch (e) {
      if (kDebugMode) print('Error stopping recording for transcription: $e');
      _isRecordingAudio = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _isRecordingAudio = false;
      _recordingStartTime = null;
      _audioBuffer = [];
    } catch (e) {
      if (kDebugMode) print('Error canceling recording: $e');
    }
  }

  /// Play audio from URL or path
  Future<void> playAudio(String source) async {
    try {
      if (kDebugMode) print('Attempting to play audio: $source');

      // Stop any currently playing audio
      await _audioPlayer.stop();

      // Play the audio
      if (source.startsWith('http') || source.startsWith('blob:')) {
        if (kDebugMode) print('Playing from URL source');
        // For web URLs (including Supabase), use UrlSource
        await _audioPlayer.play(UrlSource(source));
      } else {
        if (kDebugMode) print('Playing from device file source');
        await _audioPlayer.play(DeviceFileSource(source));
      }

      if (kDebugMode) print('Audio playback started successfully');
    } catch (e) {
      if (kDebugMode) print('Error playing audio: $e');
      // Rethrow for caller to handle if needed
    }
  }

  /// Stop audio playback
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  /// Pause audio playback
  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  /// Resume audio playback
  Future<void> resumeAudio() async {
    await _audioPlayer.resume();
  }

  /// Get the current playback position stream
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;

  /// Get the current player state stream
  Stream<PlayerState> get onPlayerStateChanged =>
      _audioPlayer.onPlayerStateChanged;

  /// Get the duration stream
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;

  /// Dispose resources
  void dispose() {
    _recordStateSubscription?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
  }
}

/// Enum for memory types
enum MemoryType { audio, video }

/// Model for recorded memory
class RecordedMemory {
  final MemoryType type;
  final String filePath;
  final DateTime timestamp;
  final String title;
  final Duration? duration;
  final Uint8List? audioData;

  RecordedMemory({
    required this.type,
    required this.filePath,
    required this.timestamp,
    required this.title,
    this.duration,
    this.audioData,
  });

  String get formattedTime {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
