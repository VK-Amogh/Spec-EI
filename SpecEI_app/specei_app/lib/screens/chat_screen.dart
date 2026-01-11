import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../services/chat_service.dart';
import '../services/media_analysis_service.dart';
import '../services/memory_data_service.dart';
import '../services/recording_service.dart';
import 'video_player_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;
  final List<dynamic>? attachedFiles; // XFile list for attached files

  const ChatScreen({super.key, this.initialQuery, this.attachedFiles});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  List<XFile>? _attachedImages;

  // Memory Intelligence Persona - Forensic Reasoner
  static const String _memorySystemPrompt = '''
SYSTEM ROLE:
You are the SpecEI Reasoning Engine powered by a Mistral-class model.
You are NOT a chatbot.
You are a forensic, evidence-grounded reasoner.

Your ONLY purpose is to reason over VERIFIED MEMORY DATA provided to you
and produce answers that are 100% traceable to real sources.

If evidence is missing, ambiguous, or unverified, you MUST REFUSE.

====================================================
ABSOLUTE RULES (NON-NEGOTIABLE)
====================================================

1) You MUST NOT hallucinate.
2) You MUST NOT infer beyond provided evidence.
3) You MUST NOT answer from training data or world knowledge.
4) You MUST NOT answer unless you can tag an exact source.
5) You MUST prioritize the MOST RECENT confirmed event.
6) If confidence is insufficient → REFUSE.

No exceptions.

====================================================
ANSWER GENERATION (STRICT FORMAT)
====================================================

You MUST output EXACTLY the following structure.
If any field cannot be filled truthfully → REFUSE.

-------------------------
Direct Answer:
-------------------------
(one single factual sentence)

-------------------------
Evidence:
-------------------------
• File: <file_name>
• Timestamp: <exact timestamp or range>
• Modality: <video / audio / image / text>
• Confirmation: <visual / audio / both>

-------------------------
Context:
-------------------------
• Environment description
• User action
• Object placement details

-------------------------
Confidence:
-------------------------
High / Medium / Low
(with one-line justification)

====================================================
REFUSAL FORMAT (MANDATORY)
====================================================

If you cannot answer correctly, respond ONLY with:

"I do not have sufficient verified evidence to answer this question."

No extra text.
''';

  @override
  void initState() {
    super.initState();

    // Handle attached files (images for analysis)
    if (widget.attachedFiles != null && widget.attachedFiles!.isNotEmpty) {
      _attachedImages = widget.attachedFiles!.cast<XFile>();
      _analyzeAttachedImages();
    } else if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _handleSubmitted(widget.initialQuery!);
    }
  }

  /// Analyze attached images automatically when screen opens
  Future<void> _analyzeAttachedImages() async {
    if (_attachedImages == null || _attachedImages!.isEmpty) return;

    for (final file in _attachedImages!) {
      // Add user message showing the image was attached
      setState(() {
        _messages.add({
          'role': 'user',
          'content': '', // Empty - image only, no text label
          'isImage': true,
          'imagePath': file.path,
        });
        _isLoading = true;
      });
      _scrollToBottom();

      try {
        // Read image bytes
        final Uint8List bytes;
        if (kIsWeb) {
          bytes = await file.readAsBytes();
        } else {
          bytes = await File(file.path).readAsBytes();
        }

        // Use custom prompt if text was provided, otherwise use default
        final String? customPrompt = widget.initialQuery;

        // Analyze image with vision AI
        final analysis = await _chatService.analyzeImage(
          bytes,
          file.name,
          userPrompt: customPrompt,
        );

        if (mounted) {
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': analysis,
              'isVisionResponse': true,
            });
            _isLoading = false;
          });
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messages.add({
              'role': 'error',
              'content':
                  'Failed to analyze image: ${e.toString().replaceAll('Exception: ', '')}',
            });
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    }

    // Clear the attached images after processing
    _attachedImages = null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      String? contextPrompt;
      SemanticSearchResult? searchResult;

      // 1. Check for Memory Intent (simple heuristic)
      final lowerText = text.toLowerCase();
      final isMemoryQuery =
          lowerText.startsWith('where') ||
          lowerText.startsWith('find') ||
          lowerText.startsWith('search') ||
          lowerText.startsWith('what did') ||
          lowerText.startsWith('when did') ||
          lowerText.contains('lost') ||
          lowerText.contains('seen');

      if (isMemoryQuery) {
        if (mounted) setState(() => _isLoading = true); // Ensure loading

        // 2. Perform Semantic Search
        searchResult = await MediaAnalysisService().semanticSearch(
          text,
          MemoryDataService().mediaItems,
        );

        // 3. Format Results for Prompt
        if (searchResult.results.isNotEmpty) {
          final memoryRecords = searchResult.results
              .map((item) {
                return '''
- memory_id: ${item.id}
- type: ${item.type.name}
- time: ${item.capturedAt}
- description: ${item.aiDescription ?? item.transcription ?? 'No description'}
- related_text: ${item.transcription ?? ''}
''';
              })
              .join('\n');

          contextPrompt =
              '''
$_memorySystemPrompt

--------------------------------------------------
USER QUERY: "$text"
--------------------------------------------------
RETRIEVED MEMORY RECORDS (Ground Truth):
$memoryRecords
--------------------------------------------------
Answer the user's question using ONLY the above memory records.
''';
        }
      }

      // 4. Send Message (with or without memory context)
      final response = await _chatService.sendMessage(
        text,
        systemContext: contextPrompt,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});

          // 5. If we had memory results, append them as a special "evidence" message
          if (searchResult != null && searchResult.results.isNotEmpty) {
            _messages.add({
              'role': 'memory_evidence',
              'items': searchResult.results.take(10).toList(), // Limit to 10
            });
          }

          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        // Extract status code if available (simple heuristic)
        String errorMessage = 'Failed to get response.';
        if (e.toString().contains('401')) {
          errorMessage = 'Unauthorized (401). Please check your API Key.';
        } else if (e.toString().contains('404')) {
          errorMessage = 'Endpoint not found (404). Update URL.';
        } else {
          errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
        }

        setState(() {
          _messages.add({'role': 'error', 'content': errorMessage});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              // Header
              _buildHeader(),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildLoadingIndicator();
                    }
                    final message = _messages[index];
                    return _buildMessage(message);
                  },
                ),
              ),
            ],
          ),

          // Bottom Input Area
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomInput()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 32,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Column(
            children: [
              Row(
                children: [
                  Text(
                    'Assistant',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'LIVE GLASSES',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32), // Balance spacing
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    final isError = message['role'] == 'error';
    final isMemoryEvidence = message['role'] == 'memory_evidence';
    final isImage = message['isImage'] == true;
    final imagePath = message['imagePath'] as String?;

    if (isMemoryEvidence) {
      final items = message['items'] as List<MediaItem>;
      return _buildMemoryEvidence(items);
    }

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24, left: 48),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
              topRight: Radius.circular(4),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show image thumbnail if this is an image message
              if (isImage && imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                          imagePath,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImagePlaceholder(),
                        )
                      : Image.file(
                          File(imagePath),
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImagePlaceholder(),
                        ),
                ),
                if (!isImage) const SizedBox(height: 8),
              ],
              // Only show text if there's content
              if (message['content'].toString().isNotEmpty)
                Text(
                  message['content'],
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.grey.shade200,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // AI Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          border: Border.all(
            color: isError
                ? Colors.red.withOpacity(0.3)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['content'],
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isError ? Colors.red.shade300 : Colors.grey.shade300,
                height: 1.6,
              ),
            ),
            if (!isError) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildTag(
                        icon: Icons.auto_awesome,
                        label: 'AI ASSISTANT',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.copy_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text(
            'Image',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Thinking...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInput() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Suggestions
              if (_messages.isEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      _buildSuggestionChip('Summarize my day'),
                      const SizedBox(width: 8),
                      _buildSuggestionChip('What\'s on my schedule?'),
                      const SizedBox(width: 8),
                      _buildSuggestionChip('Find my glasses'),
                    ],
                  ),
                ),

              // Input Field
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ask anything...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: _handleSubmitted,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.mic, color: Colors.grey),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _handleSubmitted(_textController.text),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryEvidence(List<MediaItem> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16),
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildEvidenceCard(item),
          );
        },
      ),
    );
  }

  Widget _buildEvidenceCard(MediaItem item) {
    final isVideo = item.type == MediaType.video;
    final icon = isVideo ? Icons.play_circle_fill : Icons.photo;

    return GestureDetector(
      onTap: () => _openMedia(item),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            if (item.fileUrl != null)
              Image.network(
                item.fileUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              )
            else
              Container(color: Colors.grey.shade900),

            // Overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),

            // Icon centered
            Center(
              child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 32),
            ),

            // Time label
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                _formatDate(item.capturedAt),
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    } else {
      return '${date.month}/${date.day} ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    }
  }

  void _openMedia(MediaItem item) {
    if (item.fileUrl == null) return;

    if (item.type == MediaType.video) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: item.fileUrl!),
        ),
      );
    } else if (item.type == MediaType.photo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: InteractiveViewer(child: Image.network(item.fileUrl!)),
            ),
          ),
        ),
      );
    } else if (item.type == MediaType.audio) {
      // Allow playing audio
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Playing audio clip...')));
      RecordingService().playAudio(item.fileUrl!);
    }
  }

  Widget _buildSuggestionChip(String label) {
    return GestureDetector(
      onTap: () => _handleSubmitted(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
