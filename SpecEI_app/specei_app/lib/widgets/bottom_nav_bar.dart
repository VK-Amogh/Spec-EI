import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

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
      height: 72, // Increased slightly to accommodate hover labels
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withOpacity(0.9),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AppColors.getBorderLight(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarItem(
                context: context,
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavBarItem(
                context: context,
                icon: Icons.psychology_rounded,
                label: 'Memory',
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavBarItem(
                context: context,
                icon: Icons.videocam_rounded,
                label: 'Camera',
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavBarItem(
                context: context,
                icon: Icons.settings_rounded,
                label: 'Settings',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
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
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.getBorderLight(context)),
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
            Text(
              'Capture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavBarItem({
    required this.context,
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isActive = widget.currentIndex == widget.index;
    Color iconColor = isActive
        ? AppColors.primary
        : AppColors.getTextMuted(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _bounceController.forward().then((_) => _bounceController.reverse());
          widget.onTap(widget.index);
        },
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: _isHovered ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: isActive && _isHovered
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 15, // Active tab glow
                        spreadRadius: -2,
                      ),
                    ]
                  : (_isHovered
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.05),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : null),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 26, color: iconColor),
                // Label on hover
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _isHovered ? 16 : 0,
                  margin: EdgeInsets.only(top: _isHovered ? 4 : 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isHovered ? 1.0 : 0.0,
                    child: Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
