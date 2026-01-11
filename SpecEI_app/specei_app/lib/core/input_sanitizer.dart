/// Input Sanitization Utilities for SpecEI
///
/// Provides security-focused input sanitization to prevent:
/// - Prompt injection attacks on AI services
/// - XSS and HTML injection
/// - SQL injection patterns
/// - Command injection
///
/// Usage:
/// ```dart
/// final safeInput = InputSanitizer.sanitizeForAI(userInput);
/// final safeHtml = InputSanitizer.stripHtml(userContent);
/// ```
class InputSanitizer {
  /// Sanitize user input before sending to AI services
  /// Removes common prompt injection patterns while preserving meaning
  static String sanitizeForAI(String input) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Remove code blocks that might contain injection attempts
    sanitized = sanitized.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      '[code removed]',
    );

    // Remove XML/HTML tags
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]+>'), '');

    // Remove common prompt injection patterns
    sanitized = sanitized.replaceAll(
      RegExp(
        r'ignore\s+(previous|all|above)\s+instructions?',
        caseSensitive: false,
      ),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'disregard\s+(previous|all|above)', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'forget\s+(everything|all|previous)', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'new\s+instructions?:', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'system\s*:', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'assistant\s*:', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'user\s*:', caseSensitive: false),
      '',
    );

    // Remove escape sequences that might break context
    sanitized = sanitized.replaceAll(RegExp(r'\\n\\n\\n+'), '\n\n');

    // Trim excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s{3,}'), '  ');

    return sanitized.trim();
  }

  /// Strip all HTML/XML tags from input
  static String stripHtml(String input) {
    if (input.isEmpty) return input;
    return input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Sanitize for safe display (prevent XSS)
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Sanitize filename to prevent path traversal
  static String sanitizeFilename(String filename) {
    // Remove path separators and dangerous characters
    return filename
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'\.\.'), '_')
        .replaceAll(RegExp(r'[<>:"|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Validate and sanitize URL
  static String? sanitizeUrl(String url) {
    final trimmed = url.trim();

    // Only allow http and https
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }

    // Basic URL validation
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.isEmpty) return null;
      return uri.toString();
    } catch (_) {
      return null;
    }
  }

  /// Limit input length to prevent DoS
  static String truncate(String input, {int maxLength = 10000}) {
    if (input.length <= maxLength) return input;
    return '${input.substring(0, maxLength)}... [truncated]';
  }

  /// Validate email format (basic check)
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email.trim());
  }

  /// Validate phone number format (basic check)
  static bool isValidPhone(String phone) {
    // Allow digits, spaces, dashes, parentheses, and plus sign
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return RegExp(r'^\d{10,15}$').hasMatch(cleaned);
  }
}
