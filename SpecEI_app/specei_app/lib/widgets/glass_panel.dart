import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Glass panel container matching SpecEI design
/// Dark surface with white blurred glow and hover opacity change
class GlassPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool showTopGradient;
  final List<BoxShadow>? boxShadow;
  final bool enableHoverEffect;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 32,
    this.showTopGradient = false,
    this.boxShadow,
    this.enableHoverEffect = true,
  });

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowAnimation = Tween<double>(
      begin: 0.08,
      end: 0.15,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    if (!widget.enableHoverEffect) return;
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        onTapDown: (_) => _onHoverChanged(true),
        onTapUp: (_) => _onHoverChanged(false),
        onTapCancel: () => _onHoverChanged(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -2.0 : 0.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surface.withOpacity(0.95)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _isHovered
                  ? Colors.white.withOpacity(0.15)
                  : AppColors.borderLight,
            ),
            boxShadow:
                widget.boxShadow ??
                [
                  // White blurred glow effect
                  BoxShadow(
                    color: Colors.white.withOpacity(_glowAnimation.value),
                    blurRadius: 60,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 100,
                    spreadRadius: 0,
                  ),
                  // Standard shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
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
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primary.withOpacity(0.3),
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
      ),
    );
  }
}
