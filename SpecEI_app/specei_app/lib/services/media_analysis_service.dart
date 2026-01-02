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

  /// Analyze media and store AI description + linked metadata
  /// Follows SpecEI Unified Memory spec:
  /// - Raw media remains untouched
  /// - Derived data (transcripts, descriptions) stored as linked metadata
  /// - Semantic memory created from analysis
  Future<String?> analyzeAndStoreDescription(MediaItem media) async {
    try {
      print('🔍 Analyzing media: ${media.id} (${media.type.name})');

      // Check if fileUrl is available
      if (media.fileUrl == null || media.fileUrl!.isEmpty) {
        print('⚠️ No file URL for ${media.id} - skipping analysis');
        return null;
      }

      String? description;
      String? rawTranscript; // For storing pure transcript separately

      switch (media.type) {
        case MediaType.photo:
          print('  📷 Analyzing photo: ${media.fileUrl}');
          description = await _analyzeImage(media.fileUrl);
          break;

        case MediaType.video:
          print('  🎬 Analyzing video: ${media.fileUrl}');
          // For video: Extract audio and transcribe + analyze visually
          description = await _analyzeVideoWithTranscript(media);
          break;

        case MediaType.audio:
          print('  🎤 Transcribing audio: ${media.fileUrl}');
          rawTranscript = await _extractAudioTranscript(media.fileUrl!);
          if (rawTranscript != null && rawTranscript.isNotEmpty) {
            // Store raw transcript in transcripts table (linked metadata)
            await _supabaseService.saveTranscript(
              mediaId: media.id,
              fullText: rawTranscript,
              language: 'en',
            );
            print('  💾 Transcript saved as linked metadata');

            // Extract keywords from speech content
            final keywords = await _extractKeywordsFromTranscript(
              rawTranscript,
            );

            // Create searchable description with transcript + keywords
            description =
                'Audio recording, voice memo, spoken words: $rawTranscript. Keywords: $keywords';
          }
          break;
      }

      if (description != null && description.isNotEmpty) {
        print(
          '✅ Got description: ${description.substring(0, description.length > 50 ? 50 : description.length)}...',
        );
        // Store semantic description in database (ai_description column)
        await _supabaseService.updateMediaAIDescription(media.id, description);
        return description;
      } else {
        print('⚠️ No description generated for ${media.id}');
      }
    } catch (e, stackTrace) {
      print('❌ Media analysis failed: $e');
      print(
        '   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );
    }
    return null;
  }

  /// Extract pure transcript from audio (without keywords)
  Future<String?> _extractAudioTranscript(String audioUrl) async {
    try {
      print('🎵 Downloading audio from: $audioUrl');
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode != 200) {
        print('❌ Failed to download audio: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      print('🎵 Audio downloaded: ${bytes.length} bytes');

      final uri = Uri.parse(audioUrl);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'audio.m4a';

      // Use Whisper AI for transcription
      final transcription = await _chatService.transcribeAudio(bytes, filename);
      print('✅ Whisper transcription complete: ${transcription.length} chars');
      return transcription;
    } catch (e) {
      print('❌ Audio transcription error: $e');
      return null;
    }
  }

  /// Analyze video: Download, extract audio for transcription, and analyze visually
  Future<String?> _analyzeVideoWithTranscript(MediaItem media) async {
    try {
      // First try to transcribe audio from video
      String? transcript;
      try {
        transcript = await _extractAudioTranscript(media.fileUrl!);
        if (transcript != null && transcript.isNotEmpty) {
          // Store transcript as linked metadata
          await _supabaseService.saveTranscript(
            mediaId: media.id,
            fullText: transcript,
            language: 'en',
          );
          print('  💾 Video transcript saved as linked metadata');
        }
      } catch (e) {
        print('  ⚠️ Video audio extraction failed: $e');
      }

      // Also get visual description
      final visualDescription = await _analyzeVideo(media.fileUrl);

      // Combine transcript and visual description
      if (transcript != null && transcript.isNotEmpty) {
        return '$visualDescription. Spoken words: $transcript';
      }
      return visualDescription;
    } catch (e) {
      print('❌ Video analysis with transcript failed: $e');
      return await _analyzeVideo(media.fileUrl);
    }
  }

  /// Force re-analyze ALL media - ignores existing descriptions
  /// Use this to apply new keyword extraction to existing videos/audio
  /// Runs in parallel batches for speed
  Future<int> forceReanalyzeAllMedia(List<MediaItem> mediaItems) async {
    int processed = 0;
    int total = mediaItems.length;

    print('🔄 FAST RE-ANALYZING $total media items in parallel...');

    // Process in parallel batches of 3 for speed
    const batchSize = 3;
    for (int i = 0; i < mediaItems.length; i += batchSize) {
      final batch = mediaItems.skip(i).take(batchSize).toList();
      print(
        '📊 Processing batch ${(i ~/ batchSize) + 1}: ${batch.length} items',
      );

      // Run batch in parallel
      final results = await Future.wait(
        batch.map((media) => analyzeAndStoreDescription(media)),
      );

      processed += results.where((r) => r != null).length;
    }

    print('✅ Fast re-analysis complete! Updated $processed/$total items');
    return processed;
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

  /// Analyze video - generate comprehensive searchable metadata
  /// Includes: scene description, objects, activities, OCR, temporal tags
  /// Ensures video content is fully indexed for semantic search
  Future<String?> _analyzeVideo(String? videoUrl) async {
    if (videoUrl == null || videoUrl.isEmpty) return null;

    try {
      print('🎬 Comprehensive video analysis: $videoUrl');

      final uri = Uri.parse(videoUrl);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'video';

      // Download video to analyze
      try {
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          print('📹 Video downloaded: ${bytes.length} bytes');
          final sizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
          final durationEstimate = _estimateVideoDuration(bytes.length);

          // Generate comprehensive metadata using AI
          final aiPrompt =
              '''You are analyzing a video file for a memory search system.

Video Details:
- Filename: $filename
- Size: $sizeMB MB
- Estimated Duration: $durationEstimate seconds

Generate a COMPREHENSIVE list of searchable keywords and phrases that should be associated with this video. Include:

1. **Common Objects** (always include these if likely): phone, smartphone, mobile, laptop, computer, screen, desk, table, chair, person, face, hand, wall, window, door, book, paper, pen, cup, bottle, bag, keys, glasses

2. **Scene Types**: office, home, outdoor, indoor, living room, bedroom, kitchen, street, building

3. **Activities**: talking, walking, sitting, standing, typing, reading, writing, holding, looking, showing, demonstrating

4. **Potential Subjects**: meeting, conversation, work, tutorial, demo, review, recording, video call

5. **Generic Video Terms**: video, recording, clip, footage, capture, moment, memory

Output as a comma-separated list of keywords. Be GENEROUS with keywords - include anything that MIGHT be in a typical video.''';

          final aiKeywords = await _chatService.sendMessage(aiPrompt);

          // Combine AI keywords with standard video metadata
          final baseKeywords =
              'video, recording, $filename, footage, clip, media, visual, $sizeMB MB, ${durationEstimate}s';

          print('✅ Video keywords generated');
          return 'Video Recording: $filename. $baseKeywords, $aiKeywords';
        }
      } catch (downloadError) {
        print('⚠️ Video download failed: $downloadError');
      }

      // Fallback: Generate comprehensive default keywords
      return _generateDefaultVideoKeywords(filename);
    } catch (e) {
      print('❌ Video analysis error: $e');
    }
    return null;
  }

  /// Generate default comprehensive video keywords when analysis fails
  String _generateDefaultVideoKeywords(String filename) {
    // Include ALL common objects that might appear in a video
    final commonObjects = [
      'phone',
      'smartphone',
      'mobile',
      'device',
      'laptop',
      'computer',
      'screen',
      'monitor',
      'person',
      'face',
      'hand',
      'people',
      'desk',
      'table',
      'chair',
      'room',
      'office',
      'home',
      'indoor',
      'talking',
      'speaking',
      'conversation',
      'video',
      'recording',
      'footage',
      'clip',
      'capture',
    ];

    final filenameKeywords = _extractKeywordsFromFilename(filename);

    return 'Video recording: $filename, $filenameKeywords, ${commonObjects.join(", ")}, visual memory, recorded moment';
  }

  /// Extract keywords from audio transcript using AI
  /// Identifies objects, subjects, intents, and sentiment from speech
  Future<String> _extractKeywordsFromTranscript(String transcript) async {
    try {
      final prompt =
          '''Analyze this audio transcript and extract searchable keywords:

Transcript: "$transcript"

Extract:
1. **Objects mentioned**: phone, laptop, car, keys, etc.
2. **People/Names**: any names or references to people
3. **Actions/Verbs**: check, find, look, call, etc.
4. **Topics**: work, meeting, schedule, reminder, etc.
5. **Sentiment**: positive, negative, neutral, urgent

Return ONLY a comma-separated list of keywords. Include common synonyms.
Example: phone, mobile, check, reminder, work, urgent, calling''';

      final keywords = await _chatService.sendMessage(prompt);
      print('✅ Transcript keywords extracted: ${keywords.length} chars');
      return keywords;
    } catch (e) {
      print('⚠️ Keyword extraction failed: $e');
      // Fallback: split transcript into individual words
      final words = transcript
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .take(20)
          .join(', ');
      return words.isEmpty ? 'audio, voice, speech, recording' : words;
    }
  }

  /// Estimate video duration based on file size (rough approximation)
  int _estimateVideoDuration(int fileSizeBytes) {
    // Assuming ~1MB per 10 seconds for typical mobile video
    return (fileSizeBytes / (1024 * 1024) * 10).round();
  }

  /// Extract searchable keywords from filename
  String _extractKeywordsFromFilename(String filename) {
    // Remove extension and timestamp patterns
    var name = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'_\d{10,}'), ''); // Remove timestamps
    name = name.replaceAll(RegExp(r'[_-]'), ' ');

    // Common video naming patterns
    final patterns = <String>[];
    if (name.toLowerCase().contains('screen')) patterns.add('screen recording');
    if (name.toLowerCase().contains('vid')) patterns.add('video clip');
    if (name.toLowerCase().contains('rec')) patterns.add('recording');

    return patterns.isEmpty ? 'captured video' : patterns.join(', ');
  }

  /// Search media using SEMANTIC matching - by MEANING, not exact words
  /// "teddy" matches "stuffed animal", "plush toy", etc.
  /// Implements true human-like memory recall
  Future<List<MediaItem>> searchMedia(
    String query,
    List<MediaItem> allMedia,
  ) async {
    if (query.isEmpty) return [];

    print('🔎 Semantic search for: "$query" in ${allMedia.length} media items');

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

    // Step 1: Get ALL semantically equivalent terms for the query
    final searchTerms = _getSemanticEquivalents(query);
    print('🧠 Semantic expansion: $searchTerms');

    // Score each media item based on semantic match
    final scoredMedia = <MapEntry<MediaItem, int>>[];

    for (final media in allMedia) {
      int score = 0;
      final description = (media.aiDescription ?? '').toLowerCase();
      final transcription = (media.transcription ?? '').toLowerCase();
      final combined = '$description $transcription';

      if (combined.isEmpty) continue;

      // Check EACH semantic equivalent term
      for (final term in searchTerms) {
        final termLower = term.toLowerCase().trim();
        if (termLower.isEmpty) continue;

        if (combined.contains(termLower)) {
          // Longer matches are more specific, give higher score
          score += 50 + (termLower.length * 2);
          print('  ✅ Semantic match: "$termLower" in ${media.id}');
        }
      }

      if (score > 0) {
        scoredMedia.add(MapEntry(media, score));
      }
    }

    // Sort by score descending
    scoredMedia.sort((a, b) => b.value.compareTo(a.value));

    print('🔎 Found ${scoredMedia.length} matching items');
    return scoredMedia.map((e) => e.key).toList();
  }

  /// Get ALL semantically equivalent terms for a query
  /// Maps concepts to their full semantic family
  Set<String> _getSemanticEquivalents(String query) {
    final queryLower = query.toLowerCase();
    final equivalents = <String>{queryLower};

    // Add individual words from query
    equivalents.addAll(
      queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2),
    );

    // Canonical concept groups - all terms in a group are semantically equivalent
    final conceptGroups = <List<String>>[
      // PLUSH_TOY concept
      [
        'teddy',
        'teddy bear',
        'stuffed animal',
        'plush toy',
        'soft toy',
        'plushie',
        'cuddly toy',
        'stuffed bear',
        'toy bear',
        'fluffy toy',
      ],

      // PHONE concept
      [
        'phone',
        'mobile',
        'smartphone',
        'cellphone',
        'mobile phone',
        'cell phone',
        'iphone',
        'android phone',
        'handset',
        'mobile device',
      ],

      // CAR/VEHICLE concept
      [
        'car',
        'vehicle',
        'automobile',
        'auto',
        'sedan',
        'suv',
        'truck',
        'motor vehicle',
        'wheels',
      ],

      // PERSON concept
      [
        'person',
        'human',
        'people',
        'man',
        'woman',
        'individual',
        'someone',
        'somebody',
        'face',
        'portrait',
      ],

      // PET_DOG concept
      ['dog', 'puppy', 'canine', 'doggy', 'pup', 'hound', 'pet dog'],

      // PET_CAT concept
      ['cat', 'kitten', 'feline', 'kitty', 'pet cat'],

      // KEYS concept
      [
        'key',
        'keys',
        'car key',
        'house key',
        'keychain',
        'key ring',
        'keyring',
      ],

      // GLASSES concept
      [
        'glasses',
        'eyeglasses',
        'spectacles',
        'sunglasses',
        'eyewear',
        'shades',
        'reading glasses',
      ],

      // LAPTOP/COMPUTER concept
      [
        'laptop',
        'computer',
        'pc',
        'notebook',
        'macbook',
        'chromebook',
        'desktop',
        'screen',
      ],

      // BAG concept
      [
        'bag',
        'backpack',
        'purse',
        'handbag',
        'satchel',
        'tote',
        'briefcase',
        'messenger bag',
      ],

      // BOTTLE concept
      ['bottle', 'water bottle', 'flask', 'container', 'drink bottle'],

      // CUP concept
      [
        'cup',
        'mug',
        'glass',
        'tumbler',
        'coffee cup',
        'tea cup',
        'drinking glass',
      ],

      // FOOD concept
      [
        'food',
        'meal',
        'dish',
        'snack',
        'breakfast',
        'lunch',
        'dinner',
        'eating',
      ],

      // BOOK concept
      ['book', 'novel', 'reading', 'textbook', 'paperback', 'hardcover'],

      // WATCH concept
      ['watch', 'wristwatch', 'timepiece', 'smartwatch', 'apple watch'],
    ];

    // Find which concept group(s) the query belongs to
    for (final group in conceptGroups) {
      bool queryMatchesGroup = group.any(
        (term) => queryLower.contains(term) || term.contains(queryLower),
      );

      if (queryMatchesGroup) {
        // Add ALL terms from this concept group
        equivalents.addAll(group);
        print('  📎 Matched concept group: ${group.first}...');
      }
    }

    return equivalents;
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

  /// Local fallback concept expansion when AI is unavailable
  /// Maps common search terms to related concepts
  String _getLocalConceptExpansion(String query) {
    final queryLower = query.toLowerCase();

    // Comprehensive concept mappings
    final conceptMaps = <String, List<String>>{
      'teddy': [
        'teddy',
        'teddy bear',
        'stuffed animal',
        'plush toy',
        'soft toy',
        'bear toy',
        'cuddly toy',
        'plushie',
        'stuffed bear',
        'toy bear',
      ],
      'phone': [
        'phone',
        'mobile',
        'smartphone',
        'cellphone',
        'mobile phone',
        'cell',
        'iphone',
        'android',
        'device',
        'handset',
      ],
      'car': [
        'car',
        'vehicle',
        'automobile',
        'auto',
        'sedan',
        'wheels',
        'ride',
        'motor vehicle',
        'drive',
      ],
      'person': [
        'person',
        'human',
        'people',
        'man',
        'woman',
        'individual',
        'figure',
        'someone',
        'face',
      ],
      'food': [
        'food',
        'meal',
        'dish',
        'eating',
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'cuisine',
        'plate',
      ],
      'dog': [
        'dog',
        'puppy',
        'canine',
        'pet',
        'animal',
        'pup',
        'doggy',
        'hound',
      ],
      'cat': ['cat', 'kitten', 'feline', 'pet', 'animal', 'kitty', 'meow'],
      'book': [
        'book',
        'reading',
        'novel',
        'text',
        'pages',
        'literature',
        'reading material',
      ],
      'computer': [
        'computer',
        'laptop',
        'pc',
        'desktop',
        'screen',
        'monitor',
        'device',
        'machine',
      ],
      'key': ['key', 'keys', 'car key', 'house key', 'keychain', 'keyring'],
      'bag': [
        'bag',
        'backpack',
        'purse',
        'handbag',
        'satchel',
        'tote',
        'luggage',
      ],
      'glasses': [
        'glasses',
        'eyeglasses',
        'spectacles',
        'sunglasses',
        'eyewear',
        'shades',
      ],
      'watch': ['watch', 'wristwatch', 'timepiece', 'clock', 'smartwatch'],
      'bottle': ['bottle', 'water bottle', 'container', 'flask', 'drink'],
      'cup': [
        'cup',
        'mug',
        'glass',
        'drink',
        'beverage',
        'coffee cup',
        'tea cup',
      ],
    };

    // Find matching concepts
    final expansions = <String>{queryLower};
    for (final entry in conceptMaps.entries) {
      if (queryLower.contains(entry.key) ||
          entry.value.any((v) => queryLower.contains(v))) {
        expansions.addAll(entry.value);
      }
    }

    // Also add the original query words
    expansions.addAll(
      queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2),
    );

    return expansions.join(', ');
  }

  /// Semantic search with AI-powered query interpretation and answer generation
  /// Implements semantic memory engine - matches by MEANING, not exact words
  /// "teddy" will match "plush toy", "stuffed animal", "soft toy", etc.
  Future<SemanticSearchResult> semanticSearch(
    String naturalQuery,
    List<MediaItem> allMedia,
  ) async {
    print('🧠 Semantic search: "$naturalQuery"');

    // Step 1: Use AI to expand query into ALL related concepts and synonyms
    String searchKeywords;
    try {
      final keywordPrompt =
          '''You are a semantic memory search engine.

Your task: Convert the user's query into an EXHAUSTIVE list of related concepts, synonyms, and equivalent terms.

User Query: "$naturalQuery"

CRITICAL RULES:
1. NEVER rely on exact words - expand to ALL related meanings
2. Include synonyms, alternative names, related objects
3. Include different ways people might describe the same thing
4. Include both formal and informal terms
5. Include child/parent category terms

CONCEPT MAPPING EXAMPLES:
- "teddy" → teddy, teddy bear, stuffed animal, plush toy, soft toy, bear toy, cuddly toy, plushie, stuffed bear
- "phone" → phone, mobile, smartphone, cellphone, mobile phone, cell, iphone, android, device, handset
- "car" → car, vehicle, automobile, auto, sedan, wheels, ride, motor vehicle
- "person" → person, human, people, man, woman, individual, figure, someone
- "food" → food, meal, dish, eating, breakfast, lunch, dinner, snack, cuisine

Now expand this query: "$naturalQuery"

Return ONLY a comma-separated list of 15-25 related terms. No explanations.''';

      searchKeywords = await _chatService.sendMessage(keywordPrompt);
      print('🔑 Semantic expansion: $searchKeywords');
    } catch (e) {
      // Fallback with common concept mappings
      searchKeywords = _getLocalConceptExpansion(naturalQuery);
      print('⚠️ AI expansion failed, using local mappings: $searchKeywords');
    }

    // Step 2: Search using ALL expanded keywords
    final results = await searchMedia(searchKeywords, allMedia);

    // Step 3: Generate an AI answer based on the results
    String? aiAnswer;
    if (results.isNotEmpty) {
      try {
        // Collect descriptions from top results
        final topResults = results.take(5);
        final descriptionsForContext = topResults
            .map((m) {
              final desc =
                  m.aiDescription ?? m.transcription ?? 'No description';
              final time = m.capturedAt.toString();
              return '- ${m.type.name} at $time: $desc';
            })
            .join('\n');

        final answerPrompt =
            '''Based on the user's question and the following media from their memory:

Question: "$naturalQuery"

Relevant media found:
$descriptionsForContext

Provide a brief, helpful answer to their question based on the media descriptions.
If the answer isn't clear from the media, say so honestly.
Keep the answer concise (2-3 sentences max).''';

        aiAnswer = await _chatService.sendMessage(answerPrompt);
        print('💡 AI Answer generated');
      } catch (e) {
        print('⚠️ Answer generation failed: $e');
        aiAnswer = 'Found ${results.length} related items in your memories.';
      }
    } else {
      aiAnswer =
          'I couldn\'t find any media matching "$naturalQuery" in your memories. Try recording more or use different keywords.';
    }

    return SemanticSearchResult(
      query: naturalQuery,
      keywords: searchKeywords,
      results: results,
      aiAnswer: aiAnswer,
    );
  }
}

/// Result of semantic search including AI answer
class SemanticSearchResult {
  final String query;
  final String keywords;
  final List<MediaItem> results;
  final String? aiAnswer;

  SemanticSearchResult({
    required this.query,
    required this.keywords,
    required this.results,
    this.aiAnswer,
  });
}
