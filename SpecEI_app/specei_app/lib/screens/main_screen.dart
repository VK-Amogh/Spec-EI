import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../core/app_colors.dart';
import 'tabs/home_tab.dart';
import 'tabs/memory_tab.dart';
import 'tabs/camera_tab.dart';
import 'tabs/device_settings_tab.dart';

/// Main Screen Container with PageView and Bottom Navigation
/// Provides swipe navigation between tabs with slide animations
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
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
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: const [
              HomeTab(),
              MemoryTab(),
              CameraTab(),
              DeviceSettingsTab(),
            ],
          ),

          // Bottom navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavBar(currentIndex: _currentIndex, onTap: _onNavTap),
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
            // Top-left glow
            Positioned(
              top: -100,
              left: -50,
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
            // Bottom-right glow
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 350,
                height: 350,
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
}
