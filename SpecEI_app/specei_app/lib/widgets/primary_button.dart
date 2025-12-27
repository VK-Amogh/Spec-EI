import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Primary action button with glow effect
/// Matches SpecEI design with green gradient and shadow
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.width ?? double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? Colors.transparent
                : (widget.isLoading
                      ? AppColors.primary.withOpacity(0.7)
                      : AppColors.primary.withOpacity(
                          _isPressed ? 0.8 : (_isHovered ? 0.8 : 1.0),
                        )),
            borderRadius: BorderRadius.circular(30),
            border: widget.onPressed == null
                ? Border.all(color: AppColors.primary.withOpacity(0.5))
                : null,
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
                    color: widget.onPressed == null
                        ? AppColors.primary.withOpacity(0.5)
                        : Colors.black,
                  ),
                ),
                if (widget.showArrow) ...[
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()
                      ..translate(_isPressed ? 4.0 : 0.0, 0.0),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: widget.onPressed == null
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.black,
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
