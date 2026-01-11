import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/memory_data_service.dart';

/// Full-screen camera with live preview
/// Supports photo capture, video recording, front/back camera switch
class CameraScreen extends StatefulWidget {
  final bool startInVideoMode;

  const CameraScreen({super.key, this.startInVideoMode = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isRecordingVideo = false;
  bool _isFrontCamera = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  String? _errorMessage;

  final MemoryDataService _memoryService = MemoryDataService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
          _isInitialized = false;
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

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });

        // Auto-start video recording if requested
        if (widget.startInVideoMode && !_isRecordingVideo) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _toggleVideoRecording();
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
        _isInitialized = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isInitialized = false;
    });

    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      // Flash not supported
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // Capture the photo
      final XFile photo = await _controller!.takePicture();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Photo saved to memory!'),
                ],
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          // Return to previous screen
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Cannot toggle video: controller not initialized');
      return;
    }

    if (_isRecordingVideo) {
      // Stop recording
      try {
        print('Stopping video recording...');
        final XFile video = await _controller!.stopVideoRecording();
        final bytes = await video.readAsBytes();
        final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

        setState(() => _isRecordingVideo = false);

        // Save to Supabase
        final media = await _memoryService.addMediaWithFile(
          type: MediaType.video,
          fileName: fileName,
          fileBytes: bytes,
          mimeType: 'video/mp4',
        );

        if (mounted && media != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Video saved to memory!'),
                ],
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Error stopping video: $e');
        setState(() => _isRecordingVideo = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Start recording
      try {
        print('Starting video recording...');
        await _controller!.startVideoRecording();
        print('Video recording started successfully!');
        setState(() => _isRecordingVideo = true);
      } catch (e) {
        print('Error starting video recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video recording not supported: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview or error/loading state
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!)
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initializeCamera,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Top bar with close and flash buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  _buildControlButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  // Flash toggle (only if camera is initialized)
                  if (_isInitialized && !_isFrontCamera)
                    _buildControlButton(
                      icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      onTap: _toggleFlash,
                    ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Recording indicator
                if (_isRecordingVideo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recording',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Control buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Switch camera button
                    _buildControlButton(
                      icon: Icons.cameraswitch,
                      onTap: _cameras.length > 1 ? _switchCamera : null,
                      size: 50,
                    ),
                    // Capture/Record button
                    GestureDetector(
                      onTap: _isCapturing
                          ? null
                          : (_isRecordingVideo || widget.startInVideoMode
                                ? _toggleVideoRecording
                                : _capturePhoto),
                      onLongPress: _toggleVideoRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecordingVideo
                                ? Colors.red
                                : Colors.white,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _isRecordingVideo
                                  ? Colors.red
                                  : (_isCapturing ? Colors.grey : Colors.white),
                              shape: _isRecordingVideo
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: _isRecordingVideo
                                  ? BorderRadius.circular(8)
                                  : null,
                            ),
                            child: _isCapturing
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    // Video mode indicator
                    _buildControlButton(
                      icon: Icons.videocam,
                      onTap: _toggleVideoRecording,
                      size: 50,
                      isActive: _isRecordingVideo,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Instructions
                Text(
                  widget.startInVideoMode || _isRecordingVideo
                      ? (_isRecordingVideo
                            ? 'Tap to stop recording'
                            : 'Tap to start recording')
                      : 'Tap to take photo • Tap video icon to record',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onTap,
    double size = 44,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.red.withOpacity(0.8)
              : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white38,
          size: size * 0.5,
        ),
      ),
    );
  }
}
