import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/posture_analyzer.dart';

enum MovementPhase {
  start,
  contracted,
  extended
}

class PoseCameraPage extends StatefulWidget {
  final String exerciseId;

  const PoseCameraPage({super.key, required this.exerciseId});

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
  MovementPhase _phase =
      MovementPhase.start;

  Timer? _timer;
  int _seconds = 0;
  int _setCount = 0;

  @override
  void initState() {
    super.initState();
    _analyzer = PostureAnalyzer();
    _analyzer.loadHeuristics().then((_) {
      _initializeCamera();
    });
  }

  void _updateRepCounter(
    double kneeAngle) {

    switch (_phase) {

      case MovementPhase.start:

        if (kneeAngle < 120) {
          _phase =
              MovementPhase.contracted;
        }

        break;

      case MovementPhase.contracted:

        if (kneeAngle > 150) {

          _phase =
              MovementPhase.extended;

          _repCount++;
          if (_repCount >= 10) {

            _setCount++;

            _repCount = 0;
          }
        }

        break;

      case MovementPhase.extended:

        if (kneeAngle < 120) {
          _phase =
              MovementPhase.contracted;
        }

        break;
    }
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
      if (!mounted) return;

      _cameraController?.startImageStream(_processCameraImage);
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
        final result =
            _analyzer.analyzePose(
                poses.first,
                widget.exerciseId
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

  @override
  void dispose() {
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
