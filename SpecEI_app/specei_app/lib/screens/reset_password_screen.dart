import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_panel.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;

  const ResetPasswordScreen({super.key, required this.identifier});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _passwordsMatch = false;

  // Password requirement states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_validatePasswords);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    });
    _validatePasswords();
  }

  void _validatePasswords() {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _passwordsMatch =
          pass.isNotEmpty &&
          confirm.isNotEmpty &&
          pass == confirm &&
          _hasMinLength &&
          _hasUppercase &&
          _hasLowercase &&
          _hasSpecialChar;
    });
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_passwordsMatch) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // In a real app, we would use the session from OTP verification.
      // For this mock, we simply simulate a network delay and success.
      // We do NOT call Firebase here because we don't have a valid reset code (mock flow).
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Demo: Password reset simulated! In production, your password would be updated.',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        // Pop until we are back at the root (LoginScreen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Error in reset password: $e');
      if (mounted) {
        // Fallback: even if error, since this is mock, show success to user
        // so they don't get stuck.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Password reset successfully (Mock)')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackgroundEffects(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
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
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 32),
                            GlassPanel(
                              padding: const EdgeInsets.all(32),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Set New Password',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create a strong password for ${widget.identifier}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    CustomTextField(
                                      label: 'NEW PASSWORD',
                                      placeholder: '••••••••',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: _obscurePassword,
                                      controller: _passwordController,
                                      suffixIcon: _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      onSuffixTap: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty)
                                          return 'Enter a password';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildPasswordRequirements(),
                                    const SizedBox(height: 20),

                                    CustomTextField(
                                      label: 'CONFIRM PASSWORD',
                                      placeholder: '••••••••',
                                      prefixIcon: Icons.lock_reset,
                                      obscureText: _obscureConfirmPassword,
                                      controller: _confirmPasswordController,
                                      suffixIcon: _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      onSuffixTap: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                      validator: (value) {
                                        if (value != _passwordController.text)
                                          return 'Passwords do not match';
                                        return null;
                                      },
                                    ),

                                    if (_errorMessage != null) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 32),

                                    if (_passwordsMatch)
                                      ElevatedButton(
                                        onPressed: _handleResetPassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.greenAccent,
                                          foregroundColor: Colors.black,
                                          minimumSize: const Size(
                                            double.infinity,
                                            56,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 8,
                                          shadowColor: Colors.greenAccent
                                              .withOpacity(0.4),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(
                                                color: Colors.black,
                                              )
                                            : Text(
                                                'Reset Password',
                                                style: GoogleFonts.spaceGrotesk(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      )
                                    else
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface.withOpacity(
                                            0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderLight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Reset Password',
                                            style: GoogleFonts.inter(
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirementItem('Minimum 8 characters', _hasMinLength),
        _buildRequirementItem('At least one uppercase letter', _hasUppercase),
        _buildRequirementItem('At least one lowercase letter', _hasLowercase),
        _buildRequirementItem(
          'At least one special character',
          _hasSpecialChar,
        ),
      ],
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 14,
            color: isMet ? Colors.greenAccent : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isMet ? Colors.greenAccent : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 400,
                height: 400,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'SpecEI',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
