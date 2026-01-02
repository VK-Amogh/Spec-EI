import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Face data returned from detection server
class DetectedFace {
  final int id;
  final int x;
  final int y;
  final int width;
  final int height;
  final double confidence;
  final int eyesDetected;

  DetectedFace({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.confidence = 0.85,
    this.eyesDetected = 0,
  });

  factory DetectedFace.fromJson(Map<String, dynamic> json) {
    return DetectedFace(
      id: json['id'] ?? 0,
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      confidence: (json['confidence'] ?? 0.85).toDouble(),
      eyesDetected: json['eyes_detected'] ?? 0,
    );
  }
}

/// Result from face detection
class FaceDetectionResult {
  final int faceCount;
  final List<DetectedFace> faces;
  final int imageWidth;
  final int imageHeight;

  FaceDetectionResult({
    required this.faceCount,
    required this.faces,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  factory FaceDetectionResult.fromJson(Map<String, dynamic> json) {
    final facesJson = json['faces'] as List<dynamic>? ?? [];
    return FaceDetectionResult(
      faceCount: json['face_count'] ?? 0,
      faces: facesJson.map((f) => DetectedFace.fromJson(f)).toList(),
      imageWidth: json['image_width'] ?? 0,
      imageHeight: json['image_height'] ?? 0,
    );
  }

  static FaceDetectionResult empty() {
    return FaceDetectionResult(faceCount: 0, faces: []);
  }
}

/// Service to communicate with self-hosted face detection server
class FaceDetectionService {
  static const String _baseUrl = 'http://localhost:8001';

  /// Detect faces from image bytes
  Future<FaceDetectionResult> detectFaces(
    Uint8List imageBytes,
    String filename,
  ) async {
    try {
      debugPrint('👤 Sending image for face detection...');

      final uri = Uri.parse('$_baseUrl/detect');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = FaceDetectionResult.fromJson(data);
        debugPrint('✅ Detected ${result.faceCount} face(s)');
        return result;
      } else {
        debugPrint('❌ Face detection failed: ${response.body}');
        return FaceDetectionResult.empty();
      }
    } catch (e) {
      debugPrint('❌ Face detection error: $e');
      return FaceDetectionResult.empty();
    }
  }

  /// Detect faces from base64 image (for real-time detection)
  Future<FaceDetectionResult> detectFacesBase64(String base64Image) async {
    try {
      final uri = Uri.parse('$_baseUrl/detect_base64');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FaceDetectionResult.fromJson(data);
      } else {
        return FaceDetectionResult.empty();
      }
    } catch (e) {
      debugPrint('❌ Face detection error: $e');
      return FaceDetectionResult.empty();
    }
  }

  /// Check if face detection server is running
  Future<bool> isServerRunning() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
