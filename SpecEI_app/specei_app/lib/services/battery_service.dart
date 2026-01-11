import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

/// Service for getting device battery information
class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();
  int _batteryLevel = -1;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isCharging => _batteryState == BatteryState.charging;

  /// Initialize and get current battery level
  Future<int> getBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      return _batteryLevel;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting battery level: $e');
      }
      return -1; // Return -1 if not supported
    }
  }

  /// Get battery state (charging, discharging, full, unknown)
  Future<BatteryState> getBatteryState() async {
    try {
      _batteryState = await _battery.batteryState;
      return _batteryState;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting battery state: $e');
      }
      return BatteryState.unknown;
    }
  }

  /// Stream of battery level changes
  Stream<int> get batteryLevelStream async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      yield await getBatteryLevel();
    }
  }

  /// Stream of battery state changes
  Stream<BatteryState> get batteryStateStream => _battery.onBatteryStateChanged;

  /// Listen to battery state changes
  void listenToBatteryState(Function(BatteryState) onStateChange) {
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
      _batteryState = state;
      onStateChange(state);
    });
  }

  /// Get battery color based on level
  /// Red: <20%, Yellow: <50%, Green: >=50%
  static BatteryColor getBatteryColor(int level) {
    if (level < 0) return BatteryColor.unknown;
    if (level < 20) return BatteryColor.red;
    if (level < 50) return BatteryColor.yellow;
    return BatteryColor.green;
  }

  /// Dispose resources
  void dispose() {
    _batteryStateSubscription?.cancel();
  }
}

enum BatteryColor { red, yellow, green, unknown }
