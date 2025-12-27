import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Glass panel container matching SpecEI design
/// Dark surface with subtle border, shadow, and hover glow effect
class GlassPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool showTopGradient;
  final List<BoxShadow>? boxShadow;
  final bool enableGlow;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 32,
    this.showTopGradient = false,
    this.boxShadow,
    this.enableGlow = true,
  });

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: AppColors.borderLight),
          boxShadow:
              widget.boxShadow ??
              [
                // Base shadow
                ...AppColors.panelShadow,
                // Glow effect on hover (only if enabled)
                if (_isHovered && widget.enableGlow)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 80,
                    spreadRadius: 2,
                  ),
              ],
        ),
        child: Stack(
          children: [
            if (widget.showTopGradient)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _isHovered
                            ? Colors.white.withOpacity(0.8)
                            : Colors.white.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: widget.padding ?? const EdgeInsets.all(32),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
