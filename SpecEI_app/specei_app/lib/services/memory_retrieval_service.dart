import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../database/entities.dart'; // Unused
// import '../objectbox.g.dart'; // Unused
import 'media_analysis_service.dart';
import 'memory_data_service.dart'; // For MediaItem definition
import 'chat_service.dart';
import '../core/logger.dart';
import '../core/server_config.dart';

/// The Intelligence Layer for Memory Access
/// Implements STRICT hierarchical retrieval (Object -> Event -> Frame)
/// Adheres to: RETRIEVE BEFORE REASON
class MemoryRetrievalService {
  static final MemoryRetrievalService _instance =
      MemoryRetrievalService._internal();
  factory MemoryRetrievalService() => _instance;
  MemoryRetrievalService._internal();

  final ChatService _chatService = ChatService();
  // final MediaAnalysisService _analysisService = MediaAnalysisService(); // Unused

  /// --------------------------------
  /// MAIN ENTRY POINT
  /// --------------------------------
  /// Orchestrates the 8-Step Pipeline
  Future<SemanticSearchResult> retrieveAndAnswer(
    String userQuery,
    List<MediaItem> allMedia,
  ) async {
    try {
      AppLogger.info('🚀 SERVER SEARCH: "$userQuery"');

      final url = Uri.parse('${ServerConfig.gatewayBase}/api/search');
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';

      // Call Server API
      // Note: We ignore 'allMedia' as server has the source of truth
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${ServerConfig.apiKey}', // Ensure this getter exists or use constant
        },
        body: jsonEncode({'query': userQuery, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse Media Results from JSON
        final results = (data['media'] as List).map((m) {
          // Convert server JSON to local MediaItem matches
          return MediaItem(
            id: m['media_id'],
            userId: userId,
            type: _parseMediaType(m['media_type']),
            fileUrl: _fixLocalPath(
              m['file_path'],
            ), // Helper to maybe correct path
            capturedAt: DateTime.parse(m['created_at']),
            aiDescription: (m['matches'] as List).join(
              ', ',
            ), // Show matches as description
            // timestamps: m['timestamp']... handle video markers if needed
          );
        }).toList();

        // Extract Server-generated Answer (if any)
        // The current /api/search implementation (read earlier) returns { user_id, count, media }.
        // It DOES NOT return an AI answer directly yet.
        // Mistral chat needs to optionally be called here or handled by the server.
        // CHECK: debug_search.py output showed NO "aiAnswer" field.
        // We need to generate the answer on the client side using the results OR ask the server to do it.
        // Let's replicate the old behavior: Get Results -> Ask Chat.

        String aiAnswer = "Found ${results.length} memories.";
        if (results.isNotEmpty) {
          // Should we call ChatService here?
          // Yes, to maintain the "retrieveAndAnswer" contract.
          aiAnswer = await _generateAnswerFromResults(userQuery, results);
        } else {
          aiAnswer = "I couldn't find any matching memories on the server.";
        }

        return SemanticSearchResult(
          query: userQuery,
          keywords: data['expanded_terms']?.join(', ') ?? userQuery,
          results: results,
          aiAnswer: aiAnswer,
        );
      } else {
        AppLogger.error('Server Search Failed: ${response.statusCode}');
        return SemanticSearchResult(
          query: userQuery,
          keywords: '',
          results: [],
          aiAnswer: "Server error.",
        );
      }
    } catch (e, stack) {
      AppLogger.error('Retrieval Failed', e, stack);
      return SemanticSearchResult(
        query: userQuery,
        keywords: '',
        results: [],
        aiAnswer: "Connection failed.",
      );
    }
  }

  MediaType _parseMediaType(String type) {
    if (type == 'video') return MediaType.video;
    if (type == 'audio') return MediaType.audio;
    return MediaType.photo;
  }

  // Convert server path (D:\...) to something usable or keep as identifiers
  // For Windows, we must prefix with file:/// to make it a valid URI
  String _fixLocalPath(String path) {
    if (path.startsWith('http')) return path; // Already a URL (e.g. Supabase)

    // Check if it's a Windows absolute path (e.g., D:\...)
    if (path.contains(':\\') || path.startsWith('\\')) {
      // Convert backslashes to forward slashes for URI
      final fixed = path.replaceAll('\\', '/');
      // Ensure file:/// prefix
      if (!fixed.startsWith('file:///')) {
        return 'file:///$fixed';
      }
      return fixed;
    }
    return path;
  }

  Future<String> _generateAnswerFromResults(
    String query,
    List<MediaItem> items,
  ) async {
    // Simple context build for ChatService
    final context = items
        .take(5)
        .map((m) => "- [${m.type.name}] ${m.aiDescription} (${m.capturedAt})")
        .join("\n");
    final prompt =
        "User asked: '$query'.\nFound evidence:\n$context\n\nAnswer the user based on this evidence.";
    return await _chatService.sendMessage(prompt);
  }
}
