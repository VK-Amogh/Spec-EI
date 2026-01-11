import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../services/recording_service.dart';
import '../../services/memory_data_service.dart';
import '../../services/media_analysis_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../camera_screen.dart';
import '../video_player_screen.dart';
import '../../services/notification_service.dart';

/// Memory Tab - Timeline view with memory cards
/// Matches design from memory_timeline_ultimate_ui
class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});

  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<MemoryTab> {
  int _selectedFilter = 0;
  final List<String> _filters = ['SMART GROUPING', 'VOICE', 'VISUAL', 'ALL'];

  // Sub-tab for ALL filter (0 = Visuals, 1 = Audio)
  int _allSubTab = 0;

  // Recording state
  final RecordingService _recordingService = RecordingService();
  bool _isRecordingAudio = false;
  final bool _isRecordingVideo = false;
  final List<RecordedMemory> _recordedMemories = [];

  // Real-time clock
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // Shared memory data service
  final MemoryDataService _memoryService = MemoryDataService();

  // Audio Player State
  String? _playingUrl;
  bool _isPlayerPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  // AI Search state
  final MediaAnalysisService _analysisService = MediaAnalysisService();
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;
  String? _aiAnswer; // AI Answer State

  @override
  void initState() {
    super.initState();
    _startClockTimer();
    _memoryService.addListener(_onMemoryDataChanged);
    _memoryService.loadFromDatabase(); // Load data from Supabase
    _initAudioListeners();
    // Request microphone permission on app start to avoid repeated dialogs
    _requestMicrophonePermission();
  }

  /// Request microphone permission at startup for seamless recording
  Future<void> _requestMicrophonePermission() async {
    await _recordingService.requestMicrophonePermission();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _memoryService.removeListener(_onMemoryDataChanged);
    _disposeAudioListeners();
    _searchController.dispose();
    super.dispose();
  }

  void _onMemoryDataChanged() {
    if (mounted) setState(() {});
  }

  void _startClockTimer() {
    // Update every second for real-time display
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  void _initAudioListeners() {
    // Listen to player state
    _playerStateSub = _recordingService.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayerPlaying = state == PlayerState.playing;
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            _playingUrl = null;
            _currentPosition = Duration.zero;
          }
        });
      }
    });

    // Listen to position changes
    _positionSub = _recordingService.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    // Listen to duration changes
    _durationSub = _recordingService.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _totalDuration = duration);
      }
    });
  }

  void _disposeAudioListeners() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
  }

  // ==================== SYNC METHODS ====================

  /// Sync all media to AI server for reanalysis
  Future<void> _syncAllMedia() async {
    // Show syncing indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Syncing media to AI...'),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      // Trigger server-side reanalysis for all user media
      final result = await _analysisService.serverReanalyze();

      if (result != null && result['status'] == 'processing') {
        // Start polling for completion
        _pollSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Poll sync status until complete
  Future<void> _pollSyncStatus() async {
    const maxPolls = 60; // Max 2 minutes (2s intervals)
    for (int i = 0; i < maxPolls; i++) {
      await Future.delayed(const Duration(seconds: 2));

      try {
        final status = await _analysisService.getSyncStatus();

        if (status != null) {
          if (status['status'] == 'completed') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${status['message'] ?? 'Sync complete!'}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            // Reload data
            await _memoryService.loadFromDatabase();
            return;
          } else if (status['status'] == 'syncing') {
            // Still syncing, continue polling
            continue;
          }
        }
      } catch (e) {
        // Ignore poll errors, continue trying
      }
    }

    // Timeout - show message anyway
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⏱️ Sync taking longer than expected. Check server logs.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ==================== AI SEARCH METHODS ====================

  /// Show AI-powered search modal
  void _showSearchModal() {
    _searchController.clear();
    _searchController.clear();
    _searchResults = [];
    _aiAnswer = null; // Clear answer
    _isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: AppColors.getBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.psychology, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'AI Memory Search',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppColors.getTextMuted(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search by content... (e.g., "teddy", "meeting")',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.getTextMuted(context),
                      ),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.arrow_forward,
                                color: AppColors.primary,
                              ),
                              onPressed: () async {
                                if (_searchController.text.trim().isEmpty) {
                                  return;
                                }
                                setModalState(() => _isSearching = true);

                                // Always reload fresh data from database first
                                await _memoryService.loadFromDatabase();

                                // Force re-analyze ALL videos and audio to apply new keywords
                                final videosAndAudio = _memoryService.mediaItems
                                    .where(
                                      (m) =>
                                          m.type == MediaType.video ||
                                          m.type == MediaType.audio,
                                    )
                                    .toList();

                                if (videosAndAudio.isNotEmpty) {
                                  print(
                                    '🔄 Force re-analyzing ${videosAndAudio.length} videos/audio...',
                                  );
                                  await _analysisService.forceReanalyzeAllMedia(
                                    videosAndAudio,
                                  );
                                  // Reload after analysis to get fresh descriptions
                                  await _memoryService.loadFromDatabase();
                                }

                                // Now search with fresh data
                                print(
                                  '🔎 Searching in ${_memoryService.mediaItems.length} items',
                                );
                                // Use semantic search with AI keyword expansion
                                final searchResult = await _analysisService
                                    .semanticSearch(
                                      _searchController.text.trim(),
                                      _memoryService.mediaItems,
                                    );
                                print(
                                  '📊 Search returned ${searchResult.results.length} results',
                                );
                                print(
                                  '🔑 Keywords used: ${searchResult.keywords}',
                                );
                                setModalState(() {
                                  _searchResults = searchResult.results;
                                  _aiAnswer =
                                      searchResult.aiAnswer; // Set answer
                                  _isSearching = false;
                                });
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isEmpty) return;
                      setModalState(() => _isSearching = true);

                      // Always reload fresh data from database first
                      await _memoryService.loadFromDatabase();

                      // Force re-analyze ALL videos and audio to apply new keywords
                      final videosAndAudio = _memoryService.mediaItems
                          .where(
                            (m) =>
                                m.type == MediaType.video ||
                                m.type == MediaType.audio,
                          )
                          .toList();

                      if (videosAndAudio.isNotEmpty) {
                        print(
                          '🔄 Force re-analyzing ${videosAndAudio.length} videos/audio...',
                        );
                        await _analysisService.forceReanalyzeAllMedia(
                          videosAndAudio,
                        );
                        // Reload after analysis to get fresh descriptions
                        await _memoryService.loadFromDatabase();
                      }

                      // Now search with fresh data using semantic search
                      print(
                        '🔎 Searching in ${_memoryService.mediaItems.length} items',
                      );
                      final searchResult = await _analysisService
                          .semanticSearch(
                            value.trim(),
                            _memoryService.mediaItems,
                          );
                      print(
                        '📊 Search returned ${searchResult.results.length} results',
                      );
                      print('🔑 Keywords used: ${searchResult.keywords}');
                      setModalState(() {
                        _searchResults = searchResult.results;
                        _aiAnswer = searchResult.aiAnswer; // Set answer
                        _isSearching = false;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // AI Answer Display
              if (_aiAnswer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "AI MEMORY AUDIT",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _aiAnswer!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Results section
              Expanded(
                child: _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_search,
                              size: 64,
                              color: AppColors.textMuted.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Search your memories by content'
                                  : 'No matching media found',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.getTextMuted(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI will find images, videos & audio\ncontaining what you search for',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final media = _searchResults[index];
                          return _buildSearchResultCard(media);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a search result card
  Widget _buildSearchResultCard(MediaItem media) {
    IconData icon;
    Color color;
    String typeLabel;

    switch (media.type) {
      case MediaType.photo:
        icon = Icons.photo;
        color = Colors.blue;
        typeLabel = 'Photo';
        break;
      case MediaType.video:
        icon = Icons.videocam;
        color = Colors.purple;
        typeLabel = 'Video';
        break;
      case MediaType.audio:
        icon = Icons.mic;
        color = Colors.orange;
        typeLabel = 'Audio';
        break;
    }

    return GestureDetector(
      onTap: () async {
        // Navigate to full view based on media type
        // DON'T close modal first - so back button returns to search
        if (media.type == MediaType.video && media.fileUrl != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(videoUrl: media.fileUrl!),
            ),
          );
          // After returning from video, we're back in the search modal
        } else if (media.type == MediaType.audio && media.fileUrl != null) {
          // Play audio without closing modal
          _recordingService.playAudio(media.fileUrl!);
          setState(() => _playingUrl = media.fileUrl);
        } else if (media.type == MediaType.photo && media.fileUrl != null) {
          // View photo in full screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                body: Center(
                  child: InteractiveViewer(
                    child: Image.network(media.fileUrl!, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Thumbnail or icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: media.type == MediaType.photo && media.fileUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        media.fileUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, color: color, size: 28),
                      ),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
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
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        media.formattedTime,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.getTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: AppColors.getTextMuted(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Check if there's any content to display
  bool get _hasContent {
    return _memoryService.hasContent;
  }

  // Get filtered media items based on selected filter
  // 0 = SMART GROUPING, 1 = VOICE (audio only), 2 = VISUAL (photo + video), 3 = ALL
  List<MediaItem> get _filteredMediaItems {
    final allMedia = _memoryService.mediaItems;

    switch (_selectedFilter) {
      case 0: // SMART GROUPING - show all for now
        return allMedia;
      case 1: // VOICE - audio only
        return allMedia.where((m) => m.type == MediaType.audio).toList();
      case 2: // VISUAL - photos and videos only
        return allMedia
            .where(
              (m) => m.type == MediaType.photo || m.type == MediaType.video,
            )
            .toList();
      case 3: // ALL
        return allMedia;
      default:
        return allMedia;
    }
  }

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
                      // Show content only if there's any
                      if (!_hasContent) ...[
                        // No work assigned state
                        _buildNoWorkAssignedCard(),
                      ] else if (_selectedFilter == 3) ...[
                        // ALL filter - show Visuals/Audio tabs
                        _buildAllFilterContent(),
                      ] else ...[
                        // Today section (newest first)
                        _buildTimelineSection(
                          label: 'Today',
                          isActive: true,
                          children: [
                            // Media items from Supabase (photos/videos/audio captured today)
                            ..._filteredMediaItems
                                .where((m) {
                                  final now = DateTime.now();
                                  return m.capturedAt.year == now.year &&
                                      m.capturedAt.month == now.month &&
                                      m.capturedAt.day == now.day;
                                })
                                .toList()
                                .reversed // Newest first within today
                                .map(
                                  (media) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildMediaMemoryCard(media),
                                  ),
                                ),
                            if (_filteredMediaItems.where((m) {
                              final now = DateTime.now();
                              return m.capturedAt.year == now.year &&
                                  m.capturedAt.month == now.month &&
                                  m.capturedAt.day == now.day;
                            }).isEmpty)
                              _buildEmptyScheduleCard(
                                'No activities for today',
                              ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Yesterday section
                        _buildTimelineSection(
                          label: 'Yesterday',
                          isActive: false,
                          children: [
                            // Yesterday's media
                            ..._filteredMediaItems
                                .where((m) {
                                  final yesterday = DateTime.now().subtract(
                                    const Duration(days: 1),
                                  );
                                  return m.capturedAt.year == yesterday.year &&
                                      m.capturedAt.month == yesterday.month &&
                                      m.capturedAt.day == yesterday.day;
                                })
                                .toList()
                                .reversed // Newest first within yesterday
                                .map(
                                  (media) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildMediaMemoryCard(media),
                                  ),
                                ),
                            // Show empty state if nothing from yesterday
                            if (_filteredMediaItems.where((m) {
                              final yesterday = DateTime.now().subtract(
                                const Duration(days: 1),
                              );
                              return m.capturedAt.year == yesterday.year &&
                                  m.capturedAt.month == yesterday.month &&
                                  m.capturedAt.day == yesterday.day;
                            }).isEmpty)
                              _buildEmptyScheduleCard(
                                'No activities yesterday',
                              ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Past sections (Older than yesterday) - ordered newest to oldest
                        ..._buildPastSections(),
                      ],
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
                  color: AppColors.getSurface(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.getBorderLight(context)),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.getTextMuted(context),
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'Memory',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Sync button
              GestureDetector(
                onTap: _syncAllMedia,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.getBorderLight(context),
                    ),
                  ),
                  child: Icon(Icons.sync, size: 16, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              // Search button
              GestureDetector(
                onTap: _showSearchModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.getBorderLight(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI SEARCH',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                          letterSpacing: 1,
                        ),
                      ),
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

  /// Toggle audio recording
  Future<void> _toggleAudioRecording() async {
    if (_isRecordingAudio) {
      // Stop recording
      final memory = await _recordingService.stopAudioRecording();
      if (memory != null) {
        setState(() {
          _isRecordingAudio = false;
          // Note: recording is automatically synced to Supabase by recordingService
          // We just refresh the data from the service
        });
        // Reload data from service to get the newly saved recording
        await _memoryService.loadFromDatabase();
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

  /// Open camera options dialog
  Future<void> _toggleVideoRecording() async {
    // Navigate to full-screen camera
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    // Reload data if photo/video was captured
    if (result == true) {
      await _memoryService.loadFromDatabase();
    }
  }

  Widget _buildCameraOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Capture a photo using the camera
  Future<void> _capturePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        // Read file bytes
        final bytes = await photo.readAsBytes();
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Save to Supabase
        final media = await _memoryService.addMediaWithFile(
          type: MediaType.photo,
          fileName: fileName,
          fileBytes: bytes,
          mimeType: 'image/jpeg',
        );

        if (media != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Photo saved to memory!'),
                ],
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Record a video using the camera
  Future<void> _recordVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        // Read file bytes
        final bytes = await video.readAsBytes();
        final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

        // Save to Supabase
        final media = await _memoryService.addMediaWithFile(
          type: MediaType.video,
          fileName: fileName,
          fileBytes: bytes,
          mimeType: 'video/mp4',
        );

        if (media != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Video saved to memory!'),
                ],
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTimeScrubber() {
    final hour = _currentTime.hour;
    final minute = _currentTime.minute;
    final second = _currentTime.second;
    final formattedTime =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';

    // Generate time markers around current time (hourly)
    final List<String> timeMarkers = [];
    for (int i = -3; i <= 3; i++) {
      final markerHour = (hour + i) % 24;
      if (markerHour < 0) {
        timeMarkers.add('${(markerHour + 24).toString().padLeft(2, '0')}:00');
      } else {
        timeMarkers.add('${markerHour.toString().padLeft(2, '0')}:00');
      }
    }

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Time scale with markers
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < timeMarkers.length; i++)
                    _buildTimeMarker(
                      timeMarkers[i],
                      i == 3
                          ? 1.0
                          : (i == 2 || i == 4)
                          ? 0.7
                          : 0.4,
                      i == 3 ? 20.0 : 10.0,
                      isActive: i == 3,
                    ),
                ],
              ),
            ),
          ),
          // Center current time display with indicator
          Positioned(
            top: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    formattedTime,
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                // Indicator line
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
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
                : AppColors.getTextMuted(context).withOpacity(opacity),
          ),
          const SizedBox(height: 4),
          if (label.isNotEmpty)
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : AppColors.getTextMuted(context),
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
                color: AppColors.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.getBorderLight(context)),
              ),
              child: Icon(
                Icons.tune,
                size: 20,
                color: AppColors.getTextMuted(context),
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
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSmartGrouping && !isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.getBorderLight(context),
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
                                : AppColors.getTextSecondary(context),
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

  /// Build ALL filter content with Visuals/Audio tabs
  Widget _buildAllFilterContent() {
    return Column(
      children: [
        // Tab selector (Visuals / Audio)
        _buildVisualsAudioTabs(),
        const SizedBox(height: 24),

        // Content based on selected tab
        if (_allSubTab == 0) _buildVisualsList() else _buildAudioList(),
      ],
    );
  }

  /// Build Visuals/Audio tab selector
  Widget _buildVisualsAudioTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.getBorderLight(context)),
      ),
      child: Row(
        children: [
          // Visuals tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _allSubTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _allSubTab == 0
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: _allSubTab == 0
                          ? Colors.black
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Visuals',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _allSubTab == 0
                            ? Colors.black
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Audio tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _allSubTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _allSubTab == 1
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.audiotrack_outlined,
                      size: 18,
                      color: _allSubTab == 1
                          ? Colors.black
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Audio',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _allSubTab == 1
                            ? Colors.black
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build visuals list (photos and videos) sorted by date - older first
  Widget _buildVisualsList() {
    final visuals =
        _memoryService.mediaItems
            .where(
              (m) => m.type == MediaType.photo || m.type == MediaType.video,
            )
            .toList()
          ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt)); // Older first

    if (visuals.isEmpty) {
      return _buildEmptyScheduleCard('No photos or videos yet');
    }

    // Group by date
    final Map<String, List<MediaItem>> groupedVisuals = {};
    for (final visual in visuals) {
      final dateKey = _formatDateKey(visual.capturedAt);
      groupedVisuals.putIfAbsent(dateKey, () => []).add(visual);
    }

    return Column(
      children: groupedVisuals.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                entry.key,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Media items for this date
            ...entry.value.map(
              (media) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildVisualCard(media),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  /// Build a visual card (photo or video)
  Widget _buildVisualCard(MediaItem media) {
    final isVideo = media.type == MediaType.video;
    final hasLocalBytes =
        media.localBytes != null && media.localBytes!.isNotEmpty;
    final hasRemoteUrl = media.fileUrl != null && media.fileUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          if (hasRemoteUrl) {
            _showVideoPlayer(media.fileUrl!);
          } else {
            // Video not yet uploaded - show message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video is uploading... Please wait.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Photo - can show from local bytes or remote URL
          if (hasRemoteUrl) {
            _showPhotoViewer(media.fileUrl!);
          } else if (hasLocalBytes) {
            _showLocalPhotoViewer(media.localBytes!);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image/Video thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  // Use local bytes if available, otherwise network URL
                  if (hasLocalBytes)
                    Image.memory(
                      Uint8List.fromList(media.localBytes!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
                    )
                  else if (hasRemoteUrl)
                    Image.network(
                      media.fileUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  if (isVideo)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  // Show "uploading" indicator for local items
                  if (media.isLocal)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Uploading',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isVideo ? Icons.videocam : Icons.photo_camera,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVideo ? 'Video' : 'Photo',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTime(media.capturedAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build audio list sorted by date - older first
  Widget _buildAudioList() {
    final audios =
        _memoryService.mediaItems
            .where((m) => m.type == MediaType.audio)
            .toList()
          ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt)); // Older first

    if (audios.isEmpty) {
      return _buildEmptyScheduleCard('No audio recordings yet');
    }

    // Group by date
    final Map<String, List<MediaItem>> groupedAudios = {};
    for (final audio in audios) {
      final dateKey = _formatDateKey(audio.capturedAt);
      groupedAudios.putIfAbsent(dateKey, () => []).add(audio);
    }

    return Column(
      children: groupedAudios.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                entry.key,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Audio items for this date
            ...entry.value.map(
              (audio) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAudioCard(audio),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  /// Build an audio card with waveform-style player
  Widget _buildAudioCard(MediaItem audio) {
    // Check if this audio is playing by comparing with either fileUrl or filePath
    final audioUrl = audio.fileUrl ?? audio.filePath;
    final isPlaying = _playingUrl == audioUrl && _isPlayerPlaying;

    return _AudioPlayerCard(
      key: ValueKey(audio.id),
      audio: audio,
      isPlaying: isPlaying,
      currentPosition: isPlaying ? _currentPosition : Duration.zero,
      totalDuration: isPlaying && _totalDuration.inMilliseconds > 0
          ? _totalDuration
          : (audio.duration ?? Duration.zero),
      onPlay: () => _playMediaItem(audio),
    );
  }

  /// Format date key for grouping
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format time for display
  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // No work assigned card
  Widget _buildNoWorkAssignedCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No work assigned yet',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set a reminder, take notes, or capture media\nto see your schedule here',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Schedule card for displaying scheduled items
  Widget _buildScheduleCard({
    required String title,
    required String time,
    required String type,
    String? id,
  }) {
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'meeting':
        icon = Icons.groups;
        iconColor = Colors.blue;
        break;
      case 'call':
        icon = Icons.phone;
        iconColor = Colors.green;
        break;
      case 'deadline':
        icon = Icons.flag;
        iconColor = Colors.red;
        break;
      case 'review':
        icon = Icons.rate_review;
        iconColor = Colors.purple;
        break;
      case 'reminder':
        icon = Icons.alarm;
        iconColor = AppColors.primary;
        break;
      case 'note':
        icon = Icons.note_alt;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.event;
        iconColor = AppColors.primary;
    }

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: AppColors.getTextMuted(context),
                  ),
                ),
              ],
            ),
          ),
          // 3-dot menu with delete option
          if (id != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.getTextMuted(context),
              ),
              color: AppColors.getSurface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                if (value == 'delete') {
                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Text(
                        'Delete ${type == 'reminder' ? 'Reminder' : 'Note'}?',
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
                      ),
                      content: Text(
                        'This action cannot be undone.',
                        style: GoogleFonts.inter(color: AppColors.textMuted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (type == 'reminder') {
                      await _memoryService.removeReminder(id);
                      // Also cancel the scheduled notification
                      await NotificationService().cancelReminder(
                        int.tryParse(id) ?? 0,
                      );
                    } else if (type == 'note') {
                      await _memoryService.removeNote(id);
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Icon(Icons.chevron_right, color: AppColors.getTextMuted(context)),
        ],
      ),
    );
  }

  // Empty state for schedule sections
  Widget _buildEmptyScheduleCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getBorderLight(context).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppColors.textDimmed,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.getTextMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // Build a memory card for media items (photos/videos)
  Widget _buildMediaMemoryCard(MediaItem media) {
    final isPhoto = media.type == MediaType.photo;
    final isVideo = media.type == MediaType.video;
    final isAudio = media.type == MediaType.audio;

    // Check if this item is currently playing
    final isPlaying =
        isAudio && _playingUrl == (media.fileUrl ?? media.filePath);

    if (isPlaying) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mic, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AudioWaveformPlayer(
                    isPlaying: true,
                    currentPosition: _currentPosition,
                    totalDuration: _totalDuration,
                    color: AppColors.primary,
                    height: 30,
                    barCount: 20,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _recordingService.stopAudio(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stop, size: 20, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    IconData icon = Icons.photo;
    Color iconColor = Colors.purple;
    String typeLabel = 'Photo';

    if (isVideo) {
      icon = Icons.videocam;
      iconColor = Colors.blue;
      typeLabel = 'Video';
    } else if (isAudio) {
      icon = Icons.mic;
      iconColor = Colors.red;
      typeLabel = 'Audio Recording';
    }

    final timeStr =
        '${media.capturedAt.hour.toString().padLeft(2, '0')}:${media.capturedAt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _playMediaItem(media),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorderLight(context)),
        ),
        child: Row(
          children: [
            // Thumbnail or icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isPhoto && media.fileUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        media.fileUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, size: 28, color: iconColor),
                      ),
                    )
                  : isPhoto &&
                        media.localBytes != null &&
                        media.localBytes!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        Uint8List.fromList(media.localBytes!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(icon, size: 28, color: iconColor),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(icon, size: 28, color: iconColor),
                        if (isVideo)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        typeLabel.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $timeStr',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          color: AppColors.textDimmed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPhoto
                        ? 'Photo captured'
                        : isVideo
                        ? 'Video recorded'
                        : 'Voice Note',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (media.duration != null)
                    Text(
                      'Duration: ${media.duration!.inMinutes}m ${media.duration!.inSeconds % 60}s',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (media.transcription != null &&
                      media.transcription!.isNotEmpty)
                    Text(
                      media.transcription!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // More options
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.getTextMuted(context),
                size: 20,
              ),
              color: AppColors.getSurface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteMediaItem(media.id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _playRecording(RecordedMemory memory) {
    if (memory.type == MemoryType.audio) {
      setState(() => _playingUrl = memory.filePath);
      _recordingService.playAudio(memory.filePath);
    }
  }

  void _playMediaItem(MediaItem media) {
    if (media.type == MediaType.audio) {
      // Prefer fileUrl (Supabase storage URL) over local filePath
      final url = media.fileUrl ?? media.filePath;
      if (url != null && url.isNotEmpty) {
        setState(() => _playingUrl = url);
        _recordingService.playAudio(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio file not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (media.type == MediaType.photo && media.fileUrl != null) {
      // Show photo in fullscreen dialog
      _showPhotoViewer(media.fileUrl!);
    } else if (media.type == MediaType.video && media.fileUrl != null) {
      // Show video player dialog
      _showVideoPlayer(media.fileUrl!);
    }
  }

  void _showPhotoViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 200,
                    color: AppColors.surface,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 200,
                  height: 200,
                  color: AppColors.surface,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 48),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VideoPlayerScreen(videoUrl: videoUrl, title: 'Video recorded'),
      ),
    );
  }

  /// Show photo viewer for local bytes (photos not yet uploaded)
  void _showLocalPhotoViewer(List<int> imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Photo from bytes
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                Uint8List.fromList(imageBytes),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 200,
                  height: 200,
                  color: AppColors.surface,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 48),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRecordedMemory(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Recording?',
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        content: Text(
          'This recording will be permanently deleted.',
          style: GoogleFonts.inter(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _recordedMemories.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recording deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteMediaItem(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Media?',
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        content: Text(
          'This media will be permanently deleted from your memory.',
          style: GoogleFonts.inter(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              await _memoryService.removeMedia(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Media deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
                color: isActive ? Colors.black : AppColors.getSurface(context),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.getTextMuted(context),
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
              child: Container(
                width: 1,
                color: AppColors.getBorderLight(context),
              ),
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
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
                      color: AppColors.getInputBackground(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.getBorderLight(context),
                      ),
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
                              color: AppColors.getTextMuted(context),
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
                    color: AppColors.getInputBackground(context),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.getBorderLight(context),
                    ),
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
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: AppColors.getTextMuted(context),
                  ),
                  color: AppColors.getSurface(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'delete' && onDelete != null) {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
                      color: AppColors.getInputBackground(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.getBorderLight(context),
                      ),
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
          SizedBox(
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
    return GestureDetector(
      onTap: _showSearchModal,
      child: Container(
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
      ),
    );
  }

  List<Widget> _buildPastSections() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Gather only media items older than yesterday (no notes/reminders)
    final pastMedia = _filteredMediaItems.where((m) {
      final date = DateTime(
        m.capturedAt.year,
        m.capturedAt.month,
        m.capturedAt.day,
      );
      return date.isBefore(yesterday);
    }).toList();

    // Group by date
    final Map<DateTime, List<MediaItem>> groupedItems = {};

    for (var media in pastMedia) {
      final date = DateTime(
        media.capturedAt.year,
        media.capturedAt.month,
        media.capturedAt.day,
      );
      if (!groupedItems.containsKey(date)) groupedItems[date] = [];
      groupedItems[date]!.add(media);
    }

    // Sort dates descending (Newest -> Oldest)
    final sortedDates = groupedItems.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedDates.map((date) {
      final items = groupedItems[date]!;
      // Sort items within date newest first
      items.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

      return Column(
        children: [
          _buildTimelineSection(
            label: _formatFullDate(date).toUpperCase(),
            isActive: false,
            children: items.map((media) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildMediaMemoryCard(media),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      );
    }).toList();
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

/// A widget that displays an animated audio waveform
class AudioWaveformPlayer extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final Color color;
  final double height;
  final int barCount;

  const AudioWaveformPlayer({
    super.key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.color,
    this.height = 40,
    this.barCount = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (index) {
              // Calculate progress
              final double progress = totalDuration.inMilliseconds > 0
                  ? currentPosition.inMilliseconds /
                        totalDuration.inMilliseconds
                  : 0.0;

              // Determine if this bar is "active" based on progress
              final bool isActive = index / barCount <= progress;

              // Generate a pseudo-random height for the visual waveform effect
              // We use index to make it static per bar, but varied across bars
              final double randomHeightRatio =
                  0.3 + (0.7 * ((index * 7) % 5) / 5);

              return _buildBar(
                context,
                isActive,
                height * randomHeightRatio,
                index,
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(currentPosition),
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _formatDuration(totalDuration),
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                color: AppColors.textDimmed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBar(
    BuildContext context,
    bool isActive,
    double barHeight,
    int index,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 4,
      height: isActive && isPlaying
          ? barHeight +
                (index % 2 == 0 ? 4 : -2) // Animate slightly if active
          : barHeight,
      decoration: BoxDecoration(
        color: isActive ? color : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// A stateless audio card that gets state from parent
class _AudioPlayerCard extends StatelessWidget {
  final MediaItem audio;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlay;

  const _AudioPlayerCard({
    super.key,
    required this.audio,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    // Use passed total duration if valid, otherwise metadata duration
    final durationMs = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds
        : (audio.duration?.inMilliseconds ?? 0);

    final progress = durationMs > 0
        ? currentPosition.inMilliseconds / durationMs
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderLight(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Waveform visualization
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform bars
                    SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(30, (index) {
                          // Generate pseudo-random heights for waveform
                          final heights = [
                            0.3,
                            0.5,
                            0.7,
                            0.4,
                            0.9,
                            0.6,
                            0.8,
                            0.4,
                            0.7,
                            0.5,
                            0.6,
                            0.8,
                            0.5,
                            0.7,
                            0.9,
                            0.4,
                            0.6,
                            0.8,
                            0.5,
                            0.7,
                            0.4,
                            0.6,
                            0.8,
                            0.5,
                            0.7,
                            0.9,
                            0.6,
                            0.4,
                            0.7,
                            0.5,
                          ];
                          final barProgress = index / 30;
                          final isActive = isPlaying && barProgress <= progress;

                          return Container(
                            width: 3,
                            height: 32 * heights[index],
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.getTextMuted(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Time and duration info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(audio.capturedAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Row(
                children: [
                  if (isPlaying) ...[
                    Text(
                      _formatDuration(currentPosition),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      ' / ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    audio.duration != null
                        ? _formatDuration(audio.duration!)
                        : 'Audio',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
