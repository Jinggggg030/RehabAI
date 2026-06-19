import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../utils/pose_math.dart';

class PostureResult {
  final double accuracy;
  final String feedback;
  final bool correctPose;

  const PostureResult({
    required this.accuracy,
    required this.feedback,
    required this.correctPose,
  });
}

class PostureAnalyzer {
  Map<String, dynamic> _heuristics = {};
  bool _isLoaded = false;

  Future<void> loadHeuristics() async {
    final jsonString = await rootBundle.loadString(
      'assets/exercise_sources/heuristics.json',
    );
    _heuristics = jsonDecode(jsonString);
    _isLoaded = true;
  }

  PostureResult analyzePose(
    Pose pose,
    String exerciseId, {
    double? referenceJointAngle,
  }) {
    if (!_isLoaded) {
      return const PostureResult(
        accuracy: 0,
        feedback: 'Analyzing...',
        correctPose: false,
      );
    }

    final landmarks = pose.landmarks;
    if (landmarks.isEmpty) {
      return const PostureResult(
        accuracy: 0,
        feedback: 'No person detected',
        correctPose: false,
      );
    }

    final rules = _heuristics[exerciseId] as Map<String, dynamic>?;
    final correct =
        (rules?['correct_avg_min'] as Map<String, dynamic>?) ?? {};
    final scores = <double>[];

    void compareDatasetAngle(double current, String prefix) {
      final minValue = correct['${prefix}_min'];
      final maxValue = correct['${prefix}_max'];
      final meanValue = correct['${prefix}_mean'];
      if (minValue == null && maxValue == null && meanValue == null) return;

      final target = (meanValue ?? minValue ?? maxValue).toDouble();
      final min = minValue?.toDouble() ?? target - 12;
      final max = maxValue?.toDouble() ?? target + 12;
      final tolerance = ((max - min).abs() / 2).clamp(10.0, 25.0);
      final error = current < min
          ? min - current
          : current > max
              ? current - max
              : 0.0;
      scores.add(
        (100 - (error / tolerance * 100)).clamp(0, 100).toDouble(),
      );
    }

    void scoreAngle(
      PoseLandmarkType first,
      PoseLandmarkType middle,
      PoseLandmarkType last,
      String prefix, {
      double? reference,
    }) {
      final a = landmarks[first];
      final b = landmarks[middle];
      final c = landmarks[last];
      if (a == null || b == null || c == null) return;

      final current = PoseMath.calculateAngle(a, b, c);
      if (reference != null) {
        const tolerance = 15.0;
        final error = (current - reference).abs();
        scores.add(
          (100 - (error / tolerance * 100)).clamp(0, 100).toDouble(),
        );
      } else {
        compareDatasetAngle(current, prefix);
      }
    }

    scoreAngle(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      'L_Hip',
    );
    scoreAngle(
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
      'L_Knee',
    );
    scoreAngle(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
      'L_Elbow',
      // Existing records define reference_joint_angle for the primary elbow.
      reference: referenceJointAngle,
    );

    if (scores.isEmpty) {
      return const PostureResult(
        accuracy: 0,
        feedback: 'Move your full body into the frame',
        correctPose: false,
      );
    }

    final accuracy = scores.reduce((a, b) => a + b) / scores.length;
    final feedback = accuracy >= 85
        ? 'Excellent posture!'
        : accuracy >= 70
            ? 'Good posture. Minor adjustments needed.'
            : accuracy >= 50
                ? 'Improve your alignment.'
                : 'Incorrect posture detected.';

    return PostureResult(
      accuracy: accuracy,
      feedback: feedback,
      correctPose: accuracy >= 80,
    );
  }
}
