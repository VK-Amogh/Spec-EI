import 'package:flutter/material.dart';
import 'app_colors_light.dart';

/// SpecEI Design System Colors
/// Extracted from reference HTML/CSS designs
/// Use static colors for dark theme, or dynamic methods for theme-aware colors
class AppColors {
  AppColors._();

  // Core backgrounds (dark theme - static)
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color inputBackground = Color(0xFF1A1A1A);

  // Primary brand colors (same for both themes)
  static const Color primary = Color(0xFF4ADE80);
  static const Color primaryDark = Color(0xFF22C55E);
  static const Color primaryGlow = Color(0x804ADE80);

  // Text colors (dark theme - static)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDimmed = Color(0xFF4B5563);

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
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get background color based on current theme
  static Color getBackground(BuildContext context) {
    return isDark(context) ? background : AppColorsLight.background;
  }

  /// Get surface color based on current theme
  static Color getSurface(BuildContext context) {
    return isDark(context) ? surface : AppColorsLight.surface;
  }

  /// Get input background based on current theme
  static Color getInputBackground(BuildContext context) {
    return isDark(context) ? inputBackground : AppColorsLight.inputBackground;
  }

  /// Get primary text color based on current theme
  static Color getTextPrimary(BuildContext context) {
    return isDark(context) ? textPrimary : AppColorsLight.textPrimary;
  }

  /// Get secondary text color based on current theme
  static Color getTextSecondary(BuildContext context) {
    return isDark(context) ? textSecondary : AppColorsLight.textSecondary;
  }

  /// Get muted text color based on current theme
  static Color getTextMuted(BuildContext context) {
    return isDark(context) ? textMuted : AppColorsLight.textMuted;
  }

  /// Get border color based on current theme
  static Color getBorderLight(BuildContext context) {
    return isDark(context) ? borderLight : AppColorsLight.borderLight;
  }
}
