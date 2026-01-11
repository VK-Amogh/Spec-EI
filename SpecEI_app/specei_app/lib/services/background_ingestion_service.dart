import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/logger.dart';

class BackgroundIngestionService {
  static const String _isolateName = 'BackgroundIngestionIsolate';

  static final BackgroundIngestionService _instance =
      BackgroundIngestionService._internal();
  factory BackgroundIngestionService() => _instance;
  BackgroundIngestionService._internal();

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'specei_background_service',
        initialNotificationTitle: 'SpecEI Memory Engine',
        initialNotificationContent: 'Ingesting sensory data (Remote Mode)...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Hybrid Mode: Ingestion happens via main app services sending to PC
    // This background service is a placeholder for future continuous capture

    service.on('ingest_media').listen((event) async {
      if (event == null) return;
      final filePath = event['path'] as String;
      final type = event['type'] as String;

      AppLogger.info(
        '🧠 Background Ingest Request: $filePath ($type) - Forwarding to Main',
      );
      // In hybrid mode, actual processing is done by the main isolate communicating with PC
    });
  }
}
