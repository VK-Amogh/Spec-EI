import 'dart:convert';
import 'package:http/http.dart' as http;

/// Groq AI Chat Service
/// Uses Groq's fast inference API (OpenAI-compatible)
/// Free tier available at console.groq.com
class ChatService {
  // Get your free API key from: https://console.groq.com/keys
  static const String _apiKey =
      'REMOVED_GROQ_KEY';
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

  Future<String> sendMessage(String message) async {
    // Add user message to history
    _conversationHistory.add({'role': 'user', 'content': message});

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': _model,
          'messages': _conversationHistory,
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
}
