import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Social authentication button (Google/Apple)
/// Dark glassmorphic style with hover effects
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

  /// Google sign-in button
  factory SocialAuthButton.google({VoidCallback? onPressed}) {
    return SocialAuthButton(
      label: 'Google',
      icon: _GoogleIcon(),
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF222222)
                : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? AppColors.borderMedium
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

/// Google icon widget
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

/// Google logo painter
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.96, size.height * 0.42)
        ..lineTo(size.width * 0.5, size.height * 0.42)
        ..lineTo(size.width * 0.5, size.height * 0.58)
        ..lineTo(size.width * 0.78, size.height * 0.58)
        ..cubicTo(
          size.width * 0.72,
          size.height * 0.74,
          size.width * 0.62,
          size.height * 0.84,
          size.width * 0.5,
          size.height * 0.84,
        )
        ..cubicTo(
          size.width * 0.31,
          size.height * 0.84,
          size.width * 0.16,
          size.height * 0.69,
          size.width * 0.16,
          size.height * 0.5,
        )
        ..cubicTo(
          size.width * 0.16,
          size.height * 0.31,
          size.width * 0.31,
          size.height * 0.16,
          size.width * 0.5,
          size.height * 0.16,
        )
        ..cubicTo(
          size.width * 0.62,
          size.height * 0.16,
          size.width * 0.72,
          size.height * 0.22,
          size.width * 0.79,
          size.height * 0.31,
        )
        ..lineTo(size.width * 0.91, size.height * 0.19)
        ..cubicTo(
          size.width * 0.81,
          size.height * 0.08,
          size.width * 0.66,
          size.height * 0.0,
          size.width * 0.5,
          size.height * 0.0,
        )
        ..cubicTo(
          size.width * 0.22,
          size.height * 0.0,
          0,
          size.height * 0.22,
          0,
          size.height * 0.5,
        )
        ..cubicTo(
          0,
          size.height * 0.78,
          size.width * 0.22,
          size.height,
          size.width * 0.5,
          size.height,
        )
        ..cubicTo(
          size.width * 0.87,
          size.height,
          size.width,
          size.height * 0.71,
          size.width,
          size.height * 0.46,
        )
        ..lineTo(size.width, size.height * 0.42)
        ..lineTo(size.width * 0.96, size.height * 0.42)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
