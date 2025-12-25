import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

/// Device & Settings Tab - Combined device status and settings
/// Includes system health, controls, and app settings with logout
class DeviceSettingsTab extends StatefulWidget {
  const DeviceSettingsTab({super.key});

  @override
  State<DeviceSettingsTab> createState() => _DeviceSettingsTabState();
}

class _DeviceSettingsTabState extends State<DeviceSettingsTab>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _supabaseService = SupabaseService();
  late AnimationController _pulseController;
  bool _recordingMode = true;
  bool _isLoggingOut = false;
  int _selectedSection = 0; // 0 = Device, 1 = Settings

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
      child: Column(
        children: [
          // Header with toggle
          _buildHeader(),

          // Content based on selected section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
              child: _selectedSection == 0
                  ? _buildDeviceContent()
                  : _buildSettingsContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Title
          Text(
            'Device & Settings',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Toggle between Device and Settings
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _buildTabButton('Device', 0, Icons.smart_toy),
                _buildTabButton('Settings', 1, Icons.settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isActive = _selectedSection == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSection = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.black : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DEVICE CONTENT ====================

  Widget _buildDeviceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection status
        _buildConnectionStatus(),
        const SizedBox(height: 24),

        // System Health
        _buildSystemHealth(),
        const SizedBox(height: 24),

        // Manual Control
        _buildManualControl(),
        const SizedBox(height: 24),

        // Privacy & Sensors
        _buildPrivacySensors(),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Glasses icon with pulse
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 50 + (_pulseController.value * 10),
                    height: 50 + (_pulseController.value * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(
                        0.1 * _pulseController.value,
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Icon(Icons.visibility, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SpecEI Glasses',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(8),
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
        ],
      ),
    );
  }

  Widget _buildSystemHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYSTEM HEALTH',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                'Signal',
                'Strong',
                Icons.wifi,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHealthCard(
                'Temp',
                '34°C',
                Icons.thermostat,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHealthCard(
                'Memory',
                '12GB',
                Icons.memory,
                AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color.withOpacity(0.6)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildManualControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recording Mode',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Capture audio & video',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              _buildSwitch(
                _recordingMode,
                (v) => setState(() => _recordingMode = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildControlChip(Icons.schedule, 'Timed'),
              _buildControlChip(Icons.crop_free, 'Privacy'),
              _buildControlChip(Icons.surround_sound, 'Audio'),
              _buildControlChip(Icons.visibility_off, 'Mask'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySensors() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          _buildSensorRow(Icons.mic_off, 'Microphone', 'Off', false),
          const SizedBox(height: 12),
          _buildSensorRow(Icons.videocam_off, 'Camera', 'Off', false),
          const SizedBox(height: 12),
          _buildSensorRow(Icons.cloud_sync, 'Cloud Sync', 'Active', true),
        ],
      ),
    );
  }

  Widget _buildSensorRow(
    IconData icon,
    String label,
    String status,
    bool isActive,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                status,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(
            alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SETTINGS CONTENT ====================

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile
        _buildProfileCard(),
        const SizedBox(height: 24),

        // Settings groups
        _buildSettingsGroup('Account', [
          _SettingItem(Icons.person_outline, 'Edit Profile'),
          _SettingItem(Icons.lock_outline, 'Change Password'),
          _SettingItem(Icons.security, 'Two-Factor Auth'),
        ]),
        const SizedBox(height: 16),

        _buildSettingsGroup('Preferences', [
          _SettingItem(Icons.notifications_outlined, 'Notifications'),
          _SettingItem(Icons.language, 'Language'),
          _SettingItem(Icons.dark_mode_outlined, 'Appearance'),
        ]),
        const SizedBox(height: 16),

        _buildSettingsGroup('Support', [
          _SettingItem(Icons.help_outline, 'Help Center'),
          _SettingItem(Icons.feedback_outlined, 'Feedback'),
          _SettingItem(Icons.info_outline, 'About'),
        ]),
        const SizedBox(height: 24),

        // Logout
        _buildLogoutButton(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Version 1.0.0',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _supabaseService.getUserProfile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['full_name'] ?? user.displayName ?? 'SpecEI User';
        final email = profile?['email'] ?? user.email ?? 'user@example.com';
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : const Icon(Icons.person, size: 28, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsGroup(String title, List<_SettingItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _buildSettingRow(e.value.icon, e.value.label, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(IconData icon, String label, bool isLast) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.textMuted),
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
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoggingOut ? null : _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade900.withOpacity(0.3),
          foregroundColor: Colors.red.shade400,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.red.shade800.withOpacity(0.5)),
          ),
        ),
        child: _isLoggingOut
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
