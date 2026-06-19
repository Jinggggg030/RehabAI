import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/pose_math.dart';

enum MovementState { unknown, start, end }

class MovementAnalyzer {
  MovementState _currentState = MovementState.unknown;

  /// Returns true only after a complete start -> end -> start cycle.
  bool analyzeForRep(Pose pose, String exerciseName) {
    final landmarks = pose.landmarks;
    if (landmarks.isEmpty) return false;

    // Hardcoded rules based on exercise name
    final nameLower = exerciseName.toLowerCase();

    if (nameLower.contains('bicep curl')) {
      return _checkBicepCurl(landmarks);
    } else if (nameLower.contains('squat') || nameLower.contains('sit to stand')) {
      return _checkSquat(landmarks);
    } else if (nameLower.contains('leg raise')) {
      return _checkLegRaise(landmarks);
    } else if (nameLower.contains('shoulder press') || nameLower.contains('shoulder roll')) {
      return _checkShoulderPress(landmarks);
    }
    
    // Default fallback (e.g. if we don't have rules for it, we can't reliably count)
    return false;
  }

  bool _checkBicepCurl(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (landmarks[PoseLandmarkType.leftShoulder] == null ||
        landmarks[PoseLandmarkType.leftElbow] == null ||
        landmarks[PoseLandmarkType.leftWrist] == null) {
      return false;
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final elbow = landmarks[PoseLandmarkType.leftElbow]!;
    final wrist = landmarks[PoseLandmarkType.leftWrist]!;

    // Image y grows downwards. A curl moves the wrist above the elbow and then
    // back below it. Using relative landmark positions makes rep_count distinct
    // from posture's reference-angle comparison.
    final atTop = wrist.y < elbow.y && wrist.y < shoulder.y;
    final atBottom = wrist.y > elbow.y;
    return _completeCycle(atBottom: atBottom, atTop: atTop);
  }

  bool _checkSquat(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Need hip, knee, ankle
    if (landmarks[PoseLandmarkType.leftHip] == null ||
        landmarks[PoseLandmarkType.leftKnee] == null ||
        landmarks[PoseLandmarkType.leftAnkle] == null) {
      return false;
    }

    double leftKneeAngle = PoseMath.calculateAngle(
      landmarks[PoseLandmarkType.leftHip]!,
      landmarks[PoseLandmarkType.leftKnee]!,
      landmarks[PoseLandmarkType.leftAnkle]!,
    );

    // Standing: angle > 160 means START
    // Squatting: angle < 100 means END (Rep counted)
    if (leftKneeAngle > 160) {
      return _completeCycle(atBottom: true, atTop: false);
    } else if (leftKneeAngle < 100) {
      return _completeCycle(atBottom: false, atTop: true);
    }

    return false;
  }

  bool _checkLegRaise(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (landmarks[PoseLandmarkType.leftShoulder] == null ||
        landmarks[PoseLandmarkType.leftHip] == null ||
        landmarks[PoseLandmarkType.leftKnee] == null) {
      return false;
    }

    double hipAngle = PoseMath.calculateAngle(
      landmarks[PoseLandmarkType.leftShoulder]!,
      landmarks[PoseLandmarkType.leftHip]!,
      landmarks[PoseLandmarkType.leftKnee]!,
    );

    // Lying flat: hip angle ~ 170-180 -> START
    // Leg raised: hip angle < 110 -> END
    if (hipAngle > 160) {
      return _completeCycle(atBottom: true, atTop: false);
    } else if (hipAngle < 110) {
      return _completeCycle(atBottom: false, atTop: true);
    }

    return false;
  }

  bool _checkShoulderPress(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (landmarks[PoseLandmarkType.leftShoulder] == null ||
        landmarks[PoseLandmarkType.leftElbow] == null ||
        landmarks[PoseLandmarkType.leftWrist] == null) {
      return false;
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final wrist = landmarks[PoseLandmarkType.leftWrist]!;
    return _completeCycle(
      atBottom: wrist.y > shoulder.y,
      atTop: wrist.y < shoulder.y,
    );
  }

  bool _completeCycle({required bool atBottom, required bool atTop}) {
    if (atBottom) {
      if (_currentState == MovementState.end) {
        _currentState = MovementState.start;
        return true;
      }
      _currentState = MovementState.start;
    } else if (atTop && _currentState == MovementState.start) {
      _currentState = MovementState.end;
    }
    return false;
  }
}
