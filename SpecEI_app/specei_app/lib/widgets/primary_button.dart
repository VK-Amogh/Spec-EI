import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Primary action button with glow effect and click sound
/// Matches SpecEI design with minimized rounding
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showArrow;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.showArrow = true,
    this.width,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  /// Play haptic feedback and click sound
  void _playClickSound() {
    HapticFeedback.lightImpact();
    // System click sound via haptic feedback
    SystemSound.play(SystemSoundType.click);
  }

  void _handleTap() {
    if (widget.isLoading || widget.onPressed == null) return;
    _playClickSound();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.width ?? double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.primary.withOpacity(
                    _isPressed ? 0.8 : (_isHovered ? 0.9 : 1.0),
                  ),
            // Minimized rounding - was 30, now 12
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(
                        _isHovered ? 0.4 : 0.25,
                      ),
                      blurRadius: _isHovered ? 25 : 20,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              else ...[
                Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (widget.showArrow) ...[
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()
                      ..translate(_isPressed ? 4.0 : 0.0, 0.0),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
