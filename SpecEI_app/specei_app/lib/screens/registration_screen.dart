import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_auth_button.dart';
import '../widgets/glass_panel.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

/// Registration Screen - SpecEI Account Creation
/// With Email and Phone OTP Verification Flow
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _supabaseService = SupabaseService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Verification states
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  bool _showVerifyEmailButton = false;
  bool _showVerifyPhoneButton = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final email = _emailController.text.toLowerCase().trim();
    final isValidGmail = email.endsWith('@gmail.com') && email.length > 11;
    setState(() {
      _showVerifyEmailButton = isValidGmail && !_isEmailVerified;
    });
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final isValidPhone = phone.length == 10;
    setState(() {
      _showVerifyPhoneButton = isValidPhone && !_isPhoneVerified;
    });
  }

  bool get _passwordsMatch {
    return _passwordController.text == _confirmPasswordController.text;
  }

  bool get _showPasswordMismatch {
    return _confirmPasswordController.text.isNotEmpty && !_passwordsMatch;
  }

  bool get _canSignUp {
    return _isEmailVerified &&
        _isPhoneVerified &&
        _passwordController.text.length >= 6 &&
        _passwordsMatch &&
        _nameController.text.isNotEmpty;
  }

  Future<void> _verifyEmail() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OtpVerificationScreen(
          verificationType: 'email',
          verificationTarget: _emailController.text,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _isEmailVerified = true;
        _showVerifyEmailButton = false;
      });
    }
  }

  Future<void> _verifyPhone() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OtpVerificationScreen(
          verificationType: 'phone',
          verificationTarget: '+91 ${_phoneController.text}',
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _isPhoneVerified = true;
        _showVerifyPhoneButton = false;
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSignUp) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create Firebase account
      final credential = await _authService.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
      );

      // Update display name
      await _authService.updateDisplayName(_nameController.text);

      // Store user profile in Supabase
      if (credential.user != null) {
        await _supabaseService.createUserProfile(
          firebaseUid: credential.user!.uid,
          email: _emailController.text,
          fullName: _nameController.text,
          phoneNumber: '+91${_phoneController.text}',
        );
      }

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  child: Icon(Icons.check, color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Account Created!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to SpecEI, ${_nameController.text}!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    'Continue to Login',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && result.user != null) {
        final exists = await _supabaseService.userProfileExists(
          result.user!.uid,
        );
        if (!exists) {
          await _supabaseService.createUserProfile(
            firebaseUid: result.user!.uid,
            email: result.user!.email ?? '',
            fullName: result.user!.displayName ?? 'User',
          );
        }
      } else if (mounted) {
        setState(() => _errorMessage = 'Google sign up was cancelled');
      }
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
          _buildBackgroundEffects(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogoSection(),
                      const SizedBox(height: 32),
                      GlassPanel(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_errorMessage != null) ...[
                                _buildErrorMessage(),
                                const SizedBox(height: 16),
                              ],

                              // Full Name field
                              _buildNameField(),
                              const SizedBox(height: 20),

                              // Email field with verify button
                              _buildEmailField(),
                              const SizedBox(height: 20),

                              // Phone field (enabled after email verified)
                              _buildPhoneField(),
                              const SizedBox(height: 20),

                              // Password fields (enabled after both verified)
                              _buildPasswordFields(),
                              const SizedBox(height: 24),

                              // Sign Up button
                              PrimaryButton(
                                text: 'Sign Up',
                                isLoading: _isLoading,
                                showArrow: false,
                                onPressed: _canSignUp ? _handleSignUp : null,
                              ),

                              _buildDivider(),
                              _buildSocialButtons(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildLoginLink(),
                      const SizedBox(height: 48),
                      _buildTermsText(),
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

  Widget _buildNameField() {
    final isLocked = _isEmailVerified;
    return Opacity(
      opacity: isLocked ? 0.6 : 1.0,
      child: IgnorePointer(
        ignoring: isLocked,
        child: Stack(
          children: [
            CustomTextField(
              label: 'Full Name',
              placeholder: 'Enter your name',
              prefixIcon: Icons.person_outline,
              controller: _nameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            if (isLocked)
              Positioned(
                right: 12,
                top: 32,
                child: Icon(Icons.lock, color: AppColors.textMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    final isLocked = _isEmailVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: isLocked ? 0.6 : 1.0,
          child: IgnorePointer(
            ignoring: isLocked,
            child: Stack(
              children: [
                CustomTextField(
                  label: 'Email Address',
                  placeholder: 'name@gmail.com',
                  prefixIcon: Icons.mail_outline,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.toLowerCase().endsWith('@gmail.com')) {
                      return 'Please use a Gmail address';
                    }
                    return null;
                  },
                ),
                if (_isEmailVerified)
                  Positioned(
                    right: 12,
                    top: 32,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.lock, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showVerifyEmailButton) ...[
          const SizedBox(height: 12),
          _buildVerifyButton(label: 'Verify Email', onPressed: _verifyEmail),
        ],
      ],
    );
  }

  Widget _buildPhoneField() {
    final isEnabled = _isEmailVerified && !_isPhoneVerified;
    final isLocked = _isPhoneVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: (!_isEmailVerified && !_isPhoneVerified)
              ? 0.4
              : (isLocked ? 0.6 : 1.0),
          child: IgnorePointer(
            ignoring: !isEnabled,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'Phone Number',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.inputBackground,
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: AppColors.borderLight),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.phone_android,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+91',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '10 digit number',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter phone number';
                                }
                                if (value.length != 10) {
                                  return 'Phone number must be 10 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isPhoneVerified)
                  Positioned(
                    right: 12,
                    top: 32,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.lock, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                if (!_isEmailVerified && !_isPhoneVerified)
                  Positioned(
                    right: 12,
                    top: 32,
                    child: Icon(
                      Icons.lock_outline,
                      color: AppColors.textDimmed,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showVerifyPhoneButton && _isEmailVerified) ...[
          const SizedBox(height: 12),
          _buildVerifyButton(label: 'Verify Phone', onPressed: _verifyPhone),
        ],
      ],
    );
  }

  Widget _buildPasswordFields() {
    final isEnabled = _isEmailVerified && _isPhoneVerified;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Column(
          children: [
            Stack(
              children: [
                CustomTextField(
                  label: 'Create Password',
                  placeholder: 'Create a password',
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  obscureText: _obscurePassword,
                  controller: _passwordController,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                if (!isEnabled)
                  Positioned(
                    right: 12,
                    top: 32,
                    child: Icon(
                      Icons.lock_outline,
                      color: AppColors.textDimmed,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                CustomTextField(
                  label: 'Confirm Password',
                  placeholder: 'Confirm your password',
                  prefixIcon: Icons.lock_reset_outlined,
                  suffixIcon: _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  obscureText: _obscureConfirmPassword,
                  controller: _confirmPasswordController,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (!isEnabled)
                  Positioned(
                    right: 12,
                    top: 32,
                    child: Icon(
                      Icons.lock_outline,
                      color: AppColors.textDimmed,
                      size: 20,
                    ),
                  ),
              ],
            ),
            if (_showPasswordMismatch) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Passwords do not match',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 600,
                  height: 600,
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
            Positioned(
              bottom: -60,
              right: -60,
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

  Widget _buildLogoSection() {
    return Column(
      children: [
        RichText(
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
                text: '●',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'YOUR AI COMPANION',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
            letterSpacing: 2,
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

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.borderMedium)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR CONTINUE WITH',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.borderMedium)),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: SocialAuthButton.google(onPressed: _handleGoogleSignUp),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SocialAuthButton.apple(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Apple Sign Up coming soon')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Log In',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Text(
      'By registering, you agree to our Terms of Service & Privacy Policy.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textDimmed),
    );
  }
}
