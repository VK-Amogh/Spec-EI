import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

/// Settings Tab - User account and app settings
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _authService = AuthService();
  bool _isLoggingOut = false;

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
            const SizedBox(height: 32),

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
            onTap: () {},
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
