import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Add Supabase support
import '../core/server_config.dart';

/// Groq AI Chat Service
/// Uses Groq's fast inference API (OpenAI-compatible)
/// Free tier available at console.groq.com
class ChatService {
  // Direct Groq Key
  static String get _apiKey => ServerConfig.groqApiKey;

  // For Android/Physical devices, change 'localhost' to your PC's LAN IP
  static String get _baseUrl => ServerConfig.mistralUrl;

  // Using Groq Model
  static const String _model = 'llama-3.1-8b-instant';

  // For Android/Physical devices, change 'localhost' to your PC's LAN IP
  static String get _localWhisperUrl => ServerConfig.whisperUrl;

  final List<Map<String, String>> _conversationHistory = [];

  ChatService() {
    _conversationHistory.add({
      'role': 'system',
      'content': 'You are SpecEI, a local offline AI assistant. be concise.',
    });
  }

  Future<String> sendMessage(String message, {String? systemContext}) async {
    _conversationHistory.add({'role': 'user', 'content': message});

    List<Map<String, String>> apiMessages = List.from(_conversationHistory);

    if (systemContext != null) {
      apiMessages.insert(apiMessages.length - 1, {
        'role': 'system',
        'content': systemContext,
      });
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey', // Required by Security Gateway
        },
        body: json.encode({
          'model': _model,
          'messages': apiMessages,
          'temperature': 0.7,
          'max_tokens': 1024,
          'user': Supabase
              .instance
              .client
              .auth
              .currentUser
              ?.id, // Send User ID for RAG
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final assistantMessage =
            data['choices'][0]['message']['content'] as String;

        _conversationHistory.add({
          'role': 'assistant',
          'content': assistantMessage,
        });

        return assistantMessage;
      } else {
        throw Exception(
          'Local Brain Error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _conversationHistory.removeLast();
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Clear conversation history (start fresh)
  void clearHistory() {
    _conversationHistory.clear();
    _conversationHistory.add({
      'role': 'system',
      'content': 'You are SpecEI, a local offline AI assistant. be concise.',
    });
  }

  /// Transcribe audio using Groq Whisper Cloud
  Future<String> transcribeAudio(Uint8List audioBytes, String fileName) async {
    try {
      final uri = Uri.parse(_localWhisperUrl);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.fields['model'] = 'whisper-large-v3';
      request.fields['language'] = 'en';

      request.files.add(
        http.MultipartFile.fromBytes('file', audioBytes, filename: fileName),
      );

      print('🎙️ Sending audio to Groq Cloud...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] as String;
      } else {
        throw Exception(
          'Groq Whisper failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Groq Whisper error: $e');
    }
  }

  /// Get vector embedding - Not supported by Groq properly yet?
  /// Actually Groq doesn't have embeddings endpoint active for public?
  /// We'll leave it as is or return null to avoid errors.
  Future<List<double>?> getEmbedding(String text) async {
    return null; // Embeddings not available on Groq Cloud direct yet
  }

  /// Analyze an image using Groq Vision (Direct)
  Future<String> analyzeImage(
    Uint8List imageBytes,
    String fileName, {
    String? userPrompt,
  }) async {
    try {
      print('☁️ Sending image to Groq Cloud Vision...');
      final base64Image = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      // Use Chat Completions endpoint for Vision
      final url = Uri.parse(ServerConfig.mistralUrl);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.2-11b-vision-preview', // Trying requested model
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': userPrompt ?? 'Describe this image in detail.',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
          'max_tokens': 512,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        print('✅ Groq Vision Analysis Complete');
        return content;
      } else {
        print('❌ Vision Error: ${response.statusCode} - ${response.body}');
        return "Visual analysis failed: ${response.body}";
      }
    } catch (e) {
      print('❌ Vision Exception: $e');
      return "Visual analysis error: $e";
    }
  }
}
