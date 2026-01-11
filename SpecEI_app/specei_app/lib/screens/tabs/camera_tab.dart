import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import '../../core/app_colors.dart';
import '../../services/memory_data_service.dart';
import '../../services/recording_service.dart';
// permission_state_service removed as unused
import 'package:permission_handler/permission_handler.dart';

/// Check if camera plugin is supported on current platform
bool get _isCameraPluginSupported {
  if (kIsWeb) return true; // camera_web package handles this
  try {
    // Camera plugin only supports iOS, Android, and Web
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}

/// Camera Tab - Live camera preview with AI features
/// Automatically activates camera when tab is opened
class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;

  // Camera state
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFrontCamera = false;
  bool _isCapturing = false;
  String? _errorMessage;

  // Mode selection: 0: Photo, 1: Video, 2: Scan, 3: Audio
  int _selectedMode = 0;
  bool _isRecording = false;
  bool _isAudioRecording = false;

  final MemoryDataService _memoryService = MemoryDataService();
  // PermissionStateService removed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Always attempt to initialize (logic handles permissions)
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _scanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  /// Initialize the camera
  Future<void> _initializeCamera() async {
    // Check if camera plugin is supported on this platform
    if (!_isCameraPluginSupported) {
      setState(() {
        _errorMessage =
            'Camera preview is not available on Windows desktop.\n\nYou can still use the Photo and Video buttons below to pick media from your device.';
        _isCameraInitialized = false;
      });
      return;
    }

    // Request permissions on mobile
    // Request permissions on mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraStatus = statuses[Permission.camera];
      final micStatus = statuses[Permission.microphone];

      if (cameraStatus != PermissionStatus.granted ||
          micStatus != PermissionStatus.granted) {
        // If permanently denied, show specific message to open settings
        if (cameraStatus == PermissionStatus.permanentlyDenied ||
            micStatus == PermissionStatus.permanentlyDenied) {
          setState(() {
            _errorMessage =
                'Permissions are permanently denied.\n\nPlease tap "Open Settings" to enable Camera and Microphone manually.';
            _isCameraInitialized = false;
          });
          return;
        }

        // If just denied, we can ask again (handled by retry button)
        setState(() {
          _errorMessage =
              'Camera and Microphone permissions are REQUIRED for this app to function.\n\nTap below to grant access.';
          _isCameraInitialized = false;
        });
        return;
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available on this device';
          _isCameraInitialized = false;
        });
        return;
      }

      // Select front or back camera
      final camera = _isFrontCamera
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            )
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first,
            );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera initialization failed: $e';
        _isCameraInitialized = false;
      });
    }
  }

  /// Switch between front and back camera
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();
    await _initializeCamera();
  }

  /// Show a beautiful save success notification
  void _showSaveSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Capture photo from camera or pick from device
  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      XFile? photo;

      // If camera is initialized, take picture directly
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        photo = await _cameraController!.takePicture();
      } else {
        // Use image_picker as fallback (Windows, or when camera unavailable)
        final ImagePicker picker = ImagePicker();
        photo = await picker.pickImage(source: ImageSource.camera);
        // If camera not available via picker, try gallery
        photo ??= await picker.pickImage(source: ImageSource.gallery);
      }

      if (photo == null) {
        setState(() => _isCapturing = false);
        return;
      }

      final bytes = await photo.readAsBytes();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Save to Supabase
      final media = await _memoryService.addMediaWithFile(
        type: MediaType.photo,
        fileName: fileName,
        fileBytes: bytes,
        mimeType: 'image/jpeg',
      );

      if (mounted) {
        setState(() => _isCapturing = false);

        if (media != null) {
          _showSaveSuccess('Photo saved!');
        }
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      // Silent error - just don't show harsh red messages
      debugPrint('Photo capture error: $e');
    }
  }

  /// Toggle video recording
  Future<void> _toggleVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      // Stop recording
      try {
        final XFile video = await _cameraController!.stopVideoRecording();
        final bytes = await video.readAsBytes();
        final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

        setState(() => _isRecording = false);

        final media = await _memoryService.addMediaWithFile(
          type: MediaType.video,
          fileName: fileName,
          fileBytes: bytes,
          mimeType: 'video/mp4',
        );

        if (mounted && media != null) {
          _showSaveSuccess('Video saved!');
        }
      } catch (e) {
        setState(() => _isRecording = false);
        debugPrint('Video error: $e');
      }
    } else {
      // Start recording
      try {
        await _cameraController!.startVideoRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        debugPrint('Cannot start recording: $e');
      }
    }
  }

  /// Toggle audio recording
  Future<void> _toggleAudioRecording() async {
    if (_isAudioRecording) {
      // Stop recording
      try {
        final result = await RecordingService().stopAudioRecording();
        setState(() => _isAudioRecording = false);

        if (result != null && mounted) {
          _showSaveSuccess('Audio saved!');
        }
      } catch (e) {
        setState(() => _isAudioRecording = false);
        debugPrint('Audio error: $e');
      }
    } else {
      // Start recording
      try {
        final started = await RecordingService().startAudioRecording();
        if (started && mounted) {
          setState(() => _isAudioRecording = true);
        }
      } catch (e) {
        debugPrint('Cannot start audio recording: $e');
      }
    }
  }

  /// Get the tap handler for the capture button based on current mode
  VoidCallback? _getCaptureTapHandler() {
    switch (_selectedMode) {
      case 0: // Photo - works with camera or image_picker fallback
      case 2: // Scan (same as photo for now)
        return !_isCapturing ? _capturePhoto : null;
      case 1: // Video - requires camera
        return (_isCameraInitialized && !_isCapturing)
            ? _toggleVideoRecording
            : null;
      case 3: // Audio - always available
        return _toggleAudioRecording;
      default:
        return null;
    }
  }

  /// Get the icon for the capture button based on current mode
  IconData _getCaptureIcon() {
    switch (_selectedMode) {
      case 0: // Photo
        return Icons.camera_alt;
      case 1: // Video
        return _isRecording ? Icons.stop : Icons.videocam;
      case 2: // Scan
        return Icons.document_scanner;
      case 3: // Audio
        return _isAudioRecording ? Icons.stop : Icons.mic;
      default:
        return Icons.camera_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview or placeholder
        _buildCameraPreview(),

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
        if (_isCameraInitialized) ...[
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

  /// Build camera preview widget
  Widget _buildCameraPreview() {
    if (_isCameraInitialized && _cameraController != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 100,
            height: _cameraController!.value.previewSize?.width ?? 100,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    } else if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_errorMessage != null &&
                        _errorMessage!.contains('Open Settings')) {
                      openAppSettings();
                    } else {
                      _initializeCamera();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    (_errorMessage != null &&
                            _errorMessage!.contains('Open Settings'))
                        ? 'Open Settings'
                        : 'Grant Permissions',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Loading state
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }
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
                color: _isCameraInitialized
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
                        color: _isCameraInitialized
                            ? AppColors.primary
                            : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isCameraInitialized
                                        ? AppColors.primary
                                        : Colors.red)
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
                  _isCameraInitialized ? 'Camera Active' : 'Connecting...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isCameraInitialized
                        ? AppColors.primary
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // Camera switch & settings
          Row(
            children: [
              // Switch camera button
              GestureDetector(
                onTap: _cameras.length > 1 ? _switchCamera : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(
                    Icons.cameraswitch,
                    size: 20,
                    color: _cameras.length > 1
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                  ),
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
              color: _isCameraInitialized ? AppColors.primary : Colors.orange,
              boxShadow: [
                BoxShadow(
                  color:
                      (_isCameraInitialized ? AppColors.primary : Colors.orange)
                          .withOpacity(0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isCameraInitialized ? 'VISION MODE ACTIVE' : 'INITIALIZING...',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _isCameraInitialized ? AppColors.primary : Colors.orange,
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
              _buildModeChip(
                'Photo',
                _selectedMode == 0,
                () => setState(() => _selectedMode = 0),
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                'Video',
                _selectedMode == 1,
                () => setState(() => _selectedMode = 1),
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                'Scan',
                _selectedMode == 2,
                () => setState(() => _selectedMode = 2),
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                'Audio',
                _selectedMode == 3,
                () => setState(() => _selectedMode = 3),
              ),
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

              // Capture button - handles Photo, Video, Scan, and Audio modes
              GestureDetector(
                onTap: _getCaptureTapHandler(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isCapturing || _isRecording || _isAudioRecording
                      ? 72
                      : 80,
                  height: _isCapturing || _isRecording || _isAudioRecording
                      ? 72
                      : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: _isRecording || _isAudioRecording
                          ? Colors.red
                          : (_isCameraInitialized || _selectedMode == 3
                                ? AppColors.primary
                                : Colors.grey),
                      width: 4,
                    ),
                    boxShadow: (_isCameraInitialized || _selectedMode == 3)
                        ? [
                            BoxShadow(
                              color:
                                  ((_isRecording || _isAudioRecording)
                                          ? Colors.red
                                          : AppColors.primary)
                                      .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isCapturing
                          ? 24
                          : ((_isRecording || _isAudioRecording) ? 28 : 56),
                      height: _isCapturing
                          ? 24
                          : ((_isRecording || _isAudioRecording) ? 28 : 56),
                      decoration: BoxDecoration(
                        shape: (_isRecording || _isAudioRecording)
                            ? BoxShape.rectangle
                            : BoxShape.circle,
                        borderRadius: (_isRecording || _isAudioRecording)
                            ? BorderRadius.circular(4)
                            : null,
                        color: (_isRecording || _isAudioRecording)
                            ? Colors.red
                            : ((_isCameraInitialized || _selectedMode == 3)
                                  ? AppColors.primary
                                  : Colors.grey),
                      ),
                      child: _isCapturing
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
                          : Icon(
                              _getCaptureIcon(),
                              color: Colors.black,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),

              // Switch camera button
              GestureDetector(
                onTap: _cameras.length > 1 ? _switchCamera : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(
                    Icons.cameraswitch,
                    color: _cameras.length > 1
                        ? AppColors.textMuted
                        : AppColors.textDimmed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
