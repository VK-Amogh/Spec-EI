import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/server_config.dart';
import '../core/logger.dart';

/// Server Upload Service for SpecEI
///
/// Implements the server-centric architecture:
/// - Uploads media to server for async analysis
/// - Polls for processing status
/// - Uses new /api endpoints
///
/// Per Spec: "Android acts only as a capture and interaction client"
class ServerUploadService {
  static final ServerUploadService _instance = ServerUploadService._internal();
  factory ServerUploadService() => _instance;
  ServerUploadService._internal();

  // API Key must match security_gateway.py
  static const String _apiKey = 'sk-spec-ei-secure-882193-beta';

  /// Upload media file to server for async analysis
  ///
  /// Returns media_id on success, null on failure.
  /// The server will:
  /// 1. Save raw media to storage
  /// 2. Create database entry
  /// 3. Trigger Whisper/CLIP analysis asynchronously
  Future<String?> uploadMedia({
    required Uint8List fileBytes,
    required String fileName,
    required String mediaType, // 'image', 'video', 'audio'
    required String userId,
  }) async {
    try {
      AppLogger.info('📤 Uploading $mediaType to server: $fileName');

      final uri = Uri.parse(ServerConfig.mediaUploadUrl);

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $_apiKey';

      // Add file
      final mimeType = _getMimeType(fileName, mediaType);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add form fields
      request.fields['user_id'] = userId;
      request.fields['media_type'] = mediaType;

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5), // 5 min timeout for large files
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediaId = data['media_id'] as String;
        AppLogger.info('✅ Upload successful: $mediaId');
        return mediaId;
      } else {
        AppLogger.error(
          '❌ Upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e, stack) {
      AppLogger.error('❌ Upload exception', e, stack);
      return null;
    }
  }

