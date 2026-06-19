import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/pose_math.dart';

enum MovementState { unknown, start, end }

class MovementAnalyzer {
  MovementState _currentState = MovementState.unknown;

  /// Analyzes the pose and returns true if a full rep was just completed.
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
    // Need shoulder, elbow, wrist
    if (landmarks[PoseLandmarkType.leftShoulder] == null ||
        landmarks[PoseLandmarkType.leftElbow] == null ||
        landmarks[PoseLandmarkType.leftWrist] == null) {
      return false;
    }

    // Usually we check the active arm, but let's just check left arm for simplicity or check both
    double leftAngle = PoseMath.calculateAngle(
      landmarks[PoseLandmarkType.leftShoulder]!,
      landmarks[PoseLandmarkType.leftElbow]!,
      landmarks[PoseLandmarkType.leftWrist]!,
    );

    // Arm straight: angle > 150 means START
    // Arm bent: angle < 50 means END (Rep counted)
    if (leftAngle > 150) {
      _currentState = MovementState.start;
    } else if (leftAngle < 50 && _currentState == MovementState.start) {
      _currentState = MovementState.end; // Wait for it to return to start
      return true; // Rep completed!
    }

    return false;
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
      _currentState = MovementState.start;
    } else if (leftKneeAngle < 100 && _currentState == MovementState.start) {
      _currentState = MovementState.end;
      return true; 
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
      _currentState = MovementState.start;
    } else if (hipAngle < 110 && _currentState == MovementState.start) {
      _currentState = MovementState.end;
      return true;
    }

    return false;
  }

  bool _checkShoulderPress(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (landmarks[PoseLandmarkType.leftShoulder] == null ||
        landmarks[PoseLandmarkType.leftElbow] == null ||
        landmarks[PoseLandmarkType.leftWrist] == null) {
      return false;
    }

    double elbowAngle = PoseMath.calculateAngle(
      landmarks[PoseLandmarkType.leftShoulder]!,
      landmarks[PoseLandmarkType.leftElbow]!,
      landmarks[PoseLandmarkType.leftWrist]!,
    );

    // Arms down/bent: angle < 90 -> START
    // Arms extended: angle > 150 -> END
    if (elbowAngle < 90) {
      _currentState = MovementState.start;
    } else if (elbowAngle > 150 && _currentState == MovementState.start) {
      _currentState = MovementState.end;
      return true;
    }

    return false;
  }
}
