import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/app_colors.dart';

class VoiceInteractionBall extends StatefulWidget {
  final bool isListening; // AI is listening (Pulse)
  final bool isSpeaking; // AI is speaking (Ripple)
  final double audioLevel; // User audio level (0.0 to 1.0) for vibration

  const VoiceInteractionBall({
    super.key,
    required this.isListening,
    required this.isSpeaking,
    this.audioLevel = 0.0,
  });

  @override
  State<VoiceInteractionBall> createState() => _VoiceInteractionBallState();
}

class _VoiceInteractionBallState extends State<VoiceInteractionBall>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _waveController;
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();

    // Pulse Animation (Breathing effect when listening)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Ripple Animation (Expanding rings when AI speaks)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Waveform/Vibration Animation (Jitter when user speaks)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    // Idle Animation (Soft breathing glow always active)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _waveController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. AI Speaking Ripples (Only when AI is speaking)
          if (widget.isSpeaking) ..._buildRipples(),

          // 2. Background Glow (State Dependent)
          AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _idleController,
              _waveController,
            ]),
            builder: (context, child) {
              double glowSpread = 10.0;
              double glowOpacity = 0.3;
              Color glowColor = AppColors.primary;

              if (widget.isListening) {
                // Listening: Gentle Pulse
                glowSpread = 20.0 + (_pulseController.value * 20.0);
                glowOpacity = 0.4 + (_pulseController.value * 0.2);
              } else if (widget.audioLevel > 0.05) {
                // Speaking: Reacts to audio level
                glowSpread = 20.0 + (widget.audioLevel * 40.0);
                glowOpacity = 0.5 + (widget.audioLevel * 0.4);
                glowColor =
                    AppColors.primaryHighlight; // Brighten when speaking
              } else {
                // Idle: Soft Breathing
                glowSpread = 10.0 + (_idleController.value * 15.0);
                glowOpacity = 0.2 + (_idleController.value * 0.15);
              }

              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent, // No solid fill
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(glowOpacity.clamp(0.0, 1.0)),
                      blurRadius: 50, // Soft diffuse glow
                      spreadRadius: glowSpread,
                    ),
                    // Core brightness
                    BoxShadow(
                      color: glowColor.withOpacity(
                        (glowOpacity + 0.2).clamp(0.0, 1.0),
                      ),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              );
            },
          ),

          // 3. The Symbol (EvenEi Logo)
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              // Calculate vibration scale based on audio level
              double vibration = 0.0;
              if (widget.audioLevel > 0.05) {
                // Jitter effect scaled by audio level
                vibration =
                    math.sin(_waveController.value * math.pi * 2) *
                    widget.audioLevel *
                    0.1;
              }

              // Gentle float/scale when listening
              final breathingScale = widget.isListening
                  ? 1.0 + (_pulseController.value * 0.03)
                  : 1.0;

              return Transform.scale(
                scale: breathingScale + vibration,
                child: ClipOval(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      1, 0, 0, 0, 0,
                      0, 1, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      0.8,
                      0.8,
                      0.8,
                      0,
                      0, // Boost alpha: Silver becomes solid, Black stays transparent
                    ]),
                    child: Image.asset(
                      'assets/evenei_logo_center.jpg',
                      width: 100, // Increased size
                      height: 100,
                      fit: BoxFit.contain,
                    ),
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
          final scale = 1.0 + (_rippleController.value * 1.5); // Wider ripples
          final opacity = 0.4 * (1 - _rippleController.value);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80, // Match logo size base
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(opacity),
                  width: 1.5,
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
          final scale = 1.0 + (adjustedValue * 1.5);
          final opacity = 0.4 * (1 - adjustedValue);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(opacity),
                  width: 1, // Thinner
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}
