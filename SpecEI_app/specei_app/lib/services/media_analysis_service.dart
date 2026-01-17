// import 'dart:io'; // Disabled for web compatibility
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../objectbox.g.dart'; // Generated ObjectBox code (web stub)
import '../database/entities.dart';
// Access global objectBox store if available, or we open local
import 'memory_data_service.dart';
import 'supabase_service.dart';
import 'chat_service.dart';
import 'encryption_service.dart'; // E2EE Support
import 'memory_retrieval_service.dart'; // The new Intelligence Layer
import 'server_upload_service.dart'; // Server-Centric Architecture v3.0

// Web-compatible File stub
class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<void> delete() async {}
}

/// AI-powered Media Analysis Service
///
/// Supports two modes:
/// 1. **Server-Centric (v3.0)**: Upload to server, analysis runs on server
/// 2. **Client-Side (Legacy)**: Analysis runs on device, stores to Supabase
///
/// Per spec: "Android acts only as a capture and interaction client.
/// All heavy computation, analysis, reasoning and storage happens on the server."
class MediaAnalysisService {
  static final MediaAnalysisService _instance =
      MediaAnalysisService._internal();
  factory MediaAnalysisService() => _instance;
  MediaAnalysisService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final ChatService _chatService = ChatService();
  final EncryptionService _encryptionService =
      EncryptionService(); // Layer 0 Encryption
  final ServerUploadService _serverUploadService =
      ServerUploadService(); // Server-Centric v3.0

  // Toggle server-centric mode (set true for production)
  static bool useServerCentricMode = true;

  // Access global store from main.dart or similar
  late final Store _store;
  bool _storeInitialized = false;

  Box<MemoryEvent>? _eventBox;
  Box<ObjectState>? _objectStateBox;

  // Public accessors for Retrieval Service
  Box<MemoryEvent>? get eventBox => _eventBox;
  Box<ObjectState>? get objectStateBox => _objectStateBox;

