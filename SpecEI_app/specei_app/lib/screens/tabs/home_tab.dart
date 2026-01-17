import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/app_colors.dart';
import '../../services/battery_service.dart';
import '../../services/memory_data_service.dart';
import '../../services/recording_service.dart';
import '../../services/chat_service.dart';
import 'package:battery_plus/battery_plus.dart';
import '../chat_screen.dart';
import '../focus_mode_screen.dart';
import '../notes_screen.dart';
import '../../widgets/reminder_dialog.dart';
import '../../widgets/voice_interaction_ball.dart';
import '../../services/notification_service.dart';

import '../camera_screen.dart';

/// Home Tab - AI Hub with Voice Interaction Ball
/// Matches design from home_/_ai_hub_ultimate_ui_1
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  late AnimationController _marqueeController;
  late ScrollController _promptScrollController;
  final TextEditingController _inputController = TextEditingController();

  // Voice Interaction State
  bool _isAiSpeaking = false; // Simulated AI speaking state

  // Battery
  final BatteryService _batteryService = BatteryService();
  int _batteryLevel = -1;
  bool _isCharging = false;
  Timer? _batteryTimer;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  // Memory data service for reminders/notes
  final MemoryDataService _memoryService = MemoryDataService();

  // Voice recording state
  bool _isRecording = false;
  final String _recordedText = '';

  // Dashboard state - tracks active items
  final bool _isFocusModeActive = false;

  // Attached files for preview
  final List<XFile> _attachedFiles = [];

  @override
  void initState() {
    super.initState();

    // Marquee auto-scroll setup
    _promptScrollController = ScrollController();
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    );

    // Start auto-scroll after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarqueeAnimation();
      _initBattery();
    });

    // Listen to memory data changes for dashboard updates
    _memoryService.addListener(_onMemoryDataChanged);
  }

  void _onMemoryDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initBattery() async {
    final level = await _batteryService.getBatteryLevel();
    final state = await _batteryService.getBatteryState();
    if (mounted) {
      setState(() {
        _batteryLevel = level;
        _isCharging = state == BatteryState.charging;
      });
    }

    // Listen to battery state changes
    _batteryService.listenToBatteryState((state) {
      if (mounted) {
        setState(() => _isCharging = state == BatteryState.charging);
        _refreshBatteryLevel();
      }
    });

    // Start periodic timer to refresh battery level every 10 seconds
    _batteryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshBatteryLevel();
    });
  }

  Future<void> _refreshBatteryLevel() async {
    final level = await _batteryService.getBatteryLevel();
    if (mounted) {
      setState(() => _batteryLevel = level);
    }
  }

  void _startMarqueeAnimation() {
    if (!mounted || !_promptScrollController.hasClients) return;

    final maxScroll = _promptScrollController.position.maxScrollExtent;
    _marqueeController.addListener(() {
      if (_promptScrollController.hasClients) {
        _promptScrollController.jumpTo(_marqueeController.value * maxScroll);
      }
    });
    _marqueeController.repeat();
  }

  @override
  void dispose() {
    _marqueeController.dispose();
    _promptScrollController.dispose();
    _inputController.dispose();
    _batteryService.dispose();
    _batteryTimer?.cancel();
    _memoryService.removeListener(_onMemoryDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 180),
            child: Column(
              children: [
                // Logo section
                _buildLogoSection(),
                const SizedBox(height: 16),

                // Status bar
                _buildStatusBar(),
                const SizedBox(height: 32),

                // Voice Interaction Ball
                VoiceInteractionBall(
                  isListening: _isRecording,
                  isSpeaking: _isAiSpeaking,
                  audioLevel: _isRecording
                      ? 0.0
                      : 0.0, // Placeholder for audio level
                ),
                const SizedBox(height: 32),

                // Adaptive Dashboard
                _buildDashboardSection(),
                const SizedBox(height: 24),

                // Quick actions
                _buildQuickActions(),
              ],
            ),
          ),

          // Fixed input bar at bottom (above nav bar)
          Positioned(
            left: 20,
            right: 20,
            bottom: 100, // Above the nav bar
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'SpecEI',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                  letterSpacing: -1,
                  shadows: [
                    Shadow(color: AppColors.primaryGlow, blurRadius: 30),
                  ],
                ),
              ),
              TextSpan(
                text: '●',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderLight(context)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Connected status
          Icon(Icons.smart_toy, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Connected',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          _buildDivider(),

          // Battery - Live device battery
          _buildBatteryIndicator(),
          _buildDivider(),

          // Syncing
          Icon(Icons.wifi_tethering, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            'Syncing...',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.getTextMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 1,
      height: 12,
      color: AppColors.getBorderLight(context),
    );
  }

  Widget _buildBatteryIndicator() {
    // Determine battery color based on level
    Color batteryColor;
    IconData batteryIcon;

    if (_batteryLevel < 0) {
      batteryColor = AppColors.getTextMuted(context);
      batteryIcon = Icons.battery_unknown;
    } else if (_batteryLevel < 20) {
      batteryColor = Colors.red;
      batteryIcon = _isCharging
          ? Icons.battery_charging_full
          : Icons.battery_1_bar;
    } else if (_batteryLevel < 50) {
      batteryColor = Colors.orange;
      batteryIcon = _isCharging
          ? Icons.battery_charging_full
          : Icons.battery_3_bar;
    } else {
      batteryColor = AppColors.primary;
      batteryIcon = _isCharging
          ? Icons.battery_charging_full
          : Icons.battery_5_bar;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(batteryIcon, size: 16, color: batteryColor),
        const SizedBox(width: 4),
        Text(
          _batteryLevel >= 0 ? '$_batteryLevel%' : 'N/A',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: batteryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADAPTIVE DASHBOARD',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextMuted(context),
                  letterSpacing: 1.5,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: AppColors.getTextMuted(context),
                ),
                color: AppColors.getSurface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'notes':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotesScreen()),
                      );
                      break;
                    case 'reminder':
                      showDialog(
                        context: context,
                        builder: (_) => const ReminderDialog(),
                      );
                      break;
                    case 'focus':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FocusModeScreen(),
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'notes',
                    child: Row(
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Take Notes',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reminder',
                    child: Row(
                      children: [
                        Icon(Icons.alarm, size: 18, color: Colors.orange),
                        const SizedBox(width: 12),
                        Text(
                          'Set Reminder',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'focus',
                    child: Row(
                      children: [
                        Icon(Icons.psychology, size: 18, color: Colors.purple),
                        const SizedBox(width: 12),
                        Text(
                          'Focus Mode',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dynamic dashboard content
        _memoryService.reminders.isEmpty &&
                _memoryService.notes.isEmpty &&
                !_isFocusModeActive
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getBorderLight(context)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppColors.getTextMuted(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No work assigned yet',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextMuted(context),
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Show reminders if any
                    ..._memoryService.reminders.map(
                      (reminder) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildDashboardCard(
                          icon: Icons.alarm,
                          iconColor: Colors.orange,
                          label: reminder.daysAway == 0
                              ? 'Today'
                              : 'In ${reminder.daysAway}d',
                          labelColor: Colors.orange,
                          title: reminder.title,
                          subtitle: reminder.formattedTime,
                          id: reminder.id,
                          type: 'reminder',
                          onDelete: () async {
                            await _memoryService.removeReminder(reminder.id);
                            await NotificationService().cancelReminder(
                              int.tryParse(reminder.id) ?? 0,
                            );
                          },
                        ),
                      ),
                    ),
                    // Show notes if any
                    ..._memoryService.notes.map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildDashboardCard(
                          icon: Icons.note_alt,
                          iconColor: AppColors.primary,
                          title: note.title,
                          subtitle: note.formattedTime,
                          id: note.id,
                          type: 'note',
                          onDelete: () async {
                            await _memoryService.removeNote(note.id);
                          },
                        ),
                      ),
                    ),
                    // Show focus mode if active
                    if (_isFocusModeActive)
                      _buildDashboardCard(
                        icon: Icons.psychology,
                        iconColor: Colors.purple,
                        label: 'Active',
                        labelColor: Colors.purple,
                        title: 'Focus Mode',
                        subtitle: 'In progress',
                        showAccent: true,
                      ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required Color iconColor,
    String? label,
    Color? labelColor,
    required String title,
    required String subtitle,
    bool showAccent = false,
    String? id,
    String? type,
    VoidCallback? onDelete,
  }) {
    return Container(
      width: 156,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        // Light edge glow
        border: Border.all(
          color: showAccent
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.getBorderLight(context),
          width: showAccent ? 1.5 : 1,
        ),
        boxShadow: [
          // Colored shade effect based on icon color
          BoxShadow(
            color: iconColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
          if (showAccent)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon container with subtle glow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                // Right side: label and/or 3-dot menu
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (labelColor ?? AppColors.textMuted)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                labelColor ?? AppColors.getTextMuted(context),
                          ),
                        ),
                      ),
                    if (onDelete != null)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: AppColors.getTextMuted(context),
                            size: 16,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          color: AppColors.getSurface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: Text(
                                    'Delete ${type == 'reminder' ? 'Reminder' : 'Note'}?',
                                    style: GoogleFonts.inter(
                                      color: AppColors.getTextPrimary(context),
                                    ),
                                  ),
                                  content: Text(
                                    'This action cannot be undone.',
                                    style: GoogleFonts.inter(
                                      color: AppColors.getTextMuted(context),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                        ),
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
                                onDelete();
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
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
                      ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.getTextMuted(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      controller: _promptScrollController,
      scrollDirection: Axis.horizontal,
      physics:
          const NeverScrollableScrollPhysics(), // Disable manual scroll for auto-scroll
      child: Row(
        children: [
          _buildQuickActionChip('Summarize last meeting', showDot: true),
          const SizedBox(width: 12),
          _buildQuickActionChip('Find my glasses', showDot: true),
          const SizedBox(width: 12),
          _buildQuickActionChip('Draft email'),
          const SizedBox(width: 12),
          _buildQuickActionChip('What did I see yesterday?'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Schedule reminder'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Analyze my day'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Take notes'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Search memories'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Read this text'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Translate'),
          const SizedBox(width: 12),
          _buildQuickActionChip('Set a timer'),
          const SizedBox(width: 12),
          // Duplicate first few for seamless loop
          _buildQuickActionChip('Summarize last meeting', showDot: true),
          const SizedBox(width: 12),
          _buildQuickActionChip('Find my glasses', showDot: true),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String text, {bool showDot = false}) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.getInputBackground(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: showDot
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.getBorderLight(context),
            width: 1,
          ),
          boxShadow: showDot
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.primary.withOpacity(0.2),
          highlightColor: AppColors.primary.withOpacity(0.1),
          onTap: () {
            // Auto-send to chat with smooth transition
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ChatScreen(initialQuery: text),
                transitionDuration: const Duration(milliseconds: 400),
                reverseTransitionDuration: const Duration(milliseconds: 350),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      // Chat screen slides UP from below smoothly
                      final slideIn =
                          Tween<Offset>(
                            begin: const Offset(0, 1.0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                      return SlideTransition(position: slideIn, child: child);
                    },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDot) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: showDot
                        ? AppColors.getTextPrimary(context)
                        : AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        // Dark glass background
        color: AppColors.getInputBackground(context),
        borderRadius: BorderRadius.circular(50),
        // Light edge glow effect
        border: Border.all(color: AppColors.getBorderLight(context), width: 1),
        boxShadow: [
          // Inner subtle glow
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 1,
            spreadRadius: 0,
          ),
          // Outer drop shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Plus button - Attachment options
          PopupMenuButton<String>(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getBorderLight(context),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.add,
                color: Colors.white.withOpacity(0.8),
                size: 22,
              ),
            ),
            color: AppColors.getSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            offset: const Offset(0, -200),
            onSelected: (value) async {
              switch (value) {
                case 'gallery':
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null && mounted) {
                    // Add to attached files for preview
                    setState(() {
                      _attachedFiles.add(image);
                    });
                  }
                  break;
                case 'camera':
                  // Open custom CameraScreen which handles photos and videos
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'gallery',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder_copy_rounded,
                        size: 20,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Files',
                      style: GoogleFonts.inter(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'camera',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Camera',
                      style: GoogleFonts.inter(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Small inline thumbnails (if files attached)
          if (_attachedFiles.isNotEmpty) ...[
            SizedBox(
              height: 40,
              width: _attachedFiles.length * 36.0, // 32px + 4px spacing each
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _attachedFiles.isNotEmpty
                    ? _attachedFiles.length
                    : 0,
                itemBuilder: (context, index) {
                  final file = _attachedFiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildSmallThumbnail(file),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Text input
          Expanded(
            child: TextField(
              controller: _inputController,
              style: GoogleFonts.inter(
                // keep style
                fontSize: 15,
                color: AppColors.getTextPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Ask anything or paste content...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.getTextMuted(context).withOpacity(0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (value.isNotEmpty || _attachedFiles.isNotEmpty) {
                  final files = List.from(_attachedFiles); // Copy the list
                  _inputController.clear();
                  setState(() => _attachedFiles.clear());
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          ChatScreen(
                            initialQuery: value.isNotEmpty ? value : null,
                            attachedFiles: files.isNotEmpty ? files : null,
                          ),
                      transitionDuration: const Duration(milliseconds: 400),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 350,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            // Chat screen slides UP from below smoothly
                            final slideIn =
                                Tween<Offset>(
                                  begin: const Offset(0, 1.0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );

                            return SlideTransition(
                              position: slideIn,
                              child: child,
                            );
                          },
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Microphone button for voice recording
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                // Stop and transcribe
                setState(() => _isRecording = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Transcribing...'),
                      ],
                    ),
                    backgroundColor: Color(0xFF3B82F6),
                    duration: const Duration(seconds: 2),
                  ),
                );

                try {
                  final result = await RecordingService()
                      .stopRecordingForTranscription();
                  if (result != null && mounted) {
                    final text = await ChatService().transcribeAudio(
                      result.bytes,
                      result.fileName,
                    );
                    if (mounted) {
                      setState(() {
                        final current = _inputController.text;
                        _inputController.text = current.isEmpty
                            ? text
                            : '$current $text';
                      });
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // Start recording
                final started = await RecordingService().startAudioRecording();
                if (started && mounted) {
                  setState(() => _isRecording = true);
                }
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withOpacity(0.1)
                    : AppColors.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording
                      ? Colors.red
                      : AppColors.getBorderLight(context),
                ),
              ),
              child: _isRecording
                  ? const Icon(Icons.stop_rounded, color: Colors.red, size: 22)
                  : Icon(Icons.mic_rounded, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          // Send button with green accent
          GestureDetector(
            onTap: () {
              final text = _inputController.text.trim();
              if (text.isNotEmpty || _attachedFiles.isNotEmpty) {
                final files = List.from(_attachedFiles); // Copy the list
                // Clear the input field and attachments
                _inputController.clear();
                setState(() => _attachedFiles.clear());
                // Navigate to ChatScreen with the query and files
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ChatScreen(
                          initialQuery: text.isNotEmpty ? text : null,
                          attachedFiles: files.isNotEmpty ? files : null,
                        ),
                    transitionDuration: const Duration(milliseconds: 400),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 350,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          final slideIn =
                              Tween<Offset>(
                                begin: const Offset(0.0, 0.3),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );
                          return SlideTransition(
                            position: slideIn,
                            child: child,
                          );
                        },
                  ),
                );
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a small 32x32 thumbnail for inline display in the input bar
  Widget _buildSmallThumbnail(XFile file) {
    final extension = file.name.toLowerCase().split('.').last;
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: isImage
                ? (kIsWeb
                      ? Image.network(
                          file.path,
                          fit: BoxFit.cover,
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildSmallFileIcon(extension),
                        )
                      : Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildSmallFileIcon(extension),
                        ))
                : _buildSmallFileIcon(extension),
          ),
        ),
        // Small X button
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _attachedFiles.remove(file);
              });
            },
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D0D0D), width: 1),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 8),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a small file icon for non-image files (32x32)
  Widget _buildSmallFileIcon(String extension) {
    IconData icon;
    Color color;

    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
        icon = Icons.videocam;
        color = Colors.purple;
        break;
      case 'mp3':
      case 'wav':
      case 'aac':
        icon = Icons.audiotrack;
        color = Colors.orange;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = AppColors.primary;
    }

    return Container(
      color: color.withOpacity(0.15),
      child: Center(child: Icon(icon, color: color, size: 16)),
    );
  }
}

/// Custom painter for drawing ring with dots at specified positions
class _RingWithDotsPainter extends CustomPainter {
  final double radius;
  final Color ringColor;
  final Color dotColor;
  final double dotRadius;
  final List<double> dotPositions; // in degrees

  _RingWithDotsPainter({
    required this.radius,
    required this.ringColor,
    required this.dotColor,
    required this.dotRadius,
    required this.dotPositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw dots at specified positions
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (final degrees in dotPositions) {
      final radians = degrees * math.pi / 180;
      final x = center.dx + radius * math.cos(radians - math.pi / 2);
      final y = center.dy + radius * math.sin(radians - math.pi / 2);
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
