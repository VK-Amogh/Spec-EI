import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../core/app_colors.dart';
import '../services/recording_service.dart';
import '../services/memory_data_service.dart';

/// Audio Recording Dialog with live timer and save option
class AudioRecordingDialog extends StatefulWidget {
  const AudioRecordingDialog({super.key});

  @override
  State<AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends State<AudioRecordingDialog> {
  final RecordingService _recordingService = RecordingService();
  final MemoryDataService _memoryService = MemoryDataService();

  bool _isRecording = false;
  bool _isSaving = false;
  bool _hasRecorded = false;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await _recordingService.startAudioRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _duration = Duration.zero;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _duration = _recordingService.recordingDuration;
          });
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to start recording. Check microphone permission.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    setState(() => _isRecording = false);

    // Show saving state
    setState(() => _isSaving = true);

    final memory = await _recordingService.stopAudioRecording();

    setState(() => _isSaving = false);

    if (memory != null) {
      setState(() => _hasRecorded = true);
      // Refresh memory data
      await _memoryService.loadFromDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Audio saved to memory!'),
              ],
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              _isSaving
                  ? 'Saving...'
                  : (_isRecording ? 'Recording' : 'Audio Saved'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Recording indicator with pulsing animation
            if (_isRecording || _isSaving)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(_isRecording ? 0.2 : 0.1),
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.orange,
                    width: 3,
                  ),
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.orange)
                      : Icon(Icons.mic, size: 48, color: Colors.red),
                ),
              ),

            const SizedBox(height: 24),

            // Timer
            Text(
              _formatDuration(_duration),
              style: GoogleFonts.robotoMono(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.red : Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            // Controls
            if (_isRecording)
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stop, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Stop & Save',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Cancel button
            if (_isRecording) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  _timer?.cancel();
                  await _recordingService.stopAudioRecording();
                  if (mounted) Navigator.pop(context, false);
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
