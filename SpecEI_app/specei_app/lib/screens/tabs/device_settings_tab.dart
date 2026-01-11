import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/app_colors.dart';
import '../../core/app_translations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_state_service.dart';
import '../../services/locale_service.dart';
import '../login_screen.dart';
import '../edit_profile_screen.dart';
import '../change_password_settings_screen.dart';
import '../language_selection_screen.dart';
import '../appearance_screen.dart';

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
  final _permissionService = PermissionStateService();
  late AnimationController _pulseController;
  bool _isLoggingOut = false;
  int _selectedSection = 0; // 0 = Device, 1 = Settings

  // Battery state
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _batteryTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initBattery();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _batteryStateSubscription?.cancel();
    _batteryTimer?.cancel();
    super.dispose();
  }

  /// Initialize battery monitoring
  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (e) {
      debugPrint('Battery level error: $e');
    }

    try {
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen((
        state,
      ) {
        if (mounted) {
          setState(() => _batteryState = state);
          _updateBatteryLevel();
        }
      }, onError: (e) => debugPrint('Battery state error: $e'));
    } catch (e) {
      debugPrint('Battery subscription error: $e');
    }

    // Update every 10 seconds for more responsive updates
    _batteryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateBatteryLevel();
    });
  }

  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
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
    final localeService = Provider.of<LocaleService>(context);
    final lang = localeService.locale.languageCode;
    String tr(String key) => AppTranslations.translate(key, lang);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Title
          Text(
            tr('device_settings'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),

          // Toggle between Device and Settings
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorderLight(context)),
            ),
            child: Row(
              children: [
                _buildTabButton(tr('device'), 0, Icons.smart_toy),
                _buildTabButton(tr('settings'), 1, Icons.settings),
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
                color: isActive
                    ? Colors.black
                    : AppColors.getTextMuted(context),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.black
                      : AppColors.getTextMuted(context),
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
                    color: AppColors.getTextPrimary(context),
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
              color: AppColors.getInputBackground(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _batteryState == BatteryState.charging
                      ? Icons.battery_charging_full
                      : (_batteryLevel <= 20
                            ? Icons.battery_alert
                            : Icons.battery_std),
                  size: 16,
                  color: _batteryLevel <= 20 ? Colors.red : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_batteryLevel%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextSecondary(context),
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
            color: AppColors.getTextMuted(context),
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
              color: AppColors.getTextPrimary(context),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.getTextMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderLight(context)),
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
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    'Capture audio & video',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.getTextMuted(context),
                    ),
                  ),
                ],
              ),
              _buildSwitch(_permissionService.isRecordingModeEnabled, (v) {
                _permissionService.setRecordingModeEnabled(v);
                setState(() {});
              }),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildControlChip(
                Icons.schedule,
                'Timed',
                isActive: _permissionService.isTimedRecordingEnabled,
                onToggle: () {
                  _permissionService.toggleTimedRecording();
                  setState(() {});
                },
              ),
              _buildControlChip(
                Icons.crop_free,
                'Privacy',
                isActive: _permissionService.isPrivacyZonesEnabled,
                onToggle: () {
                  _permissionService.togglePrivacyZones();
                  setState(() {});
                },
              ),
              _buildControlChip(
                Icons.surround_sound,
                'Audio',
                isActive: _permissionService.isSpatialAudioEnabled,
                onToggle: () {
                  _permissionService.toggleSpatialAudio();
                  setState(() {});
                },
              ),
              _buildControlChip(
                Icons.visibility_off,
                'Mask',
                isActive: _permissionService.isAiMaskingEnabled,
                onToggle: () {
                  _permissionService.toggleAiMasking();
                  setState(() {});
                },
              ),
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
          color: value
              ? AppColors.primary
              : AppColors.getInputBackground(context),
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

  Widget _buildControlChip(
    IconData icon,
    String label, {
    bool isActive = false,
    VoidCallback? onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.getInputBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.getBorderLight(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.primary
                  : AppColors.getTextMuted(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySensors() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderLight(context)),
      ),
      child: Column(
        children: [
          _buildInteractiveSensorRow(
            icon: _permissionService.isMicrophoneEnabled
                ? Icons.mic
                : Icons.mic_off,
            label: 'Microphone',
            status: _permissionService.isMicrophoneEnabled ? 'Active' : 'Off',
            isActive: _permissionService.isMicrophoneEnabled,
            onToggle: _toggleMicrophone,
          ),
          const SizedBox(height: 12),
          _buildInteractiveSensorRow(
            icon: _permissionService.isCameraEnabled
                ? Icons.videocam
                : Icons.videocam_off,
            label: 'Camera',
            status: _permissionService.isCameraEnabled ? 'Active' : 'Off',
            isActive: _permissionService.isCameraEnabled,
            onToggle: _toggleCamera,
          ),
        ],
      ),
    );
  }

  /// Toggle microphone permission
  void _toggleMicrophone() {
    _permissionService.toggleMicrophone();
    setState(() {});
  }

  /// Toggle camera permission
  void _toggleCamera() {
    _permissionService.toggleCamera();
    setState(() {});
  }

  Widget _buildInteractiveSensorRow({
    required IconData icon,
    required String label,
    required String status,
    required bool isActive,
    required VoidCallback onToggle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.getInputBackground(context),
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
                  color: isActive
                      ? AppColors.primary
                      : AppColors.getTextMuted(context),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : AppColors.getInputBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: isActive
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
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
                : AppColors.getInputBackground(context),
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
                  color: isActive
                      ? AppColors.primary
                      : AppColors.getTextMuted(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.getInputBackground(context),
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
    final localeService = Provider.of<LocaleService>(context);
    final lang = localeService.locale.languageCode;
    String tr(String key) => AppTranslations.translate(key, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile
        _buildProfileCard(),
        const SizedBox(height: 24),

        // Settings groups
        _buildSettingsGroup(tr('account'), [
          _SettingItem(
            Icons.person_outline,
            tr('edit_profile'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          _SettingItem(
            Icons.lock_outline,
            tr('change_password'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordSettingsScreen(),
                ),
              );
            },
          ),
          _SettingItem(Icons.security, tr('two_factor_auth')),
        ]),
        const SizedBox(height: 16),

        _buildSettingsGroup(tr('preferences'), [
          _SettingItem(Icons.notifications_outlined, tr('notifications')),
          _SettingItem(
            Icons.language,
            tr('language'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(),
                ),
              );
            },
          ),
          _SettingItem(
            Icons.dark_mode_outlined,
            tr('appearance'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              );
            },
          ),
        ]),
        const SizedBox(height: 16),

        _buildSettingsGroup(tr('support'), [
          _SettingItem(Icons.help_outline, tr('help_center')),
          _SettingItem(Icons.feedback_outlined, tr('feedback')),
          _SettingItem(
            Icons.info_outline,
            tr('about'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.visibility,
                            size: 32,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SpecEI',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SpecEI is an AI-powered smart glasses ecosystem that enhances how you see, understand, and remember the world.\n\n'
                          'By combining intelligent eyewear with a powerful mobile app, SpecEI captures visual experiences, understands them using AI, and securely stores meaningful insights on your device. With a chat-style interface, you can instantly recall past moments, details, and information—just by asking.\n\n'
                          'Built with a software-first approach, SpecEI delivers advanced intelligence without expensive hardware, making smart glasses more accessible, lightweight, and practical for everyday use.\n\n'
                          'Designed for students, professionals, creators, and explorers, SpecEI brings hands-free intelligence into your daily life.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'See smarter. Understand more. Remember effortlessly.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 24),

        // Logout
        _buildLogoutButton(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${tr('version')} 1.0.0',
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

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.getBorderLight(context)),
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
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.getTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
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
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderLight(context)),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _buildSettingRow(
                e.value.icon,
                e.value.label,
                isLast,
                e.value.onTap,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(
    IconData icon,
    String label,
    bool isLast,
    VoidCallback? onTap,
  ) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getInputBackground(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: AppColors.getTextMuted(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
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
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Container(
              height: 1,
              color: AppColors.getBorderLight(context),
            ),
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    final localeService = Provider.of<LocaleService>(context);
    final lang = localeService.locale.languageCode;
    String tr(String key) => AppTranslations.translate(key, lang);

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
                    tr('log_out'),
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
  final VoidCallback? onTap;
  _SettingItem(this.icon, this.label, {this.onTap});
}
