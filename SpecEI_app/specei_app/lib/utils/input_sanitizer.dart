import 'dart:convert';

/// Security Utility for sanitizing user inputs against Injection & XSS.
class InputSanitizer {
  static final _htmlEscape = HtmlEscape(HtmlEscapeMode.element);

  /// Sanitize general text input (e.g. chat messages, notes)
  /// Removes potentially dangerous characters or escapes them.
  static String sanitizeText(String input) {
    if (input.isEmpty) return input;
    // 1. HTML Escape (Basic XSS prevention)
    String sanitized = _htmlEscape.convert(input);

    // 2. Trim whitespace
    sanitized = sanitized.trim();

    return sanitized;
  }

  /// Sanitize SQL-sensitive input (Generic approach, though we use parameterized queries usually)
  /// Useful for search queries or raw filters.
  static String sanitizeForSql(String input) {
    // Parameterized queries are best, but this helps log cleaning etc.
    return input.replaceAll("'", "''").replaceAll(";", "");
  }

  /// Validate and Sanitize Filenames
  static String sanitizeFilename(String input) {
    // Allow alphanumerics, underscores, hyphens, dots.
    // Block slashes, backslashes, null bytes.
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  }
}
