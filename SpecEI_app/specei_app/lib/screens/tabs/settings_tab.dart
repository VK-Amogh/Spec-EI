import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:async';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import '../about_screen.dart';

/// Settings Tab - User account and app settings
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _authService = AuthService();
  bool _isLoggingOut = false;

  // Battery state
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _batteryTimer;
  bool _batterySupported = true;

  @override
  void initState() {
    super.initState();
    _initBattery();
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    _batteryTimer?.cancel();
    super.dispose();
  }

  /// Initialize battery monitoring
  Future<void> _initBattery() async {
    // Get initial battery level
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _batterySupported = true;
        });
      }
    } catch (e) {
      debugPrint('Battery level error: $e');
      // On web, battery API may not be supported
      if (mounted) {
        setState(() {
          _batterySupported = false;
          _batteryLevel = 100; // Default fallback
        });
      }
    }

    // Listen to battery state changes (charging, discharging, etc.)
    try {
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
        (state) {
          if (mounted) {
            setState(() => _batteryState = state);
            _updateBatteryLevel();
          }
        },
        onError: (e) {
          debugPrint('Battery state stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Battery state subscription error: $e');
    }

    // Update battery level periodically (every 30 seconds)
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBatteryLevel();
    });
  }

  Future<void> _updateBatteryLevel() async {
    if (!_batterySupported) return;

    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = level);
      }
    } catch (e) {
      debugPrint('Battery update error: $e');
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // Battery status card
            _buildBatteryCard(),
            const SizedBox(height: 24),

            // Profile section
            _buildProfileSection(),
            const SizedBox(height: 24),

            // Account settings
            _buildSectionTitle('Account'),
            _buildSettingsList([
              _SettingItem(Icons.person_outline, 'Edit Profile'),
              _SettingItem(Icons.lock_outline, 'Change Password'),
              _SettingItem(Icons.security, 'Two-Factor Auth'),
            ]),
            const SizedBox(height: 24),

            // App settings
            _buildSectionTitle('Preferences'),
            _buildSettingsList([
              _SettingItem(Icons.notifications_outlined, 'Notifications'),
              _SettingItem(Icons.language, 'Language'),
              _SettingItem(Icons.dark_mode_outlined, 'Appearance'),
              _SettingItem(Icons.storage_outlined, 'Storage & Data'),
            ]),
            const SizedBox(height: 24),

            // Device settings
            _buildSectionTitle('Device'),
            _buildSettingsList([
              _SettingItem(Icons.bluetooth, 'Bluetooth'),
              _SettingItem(Icons.wifi, 'Wi-Fi Settings'),
              _SettingItem(Icons.update, 'Firmware Update'),
            ]),
            const SizedBox(height: 24),

            // Support
            _buildSectionTitle('Support'),
            _buildSettingsList([
              _SettingItem(Icons.help_outline, 'Help Center'),
              _SettingItem(Icons.feedback_outlined, 'Send Feedback'),
              _SettingItem(Icons.info_outline, 'About'),
            ]),
            const SizedBox(height: 32),

            // Logout button
            _buildLogoutButton(),
            const SizedBox(height: 16),

            // Version
            Center(
              child: Text(
                'Version 1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build battery status card with live percentage
  Widget _buildBatteryCard() {
    final isCharging = _batteryState == BatteryState.charging;
    final isFull = _batteryState == BatteryState.full;
    final isLow = _batteryLevel <= 20;

    // Battery color based on level
    Color batteryColor;
    if (!_batterySupported) {
      batteryColor = AppColors.textMuted;
    } else if (isCharging || isFull) {
      batteryColor = AppColors.primary;
    } else if (isLow) {
      batteryColor = Colors.red;
    } else if (_batteryLevel <= 50) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: batteryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: batteryColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Battery icon with fill level
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: batteryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                isCharging
                    ? Icons.battery_charging_full
                    : (isFull
                          ? Icons.battery_full
                          : (isLow ? Icons.battery_alert : Icons.battery_std)),
                size: 32,
                color: batteryColor,
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Battery info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Battery',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _batterySupported ? '$_batteryLevel%' : 'N/A',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: batteryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_batterySupported)
                      Text(
                        '(Web)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (isCharging)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Charging',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Battery level bar
          Container(
            width: 8,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 8,
                height: 60 * (_batteryLevel / 100),
                decoration: BoxDecoration(
                  color: batteryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: const Icon(
            Icons.arrow_back,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.person, size: 32, color: Colors.black),
            ),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SpecEI User',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'user@example.com',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Edit button
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Icon(Icons.edit, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsList(List<_SettingItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;
          return _buildSettingRow(item.icon, item.label, isLast: isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, {bool isLast = false}) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleSettingTap(label),
            borderRadius: BorderRadius.vertical(
              top: isLast ? Radius.zero : const Radius.circular(16),
              bottom: isLast ? const Radius.circular(16) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
      ],
    );
  }

  /// Handle navigation when a setting is tapped
  void _handleSettingTap(String label) {
    switch (label) {
      case 'About':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
        break;
      // Add more cases for other settings as needed
      default:
        // Show coming soon for unimplemented settings
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label coming soon'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoggingOut ? null : _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade900.withOpacity(0.3),
          foregroundColor: Colors.red.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade800.withOpacity(0.5)),
          ),
        ),
        child: _isLoggingOut
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red.shade400,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  _SettingItem(this.icon, this.label);
}
