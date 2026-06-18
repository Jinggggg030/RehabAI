import 'package:flutter/foundation.dart';
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
    try {
      final jsonString = await rootBundle.loadString(
        'assets/exercise_sources/heuristics.json',
      );

      _heuristics = jsonDecode(jsonString);
      _isLoaded = true;
    } catch (e) {
      print("Error loading heuristics: $e");
    }
  }

  PostureResult analyzePose(
    Pose pose,
    String exerciseId,
  ) {
    if (!_isLoaded || !_heuristics.containsKey(exerciseId)) {
      return const PostureResult(
        accuracy: 0,
        feedback: "Analyzing...",
        correctPose: false,
      );
    }

    final landmarks = pose.landmarks;

    if (landmarks.isEmpty) {
      return const PostureResult(
        accuracy: 0,
        feedback: "No person detected",
        correctPose: false,
      );
    }

    final rules = _heuristics[exerciseId];
    debugPrint("Exercise ID = $exerciseId");
    debugPrint("Keys = ${_heuristics.keys}");
    debugPrint("Rules = $rules");

    final correctAvg =
        rules['correct_avg_min'] ?? {};

    List<double> scores = [];

    void compareAngle(
      double current,
      String key,
    ) {
      if (correctAvg.containsKey(key)) {
        double target =
            correctAvg[key].toDouble();

        double error =
            (current - target).abs();

        double score =
            (100 - error).clamp(0, 100);

        scores.add(score);
      }
    }

    if (landmarks[
            PoseLandmarkType.leftShoulder] !=
        null &&
        landmarks[
                PoseLandmarkType.leftHip] !=
            null &&
        landmarks[
                PoseLandmarkType.leftKnee] !=
            null) {
      double angle =
          PoseMath.calculateAngle(
        landmarks[
            PoseLandmarkType.leftShoulder]!,
        landmarks[
            PoseLandmarkType.leftHip]!,
        landmarks[
            PoseLandmarkType.leftKnee]!,
      );

      compareAngle(angle, "L_Hip_mean");
    }

    if (landmarks[
            PoseLandmarkType.leftHip] !=
        null &&
        landmarks[
                PoseLandmarkType.leftKnee] !=
            null &&
        landmarks[
                PoseLandmarkType.leftAnkle] !=
            null) {
      double angle =
          PoseMath.calculateAngle(
        landmarks[
            PoseLandmarkType.leftHip]!,
        landmarks[
            PoseLandmarkType.leftKnee]!,
        landmarks[
            PoseLandmarkType.leftAnkle]!,
      );

      compareAngle(angle, "L_Knee_mean");
    }

    if (landmarks[
            PoseLandmarkType.leftShoulder] !=
        null &&
        landmarks[
                PoseLandmarkType.leftElbow] !=
            null &&
        landmarks[
                PoseLandmarkType.leftWrist] !=
            null) {
      double angle =
          PoseMath.calculateAngle(
        landmarks[
            PoseLandmarkType.leftShoulder]!,
        landmarks[
            PoseLandmarkType.leftElbow]!,
        landmarks[
            PoseLandmarkType.leftWrist]!,
      );

      compareAngle(angle, "L_Elbow_mean");
    }

    double accuracy = 0;

    if (scores.isNotEmpty) {
      accuracy =
          scores.reduce((a, b) => a + b) /
              scores.length;
    }

    String feedback;

    if (accuracy >= 85) {
      feedback =
          "✅ Excellent posture!";
    } else if (accuracy >= 70) {
      feedback =
          "👍 Good posture. Minor adjustments needed.";
    } else if (accuracy >= 50) {
      feedback =
          "⚠️ Improve your alignment.";
    } else {
      feedback =
          "❌ Incorrect posture detected.";
    }

    debugPrint("Scores = $scores");
    debugPrint("Accuracy = $accuracy");

    return PostureResult(
      accuracy: accuracy,
      feedback: feedback,
      correctPose: accuracy >= 80,
    );
  }
}