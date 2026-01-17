import 'package:flutter/material.dart';

/// SpecEI Design System Colors
/// Extracted from reference HTML/CSS designs
/// Use static colors for dark theme, or dynamic methods for theme-aware colors
class AppColors {
  AppColors._();

  // Core backgrounds (dark theme - static)
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF0F0F0F);
  static const Color inputBackground = Color(0xFF0F0F0F);

  // Primary brand colors (same for both themes)
  static const Color primary = Color(0xFF137E3E); // Brand Accent
  static const Color primaryDark = Color(0xFF0E5E2E);
  static const Color primaryHighlight = Color(0xFF00FF88); // Neon Highlight
  static const Color primaryGlow = Color(0x8000FF88);

  // Text colors (dark theme - static)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF888888);
  static const Color textDimmed = Color(0xFF888888);

  // Border colors (dark theme - static)
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

  // ==================== DYNAMIC THEME-AWARE COLORS ====================
  // Use these methods when you want colors to change with theme

  /// Check if current theme is dark
  static bool isDark(BuildContext context) {
    return true; // Force dark mode
  }

  /// Get background color based on current theme
  static Color getBackground(BuildContext context) {
    return background;
  }

  /// Get surface color based on current theme
  static Color getSurface(BuildContext context) {
    return surface;
  }

  /// Get input background based on current theme
  static Color getInputBackground(BuildContext context) {
    return inputBackground;
  }

  /// Get primary text color based on current theme
  static Color getTextPrimary(BuildContext context) {
    return textPrimary;
  }

  /// Get secondary text color based on current theme
  static Color getTextSecondary(BuildContext context) {
    return textSecondary;
  }

  /// Get muted text color based on current theme
  static Color getTextMuted(BuildContext context) {
    return textMuted;
  }

  /// Get border color based on current theme
  static Color getBorderLight(BuildContext context) {
    return borderLight;
  }
}
