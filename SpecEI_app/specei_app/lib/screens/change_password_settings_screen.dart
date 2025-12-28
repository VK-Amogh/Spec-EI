import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/glass_panel.dart';
import 'otp_verification_screen.dart';

/// Change Password Settings Screen
/// Allows logged-in users to change their password using OTP verification
class ChangePasswordSettingsScreen extends StatefulWidget {
  const ChangePasswordSettingsScreen({super.key});

  @override
  State<ChangePasswordSettingsScreen> createState() =>
      _ChangePasswordSettingsScreenState();
}

class _ChangePasswordSettingsScreenState
    extends State<ChangePasswordSettingsScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  void _loadUserEmail() {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
      });
    }
  }

  Future<void> _handleSendOtp() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      setState(() => _errorMessage = 'No email associated with this account');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the same password reset flow as forgot password
      await _authService.sendPasswordResetEmail(_userEmail!);

      if (mounted) {
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                OtpVerificationScreen(
                  verificationType: 'email',
                  verificationTarget: _userEmail!,
                  isPasswordReset: true,
                ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.3, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background glow effect
          _buildBackgroundEffect(),

          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDark
                          ? AppColors.textSecondary
                          : Colors.grey[700],
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.surface
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo
                            _buildLogo(),
                            const SizedBox(height: 32),

                            // Form panel
                            GlassPanel(
                              padding: const EdgeInsets.all(32),
                              showTopGradient: true,
                              enableGlow: false,
                              child: _buildFormContent(isDark),
                            ),

                            // Secure connection text
                            const SizedBox(height: 32),
                            _buildSecureConnectionText(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffect() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 600,
            height: 600,
            transform: Matrix4.translationValues(0, -80, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'SpecEI',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          TextSpan(
            text: '.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(bool isDark) {
    return Column(
      children: [
        // Lock icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),

        // Header
        Text(
          'Change Password',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "We'll send a verification code to your email to confirm your identity before changing your password.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? AppColors.textSecondary : Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Error message
        if (_errorMessage != null) ...[
          _buildErrorMessage(),
          const SizedBox(height: 16),
        ],

        // Email display
        Container(
          padding: const EdgeInsets.all(16),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification email will be sent to:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userEmail ?? 'Loading...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.verified, size: 20, color: AppColors.primary),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Send OTP button
        PrimaryButton(
          text: 'Send Verification Code',
          onPressed: _userEmail != null ? _handleSendOtp : null,
          isLoading: _isLoading,
        ),

        const SizedBox(height: 16),

        // Info text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use code 123456 for testing',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureConnectionText() {
    return Opacity(
      opacity: 0.6,
      child: Text(
        'SECURE CONNECTION',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
