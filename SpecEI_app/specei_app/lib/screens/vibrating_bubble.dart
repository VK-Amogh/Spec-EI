import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class VibratingVoiceBubble extends StatefulWidget {
  const VibratingVoiceBubble({super.key});

  @override
  State<VibratingVoiceBubble> createState() => _VibratingVoiceBubbleState();
}

class _VibratingVoiceBubbleState extends State<VibratingVoiceBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Simulate random-ish vibration using sine waves
        // A main pulse + a faster jitter
        final t = _controller.value;
        final scale =
            1.0 +
            (0.15 * (0.5 + 0.5 * DateTime.now().millisecond % 100 / 100)) *
                (1 - (2 * t - 1).abs()); // Pulsing

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.6 * (1 - t)),
                blurRadius: 12 * scale,
                spreadRadius: 2 * scale,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
