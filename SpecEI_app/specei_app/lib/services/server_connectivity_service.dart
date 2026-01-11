import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/server_config.dart';

enum ServerStatus { connecting, online, offline }

class ServerConnectivityService extends ChangeNotifier {
  ServerStatus _mistralStatus = ServerStatus.connecting;
  ServerStatus _whisperStatus = ServerStatus.connecting;
  String _lastCheckTime = '';

  ServerStatus get mistralStatus => _mistralStatus;
  ServerStatus get whisperStatus => _whisperStatus;
  String get lastCheckTime => _lastCheckTime;

  bool get isFullyOnline =>
      _mistralStatus == ServerStatus.online &&
      _whisperStatus == ServerStatus.online;

  Future<void> checkConnections() async {
    _mistralStatus = ServerStatus.connecting;
    _whisperStatus = ServerStatus.connecting;
    notifyListeners();

    try {
      // Check Internet/Groq Access
      final res = await http
          .get(
            Uri.parse('https://api.groq.com/openai/v1/models'),
            headers: {'Authorization': 'Bearer ${ServerConfig.groqApiKey}'},
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 401) {
        _mistralStatus = ServerStatus.online;
        _whisperStatus = ServerStatus.online;
      } else {
        _mistralStatus = ServerStatus.offline;
        _whisperStatus = ServerStatus.offline;
      }
    } catch (e) {
      // Offline
      _mistralStatus = ServerStatus.offline;
      _whisperStatus = ServerStatus.offline;
      print('Groq Connectivity Check Failed: $e');
    }

    _lastCheckTime = DateTime.now().toLocal().toString().split('.').first;
    notifyListeners();
  }
}
