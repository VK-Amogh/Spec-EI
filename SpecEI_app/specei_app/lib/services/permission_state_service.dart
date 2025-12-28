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
  bool _cloudSyncEnabled = true;

  // Getters
  bool get isMicrophoneEnabled => _microphoneEnabled;
  bool get isCameraEnabled => _cameraEnabled;
  bool get isCloudSyncEnabled => _cloudSyncEnabled;

  // Setters that notify listeners
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

  void setCloudSyncEnabled(bool value) {
    if (_cloudSyncEnabled != value) {
      _cloudSyncEnabled = value;
      notifyListeners();
    }
  }

  // Toggle methods
  void toggleMicrophone() {
    _microphoneEnabled = !_microphoneEnabled;
    notifyListeners();
  }

  void toggleCamera() {
    _cameraEnabled = !_cameraEnabled;
    notifyListeners();
  }

  void toggleCloudSync() {
    _cloudSyncEnabled = !_cloudSyncEnabled;
    notifyListeners();
  }
}
