import 'package:flutter/foundation.dart';

/// Singleton service to manage permission states across the app
/// These states are controlled by the Device Settings toggles
class PermissionStateService extends ChangeNotifier {
  static final PermissionStateService _instance =
      PermissionStateService._internal();

  factory PermissionStateService() => _instance;

  PermissionStateService._internal();

  // Permission states controlled by Device Settings toggles
  bool _microphoneEnabled = false;
  bool _cameraEnabled = false;

  // Manual Control states
  bool _recordingModeEnabled = false;
  bool _timedRecordingEnabled = false;
  bool _privacyZonesEnabled = false;
  bool _spatialAudioEnabled = false;
  bool _aiMaskingEnabled = false;

  // Getters - Permissions
  bool get isMicrophoneEnabled => _microphoneEnabled;
  bool get isCameraEnabled => _cameraEnabled;

  // Getters - Manual Controls
  bool get isRecordingModeEnabled => _recordingModeEnabled;
  bool get isTimedRecordingEnabled => _timedRecordingEnabled;
  bool get isPrivacyZonesEnabled => _privacyZonesEnabled;
  bool get isSpatialAudioEnabled => _spatialAudioEnabled;
  bool get isAiMaskingEnabled => _aiMaskingEnabled;

  // Setters - Permissions
  void setMicrophoneEnabled(bool value) {
    if (_microphoneEnabled != value) {
      _microphoneEnabled = value;
      notifyListeners();
    }
  }

  void setCameraEnabled(bool value) {
    if (_cameraEnabled != value) {
      _cameraEnabled = value;
      notifyListeners();
    }
  }

  // Setters - Manual Controls
  void setRecordingModeEnabled(bool value) {
    if (_recordingModeEnabled != value) {
      _recordingModeEnabled = value;
      notifyListeners();
    }
  }

  void setTimedRecordingEnabled(bool value) {
    if (_timedRecordingEnabled != value) {
      _timedRecordingEnabled = value;
      notifyListeners();
    }
  }

  void setPrivacyZonesEnabled(bool value) {
    if (_privacyZonesEnabled != value) {
      _privacyZonesEnabled = value;
      notifyListeners();
    }
  }

  void setSpatialAudioEnabled(bool value) {
    if (_spatialAudioEnabled != value) {
      _spatialAudioEnabled = value;
      notifyListeners();
    }
  }

  void setAiMaskingEnabled(bool value) {
    if (_aiMaskingEnabled != value) {
      _aiMaskingEnabled = value;
      notifyListeners();
    }
  }

  // Toggle methods - Permissions
  void toggleMicrophone() {
    _microphoneEnabled = !_microphoneEnabled;
    notifyListeners();
  }

  void toggleCamera() {
    _cameraEnabled = !_cameraEnabled;
    notifyListeners();
  }

  // Toggle methods - Manual Controls
  void toggleRecordingMode() {
    _recordingModeEnabled = !_recordingModeEnabled;
    notifyListeners();
  }

  void toggleTimedRecording() {
    _timedRecordingEnabled = !_timedRecordingEnabled;
    notifyListeners();
  }

  void togglePrivacyZones() {
    _privacyZonesEnabled = !_privacyZonesEnabled;
    notifyListeners();
  }

  void toggleSpatialAudio() {
    _spatialAudioEnabled = !_spatialAudioEnabled;
    notifyListeners();
  }

  void toggleAiMasking() {
    _aiMaskingEnabled = !_aiMaskingEnabled;
    notifyListeners();
  }
}
