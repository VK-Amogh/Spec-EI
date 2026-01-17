import 'package:flutter/material.dart';

class BreathingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double spreadRadius;
  final double blurRadius;
  final Duration duration;
  final bool enableFloating;
  final double floatingRange;
  final double maxOpacity;

  const BreathingGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.spreadRadius = 2.0,
    this.blurRadius = 10.0,
    this.duration = const Duration(seconds: 2),
    this.maxOpacity = 0.4,
    this.enableFloating = false,
    this.floatingRange = 10.0,
  });

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _hoverController;
  late Animation<double> _animation;
  late Animation<double> _floatAnimation;

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = Tween<double>(
      begin: 0.2, // Min intensity
      end: 1.0, // Max intensity
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _floatAnimation = Tween<double>(
      begin: -widget.floatingRange / 2,
      end: widget.floatingRange / 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovering) {
    if (isHovering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
    setState(() => _isHovering = isHovering);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: Listenable.merge([_animation, _hoverController]),
        builder: (context, child) {
          // Glow opacity depends on both breathing cycle and hover state
          // If not hovering, opacity fades to 0
          final effectiveOpacity =
              widget.maxOpacity * _animation.value * _hoverController.value;

          return Transform.translate(
            offset: widget.enableFloating
                ? Offset(0, _floatAnimation.value)
                : Offset.zero,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  if (effectiveOpacity >
                      0.01) // Optimization: don't draw shadow if invisible
                    BoxShadow(
                      color: widget.glowColor.withOpacity(effectiveOpacity),
                      blurRadius: widget.blurRadius * _animation.value,
                      spreadRadius: widget.spreadRadius * _animation.value,
                    ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
