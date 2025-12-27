import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Audio Recording Service
/// Handles microphone recording for web and mobile
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Check if we have microphone permission
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        // Use WebM format for web compatibility
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: '', // Empty path for blob recording on web
        );
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and return audio bytes
  Future<Uint8List?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;
      final duration = recordingDuration;
      _recordingStartTime = null;

      if (path != null) {
        // For web, we need to fetch the blob data
        // The path on web is a blob URL
        return await _fetchBlobData(path);
      }
      return null;
    } catch (e) {
      print('Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _isRecording = false;
      _recordingStartTime = null;
    } catch (e) {
      print('Failed to cancel recording: $e');
    }
  }

  /// Fetch blob data from URL (for web)
  Future<Uint8List?> _fetchBlobData(String blobUrl) async {
    try {
      // On web, the record package returns audio data directly
      // We need to handle this differently
      // For now, return a placeholder - actual implementation depends on platform
      return null;
    } catch (e) {
      print('Failed to fetch blob data: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}
