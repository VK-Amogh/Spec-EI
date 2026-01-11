import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/audio_recording_dialog.dart';
import '../core/app_colors.dart';
import '../services/memory_data_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/memory_tab.dart';
import 'tabs/camera_tab.dart';
import 'tabs/device_settings_tab.dart';
import 'camera_screen.dart';
import 'package:provider/provider.dart';
import '../services/server_connectivity_service.dart';

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
    // Eagerly load user data from Supabase when app starts
    MemoryDataService().loadFromDatabase();
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

  /// Handle Photo option - open camera screen for photo
  void _onPhotoTap() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    // If photo was taken, go to Memory tab to see it
    if (result == true) {
      _onNavTap(1);
    }
  }

  /// Handle Video option - open camera screen for video recording
  void _onVideoTap() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScreen(startInVideoMode: true),
      ),
    );

    // If video was recorded, go to Memory tab to see it
    if (result == true) {
      _onNavTap(1);
    }
  }

  /// Handle Audio option - show recording dialog
  void _onAudioTap() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AudioRecordingDialog(),
    );

    // If audio was saved, go to Memory tab to see it
    if (result == true) {
      _onNavTap(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Stack(
        children: [
          // Background glow effects
          _buildBackgroundEffects(),

          // Main content - 4 tabs: Home, Memory, Camera, Settings
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
            child: BottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
              onPhotoTap: _onPhotoTap,
              onVideoTap: _onVideoTap,
              onAudioTap: _onAudioTap,
            ),
          ),

          // Server Status Indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: Consumer<ServerConnectivityService>(
              builder: (context, serverService, child) {
                final isMistralOnline =
                    serverService.mistralStatus == ServerStatus.online;
                final isWhisperOnline =
                    serverService.whisperStatus == ServerStatus.online;
                final isOnline = isMistralOnline && isWhisperOnline;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnline
                          ? Colors.green.withOpacity(0.5)
                          : Colors.red.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.green : Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: (isOnline ? Colors.green : Colors.red)
                                  .withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'BRAIN ONLINE' : 'BRAIN OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOnline ? Colors.green : Colors.red,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                );
              },
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
