import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/app_colors.dart';

/// Bottom Navigation Bar for SpecEI
/// Matches design from glasses_control_&_status/code.html
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      height: 64, // Reduced height
      decoration: BoxDecoration(
        color: const Color(0xFF111111).withOpacity(0.9), // Darker background
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ), // Subtle border
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
              _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              _buildNavItem(
                icon: Icons.psychology_rounded,
                label: 'Memory',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                index: 2,
              ),
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
        decoration: BoxDecoration(
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
