import 'package:flutter/material.dart';
import 'dart:async';
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
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

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
  Timer? _emailDebounce;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Verification states
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  bool _showVerifyEmailButton = false;
  bool _showVerifyPhoneButton = false;
  bool _isCheckingEmail = false;
  bool _isCheckingPhone = false;
  bool _emailAlreadyExists = false;
  bool _phoneAlreadyExists = false;
  String? _emailError;

  // Phone input states
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'IN');
  final String _phoneInitialValue = '';

  // Password requirement states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasSpecialChar = false;

  final Map<String, int> _countryConfigs = {
    'IN': 10,
    'US': 10,
    'GB': 10,
    'AE': 9,
    'AU': 9,
    'JP': 10,
  };

  final Map<String, String> _dialCodes = {
    'IN': '+91',
    'US': '+1',
    'GB': '+44',
    'AE': '+971',
    'AU': '+61',
    'JP': '+81',
  };

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final rawEmail = _emailController.text.trim();
    String? error;

    if (rawEmail.isEmpty) {
      error = null;
    } else if (RegExp(r'[A-Z]').hasMatch(rawEmail)) {
      error = 'Email must be in all lowercase letters';
    } else if (!RegExp(
      r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$',
    ).hasMatch(rawEmail)) {
      error = 'Please enter a valid email format';
    } else if (!rawEmail.endsWith('@gmail.com')) {
      error = 'Please use a Gmail address';
    }

    final isValidFormat = error == null;
    final isValidGmail =
        rawEmail.endsWith('@gmail.com') &&
        rawEmail.length > 11 &&
        isValidFormat;

    setState(() {
      _emailError = error;
      // Don't show verify button yet - wait for check
      _showVerifyEmailButton = false;

      if (!isValidGmail) {
        _emailAlreadyExists = false;
        _isCheckingEmail = false;
        _emailDebounce?.cancel();
      } else {
        // Valid format - Start checking
        _isCheckingEmail = true; // Show loading state immediately
        _emailAlreadyExists = false; // Reset temporary
      }
    });

    if (isValidGmail && !_isEmailVerified) {
      _emailDebounce?.cancel();
      _emailDebounce = Timer(const Duration(milliseconds: 300), () {
        _checkEmailExists(rawEmail);
      });
    }
  }

  Future<void> _checkEmailExists(String email) async {
    try {
      // Check both Firebase and Supabase
      final firebaseExists = await _authService.checkEmailExistsInFirebase(
        email,
      );
      final supabaseExists = await _supabaseService.emailExists(email);

      final exists = firebaseExists || supabaseExists;

      if (mounted && _emailController.text.toLowerCase().trim() == email) {
        setState(() {
          _emailAlreadyExists = exists;
          print(
            'DEBUG: Email check for $email -> exists: $exists',
          ); // Debug log
          if (exists) {
            _emailError = 'Account already exists. Please login.';
          }
          _showVerifyEmailButton = !exists && !_isEmailVerified;
          _isCheckingEmail = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingEmail = false);
    }
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
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
      // Store email verification in Supabase
      _supabaseService.updateEmailVerification(_emailController.text, true);
    }
  }

  Future<void> _verifyPhone() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OtpVerificationScreen(
          verificationType: 'phone',
          verificationTarget:
              '${_dialCodes[_phoneNumber.isoCode] ?? "+91"} ${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}',
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
      // Store phone verification in Supabase
      _supabaseService.updatePhoneVerification(
        _emailController.text,
        '${_dialCodes[_phoneNumber.isoCode] ?? "+91"}${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}',
        true,
      );
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
        final rawDigits = _phoneController.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final dialCode =
            _dialCodes[_phoneNumber.isoCode]?.replaceAll(
              RegExp(r'[^0-9]'),
              '',
            ) ??
            '91';
        final fullPhone = '+$dialCode$rawDigits';
        await _supabaseService.createUserProfile(
          firebaseUid: credential.user!.uid,
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          phoneNumber: fullPhone,
        );
      }

      if (mounted) {
        // Show brief success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Account created! Welcome, ${_nameController.text}!',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Navigate to login with smooth fade transition
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const LoginScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
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
                        enableGlow: false,
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
    return CustomTextField(
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
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IgnorePointer(
          ignoring: _isEmailVerified,
          child: Opacity(
            opacity: _isEmailVerified ? 0.7 : 1.0,
            child: CustomTextField(
              label: 'Email Address',
              placeholder: 'name@gmail.com',
              prefixIcon: Icons.mail_outline,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              suffix: _isEmailVerified
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    )
                  : (_isCheckingEmail
                        ? const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (RegExp(r'[A-Z]').hasMatch(value)) {
                  return 'Email must be in all lowercase letters';
                }
                if (!value.toLowerCase().endsWith('@gmail.com')) {
                  return 'Please use a Gmail address';
                }
                if (!RegExp(
                  r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email format';
                }
                return null;
              },
            ),
          ),
        ),
        if (_showVerifyEmailButton) ...[
          const SizedBox(height: 8),
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
            child: Row(
              children: [
                // Country Dropdown beside the textbox
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _phoneNumber.isoCode,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _phoneNumber = PhoneNumber(isoCode: newValue);
                            _onPhoneChanged(); // Re-validate with new country
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'IN',
                          child: Text(
                            '🇮🇳 +91',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'US',
                          child: Text(
                            '🇺🇸 +1',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'GB',
                          child: Text(
                            '🇬🇧 +44',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'AE',
                          child: Text(
                            '🇦🇪 +971',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'AU',
                          child: Text(
                            '🇦🇺 +61',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'JP',
                          child: Text(
                            '🇯🇵 +81',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Textbox for phone number
                Expanded(
                  child: CustomTextField(
                    placeholder: 'Mobile Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => _onPhoneChanged(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showVerifyPhoneButton) ...[
          const SizedBox(height: 8),
          _buildVerifyButton(label: 'Verify Phone', onPressed: _verifyPhone),
        ],
      ],
    );
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final requiredLength = _countryConfigs[_phoneNumber.isoCode] ?? 10;

    final isValidLength = phone.length == requiredLength;

    // Reset phone exists state when typing
    if (_phoneAlreadyExists) {
      setState(() => _phoneAlreadyExists = false);
    }

    setState(() {
      _showVerifyPhoneButton =
          isValidLength && !_isPhoneVerified && !_phoneAlreadyExists;
    });

    // Check if phone exists when length is valid
    if (isValidLength && !_isPhoneVerified) {
      final dialCode = _dialCodes[_phoneNumber.isoCode] ?? '+91';
      _checkPhoneExists('$dialCode$phone');
    }
  }

  Future<void> _checkPhoneExists(String fullPhone) async {
    if (_isCheckingPhone) return;

    setState(() => _isCheckingPhone = true);

    try {
      final exists = await _supabaseService.phoneExists(fullPhone);
      if (mounted) {
        final currentDigits = _phoneController.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final currentDial = _dialCodes[_phoneNumber.isoCode] ?? '+91';
        if ('$currentDial$currentDigits' == fullPhone) {
          setState(() {
            _phoneAlreadyExists = exists;
            _showVerifyPhoneButton = !exists && !_isPhoneVerified;
          });
        }
      }
    } catch (e) {
      // Silently fail
    } finally {
      if (mounted) {
        setState(() => _isCheckingPhone = false);
      }
    }
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
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                      return 'Must contain at least one uppercase letter';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(value)) {
                      return 'Must contain at least one lowercase letter';
                    }
                    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                      return 'Must contain at least one special character';
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
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPasswordRequirements(),
            ],
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

  Widget _buildPasswordRequirements() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security Requirements:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirementItem('Minimum 8 characters', _hasMinLength),
          _buildRequirementItem(
            'Upper & lower case letters',
            _hasUppercase && _hasLowercase,
          ),
          _buildRequirementItem(
            'Special character (!@#\$%^&*)',
            _hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String label, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isMet ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
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
