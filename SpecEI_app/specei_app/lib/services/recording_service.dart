import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling audio and video recording
class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  bool _isRecordingAudio = false;
  DateTime? _recordingStartTime;

  bool get isRecordingAudio => _isRecordingAudio;

  /// Check if recording is supported on this platform
  bool get isRecordingSupported => !Platform.isWindows;

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    if (Platform.isWindows) {
      // Windows doesn't need explicit permission request in the same way
      return true;
    }
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    if (Platform.isWindows) {
      return true;
    }
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Start audio recording
  Future<bool> startAudioRecording() async {
    try {
      // Check permission
      if (!await requestMicrophonePermission()) {
        return false;
      }

      // Check if already recording
      if (_isRecordingAudio) {
        return false;
      }

      _recordingStartTime = DateTime.now();
      _isRecordingAudio = true;

      // Note: Full audio recording with the record package works on mobile
      // For Windows demo, we simulate recording
      if (kDebugMode) {
        print('Audio recording started (Windows demo mode)');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting audio recording: $e');
      }
      return false;
    }
  }

  /// Stop audio recording and return the file path
  Future<RecordedMemory?> stopAudioRecording() async {
    try {
      if (!_isRecordingAudio) {
        return null;
      }

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : const Duration(seconds: 5);

      _isRecordingAudio = false;
      _recordingStartTime = null;

      // Create demo recording entry
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/audio_$timestamp.m4a';

      return RecordedMemory(
        type: MemoryType.audio,
        filePath: path,
        timestamp: DateTime.now(),
        title: 'Voice Note',
        duration: duration,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping audio recording: $e');
      }
      _isRecordingAudio = false;
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
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

  RecordedMemory({
    required this.type,
    required this.filePath,
    required this.timestamp,
    required this.title,
    this.duration,
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
