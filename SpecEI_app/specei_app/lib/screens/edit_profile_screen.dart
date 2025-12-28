import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

/// Edit Profile Screen
/// Allows users to view and edit their profile information
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _authService = AuthService();
  final _supabaseService = SupabaseService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _originalName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final profile = await _supabaseService.getUserProfile(user.uid);

      if (mounted) {
        setState(() {
          _nameController.text =
              profile?['full_name'] ?? user.displayName ?? '';
          _emailController.text = profile?['email'] ?? user.email ?? '';
          _phoneController.text = profile?['phone_number'] ?? '';
          _originalName = _nameController.text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }

    if (name == _originalName) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await _supabaseService.updateUserProfile(user.uid, {
        'full_name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Edit Profile',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimary : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile avatar
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.black,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.surface : Colors.white,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Name field (editable)
                  CustomTextField(
                    label: 'Full Name',
                    placeholder: 'Enter your name',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                  ),
                  const SizedBox(height: 16),

                  // Email field (locked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Address',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textMuted
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.inputBackground.withOpacity(0.5)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderLight
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: isDark
                                  ? AppColors.textMuted
                                  : Colors.grey[500],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _emailController.text,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.textMuted
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: isDark
                                  ? AppColors.textMuted
                                  : Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Phone field (locked if verified)
                  if (_phoneController.text.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone Number',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textMuted
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.inputBackground.withOpacity(0.5)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderLight
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 20,
                                color: isDark
                                    ? AppColors.textMuted
                                    : Colors.grey[500],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _phoneController.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColors.textMuted
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: isDark
                                    ? AppColors.textMuted
                                    : Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // Save button
                  PrimaryButton(
                    text: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: _saveProfile,
                  ),

                  const SizedBox(height: 16),

                  // Info text
                  Text(
                    'Email and phone number cannot be changed after verification',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? AppColors.textMuted : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