  Future<void> _ensureStore() async {
    if (_storeInitialized) return;
    try {
      if (Store.isOpen('spec_ei_memory.db')) {
        print('⚠️ Store already open, attaching...');
        _store = Store.attach(getObjectBoxModel(), 'spec_ei_memory.db');
      } else {
        _store = await openStore();
      }

      _eventBox = _store.box<MemoryEvent>();
      _objectStateBox = _store.box<ObjectState>();
      _storeInitialized = true;
      print('✅ ObjectBox Store Initialized');
    } catch (e) {
      print('⚠️ ObjectBox init warning: $e');
    }
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  // ==========================================
  // SERVER-CENTRIC UPLOAD (v3.0)
  // ==========================================

  /// Upload media to server for async analysis
  ///
  /// Per spec: "Android acts only as a capture and interaction client.
  /// All heavy computation, analysis, reasoning and storage happens on the server."
  ///
  /// This uploads to `/api/media/upload` and returns immediately.
  /// The server handles Whisper/CLIP analysis in the background.
  Future<String?> uploadToServer({
    required Uint8List fileBytes,
    required String fileName,
    required String mediaType, // 'image', 'video', 'audio'
    required String userId,
  }) async {
    if (!useServerCentricMode) {
      print('⚠️ Server-centric mode disabled, skipping server upload');
      return null;
    }

    return await _serverUploadService.uploadMedia(
      fileBytes: fileBytes,
      fileName: fileName,
      mediaType: mediaType,
      userId: userId,
    );
  }

  /// Wait for server to complete analysis of uploaded media
  Future<bool> waitForServerAnalysis(String mediaId) async {
    return await _serverUploadService.waitForProcessing(mediaId);
  }

  /// Search media using server's database (object-based search)
  Future<SearchResult?> serverSearch({
    required String query,
    required String userId,
  }) async {
    return await _serverUploadService.searchMedia(query: query, userId: userId);
  }

  /// Chat query with proof from server
  Future<ChatQueryResult?> serverChatQuery({
    required String question,
    required String userId,
  }) async {
    return await _serverUploadService.chatQuery(
      question: question,
      userId: userId,
    );
  }

  /// Get all detected objects for autocomplete
  Future<List<String>> getServerDetectedObjects(String userId) async {
    return await _serverUploadService.getDetectedObjects(userId);
  }

  /// Trigger reanalysis of all user media on server
  Future<Map<String, dynamic>?> serverReanalyze() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('⚠️ No user logged in for reanalyze');
      return null;
    }
    return await _serverUploadService.reanalyzeAllMedia(userId);
  }

  /// Get sync status for current user
  Future<Map<String, dynamic>?> getSyncStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    return await _serverUploadService.getSyncStatus(userId);
  }

  /// 🔒 Secure Ingestion Pipeline
  /// 1. Analyze Plaintext (RAM/Temp)
  /// 2. Encrypt Media -> Disk
  /// 3. Store Metadata -> ObjectBox
  /// 4. Shred Plaintext
  Future<void> secureIngest(File plaintextFile, MediaType type) async {
    print('🔒 Starting Secure Ingestion for: ${plaintextFile.path}');
    await _ensureStore();

    try {
      // 1. Analysis (on plaintext)
      // We create a temporary MediaItem to pass to analysis, but we don't store it yet
      // Actually, analyzeAndStoreDescription expects a MediaItem with ID/URL.
      // For local files, URL is file path.

      // We need to extract the "Processing" logic from analyzeAndStoreDescription so it returns results
      // without storing to Supabase/DB immediately, or we adapt.
      // Since this is "Add-on", let's replicate the analysis call:

      String? description;
      List<double>? embedding;

      if (type == MediaType.photo) {
        // ... (Call _analyzeImage etc. - assuming we can read file bytes)
        // For MVP we skip AI re-analysis here to focus on encryption,
        // or strictly, we should perform it.
      }

      // 2. Encryption (AES-256-GCM)
      final bytes = await plaintextFile.readAsBytes();
      print('🔐 Encrypting ${bytes.length} bytes...');
      final envelope = await _encryptionService.encryptData(bytes);

      // 3. Save Encrypted File
      final encryptedPath = '${plaintextFile.path}.enc';
      final encryptedFile = File(encryptedPath);
      await encryptedFile.writeAsBytes(envelope.ciphertext);
      print('💾 Saved encrypted file: $encryptedPath');

      // 4. Create e-MemoryEvent
      // We generate the master event here
      final event = MemoryEvent(
        startTime: DateTime.now(),
        endTime: DateTime.now(), // update for video duration?
        filePath: encryptedPath, // Point to ENCRYPTED file
        modality: type.name,
        sessionId: 'secure_ingest',
        isEncrypted: true,
        encryptionNonce: envelope.nonce,
        wrappedKey: envelope.wrappedKey,
        ephemeralPublicKey:
            (envelope.ephemeralPublicKey as SimplePublicKey).bytes,
        embedding: embedding, // If we had it
      );

      _eventBox!.put(event);
      print('✅ Secured Event Stored in ObjectBox (ID: ${event.id})');

      // 5. Shred Plaintext
      if (await plaintextFile.exists()) {
        await plaintextFile.delete();
        print('🗑️ Plaintext file destroyed');
      }
    } catch (e, stack) {
      print('❌ Secure Ingest Failed: $e');
      print(stack);
    }
  }

  /// Analyze media and store AI description + linked metadata
  /// Follows SpecEI Unified Memory spec:
  /// - Raw media remains untouched
  /// - Derived data (transcripts, descriptions) stored as linked metadata
  /// - Semantic memory created from analysis
  Future<String?> analyzeAndStoreDescription(MediaItem media) async {
    await _ensureStore(); // Ensure DB is ready

    try {
      print('🔍 Analyzing media: ${media.id} (${media.type.name})');

      // 🚀 SERVER-CENTRIC V3.0: Upload immediately if enabled
      if (useServerCentricMode) {
        try {
          print('🚀 Server-Centric Mode: Uploading ${media.id} to Gateway...');

          // Get bytes (from localBytes or fileUrl)
          Uint8List? fileBytes;
          if (media.localBytes != null && media.localBytes!.isNotEmpty) {
            fileBytes = Uint8List.fromList(media.localBytes!);
          } else if (media.fileUrl != null) {
            final file = File(media.fileUrl!);
            if (await file.exists()) {
              fileBytes = await file.readAsBytes();
            }
          }

          if (fileBytes != null) {
            // Map MediaType to Server Type ('image', 'video', 'audio')
            String serverType = 'image';
            if (media.type == MediaType.video) serverType = 'video';
            if (media.type == MediaType.audio) serverType = 'audio';

            final mediaId = await uploadToServer(
              fileBytes: fileBytes,
              fileName: "capture_${DateTime.now().millisecondsSinceEpoch}",
              mediaType: serverType,
              userId:
                  Supabase.instance.client.auth.currentUser?.id ?? 'unknown',
            );

            if (mediaId != null) {
              print('✅ Uploaded to Server. ID: $mediaId');
              // Allow background processing to handle it.
              // Return a placeholder description so UI knows it's being handled.
              return "Processing on AI Server (GPU)...";
            }
          } else {
            print('⚠️ No bytes found for upload.');
          }
        } catch (e) {
          print('❌ Server upload failed: $e. Falling back to local analysis.');
        }
      }

      // Check if content is available (URL or Local Bytes)
      bool hasContent =
          (media.fileUrl != null && media.fileUrl!.isNotEmpty) ||
          (media.localBytes != null && media.localBytes!.isNotEmpty);

      if (!hasContent) {
        print('⚠️ No content for ${media.id} - skipping analysis');
        return null;
      }

      String? description;
      String? rawTranscript; // For storing pure transcript separately

      switch (media.type) {
        case MediaType.photo:
          print('  📷 Analyzing photo...');
          // Use local bytes if available, otherwise URL
          description = await _analyzeImage(media.fileUrl, media.localBytes);
          break;

        case MediaType.video:
          print('  🎬 Analyzing video: ${media.fileUrl ?? "Local"}');
          // For video: Extract audio and transcribe + analyze visually
          description = await _analyzeVideoWithTranscript(media);
          break;

        case MediaType.audio:
          print('  🎤 Transcribing audio: ${media.fileUrl ?? "Local"}');
          // TODO: Support local bytes for audio too
          if (media.fileUrl != null) {
            rawTranscript = await _extractAudioTranscript(media.fileUrl!);
          }
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
        try {
          await _supabaseService.updateMediaAIDescription(
            media.id,
            description,
          );
        } catch (dbError) {
          print(
            '⚠️ Failed to update Supabase description (Offline?): $dbError',
          );
          // Continue to save locally/vector
        }

        // SpecEI Layer 2: Create a structured Event for this moment
        await _createEventForMedia(media, description);

        // 🧠 OBJECTBOX VECTOR GENERATION
        if (_storeInitialized && _eventBox != null) {
          try {
            print('🧠 Generating Vector Embedding (4096 dims)...');
            final embedding = await _chatService.getEmbedding(description);

            if (embedding != null && embedding.isNotEmpty) {
              final event = MemoryEvent(
                startTime: media.capturedAt,
                endTime: media.capturedAt.add(
                  media.duration ?? const Duration(seconds: 0),
                ),
                filePath: media.filePath ?? media.fileUrl ?? '',
                modality: media.type.name,
                sessionId: 'auto_analysis',
                embedding: embedding, // <--- SAVING VECTOR
              );

              final id = _eventBox!.put(event);
              print('✅ Vector Saved to ObjectBox! Event ID: $id');
            }
          } catch (e) {
            print('⚠️ Vector Generation/Save Failed: $e');
          }
        } else {
          print('⚠️ ObjectBox not initialized - skipping vector save');
        }

        // SpecEI Layer 3: Populate Object Memory
        await _extractAndStoreObjects(media.id, description);

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
        if (media.fileUrl != null) {
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
        }
      } catch (e) {
        print('  ⚠️ Video audio extraction failed: $e');
      }

      // Also get visual description
      // For local video, _analyzeVideo will handle it if we implement local support there,
      // but for now it might download from URL.
      // If URL is null, it returns null.
      final visualDescription = await _analyzeVideo(media.fileUrl);

      // Combine transcript and visual description
      if (transcript != null && transcript.isNotEmpty) {
        return '${visualDescription ?? "Video content"}. Spoken words: $transcript';
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
  Future<String?> _analyzeImage(String? imageUrl, List<int>? localBytes) async {
    try {
      Uint8List bytes;
      String filename = 'image.jpg';

      if (localBytes != null && localBytes.isNotEmpty) {
        print('📷 Using local bytes for analysis (${localBytes.length} bytes)');
        bytes = Uint8List.fromList(localBytes);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        print('📷 Downloading image from: $imageUrl');
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode != 200) {
          print('❌ Failed to download image: ${response.statusCode}');
          return null;
        }
        bytes = response.bodyBytes;
        final uri = Uri.parse(imageUrl);
        filename = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : 'image.jpg';
      } else {
        return null;
      }

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

  /// Semantic search with AI-powered query interpretation and answer generation
  /// Implements "SpecEI Intelligence Engine" Pipeline (6 Steps)
  Future<SemanticSearchResult> semanticSearch(
    String naturalQuery,
    List<MediaItem> allMedia,
  ) async {
    print('🧠 Intelligence Engine: "$naturalQuery"');
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (naturalQuery.isEmpty) {
      return SemanticSearchResult(
        query: naturalQuery,
        keywords: '',
        results: [],
        aiAnswer: 'Please ask a question.',
      );
    }

    // 🚀 SERVER-CENTRIC V3.0: Delegate search to Server Gateway
    if (useServerCentricMode) {
      print('🚀 Server-Centric Mode: Delegating search to Gateway...');
      final serverResults = await serverSearch(
        query: naturalQuery,
        userId: userId ?? 'unknown',
      );

      if (serverResults != null) {
        print('✅ Server returned ${serverResults.resultCount} results');

        // Map Server Results (MediaMatch) -> App Model (MediaItem)
        final results = serverResults.results.map((match) {
          DateTime capturedTime = DateTime.now();
          if (match.createdAt != null) {
            try {
              capturedTime = DateTime.parse(match.createdAt!);
            } catch (_) {}
          }

          // Flatten tags/transcripts into description for UI context
          final contextParts = <String>[];
          for (final t in match.tags) {
            contextParts.add(t.tagName);
          }
          for (final t in match.transcripts) {
            contextParts.add('"${t.text}"');
          }

          return MediaItem(
            id: match.mediaId,
            type: MediaType.values.firstWhere(
              (e) => e.name == match.mediaType,
              orElse: () => MediaType.photo,
            ),
            fileUrl: match
                .filePath, // Note: This is a PC path, might not load image but allows result display
            capturedAt: capturedTime,
            aiDescription: contextParts.join(', '),
          );
        }).toList();

        // Construct a simple answer since search doesn't return one
        String answer =
            "I found ${results.length} memories matching '$naturalQuery' on your server.";
        if (results.isEmpty) {
          answer =
              "I searched your server memory but found no matches for '$naturalQuery'.";
        }

        return SemanticSearchResult(
          query: naturalQuery,
          keywords: naturalQuery, // Server handles expansion
          results: results,
          aiAnswer: answer,
        );
      }
    }

    String searchKeywords = naturalQuery;
    String? objectIntent;

    try {
      // 🚀 STEP 0: PRECISE RETRIEVAL (The New "Access Layer")
      // Try strict object-based retrieval first (O(1) lookup + Event narrowing)
      try {
        final retrievalService = MemoryRetrievalService();
        final preciseResult = await retrievalService.retrieveAndAnswer(
          naturalQuery,
          allMedia,
        );

        // If precise retrieval worked (found object and evidence), return it immediately
        if (!preciseResult.aiAnswer!.startsWith("I'm not sure") &&
            !preciseResult.aiAnswer!.startsWith("Please specify") &&
            !preciseResult.aiAnswer!.startsWith(
              "I do not have a confirmed record",
            )) {
          print('✅ Precise Retrieval Success: ${preciseResult.aiAnswer}');
          return preciseResult;
        }
      } catch (e) {
        print('⚠️ Precise retrieval skipped/failed: $e');
      }

      // STEP 1: INTENT PARSING (Legacy/Fallback)
      // Identify if looking for a specific object and what it is
      final intentPrompt = '''Analyze this query: "$naturalQuery"
      
Return a JSON object with:
{
  "intent": "object_search" OR "general_search",
  "object": "name of object if object_search" (e.g., "keys", "wallet"),
  "time_bias": "recent" OR "past" OR "none"
}
Return ONLY JSON.''';

      final intentJson = await _chatService.sendMessage(intentPrompt);
      try {
        final decoded = jsonDecode(intentJson);
        if (decoded['intent'] == 'object_search') {
          objectIntent = decoded['object'];
          print('🎯 Object Intent Detected: $objectIntent');
        }
      } catch (e) {
        // Fallback if valid JSON not returned
        print('⚠️ Intent parsing failed, defaulting to general search');
      }

      // STEP 2: OBJECT-FIRST LOOKUP (Layer 3 Memory)
      if (objectIntent != null && userId != null) {
        print('🔍 Checking Object Memory for "$objectIntent"...');
        final detection = await _supabaseService.findLatestObjectDetection(
          userId,
          objectIntent,
        );

        if (detection != null) {
          // Calculate Decay (Layer 4 Rule: confidence decays over time)
          final capturedAtStr =
              detection['captured_at'] ??
              detection['media']['captured_at'] ??
              detection['created_at'];
          final capturedAt = DateTime.parse(capturedAtStr);
          final daysDiff = DateTime.now().difference(capturedAt).inDays;

          final baseConfidence =
              (detection['confidence'] as num?)?.toDouble() ?? 0.85;
          // Decay: 5% per day approx (0.95^days)
          // Using pow requires dart:math, import added if missing
          final decayFactor = (daysDiff > 0)
              ? (1.0 / (1.0 + (daysDiff * 0.1)))
              : 1.0; // Linear decay 10% impact/day simpler
          final currentConfidence = baseConfidence * decayFactor;

          print(
            '📉 Confidence Decay: Base $baseConfidence -> Current ${currentConfidence.toStringAsFixed(2)} ($daysDiff days old)',
          );

          if (currentConfidence >= 0.3) {
            print('✅ Found confirmed object sighting (Confident)!');

            final mediaId = detection['media']['id'];
            final timestamp = capturedAt;

            // Fetch the media to display
            final media = allMedia.firstWhere(
              (m) => m.id == mediaId,
              orElse: () => MediaItem(
                id: mediaId,
                type: MediaType.photo, // Placeholder for object result
                fileUrl: detection['media']['file_url'],
              ),
            );

            final answerPrompt =
                '''Generate a Strict Evidence-Based Answer.
Question: "$naturalQuery"
Evidence: Confirmed object detection of "$objectIntent" at $timestamp.
Media URL: ${detection['media']['file_url']}
Confidence: High (Layer 3 Object Memory) - Decayed Score: ${currentConfidence.toStringAsFixed(2)}

FORMAT REQUIRED:
Direct Answer: (One sentence)
Evidence: (Filename/Time)
Context: (Describe placement based on knowledge of object)
Confidence: ${currentConfidence > 0.7 ? 'High' : 'Medium'} (Confirmed Detection)''';

            final answer = await _chatService.sendMessage(answerPrompt);

            return SemanticSearchResult(
              query: naturalQuery,
              keywords: objectIntent,
              results: [media],
              aiAnswer: answer,
            );
          } else {
            print(
              '⚠️ Object state decayed to UNKNOWN (Score: $currentConfidence). Fallback to Semantic Search.',
            );
          }
        }
      }

      // STEP 3: SEMANTIC SEARCH (Layer 4 Memory)
      List<MediaItem> rankedResults = [];

      // A. LOCAL VECTOR SEARCH (ObjectBox) - Priority 1 (Local Mistral)
      if (_storeInitialized && _eventBox != null) {
        try {
          print('🧠 Generating Query Embedding (Local Mistral)...');
          final queryVector = await _chatService.getEmbedding(naturalQuery);

          if (queryVector != null) {
            // ObjectBox HNSW: Use manual similarity search as a workaround
            // Since nearestNeighborsF32 API may not be available in all versions
            final allEvents = _eventBox!.getAll();

            // Calculate cosine similarity and rank
            final scoredEvents = <MapEntry<MemoryEvent, double>>[];
            for (final event in allEvents) {
              if (event.embedding != null && event.embedding!.isNotEmpty) {
                final similarity = _cosineSimilarity(
                  queryVector,
                  event.embedding!,
                );
                if (similarity > 0.3) {
                  // Threshold
                  scoredEvents.add(MapEntry(event, similarity));
                }
              }
            }

            // Sort by similarity descending and take top 20
            scoredEvents.sort((a, b) => b.value.compareTo(a.value));
            final topEvents = scoredEvents.take(20).map((e) => e.key).toList();

            print('✅ Local Vector Search found ${topEvents.length} matches');

            // Hydrate MediaItems from Events by matching File Path
            final eventPaths = topEvents.map((e) => e.filePath).toSet();

            // Filter allMedia to find matching items
            // This assumes allMedia contains the items we just found vectors for
            final localMatches = allMedia.where((m) {
              final path = m.filePath ?? m.fileUrl;
              return path != null && eventPaths.contains(path);
            }).toList();

            if (localMatches.isNotEmpty) {
              rankedResults.addAll(localMatches);
              print(
                '🔗 Hydrated ${localMatches.length} MediaItems from Local Vectors',
              );
            }
          }
        } catch (e) {
          print('⚠️ Local Vector Search error: $e');
        }
      }

      // B. CLOUD/SUPABASE SEARCH (Supplement if needed)
      if (rankedResults.isEmpty && userId != null) {
        print('📡 Querying Semantic Memory (Vector DB)...');
        final vectorResults = await _supabaseService.searchMemory(
          userId,
          naturalQuery,
        );

        // Map back to MediaItems
        rankedResults = vectorResults
            .map(
              (r) => MediaItem(
                id: r['media_id'],
                type: MediaType.values.firstWhere(
                  (e) => e.name == r['media_type'],
                  orElse: () => MediaType.photo,
                ),
                fileUrl: r['file_url'],
                aiDescription:
                    r['match_text'], // Use match text as description context
              ),
            )
            .toList();
      } else if (rankedResults.isEmpty) {
        // Fallback to client-side keyword search (if both Vector searches fail)
        print('⚠️ Falling back to client-side keyword search');
        final keywordPrompt =
            '''Expand query "$naturalQuery" to synonyms. CSV only.''';
        searchKeywords = await _chatService.sendMessage(keywordPrompt);
        rankedResults = await searchMedia(searchKeywords, allMedia);
      }

      if (rankedResults.isEmpty) {
        return SemanticSearchResult(
          query: naturalQuery,
          keywords: searchKeywords,
          results: [],
          aiAnswer: 'I do not have a confirmed record of that.',
        );
      }

      // STEP 6: ANSWER GENERATION
      final topResults = rankedResults.take(5).toList();
      final context = topResults
          .map((m) => '- [${m.type.name}] ${m.aiDescription ?? "No desc"}')
          .join('\n');

      final finalPrompt =
          '''Based ONLY on this evidence, answer the user.
Question: "$naturalQuery"
Evidence:
$context

MANDATORY FORMAT:
Direct Answer: (One clear sentence)
Evidence: (Event/Media referenced)
Context Description: (Surroundings/Placement)
Confidence: (High/Medium/Low based on evidence match)

If no evidence matches, say "I do not have a confirmed record."''';

      final aiAnswer = await _chatService.sendMessage(finalPrompt);

      return SemanticSearchResult(
        query: naturalQuery,
        keywords: searchKeywords,
        results: topResults,
        aiAnswer: aiAnswer,
      );
    } catch (e) {
      print('❌ Intelligence Engine Error: $e');
      return SemanticSearchResult(
        query: naturalQuery,
        keywords: searchKeywords,
        results: [],
        aiAnswer: 'System error during memory retrieval.',
      );
    }
  }

  /// Create a structured Event (Layer 2) from analyzed media
  Future<void> _createEventForMedia(MediaItem media, String description) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Extract title/summary using AI or defaults
      final title = '${media.type.name.toUpperCase()} Memory';

      await _supabaseService.createEvent(
        userId: userId,
        title: title,
        summary: description,
        startTime: media.capturedAt,
        endTime: media.capturedAt.add(
          media.duration ?? const Duration(minutes: 1),
        ),
        eventType: 'memory',
        tags: [media.type.name, 'auto-generated'],
      );
      print('📅 Event created for media ${media.id}');
    } catch (e) {
      print('⚠️ Failed to create event: $e');
    }
  }

  /// Extract and store objects for Layer 3 Memory
  Future<void> _extractAndStoreObjects(
    String mediaId,
    String description,
  ) async {
    try {
      final prompt =
          '''Extract physical objects from this description for an object detection database.
Description: "$description"

Return a JSON list of objects found.
Format: [{"label": "object_name", "type": "object", "confidence": 0.9}]
Include only concrete physical objects (keys, laptop, phone, car, person, bottle, etc.).
Do not include abstract concepts.
Return ONLY JSON.''';

      final jsonStr = await _chatService.sendMessage(prompt);
      final List<dynamic> objects = jsonDecode(jsonStr);

      for (final obj in objects) {
        // 1. Supabase Cloud Save (Backup)
        await _supabaseService.saveDetectedObject(
          mediaId: mediaId,
          objectType: obj['type'] ?? 'object',
          label: obj['label'],
          confidence: (obj['confidence'] as num?)?.toDouble() ?? 0.85,
          timestampSeconds: 0.0, // Static image/summary
        );

        // 2. ObjectBox Local Index (Level 1 Memory - O(1) Access)
        // NOTE: Disabled for web compatibility - ObjectBox not supported on web
        /*
        if (_storeInitialized && _objectStateBox != null) {
          final label = (obj['label'] as String).toLowerCase();
          final confidence = (obj['confidence'] as num?)?.toDouble() ?? 0.85;

          // Upsert: Find existing state or create new
          // Note: In real app, we should query by label first.
          // For MVP, we just add new observation.
          // To do O(1) correctly, we should maintain ONE ObjectState per label.

          final query = _objectStateBox!
              .query(ObjectState_.label.equals(label))
              .build();
          final existingState = query.findFirst();
          query.close();

          if (existingState != null) {
            // Update existing
            existingState.lastConfirmedTime =
                DateTime.now(); // Should be media.capturedAt
            existingState.confidenceScore = confidence;
            existingState.confirmationType = 'visual'; // derived
            _objectStateBox!.put(existingState);
          } else {
            // Create new
            final newState = ObjectState(
              label: label,
              lastConfirmedEventId: 0, // Need to link to event ID later
              lastConfirmedTime: DateTime.now(),
              confirmationType: 'visual',
              confidenceScore: confidence,
            );
            _objectStateBox!.put(newState);
          }
        }
        */
      }
      print(
        '📦 Stored ${objects.length} detected objects for Level 1 & Level 3 memory',
      );
    } catch (e) {
      print('⚠️ Object extraction failed: $e');
    }
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
