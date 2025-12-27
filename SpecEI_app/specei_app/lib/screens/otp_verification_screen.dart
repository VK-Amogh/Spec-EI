import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../services/supabase_service.dart';

/// OTP Verification Screen
/// 6-digit OTP input with auto-focus, mock OTP generation, and countdown timer
class OtpVerificationScreen extends StatefulWidget {
  final String verificationType; // 'email' or 'phone'
  final String verificationTarget; // email address or phone number
  final bool isPasswordReset;

  const OtpVerificationScreen({
    super.key,
    required this.verificationType,
    required this.verificationTarget,
    this.isPasswordReset = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _mockOtp = '';
  bool _isVerifying = false;
  bool _isSuccess = false;
  bool _showError = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  bool _canResend = false;
  final _supabaseService = SupabaseService();

  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successAnimController, curve: Curves.elasticOut),
    );

    _initializeOtp();
    _startCountdown();
  }

  Future<void> _initializeOtp() async {
    if (widget.isPasswordReset) {
      // For password reset, get the code from Supabase
      final code = await _supabaseService.getLatestResetCode(
        widget.verificationTarget,
      );
      if (code != null) {
        setState(() {
          _mockOtp = code;
        });
        if (mounted) {
          _showOtpNotification();
        }
        return;
      }
    }

    // Fallback or default for registration
    // Generate mock OTP after 1 second
    Future.delayed(const Duration(seconds: 1), _generateAndShowMockOtp);
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _countdownTimer?.cancel();
    _successAnimController.dispose();
    super.dispose();
  }

  void _generateAndShowMockOtp() {
    final random = Random();
    _mockOtp = List.generate(6, (_) => random.nextInt(10).toString()).join();

    if (mounted) {
      _showOtpNotification();
    }
  }

  void _autoFillOtp() {
    if (!mounted || _mockOtp.isEmpty) return;

    // Fill each digit into the corresponding controller
    for (int i = 0; i < 6 && i < _mockOtp.length; i++) {
      _controllers[i].text = _mockOtp[i];
    }

    // Trigger verification after auto-fill
    setState(() {});
    _verifyOtp();
  }

  void _showOtpNotification() {
    // Show notification at the top of the screen (Overlay logic)
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sms, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Your OTP Code',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mockOtp,
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          letterSpacing: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _canResend = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  void _onOtpDigitChanged(int index, String value) {
    setState(() => _showError = false);

    if (value.isNotEmpty && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    }

    // Check if OTP is complete
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      // Move to previous field on backspace
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _verifyOtp() async {
    final enteredOtp = _controllers.map((c) => c.text).join();

    setState(() => _isVerifying = true);

    // Simulate verification delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (enteredOtp == _mockOtp) {
      setState(() {
        _isSuccess = true;
        _isVerifying = false;
      });
      _successAnimController.forward();

      // Wait for animation then navigate back
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        if (widget.isPasswordReset) {
          // Navigate to Reset Password Screen
          // We'll create this screen next
          Navigator.pushReplacementNamed(
            context,
            '/reset-password',
            arguments: widget.verificationTarget,
          );
        } else {
          Navigator.pop(context, true); // Return success
        }
      }
    } else {
      setState(() {
        _isVerifying = false;
        _showError = true;
      });
      // Clear OTP fields
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  void _resendOtp() {
    _initializeOtp();
    _startCountdown();
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
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: GlassPanel(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildIcon(),
                              const SizedBox(height: 24),
                              _buildTitle(),
                              const SizedBox(height: 8),
                              _buildSubtitle(),
                              const SizedBox(height: 32),
                              if (_isSuccess)
                                _buildSuccessState()
                              else ...[
                                _buildOtpFields(),
                                const SizedBox(height: 16),
                                _buildAutoEnterButton(),
                                if (_showError) ...[
                                  const SizedBox(height: 16),
                                  _buildErrorMessage(),
                                ],
                                const SizedBox(height: 24),
                                _buildResendSection(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isVerifying) _buildLoadingOverlay(),
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
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
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
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
      ),
      child: Icon(
        widget.verificationType == 'email'
            ? Icons.mail_outline
            : Icons.phone_android,
        color: AppColors.primary,
        size: 36,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Verify Your ${widget.verificationType == 'email' ? 'Email' : 'Phone'}',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }

  String _maskIdentifier(String target) {
    if (widget.verificationType == 'email') {
      final parts = target.split('@');
      if (parts.length != 2) return target;
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 2) return target;
      return '${name.substring(0, 2)}*****@$domain';
    } else {
      // Phone masking: Only show last two digits
      if (target.length <= 2) return target;
      final maskedPart = '*' * (target.length - 2);
      final lastTwo = target.substring(target.length - 2);
      return '$maskedPart$lastTwo';
    }
  }

  Widget _buildSubtitle() {
    return Text(
      'Enter the 6-digit code sent to\n${_maskIdentifier(widget.verificationTarget)}',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textMuted,
        height: 1.5,
      ),
    );
  }

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 52,
          height: 60,
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (event) => _onKeyDown(index, event),
            child: TextFormField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => _onOtpDigitChanged(index, value),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _showError
                        ? Colors.red.withOpacity(0.5)
                        : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAutoEnterButton() {
    final bool isEnabled = _mockOtp.isNotEmpty;
    return InkWell(
      onTap: isEnabled ? _autoFillOtp : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.greenAccent : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? Colors.greenAccent
                : AppColors.borderLight.withOpacity(0.5),
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flash_on,
              color: isEnabled ? Colors.black : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Auto Enter OTP',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.black : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(
            'Invalid OTP. Please try again.',
            style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        if (!_canResend)
          Text(
            'Resend code in ${_resendCountdown}s',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
          )
        else
          TextButton(
            onPressed: _resendOtp,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
            ),
            child: Text(
              'Resend OTP',
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

  Widget _buildSuccessState() {
    return ScaleTransition(
      scale: _successScaleAnim,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: Icon(Icons.check, color: AppColors.primary, size: 50),
          ),
          const SizedBox(height: 20),
          Text(
            'Verified Successfully!',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Verifying...',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
