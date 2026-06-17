import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/pose_math.dart';

class PostureAnalyzer {
  Map<String, dynamic> _heuristics = {};
  bool _isLoaded = false;

  Future<void> loadHeuristics() async {
    try {
      final jsonString = await rootBundle.loadString('assets/exercise_sources/heuristics.json');
      _heuristics = jsonDecode(jsonString);
      _isLoaded = true;
    } catch (e) {
      print("Error loading heuristics: $e");
    }
  }

  String analyzePose(Pose pose, String exerciseId) {
    if (!_isLoaded || !_heuristics.containsKey(exerciseId)) {
      return "Analyzing...";
    }

    final landmarks = pose.landmarks;
    if (landmarks.isEmpty) return "No person detected";

    final rules = _heuristics[exerciseId];
    final correctAvg = rules['correct_avg_min'] ?? {};
    final incorrectAvg = rules['incorrect_avg_min'] ?? {};

    // Analyze Hip / Spine (Posture)
    if (landmarks[PoseLandmarkType.leftShoulder] != null && 
        landmarks[PoseLandmarkType.leftHip] != null && 
        landmarks[PoseLandmarkType.leftKnee] != null) {
      double lHip = PoseMath.calculateAngle(landmarks[PoseLandmarkType.leftShoulder]!, landmarks[PoseLandmarkType.leftHip]!, landmarks[PoseLandmarkType.leftKnee]!);
      
      if (correctAvg.containsKey('L_Hip_mean') && incorrectAvg.containsKey('L_Hip_mean')) {
         double correctLHip = correctAvg['L_Hip_mean'];
         double incorrectLHip = incorrectAvg['L_Hip_mean'];
         if ((lHip - incorrectLHip).abs() < (lHip - correctLHip).abs()) {
           return "⚠️ Keep your back straight!";
         }
      }
    }

    // Analyze Knee
    if (landmarks[PoseLandmarkType.leftHip] != null && 
        landmarks[PoseLandmarkType.leftKnee] != null && 
        landmarks[PoseLandmarkType.leftAnkle] != null) {
      double lKnee = PoseMath.calculateAngle(landmarks[PoseLandmarkType.leftHip]!, landmarks[PoseLandmarkType.leftKnee]!, landmarks[PoseLandmarkType.leftAnkle]!);
      
      if (correctAvg.containsKey('L_Knee_mean') && incorrectAvg.containsKey('L_Knee_mean')) {
         double correctLKnee = correctAvg['L_Knee_mean'];
         double incorrectLKnee = incorrectAvg['L_Knee_mean'];
         if ((lKnee - incorrectLKnee).abs() < (lKnee - correctLKnee).abs()) {
           return "⚠️ Check your knee extension!";
         }
      }
    }

    // Analyze Elbow
    if (landmarks[PoseLandmarkType.leftShoulder] != null && 
        landmarks[PoseLandmarkType.leftElbow] != null && 
        landmarks[PoseLandmarkType.leftWrist] != null) {
      double lElbow = PoseMath.calculateAngle(landmarks[PoseLandmarkType.leftShoulder]!, landmarks[PoseLandmarkType.leftElbow]!, landmarks[PoseLandmarkType.leftWrist]!);
      
      if (correctAvg.containsKey('L_Elbow_mean') && incorrectAvg.containsKey('L_Elbow_mean')) {
         double correctLElbow = correctAvg['L_Elbow_mean'];
         double incorrectLElbow = incorrectAvg['L_Elbow_mean'];
         if ((lElbow - incorrectLElbow).abs() < (lElbow - correctLElbow).abs() && (lElbow - incorrectLElbow).abs() < 20) {
           return "⚠️ Watch your arm extension!";
         }
      }
    }

    return "✅ Great form! Keep it up.";
  }
}