  /// Upload a File object to server
  Future<String?> uploadFile({
    required File file,
    required String mediaType,
    required String userId,
  }) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split(Platform.pathSeparator).last;
    return uploadMedia(
      fileBytes: bytes,
      fileName: fileName,
      mediaType: mediaType,
      userId: userId,
    );
  }

  /// Get processing status for uploaded media
  Future<MediaProcessingStatus?> getMediaStatus(String mediaId) async {
    try {
      final uri = Uri.parse(ServerConfig.mediaStatusUrl(mediaId));

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MediaProcessingStatus.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        AppLogger.error('Status check failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Status check error: $e');
      return null;
    }
  }

  /// Poll for processing completion
  /// Returns true when processing is complete (success or failure)
  Future<bool> waitForProcessing(
    String mediaId, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final status = await getMediaStatus(mediaId);

      if (status == null) {
        AppLogger.warning('Media not found: $mediaId');
        return false;
      }

      if (status.isCompleted || status.isFailed) {
        AppLogger.info('Processing finished: ${status.status}');
        return status.isCompleted;
      }

      await Future.delayed(pollInterval);
    }

    AppLogger.warning('Processing timeout for: $mediaId');
    return false;
  }

  /// Search for media by object/text query
  Future<SearchResult?> searchMedia({
    required String query,
    required String userId,
  }) async {
    try {
      AppLogger.info('🔍 Searching: "$query"');

      final uri = Uri.parse(ServerConfig.searchUrl);

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({'query': query, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SearchResult.fromJson(data);
      } else {
        AppLogger.error('Search failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Search error: $e');
      return null;
    }
  }

  /// Chat query with proof from memory
  Future<ChatQueryResult?> chatQuery({
    required String question,
    required String userId,
  }) async {
    try {
      AppLogger.info('💬 Chat query: "$question"');

      final uri = Uri.parse(ServerConfig.chatQueryUrl);

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({'question': question, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatQueryResult.fromJson(data);
      } else {
        AppLogger.error('Chat query failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Chat query error: $e');
      return null;
    }
  }

  /// Get all detected objects for autocomplete
  Future<List<String>> getDetectedObjects(String userId) async {
    try {
      final uri = Uri.parse(ServerConfig.objectsUrl(userId));

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['objects'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      AppLogger.error('Get objects error: $e');
      return [];
    }
  }

  /// Trigger reanalysis of all user media
  /// Used for manual sync when AI models are updated
  Future<Map<String, dynamic>?> reanalyzeAllMedia(String userId) async {
    try {
      AppLogger.info('🔄 Triggering reanalysis for user: $userId');

      final uri = Uri.parse(ServerConfig.reanalyzeUrl);

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('✅ Reanalyze response: ${data['message']}');
        return data;
      } else {
        AppLogger.error('Reanalyze failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Reanalyze error: $e');
      return null;
    }
  }

  /// Get sync status for a user
  Future<Map<String, dynamic>?> getSyncStatus(String userId) async {
    try {
      final uri = Uri.parse(ServerConfig.syncStatusUrl(userId));

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      AppLogger.error('Sync status error: $e');
      return null;
    }
  }

  String _getMimeType(String fileName, String mediaType) {
    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      // Videos
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        // WebM can be video or audio - check media type
        return mediaType == 'audio' ? 'audio/webm' : 'video/webm';
      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      default:
        // Fallback based on media type
        switch (mediaType) {
          case 'image':
            return 'image/jpeg';
          case 'video':
            return 'video/mp4';
          case 'audio':
            return 'audio/mpeg';
          default:
            return 'application/octet-stream';
        }
    }
  }
}

/// Media processing status from server
class MediaProcessingStatus {
  final String mediaId;
  final String status;
  final String mediaType;
  final String? createdAt;
  final int transcriptCount;
  final int tagCount;

  MediaProcessingStatus({
    required this.mediaId,
    required this.status,
    required this.mediaType,
    this.createdAt,
    this.transcriptCount = 0,
    this.tagCount = 0,
  });

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory MediaProcessingStatus.fromJson(Map<String, dynamic> json) {
    return MediaProcessingStatus(
      mediaId: json['media_id'] as String,
      status: json['status'] as String,
      mediaType: json['media_type'] as String,
      createdAt: json['created_at'] as String?,
      transcriptCount: json['transcript_count'] as int? ?? 0,
      tagCount: json['tag_count'] as int? ?? 0,
    );
  }
}

/// Search result from server
class SearchResult {
  final String query;
  final int resultCount;
  final List<MediaMatch> results;

  SearchResult({
    required this.query,
    required this.resultCount,
    required this.results,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      query: json['query'] as String,
      resultCount: json['result_count'] as int,
      results: (json['results'] as List)
          .map((r) => MediaMatch.fromJson(r))
          .toList(),
    );
  }
}

/// A single media match from search
class MediaMatch {
  final String mediaId;
  final String mediaType;
  final String filePath;
  final String? createdAt;
  final List<TagMatch> tags;
  final List<TranscriptMatch> transcripts;

  MediaMatch({
    required this.mediaId,
    required this.mediaType,
    required this.filePath,
    this.createdAt,
    this.tags = const [],
    this.transcripts = const [],
  });

  factory MediaMatch.fromJson(Map<String, dynamic> json) {
    return MediaMatch(
      mediaId: json['media_id'] as String,
      mediaType: json['media_type'] as String,
      filePath: json['file_path'] as String,
      createdAt: json['created_at'] as String?,
      tags:
          (json['tags'] as List?)?.map((t) => TagMatch.fromJson(t)).toList() ??
          [],
      transcripts:
          (json['transcripts'] as List?)
              ?.map((t) => TranscriptMatch.fromJson(t))
              .toList() ??
          [],
    );
  }
}

/// Tag match with timestamp
class TagMatch {
  final String tagName;
  final double? confidence;
  final double? timestampStart;
  final double? timestampEnd;

  TagMatch({
    required this.tagName,
    this.confidence,
    this.timestampStart,
    this.timestampEnd,
  });

  factory TagMatch.fromJson(Map<String, dynamic> json) {
    return TagMatch(
      tagName: json['tag_name'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestampStart: (json['timestamp_start'] as num?)?.toDouble(),
      timestampEnd: (json['timestamp_end'] as num?)?.toDouble(),
    );
  }
}

/// Transcript match with timestamp
class TranscriptMatch {
  final String text;
  final double? startTime;
  final double? endTime;

  TranscriptMatch({required this.text, this.startTime, this.endTime});

  factory TranscriptMatch.fromJson(Map<String, dynamic> json) {
    return TranscriptMatch(
      text: json['text'] as String,
      startTime: (json['start_time'] as num?)?.toDouble(),
      endTime: (json['end_time'] as num?)?.toDouble(),
    );
  }
}

/// Chat query result with proof
class ChatQueryResult {
  final String question;
  final String answer;
  final bool hasProof;
  final List<ProofReference> proof;

  ChatQueryResult({
    required this.question,
    required this.answer,
    required this.hasProof,
    this.proof = const [],
  });

  factory ChatQueryResult.fromJson(Map<String, dynamic> json) {
    return ChatQueryResult(
      question: json['question'] as String,
      answer: json['answer'] as String,
      hasProof: json['has_proof'] as bool,
      proof:
          (json['proof'] as List?)
              ?.map((p) => ProofReference.fromJson(p))
              .toList() ??
          [],
    );
  }
}

/// A proof reference attached to an answer
class ProofReference {
  final String type; // 'visual' or 'audio'
  final String mediaId;
  final String detail;
  final double? confidence;
  final double? timestamp;

  ProofReference({
    required this.type,
    required this.mediaId,
    required this.detail,
    this.confidence,
    this.timestamp,
  });

  factory ProofReference.fromJson(Map<String, dynamic> json) {
    return ProofReference(
      type: json['type'] as String,
      mediaId: json['media_id'] as String,
      detail: json['detail'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestamp: (json['timestamp'] as num?)?.toDouble(),
    );
  }
}
