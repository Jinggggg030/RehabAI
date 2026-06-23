import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:rehab_ai/services/movement_analyzer.dart';
import 'package:rehab_ai/services/voice_coach.dart';
import 'ai_session_setup_dialog.dart';
import 'session_summary_page.dart';

class RepCounterPage extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final int? scheduleId;

  const RepCounterPage({super.key, required this.exercise, this.scheduleId});

  @override
  State<RepCounterPage> createState() => _RepCounterPageState();
}

class _RepCounterPageState extends State<RepCounterPage> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _isBusy = false;
  List<Pose> _poses = [];
  String _feedbackText = "Initializing Camera...";
  MovementAnalyzer? _analyzer;
  final VoiceCoach _voiceCoach = VoiceCoach();
  int _sensorOrientation = 0;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  Size? _inputImageSize;
  InputImageRotation _inputImageRotation = InputImageRotation.rotation0deg;
  AiTrackingMode _trackingMode = AiTrackingMode.reps;
  int _targetPerSet = 10;
  int _totalSets = 3;
  int _currentSet = 1;
  int _completedSets = 0;
  int _setRepCount = 0;
  int _totalRepCount = 0;
  int _setSecondsRemaining = 30;
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
    final prescribed =
        widget.exercise['session_origin']?.toString().toLowerCase() ==
        'assigned';
    final prescribedMode =
        widget.exercise['assigned_tracking_mode']?.toString().toLowerCase() ==
            'reps'
        ? AiTrackingMode.reps
        : AiTrackingMode.duration;
    final prescribedTarget = prescribedMode == AiTrackingMode.duration
        ? _readPositiveInt(widget.exercise['assigned_duration'])
        : _readPositiveInt(widget.exercise['assigned_reps']);
    final config = await showAiSessionSetupDialog(
      context,
      defaultMode: prescribed ? prescribedMode : AiTrackingMode.reps,
      initialTarget: prescribed ? prescribedTarget : null,
      initialSets: prescribed
          ? _readPositiveInt(widget.exercise['assigned_sets'])
          : null,
      prescribedSettings: prescribed,
    );
    if (!mounted) return;
    if (config == null) {
      Navigator.pop(context);
      return;
    }
    final analyzer = await MovementAnalyzer.create(
      exerciseId: (widget.exercise['exercise_id'] as num?)?.toInt(),
      exerciseName: widget.exercise['name']?.toString() ?? '',
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
          : 'No automatic rep rule is configured for this exercise.';
    });
    await _initializeCamera();
  }

  int? _readPositiveInt(dynamic value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
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
      _cameraLensDirection = camera.lensDirection;

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
        final repCompleted =
            _setActive &&
            analyzer != null &&
            analyzer.analyzeForRep(poses.first);

        if (mounted) {
          var reachedTarget = false;
          if (repCompleted) {
            _setRepCount++;
            _totalRepCount++;
            reachedTarget =
                _trackingMode == AiTrackingMode.reps &&
                _setRepCount >= _targetPerSet;
          }

          setState(() {
            _poses = poses;
            if (_setActive && analyzer != null) {
              _feedbackText = analyzer.lastFeedback;
            }
          });
          if (reachedTarget) {
            _finishSet();
          } else if (_setActive && repCompleted) {
            unawaited(
              _voiceCoach.speak('Rep $_setRepCount completed.', force: true),
            );
          } else if (_setActive && analyzer != null) {
            unawaited(_voiceCoach.speak(analyzer.lastFeedback));
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
    if (_trackingMode == AiTrackingMode.reps &&
        (analyzer == null || !analyzer.isSupported)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Automatic rep counting is not configured for this exercise.',
          ),
        ),
      );
      return;
    }
    _timer?.cancel();
    setState(() {
      _setActive = true;
      _setRepCount = 0;
      _setSecondsRemaining = _targetPerSet;
      analyzer?.reset();
      _feedbackText = 'Set $_currentSet started. Keep going!';
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
                backgroundColor: const Color(0xFF1565C0),
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

    final rotation = _cameraImageRotation();
    if (rotation == null) return null;

    _inputImageSize = Size(image.width.toDouble(), image.height.toDouble());
    _inputImageRotation = rotation;

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

  InputImageRotation? _cameraImageRotation() {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(_sensorOrientation);
    }

    const orientationDegrees = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceDegrees =
        orientationDegrees[_cameraController?.value.deviceOrientation];
    if (deviceDegrees == null) return null;

    final rotationDegrees = _cameraLensDirection == CameraLensDirection.front
        ? (_sensorOrientation + deviceDegrees) % 360
        : (_sensorOrientation - deviceDegrees + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationDegrees);
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
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    Slider(
                      value: localPain.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: const Color(0xFF1565C0),
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
                      color: const Color(0xFF1565C0),
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
          exerciseName: widget.exercise['name'] ?? 'Rep Exercise',
          durationSeconds: _secondsElapsed,
          reps: _totalRepCount,
          accuracyScore: null, // No accuracy for rep counter exercises
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
          widget.exercise['name'] ?? 'Rep Counter',
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
                color: const Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                if (_poses.isNotEmpty && _inputImageSize != null)
                  CustomPaint(
                    painter: PosePainter(
                      _poses,
                      _inputImageSize!,
                      _inputImageRotation,
                      _cameraLensDirection,
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
                          "Set $_currentSet / $_totalSets",
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _trackingMode == AiTrackingMode.reps
                              ? '$_setRepCount / $_targetPerSet reps'
                              : '${_formatTime(_setSecondsRemaining)} left',
                          style: GoogleFonts.readexPro(
                            color: const Color(0xFF1565C0),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Time: ${_formatTime(_secondsElapsed)}",
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 16,
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
                        color: const Color(0xFF1565C0),
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
                              backgroundColor: const Color(0xFF1565C0),
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
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  PosePainter(
    this.poses,
    this.absoluteImageSize,
    this.rotation,
    this.lensDirection,
  );

  Offset _translate(PoseLandmark landmark, Size canvasSize) {
    late double x;
    late double y;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        x =
            landmark.x *
            canvasSize.width /
            (Platform.isIOS
                ? absoluteImageSize.width
                : absoluteImageSize.height);
        y =
            landmark.y *
            canvasSize.height /
            (Platform.isIOS
                ? absoluteImageSize.height
                : absoluteImageSize.width);
        break;
      case InputImageRotation.rotation270deg:
        x =
            landmark.x *
                canvasSize.width /
                (Platform.isIOS
                    ? absoluteImageSize.width
                    : absoluteImageSize.height);
        y =
            landmark.y *
            canvasSize.height /
            (Platform.isIOS
                ? absoluteImageSize.height
                : absoluteImageSize.width);
        break;
      case InputImageRotation.rotation0deg:
        x = landmark.x * canvasSize.width / absoluteImageSize.width;
        y = landmark.y * canvasSize.height / absoluteImageSize.height;
        break;
      case InputImageRotation.rotation180deg:
        x =
            canvasSize.width -
            landmark.x * canvasSize.width / absoluteImageSize.width;
        y =
            canvasSize.height -
            landmark.y * canvasSize.height / absoluteImageSize.height;
        break;
    }
    return Offset(
      lensDirection == CameraLensDirection.front ? canvasSize.width - x : x,
      y,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = const Color(0xFF1565C0);

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..color = Colors.white;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(_translate(landmark, size), 5, jointPaint);
      });

      void drawLine(PoseLandmarkType t1, PoseLandmarkType t2) {
        final l1 = pose.landmarks[t1];
        final l2 = pose.landmarks[t2];
        if (l1 != null && l2 != null) {
          canvas.drawLine(_translate(l1, size), _translate(l2, size), paint);
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
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.lensDirection != lensDirection;
  }
}
