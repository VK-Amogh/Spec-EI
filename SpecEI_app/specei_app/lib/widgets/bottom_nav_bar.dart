import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/app_colors.dart';

/// Bottom Navigation Bar for SpecEI
/// Includes navigation tabs and central action button for capture options
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onVideoTap;
  final VoidCallback? onAudioTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onPhotoTap,
    this.onVideoTap,
    this.onAudioTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF111111).withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Home
              _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              // Memory
              _buildNavItem(
                icon: Icons.psychology_rounded,
                label: 'Memory',
                index: 1,
              ),
              // Central action button (circle)
              _buildCentralActionButton(context),
              // Camera
              _buildNavItem(
                icon: Icons.videocam_rounded,
                label: 'Camera',
                index: 2,
              ),
              // Settings
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Central circle button that shows capture options
  Widget _buildCentralActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCaptureOptionsModal(context),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }

  /// Show modal bottom sheet with Photo, Video, Audio options
  void _showCaptureOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              'Capture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // Options row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Photo option
                  _buildCaptureOption(
                    context: context,
                    icon: Icons.photo_camera_rounded,
                    label: 'Photo',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      onPhotoTap?.call();
                    },
                  ),
                  // Video option
                  _buildCaptureOption(
                    context: context,
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      onVideoTap?.call();
                    },
                  ),
                  // Audio option
                  _buildCaptureOption(
                    context: context,
                    icon: Icons.mic_rounded,
                    label: 'Audio',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      onAudioTap?.call();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 26,
          color: isActive ? AppColors.primary : Colors.grey.shade600,
        ),
      ),
    );
  }
}
