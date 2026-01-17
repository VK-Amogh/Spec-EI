import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_auth_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/breathing_glow.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'registration_screen.dart';
import 'forgot_password_screen.dart';
import 'main_screen.dart';

/// Login Screen - SpecEI Authentication
/// Matches design from _ai_hub_ultimate_ui_3
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _supabaseService = SupabaseService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _emailValidationError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailValidationError = null;
      });
      return;
    }

    // Check conditions - capital letters first, then format
    String? error;

    // Check for capital letters first
    if (RegExp(r'[A-Z]').hasMatch(email)) {
      error = 'Email must be in lowercase';
    }
    // Then check valid @gmail.com format specifically
    else if (!RegExp(r'^[a-z0-9._%+-]+@gmail\.com$').hasMatch(email)) {
      error = 'Please enter a valid @gmail.com address';
    }

    setState(() {
      _emailValidationError = error;
      // Note: Account existence check removed - Firebase deprecated fetchSignInMethodsForEmail
      // for security reasons (prevents email enumeration attacks)
      // The actual login will determine if account exists
    });
  }

  // Note: Account existence check removed - Firebase deprecated fetchSignInMethodsForEmail
  // The login attempt itself will determine if the account exists

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      // Navigate to home on success
      if (mounted) {
        // Navigation will be handled by auth state listener in main.dart
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
        // Explicitly navigate to MainScreen to ensure redirection
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && result.user != null) {
        // Check if profile exists in Supabase, if not create it
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: AppColors.primaryDark,
            ),
          );
          // Explicitly navigate to MainScreen to ensure redirection
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else if (mounted) {
        setState(() => _errorMessage = 'Google sign in was cancelled');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithApple();
      // Note: signInWithApple returns UserCredential, not nullable
      if (result.user != null) {
        // Check if profile exists
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: AppColors.primaryDark,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
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
          // Background glow effects
          _buildBackgroundEffects(),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo section
                      _buildLogoSection(),
                      const SizedBox(height: 32),

                      // Login form panel with breathing effect
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                _buildHeader(),
                                const SizedBox(height: 24),

                                // Error message
                                if (_errorMessage != null) ...[
                                  _buildErrorMessage(),
                                  const SizedBox(height: 16),
                                ],

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextField(
                                      label: 'EMAIL',
                                      placeholder: 'name@gmail.com',
                                      prefixIcon: Icons.mail_outline,
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      errorText: _emailValidationError,
                                      onChanged: (_) => _onEmailChanged(),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        return _emailValidationError;
                                      },
                                    ),
                                    // Account existence check removed - Firebase deprecated this API
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Password field
                                CustomTextField(
                                  label: 'PASSWORD',
                                  placeholder: '••••••••',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  onSuffixTap: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  obscureText: _obscurePassword,
                                  controller: _passwordController,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Forgot password link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Login button
                                PrimaryButton(
                                  text: 'Login',
                                  isLoading: _isLoading,
                                  onPressed: _handleLogin,
                                ),

                                // Divider
                                _buildDivider(),

                                // Social buttons
                                _buildSocialButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Sign up link
                      const SizedBox(height: 32),
                      _buildSignUpLink(),
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

  Widget _buildBackgroundEffects() {
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI COMPANION ACCESS',
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please sign in to continue syncing.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
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
              'Or continue with',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
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
          child: SocialAuthButton.google(onPressed: _handleGoogleSignIn),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SocialAuthButton.apple(
            onPressed: () {
              // Apple sign in - now implemented for Web
              _handleAppleSignIn();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegistrationScreen()),
            );
          },
          child: Text(
            'Sign Up',
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
}
