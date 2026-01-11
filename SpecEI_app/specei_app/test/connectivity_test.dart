import 'package:http/http.dart' as http;
import 'package:specei_app/core/server_config.dart';

Future<void> main() async {
  print('🔎 Starting Connectivity Test...');
  print('Target: ${ServerConfig.gatewayBase}');

  // 1. Test Gateway/Health
  try {
    // Gateway usually forwards, so we check Mistral/Whisper health independently if gateway doesn't have its own
    // Assuming gateway forwards /health or similar, or we check endpoints directly via gateway

    // Check Mistral Health (via Gateway)
    // Note: If mistral_server has no root endpoint, we try /messages or just connect
    print('\nChecking AI Brain (Mistral)...');
    final mistralUri = Uri.parse('${ServerConfig.mistralUrl}/v1/models');
    // Mistral server usually has /v1/models from llama-cpp-python

    final mistralRes = await http.get(mistralUri).timeout(Duration(seconds: 2));
    if (mistralRes.statusCode == 200) {
      print('✅ AI Brain ONLINE');
    } else {
      print('⚠️ AI Brain Responded with ${mistralRes.statusCode}');
    }
  } catch (e) {
    print('❌ AI Brain Connection Failed: $e');
    print('   (Make sure mistral_server.py is running on port 8001)');
  }

  // 2. Test Whisper Health
  try {
    print('\nChecking Ears (Whisper)...');
    final whisperUri = Uri.parse('${ServerConfig.whisperBase}/health');
    // Assuming whisper_server.py has /health

    final whisperRes = await http.get(whisperUri).timeout(Duration(seconds: 2));
    if (whisperRes.statusCode == 200) {
      print('✅ Ears ONLINE');
    } else {
      print('⚠️ Ears Responded with ${whisperRes.statusCode}');
    }
  } catch (e) {
    print('❌ Ears Connection Failed: $e');
    print('   (Make sure whisper_server.py is running on port 8000)');
  }

  print('\n------------------------------------------------');
  print('If you see ❌, ensure:');
  print('1. Phones/PC are on SAME Wi-Fi (192.168.29.x)');
  print('2. Python servers are running (mistral_server.py, whisper_server.py)');
  print('3. Security Gateway is running (security_gateway.py)');
  print('4. Windows Firewall allows Python/Port 8000/8001/8080');
}
