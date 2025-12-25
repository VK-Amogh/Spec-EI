import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/glass_panel.dart';
import '../services/auth_service.dart';

/// Forgot Password Screen - SpecEI
/// Matches design from _ai_hub_ultimate_ui_4
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(_emailController.text);
      setState(() => _emailSent = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background glow effect
          _buildBackgroundEffect(),

          // Main content
          SafeArea(
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
                        child: _emailSent
                            ? _buildSuccessContent()
                            : _buildFormContent(),
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

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Header
          Text(
            'Forgot Password?',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Enter the email associated with your account and we'll send you a link to reset your password.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Error message
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],

          // Email field
          CustomTextField(
            placeholder: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Send Reset Link button
          PrimaryButton(
            text: 'Send Reset Link',
            isLoading: _isLoading,
            onPressed: _handleSendResetLink,
          ),

          // Back to login link
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: Text(
                'Back to Login',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check Your Email',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          text: 'Back to Login',
          showArrow: false,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _emailController.clear();
            });
          },
          child: Text(
            'Try a different email',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
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
