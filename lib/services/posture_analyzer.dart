import 'dart:convert';
import 'dart:math';

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

class PostureCheck {
  final String metric;
  final String label;
  final double minimum;
  final double maximum;
  final bool showMeasurement;
  final String? instruction;

  const PostureCheck({
    required this.metric,
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.showMeasurement,
    this.instruction,
  });

  factory PostureCheck.fromJson(Map<String, dynamic> json) => PostureCheck(
    metric: json['metric'] as String,
    label: json['label'] as String,
    minimum: (json['min'] as num).toDouble(),
    maximum: (json['max'] as num).toDouble(),
    showMeasurement: json['show_measurement'] as bool? ?? true,
    instruction: json['instruction'] as String?,
  );
}

class PostureRule {
  final String name;
  final String cameraGuidance;
  final int stableFrames;
  final List<PostureCheck> checks;

  const PostureRule({
    required this.name,
    required this.cameraGuidance,
    required this.stableFrames,
    required this.checks,
  });

  factory PostureRule.fromJson(Map<String, dynamic> json) => PostureRule(
    name: json['name'] as String,
    cameraGuidance: json['camera_guidance'] as String,
    stableFrames: (json['stable_frames'] as num).toInt(),
    checks: (json['checks'] as List<dynamic>)
        .map((item) => PostureCheck.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

enum _BodySide { left, right }

class PostureAnalyzer {
  static const double _minimumLikelihood = 0.5;
  static Future<Map<int, PostureRule>>? _rulesFuture;

  final PostureRule? rule;
  final int? requestedExerciseId;
  final String requestedExerciseName;
  int _consecutiveCorrectFrames = 0;
  _BodySide? _activeArmSide;

  PostureAnalyzer._(
    this.rule, {
    required this.requestedExerciseId,
    required this.requestedExerciseName,
  });

  bool get isSupported => rule != null;
  String get cameraGuidance => rule?.cameraGuidance ?? _unsupportedMessage;

  String get _unsupportedMessage =>
      'No posture rule found for '
      '${requestedExerciseName.isEmpty ? 'unknown exercise' : requestedExerciseName} '
      '(ID: ${requestedExerciseId ?? 'missing'}).';

  static Future<PostureAnalyzer> create({
    required int? exerciseId,
    String exerciseName = '',
  }) async {
    final rules = await (_rulesFuture ??= _loadRules());
    var selected = exerciseId == null ? null : rules[exerciseId];
    selected ??= _findRuleByName(rules, exerciseName);
    return PostureAnalyzer._(
      selected,
      requestedExerciseId: exerciseId,
      requestedExerciseName: exerciseName,
    );
  }

  static PostureRule? _findRuleByName(
    Map<int, PostureRule> rules,
    String exerciseName,
  ) {
    final name = exerciseName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (name.isEmpty) return null;
    const aliases = <int, List<String>>{
      1: ['halfkneel', 'hipflexorstretch'],
      3: ['bridging', 'bridge'],
      7: ['sidelyinghipabduction', 'hipabduction'],
      40: ['plank'],
      41: ['wallsit'],
      62: ['bicepcurl'],
      69: ['bodyweightsquat', 'squat'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any(name.contains)) return rules[entry.key];
    }
    return null;
  }

  static Future<Map<int, PostureRule>> _loadRules() async {
    final source = await rootBundle.loadString(
      'assets/exercise_sources/posture_rules.json',
    );
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map(
      (id, value) => MapEntry(
        int.parse(id),
        PostureRule.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  void reset() {
    _consecutiveCorrectFrames = 0;
    _activeArmSide = null;
  }

  PostureResult analyzePose(Pose pose) {
    final activeRule = rule;
    if (activeRule == null) {
      return PostureResult(
        accuracy: 0,
        feedback: _unsupportedMessage,
        correctPose: false,
      );
    }
    if (pose.landmarks.isEmpty) {
      reset();
      return const PostureResult(
        accuracy: 0,
        feedback: 'No person detected.',
        correctPose: false,
      );
    }

    final evaluations = activeRule.checks
        .map((check) => _evaluateCheck(pose, check))
        .toList();
    final missing = evaluations.where((evaluation) => evaluation.value == null);
    if (missing.isNotEmpty) {
      _consecutiveCorrectFrames = 0;
      return PostureResult(
        accuracy: 0,
        feedback: 'Keep the ${missing.first.check.label} visible in the frame.',
        correctPose: false,
      );
    }

    final accuracy =
        evaluations
            .map((evaluation) => evaluation.score)
            .reduce((a, b) => a + b) /
        evaluations.length;
    final failed =
        evaluations.where((evaluation) => !evaluation.passed).toList()
          ..sort((a, b) => a.score.compareTo(b.score));

    if (failed.isNotEmpty) {
      _consecutiveCorrectFrames = 0;
      return PostureResult(
        accuracy: accuracy,
        feedback: _failureFeedback(failed.first),
        correctPose: false,
      );
    }

    _consecutiveCorrectFrames++;
    final stable = _consecutiveCorrectFrames >= activeRule.stableFrames;
    return PostureResult(
      accuracy: accuracy,
      feedback: stable
          ? 'Correct posture. Keep holding.'
          : 'Good position. Hold steady '
                '($_consecutiveCorrectFrames/${activeRule.stableFrames}).',
      correctPose: stable,
    );
  }

  _CheckEvaluation _evaluateCheck(Pose pose, PostureCheck check) {
    final value = _metricValue(pose, check);
    if (value == null) {
      return _CheckEvaluation(
        check: check,
        value: null,
        score: 0,
        passed: false,
      );
    }
    final passed = value >= check.minimum && value <= check.maximum;
    final error = value < check.minimum
        ? check.minimum - value
        : value > check.maximum
        ? value - check.maximum
        : 0.0;
    final tolerance = max(10.0, check.maximum - check.minimum);
    final score = (100 - (error / tolerance * 100)).clamp(0, 100).toDouble();
    return _CheckEvaluation(
      check: check,
      value: value,
      score: score,
      passed: passed,
    );
  }

  String _failureFeedback(_CheckEvaluation evaluation) {
    final check = evaluation.check;
    if (!check.showMeasurement) {
      return check.instruction ?? 'Adjust your ${check.label}.';
    }
    final value = evaluation.value!;
    final direction = value < check.minimum ? 'Increase' : 'Reduce';
    return '$direction ${check.label}: ${value.toStringAsFixed(0)}° '
        '(target ${check.minimum.toStringAsFixed(0)}–'
        '${check.maximum.toStringAsFixed(0)}°).';
  }

  double? _metricValue(Pose pose, PostureCheck check) {
    switch (check.metric) {
      case 'best_knee_angle':
        return _bestKneeAngle(pose, (check.minimum + check.maximum) / 2);
      case 'left_knee_angle':
        return _kneeAngle(pose, _BodySide.left);
      case 'right_knee_angle':
        return _kneeAngle(pose, _BodySide.right);
      case 'left_body_alignment':
        return _bodyAlignment(pose, _BodySide.left);
      case 'right_body_alignment':
        return _bodyAlignment(pose, _BodySide.right);
      case 'best_elbow_angle':
        return _bestElbowAngle(pose, (check.minimum + check.maximum) / 2);
      case 'whole_leg_separation':
        return _wholeLegSeparation(pose);
      case 'raised_knee_angle':
        return _raisedKneeAngle(pose);
      case 'active_elbow_angle':
        return _activeElbowAngle(pose, (check.minimum + check.maximum) / 2);
      case 'active_wrist_position':
        return _activeWristPosition(pose);
      case 'thigh_horizontal_angle':
        return _thighHorizontalAngle(pose);
    }
    return null;
  }

  double? _bestKneeAngle(Pose pose, double target) {
    final values = [
      _kneeAngle(pose, _BodySide.left),
      _kneeAngle(pose, _BodySide.right),
    ].whereType<double>().toList();
    if (values.isEmpty) return null;
    values.sort((a, b) => (a - target).abs().compareTo((b - target).abs()));
    return values.first;
  }

  double? _bodyAlignment(Pose pose, _BodySide side) {
    final shoulder = _armLandmark(pose, side, 'shoulder');
    final hip = _landmark(
      pose,
      side == _BodySide.left
          ? PoseLandmarkType.leftHip
          : PoseLandmarkType.rightHip,
    );
    final ankle = _landmark(
      pose,
      side == _BodySide.left
          ? PoseLandmarkType.leftAnkle
          : PoseLandmarkType.rightAnkle,
    );
    if (shoulder == null || hip == null || ankle == null) return null;
    return PoseMath.calculateAngle(shoulder, hip, ankle);
  }

  double? _bestElbowAngle(Pose pose, double target) {
    final values = _BodySide.values
        .map((side) => _elbowAngle(pose, side))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    values.sort((a, b) => (a - target).abs().compareTo((b - target).abs()));
    return values.first;
  }

  double? _kneeAngle(Pose pose, _BodySide side) {
    final hip = _landmark(
      pose,
      side == _BodySide.left
          ? PoseLandmarkType.leftHip
          : PoseLandmarkType.rightHip,
    );
    final knee = _landmark(
      pose,
      side == _BodySide.left
          ? PoseLandmarkType.leftKnee
          : PoseLandmarkType.rightKnee,
    );
    final ankle = _landmark(
      pose,
      side == _BodySide.left
          ? PoseLandmarkType.leftAnkle
          : PoseLandmarkType.rightAnkle,
    );
    if (hip == null || knee == null || ankle == null) return null;
    return PoseMath.calculateAngle(hip, knee, ankle);
  }

  double? _wholeLegSeparation(Pose pose) {
    final leftHip = _landmark(pose, PoseLandmarkType.leftHip);
    final leftAnkle = _landmark(pose, PoseLandmarkType.leftAnkle);
    final rightHip = _landmark(pose, PoseLandmarkType.rightHip);
    final rightAnkle = _landmark(pose, PoseLandmarkType.rightAnkle);
    if (leftHip == null ||
        leftAnkle == null ||
        rightHip == null ||
        rightAnkle == null) {
      return null;
    }
    return _vectorAngle(
      leftAnkle.x - leftHip.x,
      leftAnkle.y - leftHip.y,
      rightAnkle.x - rightHip.x,
      rightAnkle.y - rightHip.y,
    );
  }

  double? _raisedKneeAngle(Pose pose) {
    final leftAnkle = _landmark(pose, PoseLandmarkType.leftAnkle);
    final rightAnkle = _landmark(pose, PoseLandmarkType.rightAnkle);
    if (leftAnkle == null || rightAnkle == null) return null;
    return _kneeAngle(
      pose,
      leftAnkle.y < rightAnkle.y ? _BodySide.left : _BodySide.right,
    );
  }

  double? _activeElbowAngle(Pose pose, double target) {
    final candidates = <_BodySide, double>{};
    for (final side in _BodySide.values) {
      final angle = _elbowAngle(pose, side);
      if (angle != null) candidates[side] = angle;
    }
    if (candidates.isEmpty) return null;
    final selected = candidates.entries.reduce(
      (a, b) => (a.value - target).abs() <= (b.value - target).abs() ? a : b,
    );
    _activeArmSide = selected.key;
    return selected.value;
  }

  double? _elbowAngle(Pose pose, _BodySide side) {
    final shoulder = _armLandmark(pose, side, 'shoulder');
    final elbow = _armLandmark(pose, side, 'elbow');
    final wrist = _armLandmark(pose, side, 'wrist');
    if (shoulder == null || elbow == null || wrist == null) return null;
    return PoseMath.calculateAngle(shoulder, elbow, wrist);
  }

  double? _activeWristPosition(Pose pose) {
    final side = _activeArmSide;
    if (side == null) return null;
    final shoulder = _armLandmark(pose, side, 'shoulder');
    final elbow = _armLandmark(pose, side, 'elbow');
    final wrist = _armLandmark(pose, side, 'wrist');
    if (shoulder == null || elbow == null || wrist == null) return null;
    final upperArm = _distance(shoulder, elbow);
    if (upperArm == 0) return null;
    final wristNearShoulder = _distance(wrist, shoulder) / upperArm <= 1.3;
    final wristRaised = wrist.y < elbow.y;
    return wristNearShoulder && wristRaised ? 1 : 0;
  }

  double? _thighHorizontalAngle(Pose pose) {
    final values = <double>[];
    for (final side in _BodySide.values) {
      final hip = _landmark(
        pose,
        side == _BodySide.left
            ? PoseLandmarkType.leftHip
            : PoseLandmarkType.rightHip,
      );
      final knee = _landmark(
        pose,
        side == _BodySide.left
            ? PoseLandmarkType.leftKnee
            : PoseLandmarkType.rightKnee,
      );
      if (hip != null && knee != null) {
        values.add(
          atan2((knee.y - hip.y).abs(), (knee.x - hip.x).abs()) * 180 / pi,
        );
      }
    }
    return values.length < 2 ? null : values.reduce(max);
  }

  PoseLandmark? _armLandmark(Pose pose, _BodySide side, String joint) {
    final type = switch ((side, joint)) {
      (_BodySide.left, 'shoulder') => PoseLandmarkType.leftShoulder,
      (_BodySide.left, 'elbow') => PoseLandmarkType.leftElbow,
      (_BodySide.left, 'wrist') => PoseLandmarkType.leftWrist,
      (_BodySide.right, 'shoulder') => PoseLandmarkType.rightShoulder,
      (_BodySide.right, 'elbow') => PoseLandmarkType.rightElbow,
      (_BodySide.right, 'wrist') => PoseLandmarkType.rightWrist,
      _ => null,
    };
    return type == null ? null : _landmark(pose, type);
  }

  PoseLandmark? _landmark(Pose pose, PoseLandmarkType type) {
    final landmark = pose.landmarks[type];
    if (landmark == null || landmark.likelihood < _minimumLikelihood) {
      return null;
    }
    return landmark;
  }

  double _vectorAngle(double ax, double ay, double bx, double by) {
    final magnitudeA = sqrt(ax * ax + ay * ay);
    final magnitudeB = sqrt(bx * bx + by * by);
    if (magnitudeA == 0 || magnitudeB == 0) return 0;
    final cosine = ((ax * bx + ay * by) / (magnitudeA * magnitudeB)).clamp(
      -1,
      1,
    );
    return acos(cosine) * 180 / pi;
  }

  double _distance(PoseLandmark a, PoseLandmark b) =>
      sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
}

class _CheckEvaluation {
  final PostureCheck check;
  final double? value;
  final double score;
  final bool passed;

  const _CheckEvaluation({
    required this.check,
    required this.value,
    required this.score,
    required this.passed,
  });
}
