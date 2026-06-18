import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/posture_analyzer.dart';
import 'session_summary_page.dart';

class PoseCameraPage extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const PoseCameraPage({super.key, required this.exercise});

  @override
  State<PoseCameraPage> createState() => _PoseCameraPageState();
}

class _PoseCameraPageState extends State<PoseCameraPage> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isBusy = false;
  List<Pose> _poses = [];
  String _feedbackText = "Initializing AI...";
  late PostureAnalyzer _analyzer;
  int _sensorOrientation = 0;
  double _accuracy = 0;
int _repCount = 0;
bool _previousCorrect = false;
Timer? _timer;
int _secondsElapsed = 0;

int? _painBefore;
int? _painAfter;

  @override
  void initState() {
    super.initState();
    _analyzer = PostureAnalyzer();
    _analyzer.loadHeuristics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPainDialog(isBefore: true);
    });
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
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController?.initialize();
      print("CAMERA INITIALIZED");
      if (!mounted) return;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _secondsElapsed++;
          });
        }
      });

      _cameraController?.startImageStream(_processCameraImage);
      print("IMAGE STREAM STARTED");
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
      print("Poses detected: ${poses.length}");
      
      if (poses.isNotEmpty) {
        final result =
            _analyzer.analyzePose(
                poses.first,
                widget.exercise['exercise_id']?.toString() ?? '1'
            );
          if (mounted) {
                    if (!_previousCorrect &&
              result.correctPose) {
            _repCount++;
          }

          _previousCorrect =
              result.correctPose;

          setState(() {
            _poses = poses;
            _feedbackText =
                result.feedback;
            _accuracy =
                result.accuracy;
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _poses = [];
            _feedbackText = "Step into the frame";
          });
        }
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      _isBusy = false;
    }
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
                      isBefore ? 'Rate your Pain Before Exercise' : 'Rate your Pain After Exercise',
                      style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '0 (No Pain) to 10 (Worst Pain)',
                      style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$localPain',
                      style: GoogleFonts.readexPro(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF207866)),
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
                  child: Text('Confirm', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold, color: const Color(0xFF207866))),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _completeSessionNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSummaryPage(
          exerciseName: widget.exercise['name'] ?? 'AI Exercise',
          durationSeconds: _secondsElapsed,
          reps: _repCount,
          accuracyScore: _accuracy,
          painBefore: _painBefore,
          painAfter: _painAfter,
          exerciseId: widget.exercise['exercise_id'] ?? 1,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('AI Coach', style: GoogleFonts.readexPro(color: Colors.white, fontWeight: FontWeight.bold)),
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
              style: GoogleFonts.readexPro(color: const Color(0xFF207866), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          )
        ],
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF207866)))
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                if (_poses.isNotEmpty)
                  CustomPaint(
                    painter: PosePainter(_poses, _cameraController!.value.previewSize!),
                  ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Accuracy: ${_accuracy.toStringAsFixed(0)}%",
                          style:
                              GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Reps: $_repCount",
                          style:
                              GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Time: ${_formatTime(_secondsElapsed)}",
                          style:
                              GoogleFonts.readexPro(
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
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _feedbackText.contains('⚠️') || _feedbackText.contains('❌') ? Colors.orange : const Color(0xFF207866), width: 2)
                    ),
                    child: Text(
                      _feedbackText,
                      style: GoogleFonts.readexPro(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
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
        final x = size.width - (landmark.x * (size.width / absoluteImageSize.height)); // Mirrored X
        final y = landmark.y * (size.height / absoluteImageSize.width);
        canvas.drawCircle(Offset(x, y), 5, jointPaint);
      });
      
      // Helper to draw line
      void drawLine(PoseLandmarkType t1, PoseLandmarkType t2) {
        final l1 = pose.landmarks[t1];
        final l2 = pose.landmarks[t2];
        if (l1 != null && l2 != null) {
          final x1 = size.width - (l1.x * (size.width / absoluteImageSize.height));
          final y1 = l1.y * (size.height / absoluteImageSize.width);
          final x2 = size.width - (l2.x * (size.width / absoluteImageSize.height));
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
    return oldDelegate.poses != poses || oldDelegate.absoluteImageSize != absoluteImageSize;
  }
}
