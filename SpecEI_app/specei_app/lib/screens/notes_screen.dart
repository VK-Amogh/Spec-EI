import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/memory_data_service.dart';

/// Simple Notes Screen for quick note-taking
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final MemoryDataService _memoryService = MemoryDataService();
  List<NoteItem> _notes = [];

  @override
  void initState() {
    super.initState();
    _notes = _memoryService.notes.toList();
    _memoryService.addListener(_onMemoryChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _memoryService.removeListener(_onMemoryChanged);
    super.dispose();
  }

  void _onMemoryChanged() {
    if (mounted) {
      setState(() {
        _notes = _memoryService.notes.toList();
      });
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isNotEmpty ||
        _contentController.text.isNotEmpty) {
      final note = NoteItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.isEmpty
            ? 'Untitled'
            : _titleController.text,
        content: _contentController.text,
      );

      await _memoryService.addNote(note);

      _titleController.clear();
      _contentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note saved!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  Text(
                    'Notes',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _saveNote,
                    icon: Icon(Icons.check, color: AppColors.primary, size: 28),
                  ),
                ],
              ),
            ),

            // Note input area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    TextField(
                      controller: _contentController,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Start typing your note...',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notes list header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'RECENT NOTES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_notes.length} notes',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textDimmed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Notes list
            Expanded(
              child: _notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 64,
                            color: AppColors.textDimmed,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notes yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            'Start typing above to create one',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textDimmed,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(note.createdAt),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textDimmed,
                                    ),
                                  ),
                                ],
                              ),
                              if (note.content.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  note.content,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
