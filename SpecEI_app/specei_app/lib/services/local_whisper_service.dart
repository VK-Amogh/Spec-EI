import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../core/env_config.dart';

/// Service to interact with self-hosted Whisper server
class LocalWhisperService {
  // Get URL from EnvConfig or default to localhost
  String get _baseUrl {
    // If running on Android emulator, localhost is 10.0.2.2
    // If running on Web/Desktop, localhost is localhost
    // We'll trust the EnvConfig value or fallback
    try {
      return EnvConfig.localWhisperUrl;
    } catch (_) {
      return 'http://localhost:8000/transcribe';
    }
  }

  Future<String> transcribe(Uint8List audioBytes, String filename) async {
    try {
      final url = _baseUrl;
      debugPrint('🎙️ Sending audio to Local Whisper: $url');
      debugPrint('📦 Audio size: ${audioBytes.length} bytes');

      var uri = Uri.parse(url);
      var request = http.MultipartRequest('POST', uri);

      // Determine content type based on filename
      var contentType = MediaType('audio', 'm4a');
      if (filename.endsWith('.webm')) contentType = MediaType('audio', 'webm');
      if (filename.endsWith('.wav')) contentType = MediaType('audio', 'wav');

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: filename,
          contentType: contentType,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseString);
        final text = jsonResponse['text'] as String;
        debugPrint('✅ Local Whisper Transcription: $text');
        return text;
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - $responseString',
        );
      }
    } catch (e) {
      debugPrint('❌ Local Whisper Error: $e');
      rethrow;
    }
  }
}
