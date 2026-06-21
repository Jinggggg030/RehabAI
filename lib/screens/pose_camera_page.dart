import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/posture_analyzer.dart';
import '../services/voice_coach.dart';
import 'ai_session_setup_dialog.dart';
import 'session_summary_page.dart';

class PoseCameraPage extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final int? scheduleId;

  const PoseCameraPage({super.key, required this.exercise, this.scheduleId});

  @override
  State<PoseCameraPage> createState() => _PoseCameraPageState();
}

class _PoseCameraPageState extends State<PoseCameraPage> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _isBusy = false;
  List<Pose> _poses = [];
  String _feedbackText = "Initializing AI...";
  PostureAnalyzer? _analyzer;
  final VoiceCoach _voiceCoach = VoiceCoach();
  int _sensorOrientation = 0;
  double _accuracy = 0;
  double _accuracyTotal = 0;
  int _accuracySamples = 0;
  AiTrackingMode _trackingMode = AiTrackingMode.duration;
  int _targetPerSet = 30;
  int _totalSets = 3;
  int _currentSet = 1;
  int _completedSets = 0;
  int _setSecondsRemaining = 30;
  int _setRepCount = 0;
  int _totalRepCount = 0;
  bool _postureRepReady = true;
  int _correctFrames = 0;
  int _incorrectFrames = 0;
  bool _setActive = false;
  Timer? _timer;
  int _secondsElapsed = 0;

  int? _painBefore;
  int? _painAfter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configureSession();
    });
  }

  Future<void> _configureSession() async {
    final config = await showAiSessionSetupDialog(
      context,
      defaultMode: AiTrackingMode.duration,
    );
    if (!mounted || config == null) return;
    final exerciseId = _readExerciseId();
    final exerciseName = widget.exercise['name']?.toString() ?? '';
    final analyzer = await PostureAnalyzer.create(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
    );
    if (!mounted) return;
    setState(() {
      _analyzer = analyzer;
      _trackingMode = config.mode;
      _targetPerSet = config.target;
      _totalSets = config.sets;
      _painBefore = config.painBefore;
      _setSecondsRemaining = config.target;
      _feedbackText = analyzer.isSupported
          ? '${analyzer.cameraGuidance} Tap Start Set when ready.'
          : analyzer.cameraGuidance;
    });
    await _initializeCamera();
  }

  int? _readExerciseId() {
    final rawId =
        widget.exercise['exercise_id'] ??
        widget.exercise['exerciseId'] ??
        widget.exercise['id'];
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId?.toString().trim() ?? '');
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Use front camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _sensorOrientation = camera.sensorOrientation;

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController?.initialize();
      debugPrint('Camera initialized');
      if (!mounted) return;

      _cameraController?.startImageStream(_processCameraImage);
      debugPrint('Image stream started');
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        final analyzer = _analyzer;
        if (analyzer == null) return;
        final result = analyzer.analyzePose(poses.first);
        if (mounted) {
          var reachedTarget = false;
          var repCompleted = false;
          if (_setActive && result.accuracy > 0) {
            _accuracyTotal += result.accuracy;
            _accuracySamples++;
          }

          if (_setActive && _trackingMode == AiTrackingMode.reps) {
            if (result.correctPose) {
              _correctFrames++;
              _incorrectFrames = 0;
              if (_postureRepReady && _correctFrames >= 5) {
                _setRepCount++;
                _totalRepCount++;
                repCompleted = true;
                _postureRepReady = false;
                reachedTarget = _setRepCount >= _targetPerSet;
              }
            } else {
              _incorrectFrames++;
              _correctFrames = 0;
              if (_incorrectFrames >= 5) _postureRepReady = true;
            }
          }

          setState(() {
            _poses = poses;
            _feedbackText = result.feedback;
            _accuracy = result.accuracy;
          });
          if (reachedTarget) {
            _finishSet();
          } else if (_setActive && repCompleted) {
            unawaited(
              _voiceCoach.speak('Rep $_setRepCount completed.', force: true),
            );
          } else if (_setActive) {
            unawaited(_voiceCoach.speak(result.feedback));
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _poses = [];
            _feedbackText = "Step into the frame";
          });
          if (_setActive) {
            unawaited(_voiceCoach.speak('Step into the frame.'));
          }
        }
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      _isBusy = false;
    }
  }

  void _startSet() {
    final analyzer = _analyzer;
    if (analyzer == null || !analyzer.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Posture detection is not configured for this exercise.',
          ),
        ),
      );
      return;
    }
    _timer?.cancel();
    analyzer.reset();
    setState(() {
      _setActive = true;
      _setRepCount = 0;
      _setSecondsRemaining = _targetPerSet;
      _postureRepReady = true;
      _correctFrames = 0;
      _incorrectFrames = 0;
      _feedbackText = 'Set $_currentSet started. Hold the correct posture.';
    });
    unawaited(_voiceCoach.speak(_feedbackText, force: true));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_setActive) return;
      var shouldFinish = false;
      setState(() {
        _secondsElapsed++;
        if (_trackingMode == AiTrackingMode.duration) {
          _setSecondsRemaining--;
          shouldFinish = _setSecondsRemaining <= 0;
        }
      });
      if (shouldFinish) _finishSet();
    });
  }

  void _finishSet() {
    if (!_setActive) return;
    _timer?.cancel();
    setState(() {
      _setActive = false;
      _completedSets++;
      _feedbackText = 'Set $_currentSet of $_totalSets complete.';
    });
    unawaited(_voiceCoach.speak(_feedbackText, force: true));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showSetCompleteDialog(),
    );
  }

  Future<void> _showSetCompleteDialog() async {
    if (!mounted) return;
    final hasNextSet = _currentSet < _totalSets;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Set $_currentSet / $_totalSets complete'),
        content: Text(
          hasNextSet
              ? 'Take a rest. Start the next set when you are ready.'
              : 'You completed all planned sets.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showPainDialog(isBefore: false);
            },
            child: Text(hasNextSet ? 'Stop Performing' : 'Finish'),
          ),
          if (hasNextSet)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() => _currentSet++);
                _startSet();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF207866),
              ),
              child: const Text('Start Next Set'),
            ),
        ],
      ),
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(_sensorOrientation);
    if (rotation == null) return null;

    final bytes = image.planes.expand((plane) => plane.bytes).toList();

    return InputImage.fromBytes(
      bytes: Uint8List.fromList(bytes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _showPainDialog({required bool isBefore}) {
    int localPain = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isBefore ? 'Exercise Setup' : 'Session Complete'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isBefore
                          ? 'Rate your Pain Before Exercise'
                          : 'Rate your Pain After Exercise',
                      style: GoogleFonts.readexPro(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '0 (No Pain) to 10 (Worst Pain)',
                      style: GoogleFonts.readexPro(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$localPain',
                      style: GoogleFonts.readexPro(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF207866),
                      ),
                    ),
                    Slider(
                      value: localPain.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: const Color(0xFF207866),
                      onChanged: (value) {
                        setDialogState(() {
                          localPain = value.toInt();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (isBefore) {
                        _painBefore = localPain;
                        _secondsElapsed = 0;
                      } else {
                        _painAfter = localPain;
                      }
                    });
                    Navigator.pop(context);
                    if (isBefore) {
                      _initializeCamera();
                    } else {
                      _completeSessionNavigation();
                    }
                  },
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.readexPro(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _completeSessionNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSummaryPage(
          exerciseName: widget.exercise['name'] ?? 'AI Exercise',
          durationSeconds: _secondsElapsed,
          reps: _trackingMode == AiTrackingMode.reps ? _totalRepCount : null,
          accuracyScore: _accuracySamples == 0
              ? 0
              : _accuracyTotal / _accuracySamples,
          painBefore: _painBefore,
          painAfter: _painAfter,
          exerciseId: widget.exercise['exercise_id'] ?? 1,
          scheduleId: widget.scheduleId,
          completedSets: _completedSets,
          plannedSets: _totalSets,
          sessionOrigin:
              widget.exercise['session_origin']?.toString() ?? 'Self-selected',
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.close();
    unawaited(_voiceCoach.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'AI Coach',
          style: GoogleFonts.readexPro(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              _timer?.cancel();
              _cameraController?.stopImageStream();
              _showPainDialog(isBefore: false);
            },
            child: Text(
              "Finish",
              style: GoogleFonts.readexPro(
                color: const Color(0xFF207866),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF207866)),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                if (_poses.isNotEmpty)
                  CustomPaint(
                    painter: PosePainter(
                      _poses,
                      _cameraController!.value.previewSize!,
                    ),
                  ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set $_currentSet / $_totalSets',
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Accuracy: ${_accuracy.toStringAsFixed(0)}%",
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _trackingMode == AiTrackingMode.duration
                              ? 'Time left: ${_formatTime(_setSecondsRemaining)}'
                              : 'Reps: $_setRepCount / $_targetPerSet',
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _accuracy < 70
                            ? Colors.orange
                            : const Color(0xFF207866),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _feedbackText,
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!_setActive) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _startSet,
                            icon: const Icon(Icons.play_arrow),
                            label: Text('Start Set $_currentSet'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF207866),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;

  PosePainter(this.poses, this.absoluteImageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = const Color(0xFF207866);

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..color = Colors.white;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        final x =
            size.width -
            (landmark.x *
                (size.width / absoluteImageSize.height)); // Mirrored X
        final y = landmark.y * (size.height / absoluteImageSize.width);
        canvas.drawCircle(Offset(x, y), 5, jointPaint);
      });

      // Helper to draw line
      void drawLine(PoseLandmarkType t1, PoseLandmarkType t2) {
        final l1 = pose.landmarks[t1];
        final l2 = pose.landmarks[t2];
        if (l1 != null && l2 != null) {
          final x1 =
              size.width - (l1.x * (size.width / absoluteImageSize.height));
          final y1 = l1.y * (size.height / absoluteImageSize.width);
          final x2 =
              size.width - (l2.x * (size.width / absoluteImageSize.height));
          final y2 = l2.y * (size.height / absoluteImageSize.width);
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        }
      }

      // Torso
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Arms
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Legs
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.absoluteImageSize != absoluteImageSize;
  }
}
