import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../core/app_colors.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;

  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _handleSubmitted(widget.initialQuery!);
    }
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
      final response = await _chatService.sendMessage(text);
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
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

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          child: Text(
            message['content'],
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.grey.shade200,
              height: 1.5,
            ),
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
