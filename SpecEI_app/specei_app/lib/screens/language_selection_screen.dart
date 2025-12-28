import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_translations.dart';
import '../services/locale_service.dart';

/// Language Selection Screen
/// Allows users to select their preferred app language
/// Language changes are applied immediately throughout the app
class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文', 'flag': '🇨🇳'},
    {'code': 'ja', 'name': 'Japanese', 'native': '日本語', 'flag': '🇯🇵'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeService = Provider.of<LocaleService>(context);
    final currentLang = localeService.locale.languageCode;

    // Get translations for current language
    String tr(String key) => AppTranslations.translate(key, currentLang);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppColors.textSecondary : Colors.grey[700],
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('language'),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimary : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('select_language').toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textMuted : Colors.grey[600],
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            // Language options container
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: _languages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final language = entry.value;
                  final isLast = index == _languages.length - 1;
                  final isSelected = currentLang == language['code'];

                  return Column(
                    children: [
                      _buildLanguageOption(
                        context: context,
                        flag: language['flag']!,
                        name: language['name']!,
                        native: language['native']!,
                        code: language['code']!,
                        isSelected: isSelected,
                        onTap: () {
                          localeService.setLocale(Locale(language['code']!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${tr('language_changed')} ${language['native']}',
                                style: GoogleFonts.inter(),
                              ),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                      if (!isLast) _buildDivider(isDark),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Info note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('language_note'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String flag,
    required String name,
    required String native,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  Text(
                    native,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? AppColors.textMuted : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.black),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.textMuted : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Container(
        height: 1,
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
      ),
    );
  }
}
