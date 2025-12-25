import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../core/app_colors.dart';

/// Camera Tab - Connect to AI Glasses and capture photos
/// Allows manual photo capture through the glasses
class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  bool _isConnected = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  void _capturePhoto() {
    setState(() => _isCapturing = true);
    // Simulate capture delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Photo captured successfully!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera view placeholder (full screen black)
        Container(color: Colors.black),

        // Grid overlay
        _buildGridOverlay(),

        // Top status bar
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              // Bottom controls
              _buildBottomControls(),
              const SizedBox(height: 120), // Space for nav bar
            ],
          ),
        ),

        // Vision mode indicator
        Positioned(
          top: MediaQuery.of(context).padding.top + 80,
          left: 0,
          right: 0,
          child: Center(child: _buildVisionModeIndicator()),
        ),

        // Detection panels
        if (_isConnected) ...[
          Positioned(
            left: 20,
            top: MediaQuery.of(context).size.height * 0.35,
            child: _buildDetectionPanel(
              icon: Icons.face,
              label: 'Face Detection',
              status: 'Active',
              isActive: true,
            ),
          ),
          Positioned(
            right: 20,
            top: MediaQuery.of(context).size.height * 0.35,
            child: _buildDetectionPanel(
              icon: Icons.text_fields,
              label: 'OCR Ready',
              status: 'Standby',
              isActive: false,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGridOverlay() {
    return CustomPaint(size: Size.infinite, painter: _GridPainter());
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isConnected
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? AppColors.primary : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isConnected ? AppColors.primary : Colors.red)
                                    .withOpacity(0.5 * _pulseController.value),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Glasses Connected' : 'Disconnected',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isConnected ? AppColors.primary : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Battery & settings
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.battery_charging_full,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '82%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(
                  Icons.flash_off,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisionModeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'VISION MODE ACTIVE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionPanel({
    required IconData icon,
    required String label,
    required String status,
    required bool isActive,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppColors.primary : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: isActive ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Mode selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeChip('Photo', true),
              const SizedBox(width: 12),
              _buildModeChip('Video', false),
              const SizedBox(width: 12),
              _buildModeChip('Scan', false),
            ],
          ),
          const SizedBox(height: 24),

          // Capture controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppColors.textMuted,
                ),
              ),

              // Capture button
              GestureDetector(
                onTap: _isConnected && !_isCapturing ? _capturePhoto : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isCapturing ? 72 : 80,
                  height: _isCapturing ? 72 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: _isConnected ? AppColors.primary : Colors.grey,
                      width: 4,
                    ),
                    boxShadow: _isConnected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isCapturing ? 24 : 56,
                      height: _isCapturing ? 24 : 56,
                      decoration: BoxDecoration(
                        shape: _isCapturing
                            ? BoxShape.rectangle
                            : BoxShape.circle,
                        borderRadius: _isCapturing
                            ? BorderRadius.circular(4)
                            : null,
                        color: _isConnected ? AppColors.primary : Colors.grey,
                      ),
                      child: _isCapturing
                          ? null
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),

              // Flip camera button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(
                  Icons.cameraswitch,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppColors.primary : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.black : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // Vertical lines (rule of thirds)
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );

    // Center crosshair
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final crosshairPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(centerX - 20, centerY),
      Offset(centerX + 20, centerY),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - 20),
      Offset(centerX, centerY + 20),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
