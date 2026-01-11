import 'package:flutter/foundation.dart';

/// Production-safe logging utility for SpecEI
///
/// Features:
/// - Only logs in debug mode (kDebugMode)
/// - Masks sensitive data (user IDs, emails, tokens)
/// - Consistent log format across the app
///
/// Usage:
/// ```dart
/// AppLogger.debug('Loading user data');
/// AppLogger.info('User logged in: ${AppLogger.maskUserId(userId)}');
/// AppLogger.error('Failed to load', error);
/// ```
class AppLogger {
  /// Debug level log - only in debug mode
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// Info level log - only in debug mode
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// Warning level log - only in debug mode
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  /// Error level log - only in debug mode
  /// Consider sending to error tracking service in production
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null) {
        debugPrint(
          '  Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}',
        );
      }
    }
    // TODO: In production, send to error tracking (e.g., Sentry, Crashlytics)
  }

  /// Mask sensitive string data
  /// Shows only first N characters followed by asterisks
  ///
  /// Example: "user123abc" -> "user****"
  static String maskSensitive(String? value, {int visibleChars = 4}) {
    if (value == null || value.isEmpty) return '***';
    if (value.length <= visibleChars) return '***';
    return '${value.substring(0, visibleChars)}****';
  }

  /// Mask user ID for logging
  static String maskUserId(String? userId) {
    return maskSensitive(userId, visibleChars: 6);
  }

  /// Mask email for logging (shows first part before @)
  static String maskEmail(String? email) {
    if (email == null || !email.contains('@')) return '***@***';
    final parts = email.split('@');
    final localPart = parts[0];
    final maskedLocal = localPart.length > 2
        ? '${localPart.substring(0, 2)}***'
        : '***';
    return '$maskedLocal@${parts[1]}';
  }

  /// Mask API key or token
  static String maskToken(String? token) {
    return maskSensitive(token, visibleChars: 8);
  }
}
