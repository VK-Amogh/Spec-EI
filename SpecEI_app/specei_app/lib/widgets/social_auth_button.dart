import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Social authentication button (Google/Apple)
/// Dark glassmorphic style with hover effects and click sound
class SocialAuthButton extends StatefulWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  const SocialAuthButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  /// Google sign-in button with improved colored icon
  factory SocialAuthButton.google({VoidCallback? onPressed}) {
    return SocialAuthButton(
      label: 'Google',
      icon: const _GoogleColoredIcon(),
      onPressed: onPressed,
    );
  }

  /// Apple sign-in button
  factory SocialAuthButton.apple({VoidCallback? onPressed}) {
    return SocialAuthButton(
      label: 'Apple',
      icon: const Icon(Icons.apple, size: 20, color: Colors.white),
      onPressed: onPressed,
    );
  }

  @override
  State<SocialAuthButton> createState() => _SocialAuthButtonState();
}

class _SocialAuthButtonState extends State<SocialAuthButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  /// Play haptic feedback and click sound
  void _playClickSound() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    _playClickSound();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF222222)
                : AppColors.inputBackground,
            // Minimized rounding - was 12, keeping at 12 for consistency
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? Colors.white.withOpacity(0.2)
                  : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isHovered
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
}

/// Improved Google icon with official brand colors
class _GoogleColoredIcon extends StatelessWidget {
  const _GoogleColoredIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleColoredLogoPainter()),
    );
  }
}

/// Google logo painter with official brand colors
class _GoogleColoredLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    // Scale factor for the paths
    final double scale = w / 24;

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    // Blue section (right side + bar)
    Path bluePath = Path();
    bluePath.moveTo(22.56 * scale, 12.25 * scale);
    bluePath.cubicTo(
      22.56 * scale,
      11.47 * scale,
      22.49 * scale,
      10.72 * scale,
      22.36 * scale,
      10.0 * scale,
    );
    bluePath.lineTo(12 * scale, 10.0 * scale);
    bluePath.lineTo(12 * scale, 14.26 * scale);
    bluePath.lineTo(17.92 * scale, 14.26 * scale);
    bluePath.cubicTo(
      17.66 * scale,
      15.63 * scale,
      16.88 * scale,
      16.79 * scale,
      15.71 * scale,
      17.57 * scale,
    );
    bluePath.lineTo(15.71 * scale, 20.34 * scale);
    bluePath.lineTo(19.28 * scale, 20.34 * scale);
    bluePath.cubicTo(
      21.36 * scale,
      18.42 * scale,
      22.56 * scale,
      15.6 * scale,
      22.56 * scale,
      12.25 * scale,
    );
    bluePath.close();
    canvas.drawPath(bluePath, bluePaint);

    // Green section (bottom right)
    Path greenPath = Path();
    greenPath.moveTo(12 * scale, 23 * scale);
    greenPath.cubicTo(
      14.97 * scale,
      23 * scale,
      17.46 * scale,
      22.02 * scale,
      19.28 * scale,
      20.34 * scale,
    );
    greenPath.lineTo(15.71 * scale, 17.57 * scale);
    greenPath.cubicTo(
      14.73 * scale,
      18.23 * scale,
      13.48 * scale,
      18.63 * scale,
      12 * scale,
      18.63 * scale,
    );
    greenPath.cubicTo(
      9.14 * scale,
      18.63 * scale,
      6.71 * scale,
      16.7 * scale,
      5.84 * scale,
      14.1 * scale,
    );
    greenPath.lineTo(2.18 * scale, 14.1 * scale);
    greenPath.lineTo(2.18 * scale, 16.94 * scale);
    greenPath.cubicTo(
      3.99 * scale,
      20.53 * scale,
      7.7 * scale,
      23 * scale,
      12 * scale,
      23 * scale,
    );
    greenPath.close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow section (bottom left)
    Path yellowPath = Path();
    yellowPath.moveTo(5.84 * scale, 14.09 * scale);
    yellowPath.cubicTo(
      5.62 * scale,
      13.43 * scale,
      5.49 * scale,
      12.73 * scale,
      5.49 * scale,
      12 * scale,
    );
    yellowPath.cubicTo(
      5.49 * scale,
      11.27 * scale,
      5.62 * scale,
      10.57 * scale,
      5.84 * scale,
      9.91 * scale,
    );
    yellowPath.lineTo(5.84 * scale, 7.07 * scale);
    yellowPath.lineTo(2.18 * scale, 7.07 * scale);
    yellowPath.cubicTo(
      1.43 * scale,
      8.55 * scale,
      1 * scale,
      10.22 * scale,
      1 * scale,
      12 * scale,
    );
    yellowPath.cubicTo(
      1 * scale,
      13.78 * scale,
      1.43 * scale,
      15.45 * scale,
      2.18 * scale,
      16.93 * scale,
    );
    yellowPath.lineTo(5.84 * scale, 14.09 * scale);
    yellowPath.close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red section (top)
    Path redPath = Path();
    redPath.moveTo(12 * scale, 5.38 * scale);
    redPath.cubicTo(
      13.62 * scale,
      5.38 * scale,
      15.06 * scale,
      5.94 * scale,
      16.21 * scale,
      7.02 * scale,
    );
    redPath.lineTo(19.36 * scale, 3.87 * scale);
    redPath.cubicTo(
      17.45 * scale,
      2.09 * scale,
      14.97 * scale,
      1 * scale,
      12 * scale,
      1 * scale,
    );
    redPath.cubicTo(
      7.7 * scale,
      1 * scale,
      3.99 * scale,
      3.47 * scale,
      2.18 * scale,
      7.07 * scale,
    );
    redPath.lineTo(5.84 * scale, 9.91 * scale);
    redPath.cubicTo(
      6.71 * scale,
      7.31 * scale,
      9.14 * scale,
      5.38 * scale,
      12 * scale,
      5.38 * scale,
    );
    redPath.close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
