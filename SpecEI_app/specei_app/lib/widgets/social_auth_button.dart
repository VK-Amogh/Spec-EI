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
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);

    // Stroke width (approx 18% of size)
    final double strokeWidth = w * 0.18;
    // Radius for the stroke center
    final double radius = (w - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // 1. Blue (Right Arc segment)
    // Starts from 0 (East) down to ~+80 deg
    paint.color = const Color(0xFF4285F4);
    // Draw from -8 deg to +85 deg to cover the right side gap nicely
    canvas.drawArc(rect, -0.15, 1.6, false, paint);

    // 2. Green (Bottom)
    // From end of Blue (~85 deg) to ~175 deg
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.35, 1.6, false, paint);

    // 3. Yellow (Left)
    // From ~175 deg to ~265 deg
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.9, 1.4, false, paint);

    // 4. Red (Top)
    // From ~265 deg to ~-25 deg (top right gap)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 4.25, 1.6, false, paint);

    // 5. Blue Bar (Filled Rect)
    paint.style = PaintingStyle.fill;
    paint.strokeWidth = 0;
    paint.color = const Color(0xFF4285F4);

    // The bar goes from center to the right edge, but slightly masked by the arc?
    // It sits horizontally centered-ish.
    // Width: radius (from center to almost edge)
    // Height: same as stroke width
    // Top: center.dy - strokeWidth/2
    // Left: center.dx (approx)

    // Adjust logic: Bar starts slight left of center to fully cover hole
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 2,
        center.dy - strokeWidth / 2,
        radius + strokeWidth / 2 + 2,
        strokeWidth,
      ),
      paint,
    );

    // Masking the left part of blue bar inside the G?
    // No, standard G has the bar going all the way to the blue arc on the right.
    // And on the left side, it stops at the center vertical line effectively.
    // The previous drawRect covers it.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
