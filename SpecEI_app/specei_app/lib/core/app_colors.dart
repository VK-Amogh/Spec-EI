import 'package:flutter/material.dart';

/// SpecEI Design System Colors
/// Extracted from reference HTML/CSS designs
class AppColors {
  AppColors._();

  // Core backgrounds
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color inputBackground = Color(0xFF1A1A1A);

  // Primary brand colors
  static const Color primary = Color(0xFF4ADE80);
  static const Color primaryDark = Color(0xFF22C55E);
  static const Color primaryGlow = Color(0x804ADE80);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDimmed = Color(0xFF4B5563);

  // Border colors
  static const Color borderLight = Color(0x0DFFFFFF);
  static const Color borderMedium = Color(0x1AFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> primaryButtonShadow = [
    BoxShadow(color: primary.withOpacity(0.2), blurRadius: 20, spreadRadius: 0),
  ];

  static List<BoxShadow> primaryButtonHoverShadow = [
    BoxShadow(color: primary.withOpacity(0.3), blurRadius: 25, spreadRadius: 0),
  ];

  static List<BoxShadow> panelShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];
}
