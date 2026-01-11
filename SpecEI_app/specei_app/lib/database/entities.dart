import 'package:objectbox/objectbox.dart';

/// Layer 2: Event Memory (Timeline Core)
@Entity()
class MemoryEvent {
  @Id()
  int id = 0;

  @Property(type: PropertyType.date)
  DateTime startTime;

  @Property(type: PropertyType.date)
  DateTime endTime;

  String filePath;
  String modality; // 'video', 'audio', 'image', 'text'
  String sessionId;

  // Vector embedding for the *entire* event (summary)
  @HnswIndex(dimensions: 4096)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  // E2EE Metadata
  bool isEncrypted;

  @Property(type: PropertyType.byteVector)
  List<int>? encryptionNonce;

  @Property(type: PropertyType.byteVector)
  List<int>? wrappedKey;

  @Property(type: PropertyType.byteVector)
  List<int>? ephemeralPublicKey;

  MemoryEvent({
    this.id = 0,
    required this.startTime,
    required this.endTime,
    required this.filePath,
    required this.modality,
    required this.sessionId,
    this.embedding,
    this.isEncrypted = false,
    this.encryptionNonce,
    this.wrappedKey,
    this.ephemeralPublicKey,
  });
}

/// Layer 3: Signal Memory (Transcripts)
@Entity()
class TranscriptSegment {
  @Id()
  int id = 0;

  // Link to Event
  final event = ToOne<MemoryEvent>();

  String text;
  int startOffsetMs;
  int endOffsetMs;

  @HnswIndex(dimensions: 4096)
  @Property(type: PropertyType.floatVector)
  List<double>? vector;

  TranscriptSegment({
    this.id = 0,
    required this.text,
    required this.startOffsetMs,
    required this.endOffsetMs,
    this.vector,
  });
}

/// Layer 3: Signal Memory (Visual Frames)
@Entity()
class VisualFrame {
  @Id()
  int id = 0;

  final event = ToOne<MemoryEvent>();

  @Property(type: PropertyType.date)
  DateTime timestamp;

  @HnswIndex(dimensions: 4096)
  @Property(type: PropertyType.floatVector)
  List<double>? vector;

  // JSON list of detected objects (e.g. ["keys", "wallet"])
  String detectedObjectsJson;

  VisualFrame({
    this.id = 0,
    required this.timestamp,
    this.vector,
    this.detectedObjectsJson = '[]',
  });
}

/// Layer 4: Object Memory (State Machine)
@Entity()
class ObjectState {
  @Id()
  int id = 0;

  @Index()
  String label; // 'keys', 'notebook'

  int lastConfirmedEventId;

  @Property(type: PropertyType.date)
  DateTime lastConfirmedTime;

  String confirmationType; // 'visual', 'audio', 'both'
  double confidenceScore;

  ObjectState({
    this.id = 0,
    required this.label,
    required this.lastConfirmedEventId,
    required this.lastConfirmedTime,
    required this.confirmationType,
    required this.confidenceScore,
  });
}
