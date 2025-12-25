import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Glass panel container matching SpecEI design
/// Dark surface with subtle border and shadow
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool showTopGradient;
  final List<BoxShadow>? boxShadow;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 32,
    this.showTopGradient = false,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: boxShadow ?? AppColors.panelShadow,
      ),
      child: Stack(
        children: [
          if (showTopGradient)
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
          Padding(padding: padding ?? const EdgeInsets.all(32), child: child),
        ],
      ),
    );
  }
}
