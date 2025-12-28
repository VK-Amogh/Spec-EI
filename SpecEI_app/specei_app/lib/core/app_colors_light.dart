import 'package:flutter/material.dart';

/// SpecEI Light Theme Colors
/// Matching structure of app_colors.dart for light mode
class AppColorsLight {
  AppColorsLight._();

  // Core backgrounds
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFE8E8E8);

  // Primary brand colors (same as dark theme)
  static const Color primary = Color(0xFF4ADE80);
  static const Color primaryDark = Color(0xFF22C55E);
  static const Color primaryGlow = Color(0x804ADE80);

  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDimmed = Color(0xFF9CA3AF);

  // Border colors
  static const Color borderLight = Color(0x1A000000);
  static const Color borderMedium = Color(0x33000000);

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
      color: Colors.black.withOpacity(0.1),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];
}
