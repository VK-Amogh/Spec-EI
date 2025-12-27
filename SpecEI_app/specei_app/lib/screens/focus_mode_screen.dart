import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Focus Mode Screen - Distraction-free focus session
class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with TickerProviderStateMixin {
  bool _isFocusing = false;
  bool _useTimer = false;
  int _focusDuration = 25; // minutes
  int _elapsedSeconds = 0;
  late AnimationController _pulseController;
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  void _startFocus() {
    setState(() {
      _isFocusing = true;
      _elapsedSeconds = 0;
    });
    _runTimer();
  }

  void _runTimer() async {
    while (_isFocusing && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_isFocusing && mounted) {
        setState(() {
          _elapsedSeconds++;
        });

        // Check if timer mode and time is up
        if (_useTimer && _elapsedSeconds >= _focusDuration * 60) {
          _endFocus();
        }
      }
    }
  }

  void _endFocus() {
    setState(() {
      _isFocusing = false;
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isFocusing ? _buildFocusingView() : _buildSetupView(),
      ),
    );
  }

  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Focus Mode',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Focus icon
          Center(
            child: AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                final scale = 1.0 + (_breatheController.value * 0.1);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF16A34A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology,
                      size: 60,
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),

          // Timer toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Timer',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Set a duration for your focus session',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _useTimer,
                  onChanged: (value) => setState(() => _useTimer = value),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Duration selector (if timer is on)
          if (_useTimer)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duration: $_focusDuration minutes',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _focusDuration.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.grey.shade800,
                    onChanged: (value) {
                      setState(() => _focusDuration = value.toInt());
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '5 min',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '120 min',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startFocus,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                'Start Focus Session',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tip
          Center(
            child: Text(
              _useTimer
                  ? 'You\'ll be notified when time is up'
                  : 'Focus until you\'re ready to stop',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusingView() {
    return GestureDetector(
      onTap: () {}, // Prevent accidental taps
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.background.withOpacity(0.95),
              const Color(0xFF0A1A0F),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Breathing orb
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.15);
                final opacity = 0.3 + (_pulseController.value * 0.3);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow
                    Transform.scale(
                      scale: scale * 1.3,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(opacity * 0.3),
                        ),
                      ),
                    ),
                    // Inner orb
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF16A34A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 60),

            // Timer display
            Text(
              _formatTime(_elapsedSeconds),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _useTimer
                  ? '${_focusDuration - (_elapsedSeconds ~/ 60)} min remaining'
                  : 'Open-ended focus',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 80),

            // Breathe text
            AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                final breathePhase = _breatheController.value < 0.5
                    ? 'Breathe in...'
                    : 'Breathe out...';
                return Text(
                  breathePhase,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            ),
            const SizedBox(height: 100),

            // End button
            TextButton(
              onPressed: _endFocus,
              child: Text(
                'End Focus Session',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
