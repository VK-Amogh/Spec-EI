import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/glass_panel.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../widgets/breathing_glow.dart';

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
  final _phoneController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  bool _usePhone = false;
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'IN');

  bool _isPhoneValid = false;
  bool _isEmailValid = false;
  String? _emailError;

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
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final requiredLength = _countryConfigs[_phoneNumber.isoCode] ?? 10;
    setState(() {
      _isPhoneValid = phone.length == requiredLength;
    });
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    setState(() {
      // Check for capital letters first
      if (RegExp(r'[A-Z]').hasMatch(email)) {
        _emailError = 'Email must be in lowercase';
        _isEmailValid = false;
      }
      // Check for valid @gmail.com format specifically
      else if (email.isNotEmpty &&
          !RegExp(r'^[a-z0-9._%+-]+@gmail\.com$').hasMatch(email)) {
        _emailError = 'Please enter a valid @gmail.com address';
        _isEmailValid = false;
      }
      // Valid gmail address
      else if (email.isNotEmpty &&
          RegExp(r'^[a-z0-9._%+-]+@gmail\.com$').hasMatch(email)) {
        _emailError = null;
        _isEmailValid = true;
      }
      // Empty field
      else {
        _emailError = null;
        _isEmailValid = false;
      }
    });
  }

  Future<void> _handleSendResetLink() async {
    if (_usePhone) {
      if (!_isPhoneValid) return;
    } else {
      if (!_isEmailValid) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_usePhone) {
        final dialCode = _dialCodes[_phoneNumber.isoCode] ?? '+91';
        final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
        final fullPhone = '$dialCode$digits';
        // This now logs to Supabase AND triggers code logic
        await _authService.sendPasswordResetPhone(fullPhone);
      } else {
        final email = _emailController.text.trim();
        // This now logs to Supabase AND sends Firebase link
        await _authService.sendPasswordResetEmail(email);
      }

      if (mounted) {
        // Navigate with slide effect
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                OtpVerificationScreen(
                  verificationType: _usePhone ? 'phone' : 'email',
                  verificationTarget: _usePhone
                      ? '${_dialCodes[_phoneNumber.isoCode] ?? "+91"}${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}'
                      : _emailController.text.trim(),
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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo
                            _buildLogo(),
                            const SizedBox(height: 32),

                            // Form panel
                            BreathingGlow(
                              glowColor: Colors.white,
                              maxOpacity: 0.04,
                              enableFloating: true,
                              floatingRange: 6.0,
                              blurRadius: 40,
                              spreadRadius: 4,
                              duration: const Duration(seconds: 3),
                              child: GlassPanel(
                                padding: const EdgeInsets.all(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(
                                      0.05,
                                    ), // Light blurred white glow
                                    blurRadius: 60,
                                    spreadRadius: 2,
                                  ),
                                ],
                                child: _emailSent
                                    ? _buildSuccessContent()
                                    : _buildFormContent(),
                              ),
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
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -60,
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
            Positioned(
              bottom: -60,
              right: -60,
              child: Container(
                width: 500,
                height: 500,
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
            _usePhone
                ? "Enter your registered mobile number to receive a verification code."
                : "Enter the email associated with your account and we'll send you a link to reset your password.",
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

          // Field switcher using IndexedStack for zero-flicker transitions
          SizedBox(
            height:
                80, // Fixed height to prevent layout jumps during validation errors
            child: IndexedStack(
              index: _usePhone ? 0 : 1,
              children: [
                // Phone Mode
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Country Dropdown
                        Container(
                          height: 56, // Fixed height matching CustomTextField
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _phoneNumber.isoCode,
                              dropdownColor: AppColors.surface,
                              elevation: 2,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _phoneNumber = PhoneNumber(
                                      isoCode: newValue,
                                    );
                                    _onPhoneChanged();
                                  });
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'IN',
                                  child: Text(
                                    '🇮🇳 +91',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'US',
                                  child: Text(
                                    '🇺🇸 +1',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'GB',
                                  child: Text(
                                    '🇬🇧 +44',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'AE',
                                  child: Text(
                                    '🇦🇪 +971',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'AU',
                                  child: Text(
                                    '🇦🇺 +61',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'JP',
                                  child: Text(
                                    '🇯🇵 +81',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Email Mode
                CustomTextField(
                  label: 'Email Address',
                  placeholder: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: (_) => _onEmailChanged(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          // Toggle option
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _usePhone = !_usePhone;
                  _errorMessage = null;
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _usePhone
                    ? 'Use email address instead'
                    : 'Use mobile number instead',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.primary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Send Reset Link button
          PrimaryButton(
            text: 'Send Reset Link',
            onPressed:
                (_usePhone
                    ? _isPhoneValid
                    : (_isEmailValid && _emailError == null))
                ? _handleSendResetLink
                : null,
            isLoading: _isLoading,
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
          child: Icon(
            _usePhone ? Icons.sms_outlined : Icons.mark_email_read_outlined,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _usePhone
              ? 'We sent a verification code to\n${_phoneNumber.phoneNumber}'
              : 'We sent a password reset link to\n${_emailController.text}',
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
              _phoneController.clear();
            });
          },
          child: Text(
            'Try a different ${_usePhone ? 'number' : 'email'}',
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
