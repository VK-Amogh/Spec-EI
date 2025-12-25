import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../core/app_colors.dart';
import '../chat_screen.dart';

/// Home Tab - AI Hub with animated orb
/// Matches design from home_/_ai_hub_ultimate_ui_1
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _rippleController;
  late AnimationController _ring1Controller;
  late AnimationController _ring2Controller;
  late AnimationController _marqueeController;
  late ScrollController _promptScrollController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _ring1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _ring2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    // Marquee auto-scroll setup
    _promptScrollController = ScrollController();
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    );

    // Start auto-scroll after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarqueeAnimation();
    });
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
    _orbController.dispose();
    _rippleController.dispose();
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    _marqueeController.dispose();
    _promptScrollController.dispose();
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

                // Animated orb
                _buildAnimatedOrb(),
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
                  color: AppColors.textPrimary,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              color: AppColors.textSecondary,
            ),
          ),
          _buildDivider(),

          // Battery
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '82%',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          _buildDivider(),

          // Syncing
          Icon(Icons.wifi_tethering, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            'Syncing...',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
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
      color: Colors.grey.shade700,
    );
  }

  Widget _buildAnimatedOrb() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring with multiple dots
          AnimatedBuilder(
            animation: _ring1Controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _ring1Controller.value * 2 * math.pi,
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: _RingWithDotsPainter(
                      radius: 140,
                      ringColor: Colors.grey.shade800,
                      dotColor: AppColors.primary,
                      dotRadius: 5,
                      dotPositions: [0, 90, 180, 270], // degrees
                    ),
                  ),
                ),
              );
            },
          ),

          // Inner dashed ring with dots (rotates opposite direction)
          AnimatedBuilder(
            animation: _ring2Controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_ring2Controller.value * 2 * math.pi,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _RingWithDotsPainter(
                      radius: 120,
                      ringColor: Colors.grey.shade800,
                      dotColor: AppColors.primary.withOpacity(0.7),
                      dotRadius: 4,
                      dotPositions: [45, 135, 225, 315], // offset degrees
                    ),
                  ),
                ),
              );
            },
          ),

          // Glowing ring
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade800, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Ripple effects
          ..._buildRipples(),

          // Core orb
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              final scale = 1.0 + (_orbController.value * 0.05);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRipples() {
    return [
      AnimatedBuilder(
        animation: _rippleController,
        builder: (context, child) {
          final scale = 0.8 + (_rippleController.value * 0.7);
          final opacity = 0.6 * (1 - _rippleController.value);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(opacity),
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _rippleController,
        builder: (context, child) {
          final adjustedValue = (_rippleController.value + 0.5) % 1.0;
          final scale = 0.8 + (adjustedValue * 0.7);
          final opacity = 0.6 * (1 - adjustedValue);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(opacity),
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    ];
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
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(Icons.more_horiz, size: 16, color: AppColors.textDimmed),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDashboardCard(
                icon: Icons.event,
                iconColor: Colors.blue.shade400,
                label: 'In 15m',
                title: 'Meeting with',
                subtitle: 'Design Team',
              ),
              const SizedBox(width: 12),
              _buildDashboardCard(
                icon: Icons.auto_graph,
                iconColor: AppColors.primary,
                label: 'Focus',
                labelColor: AppColors.primary,
                title: 'Deep Work',
                subtitle: '2h Predicted',
                showAccent: true,
              ),
              const SizedBox(width: 12),
              _buildDashboardCard(
                icon: Icons.history_edu,
                iconColor: Colors.purple.shade400,
                title: 'Yesterday',
                subtitle: 'Cafe Ideas...',
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
  }) {
    return Container(
      width: 156,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        // Light edge glow
        border: Border.all(
          color: showAccent
              ? AppColors.primary.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
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
                if (label != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (labelColor ?? AppColors.textMuted).withOpacity(
                        0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.textMuted,
                      ),
                    ),
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
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
      child: InkWell(
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
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.primary.withOpacity(0.2),
        highlightColor: AppColors.primary.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: showDot
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.08),
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
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
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
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(50),
        // Light edge glow effect
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
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
          // Plus button - matching roundness
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.add,
              color: Colors.white.withOpacity(0.8),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Text input
          Expanded(
            child: TextField(
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ask anything or paste content...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textMuted.withOpacity(0.5),
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
                if (value.isNotEmpty) {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          ChatScreen(initialQuery: value),
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
          // Send button with green accent
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
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
        ],
      ),
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
