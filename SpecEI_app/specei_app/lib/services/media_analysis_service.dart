import 'dart:convert';
import 'package:http/http.dart' as http;
import 'memory_data_service.dart';
import 'supabase_service.dart';
import 'chat_service.dart';

/// AI-powered Media Analysis Service
/// Analyzes images, videos, and audio to generate searchable descriptions
/// Uses ChatService for AI analysis to share API configuration
class MediaAnalysisService {
  static final MediaAnalysisService _instance =
      MediaAnalysisService._internal();
  factory MediaAnalysisService() => _instance;
  MediaAnalysisService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final ChatService _chatService = ChatService();

  /// Analyze media and store AI description
  /// Returns the generated description or null on failure
  Future<String?> analyzeAndStoreDescription(MediaItem media) async {
    try {
      print('🔍 Analyzing media: ${media.id} (${media.type.name})');
      String? description;

      switch (media.type) {
        case MediaType.photo:
          description = await _analyzeImage(media.fileUrl);
          break;
        case MediaType.video:
          description = await _analyzeVideo(media.fileUrl);
          break;
        case MediaType.audio:
          description = await _transcribeAudio(media.fileUrl);
          break;
      }

      if (description != null && description.isNotEmpty) {
        print(
          '✅ Got description: ${description.substring(0, description.length > 50 ? 50 : description.length)}...',
        );
        // Store description in database
        await _supabaseService.updateMediaAIDescription(media.id, description);
        return description;
      } else {
        print('⚠️ No description generated for ${media.id}');
      }
    } catch (e) {
      print('❌ Media analysis failed: $e');
    }
    return null;
  }

  /// Analyze an image using ChatService's vision capabilities
  Future<String?> _analyzeImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      print('⚠️ No image URL provided');
      return null;
    }

    try {
      print('📷 Downloading image from: $imageUrl');
      // Download image bytes
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        print('❌ Failed to download image: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      print('📷 Image downloaded: ${bytes.length} bytes');

      // Determine filename from URL
      final uri = Uri.parse(imageUrl);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'image.jpg';

      // Use ChatService to analyze image
      final description = await _chatService.analyzeImage(
        bytes,
        filename,
        userPrompt:
            'Describe this image in detail for search purposes. '
            'List all objects, people, animals, colors, text, brands, locations, activities, '
            'and notable features. Use keywords that someone might search for. '
            'Be thorough but concise. Format: comma-separated keywords and short phrases.',
      );

      return description;
    } catch (e) {
      print('❌ Image analysis error: $e');
    }
    return null;
  }

  /// Analyze video - extract thumbnail description
  Future<String?> _analyzeVideo(String? videoUrl) async {
    if (videoUrl == null || videoUrl.isEmpty) return null;

    try {
      print('🎬 Analyzing video: $videoUrl');
      // For now, create a basic description based on filename
      // Full video analysis would require extracting frames
      final uri = Uri.parse(videoUrl);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'video';

      // Create a searchable description
      return 'Video recording, $filename, video content, recorded media, capture, footage, clip, movie, recording';
    } catch (e) {
      print('❌ Video analysis error: $e');
    }
    return null;
  }

  /// Transcribe audio using ChatService's Whisper integration
  Future<String?> _transcribeAudio(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) {
      print('⚠️ No audio URL provided');
      return null;
    }

    try {
      print('🎵 Downloading audio from: $audioUrl');
      // Download audio bytes
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode != 200) {
        print('❌ Failed to download audio: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      print('🎵 Audio downloaded: ${bytes.length} bytes');

      // Determine filename from URL
      final uri = Uri.parse(audioUrl);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'audio.m4a';

      // Use ChatService to transcribe
      final transcription = await _chatService.transcribeAudio(bytes, filename);

      if (transcription.isNotEmpty) {
        return 'Audio recording, voice memo, spoken words: $transcription';
      }
    } catch (e) {
      print('❌ Audio transcription error: $e');
    }
    return null;
  }

  /// Search media by AI-generated descriptions
  /// Returns matching media items sorted by relevance
  /// Use "*" to show all media with descriptions
  Future<List<MediaItem>> searchMedia(
    String query,
    List<MediaItem> allMedia,
  ) async {
    if (query.isEmpty) return [];

    print('🔎 Searching for: "$query" in ${allMedia.length} media items');

    // Wildcard search - show all media with descriptions
    if (query == '*') {
      print('📋 Wildcard search - showing all media with descriptions');
      return allMedia
          .where(
            (m) =>
                (m.aiDescription != null && m.aiDescription!.isNotEmpty) ||
                (m.transcription != null && m.transcription!.isNotEmpty),
          )
          .toList();
    }

    final queryLower = query.toLowerCase();
    final queryWords = queryLower
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Score each media item based on description match
    final scoredMedia = <MapEntry<MediaItem, int>>[];

    for (final media in allMedia) {
      int score = 0;
      final description = (media.aiDescription ?? '').toLowerCase();
      final transcription = (media.transcription ?? '').toLowerCase();
      final combined = '$description $transcription';

      // Debug log - show preview of actual content
      if (combined.isNotEmpty) {
        final preview = combined.length > 80
            ? '${combined.substring(0, 80)}...'
            : combined;
        print('  📝 Media ${media.id}: "$preview"');
      } else {
        print('  ⚠️ Media ${media.id}: NO AI description');
      }

      if (combined.isEmpty) continue;

      // Exact phrase match gets highest score
      if (combined.contains(queryLower)) {
        score += 100;
      }

      // Individual word matches
      for (final word in queryWords) {
        if (combined.contains(word)) {
          score += 10;

          // Bonus for word appearing multiple times
          final matches = RegExp(word).allMatches(combined).length;
          score += matches * 2;
        }
      }

      if (score > 0) {
        print('  ✅ Match found: ${media.id} with score $score');
        scoredMedia.add(MapEntry(media, score));
      }
    }

    // Sort by score descending
    scoredMedia.sort((a, b) => b.value.compareTo(a.value));

    print('🔎 Found ${scoredMedia.length} matching items');
    return scoredMedia.map((e) => e.key).toList();
  }

  /// Batch analyze all unanalyzed media items
  /// Returns number of items processed
  Future<int> analyzeAllPendingMedia(List<MediaItem> mediaItems) async {
    int processed = 0;
    int total = mediaItems.length;

    print('🚀 Starting analysis of $total media items...');

    for (int i = 0; i < mediaItems.length; i++) {
      final media = mediaItems[i];

      // Skip if already has AI description
      if (media.aiDescription != null && media.aiDescription!.isNotEmpty) {
        print('⏭️ Skipping ${media.id} - already analyzed');
        continue;
      }

      print('📊 Processing ${i + 1}/$total: ${media.type.name}');
      final result = await analyzeAndStoreDescription(media);
      if (result != null) {
        processed++;
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('✅ Analysis complete! Processed $processed items');
    return processed;
  }
}
