import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/env_config.dart';

/// Groq AI Chat Service
/// Uses Groq's fast inference API (OpenAI-compatible)
/// Free tier available at console.groq.com
class ChatService {
  // API key loaded from env_config.dart (gitignored)
  static String get _apiKey => EnvConfig.groqApiKey;
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Using llama-3.3-70b-versatile - fast and capable model
  static const String _model = 'llama-3.3-70b-versatile';

  final List<Map<String, String>> _conversationHistory = [];

  ChatService() {
    // Add system prompt for SpecEI assistant
    _conversationHistory.add({
      'role': 'system',
      'content':
          'You are SpecEI, an AI assistant integrated with smart glasses. '
          'You help users with information, tasks, and provide intelligent insights. '
          'Be concise, helpful, and friendly.',
    });
  }

  Future<String> sendMessage(String message, {String? systemContext}) async {
    // Add user message to history
    _conversationHistory.add({'role': 'user', 'content': message});

    // Prepare messages for API (copy history)
    List<Map<String, String>> apiMessages = List.from(_conversationHistory);

    if (systemContext != null) {
      // Insert system context before the last user message to guide the response
      // The last message is the user message we just added
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
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': _model,
          'messages': apiMessages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final assistantMessage =
            data['choices'][0]['message']['content'] as String;

        // Add assistant response to history for context
        _conversationHistory.add({
          'role': 'assistant',
          'content': assistantMessage,
        });

        return assistantMessage;
      } else if (response.statusCode == 401) {
        throw Exception(
          'Invalid API key. Get a free key at console.groq.com/keys',
        );
      } else if (response.statusCode == 429) {
        throw Exception(
          'Rate limit exceeded. Please wait a moment and try again.',
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['error']?['message'] ?? 'API error: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Remove the failed user message from history
      _conversationHistory.removeLast();

      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  /// Clear conversation history (start fresh)
  void clearHistory() {
    _conversationHistory.clear();
    _conversationHistory.add({
      'role': 'system',
      'content':
          'You are SpecEI, an AI assistant integrated with smart glasses. '
          'You help users with information, tasks, and provide intelligent insights. '
          'Be concise, helpful, and friendly.',
    });
  }

  /// Transcribe audio using Groq Whisper model
  Future<String> transcribeAudio(Uint8List audioBytes, String fileName) async {
    try {
      final uri = Uri.parse(
        'https://api.groq.com/openai/v1/audio/transcriptions',
      );
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $_apiKey';

      request.fields['model'] = 'whisper-large-v3'; // Groq Whisper model
      request.fields['response_format'] = 'json';

      request.files.add(
        http.MultipartFile.fromBytes('file', audioBytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] as String;
      } else {
        throw Exception('Transcription failed: ${response.body}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Transcription error: $e');
    }
  }

  /// Analyze an image using Groq's Llama 3.2 Vision model
  /// Supports both file bytes and URL-based images
  Future<String> analyzeImage(
    Uint8List imageBytes,
    String fileName, {
    String? userPrompt,
  }) async {
    // Convert image to base64
    final base64Image = base64Encode(imageBytes);

    // Determine MIME type from filename
    String mimeType = 'image/jpeg';
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'png':
        mimeType = 'image/png';
        break;
      case 'gif':
        mimeType = 'image/gif';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      case 'jpg':
      case 'jpeg':
      default:
        mimeType = 'image/jpeg';
    }

    // Build the prompt
    final prompt =
        userPrompt ??
        'Analyze this image in detail. Describe what you see including objects, people, text, colors, setting, and any notable features. Be thorough but concise.';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model':
              'meta-llama/llama-4-scout-17b-16e-instruct', // Llama 4 Scout vision model
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
                },
              ],
            },
          ],
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final analysisResult =
            data['choices'][0]['message']['content'] as String;

        // Add to conversation history for context
        _conversationHistory.add({
          'role': 'user',
          'content': '[Image attached: $fileName] $prompt',
        });
        _conversationHistory.add({
          'role': 'assistant',
          'content': analysisResult,
        });

        return analysisResult;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Check your Groq API key.');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait and try again.');
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['error']?['message'] ??
              'Vision API error: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Image analysis error: $e');
    }
  }
}
