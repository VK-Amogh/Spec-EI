import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/recording_service.dart';

/// Memory Tab - Timeline view with memory cards
/// Matches design from memory_timeline_ultimate_ui
class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});

  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<MemoryTab> {
  int _selectedFilter = 0;
  final List<String> _filters = ['ALL', 'VOICE', 'VISUAL', 'SMART GROUPING'];

  // Recording state
  final RecordingService _recordingService = RecordingService();
  bool _isRecordingAudio = false;
  bool _isRecordingVideo = false;
  final List<RecordedMemory> _recordedMemories = [];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader()),

              // Time scrubber
              SliverToBoxAdapter(child: _buildTimeScrubber()),

              // Filter chips
              SliverToBoxAdapter(child: _buildFilterChips()),

              // Main content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                  child: Column(
                    children: [
                      // Pattern detected banner
                      _buildPatternBanner(),
                      const SizedBox(height: 24),

                      // Today section
                      _buildTimelineSection(
                        label: 'Today',
                        isActive: true,
                        children: [
                          // Dynamically recorded memories
                          ..._recordedMemories.map(
                            (memory) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildMemoryCard(
                                icon: memory.type == MemoryType.audio
                                    ? Icons.mic
                                    : Icons.videocam,
                                iconColor: memory.type == MemoryType.audio
                                    ? AppColors.primary
                                    : Colors.blue,
                                relevance: memory.type == MemoryType.audio
                                    ? 'Voice Note'
                                    : 'Video Recording',
                                time: memory.formattedTime,
                                title: memory.title,
                                description: memory.formattedDuration.isNotEmpty
                                    ? 'Duration: ${memory.formattedDuration}'
                                    : 'Recording saved',
                              ),
                            ),
                          ),
                          _buildMemoryCard(
                            icon: Icons.videocam,
                            iconColor: AppColors.primary,
                            relevance: 'High Relevance',
                            time: '11:15 AM',
                            title: 'Design Sync & Patterns',
                            description:
                                'Discussion with the design team about new interaction patterns. Action item: Buy oat milk and check delivery confirmation.',
                            sentiment: 'Positive',
                          ),
                          const SizedBox(height: 16),
                          _buildContextGraph(),
                          const SizedBox(height: 16),
                          _buildMemoryCard(
                            icon: Icons.psychology_alt,
                            iconColor: const Color(0xFFA855F7),
                            relevance: 'Focus Mode',
                            relevanceColor: const Color(0xFFA855F7),
                            time: '09:45 AM',
                            title: 'Deep Work Session',
                            description:
                                'Sustained concentration period detected. Context: Coding session.',
                            duration: '45m',
                            showProgressBar: true,
                            progressColor: const Color(0xFFA855F7),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Yesterday section
                      _buildTimelineSection(
                        label: 'Yesterday',
                        isActive: false,
                        children: [
                          _buildImageMemoryCard(),
                          const SizedBox(height: 16),
                          _buildWorkoutCard(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating AI button
          Positioned(bottom: 140, right: 24, child: _buildFloatingAIButton()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'Memory',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Audio Record Button
              GestureDetector(
                onTap: _toggleAudioRecording,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isRecordingAudio
                        ? Colors.red.withOpacity(0.2)
                        : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecordingAudio
                          ? Colors.red
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Icon(
                    _isRecordingAudio ? Icons.stop : Icons.mic,
                    size: 20,
                    color: _isRecordingAudio ? Colors.red : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Video Record Button
              GestureDetector(
                onTap: _toggleVideoRecording,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isRecordingVideo
                        ? Colors.red.withOpacity(0.2)
                        : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecordingVideo
                          ? Colors.red
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Icon(
                    _isRecordingVideo ? Icons.stop : Icons.videocam,
                    size: 20,
                    color: _isRecordingVideo ? Colors.red : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'SEARCH',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Toggle audio recording
  Future<void> _toggleAudioRecording() async {
    if (_isRecordingAudio) {
      // Stop recording
      final memory = await _recordingService.stopAudioRecording();
      if (memory != null) {
        setState(() {
          _isRecordingAudio = false;
          _recordedMemories.insert(0, memory);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio saved: ${memory.formattedDuration}'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        setState(() => _isRecordingAudio = false);
      }
    } else {
      // Start recording
      final started = await _recordingService.startAudioRecording();
      if (started) {
        setState(() => _isRecordingAudio = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to start recording. Check microphone permissions.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Toggle video recording (placeholder - opens camera preview)
  Future<void> _toggleVideoRecording() async {
    if (_isRecordingVideo) {
      setState(() => _isRecordingVideo = false);
      // Video recording stop logic would go here
    } else {
      // Check camera permission
      final hasPermission = await _recordingService.requestCameraPermission();
      if (hasPermission) {
        setState(() => _isRecordingVideo = true);
        // For now, just show a message - full camera implementation requires more setup
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Video recording started (camera preview coming soon)',
              ),
              backgroundColor: AppColors.primary,
              action: SnackBarAction(
                label: 'STOP',
                textColor: Colors.black,
                onPressed: () => setState(() => _isRecordingVideo = false),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTimeScrubber() {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Time markers
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Row(
              children: [
                _buildTimeMarker('09:00', 0.4, 6),
                _buildTimeMarker('', 0.4, 12),
                _buildTimeMarker('10:00', 0.6, 6),
                _buildTimeMarker('', 0.6, 12),
                _buildTimeMarker('11:15', 1.0, 16, isActive: true),
                _buildTimeMarker('', 0.6, 12),
                _buildTimeMarker('12:00', 0.6, 6),
                _buildTimeMarker('', 0.4, 12),
                _buildTimeMarker('13:00', 0.4, 6),
              ],
            ),
          ),
          // Center indicator
          Positioned(
            bottom: 0,
            child: Container(
              width: 2,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.8),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeMarker(
    String label,
    double opacity,
    double height, {
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: isActive ? 2 : 1,
            height: height,
            color: isActive
                ? AppColors.primary
                : Colors.grey.shade600.withOpacity(opacity),
          ),
          const SizedBox(height: 4),
          if (label.isNotEmpty)
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Tune button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.tune,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            // Filter chips
            ...List.generate(_filters.length, (index) {
              final isSelected = _selectedFilter == index;
              final isSmartGrouping = index == 3;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFilter = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSmartGrouping && !isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _filters[index],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.black
                                : isSmartGrouping
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isSmartGrouping) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            size: 14,
                            color: isSelected
                                ? Colors.black
                                : AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PATTERN DETECTED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      const TextSpan(text: "You've discussed "),
                      TextSpan(
                        text: 'interaction design',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(text: ' in 3 consecutive meetings.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection({
    required String label,
    required bool isActive,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.black : AppColors.surface,
                border: Border.all(
                  color: isActive ? AppColors.primary : Colors.grey.shade600,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.6),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Children with timeline line
        Stack(
          children: [
            // Timeline line
            Positioned(
              left: 5,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: Colors.grey.shade800),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(children: children),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemoryCard({
    required IconData icon,
    required Color iconColor,
    required String relevance,
    Color? relevanceColor,
    required String time,
    required String title,
    required String description,
    String? sentiment,
    String? duration,
    bool showProgressBar = false,
    Color? progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            relevance.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: relevanceColor ?? AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            time,
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (duration != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Text(
                    duration,
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                Icon(Icons.more_horiz, color: AppColors.textMuted),
            ],
          ),

          // Sentiment bar (optional)
          if (sentiment != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Waveform visualization
                  Row(
                    children: List.generate(12, (index) {
                      final heights = [3, 5, 8, 6, 4, 2, 5, 7, 4, 2, 4, 6];
                      return Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 4,
                        height: heights[index].toDouble() * 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sentiment_satisfied,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sentiment.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Description
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),

          // Progress bar (optional)
          if (showProgressBar) ...[
            const SizedBox(height: 16),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor ?? AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],

          // Action buttons (optional)
          if (sentiment != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionButton(
                  Icons.mic,
                  'Key Topics',
                  Colors.orange.shade400,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  Icons.list_alt,
                  'Action Items  2',
                  Colors.blue.shade400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Input field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: TextField(
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask memory about this...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: Icon(
                    Icons.arrow_upward,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextGraph() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTEXT GRAPH',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatar stack
              SizedBox(
                width: 54,
                height: 36,
                child: Stack(
                  children: [
                    Positioned(left: 0, child: _buildAvatar('A')),
                    Positioned(left: 18, child: _buildAvatar('B')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      const TextSpan(text: 'Related to '),
                      TextSpan(
                        text: 'Project Alpha',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const TextSpan(text: ' timeline.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildImageMemoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Image placeholder
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade800.withOpacity(0.6),
                  Colors.purple.shade900.withOpacity(0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Content
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.graphic_eq,
                                      size: 12,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Vibe',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '18:20',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Downtown Loft Sunset',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      size: 20,
                      color: Colors.orange.shade500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Recovery Workout',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '18:25',
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatBox('HRV', '42ms', AppColors.primary)),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatBox('Strain', '10.2', Colors.orange.shade400),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Performance +10 pts above baseline.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Simple graph line placeholder
          Container(
            height: 24,
            child: CustomPaint(
              size: const Size(double.infinity, 24),
              painter: _GraphPainter(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAIButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.smart_toy, size: 28, color: Colors.black),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final Color color;
  _GraphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.2,
      size.width,
      size.height * 0.3,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
