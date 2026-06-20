import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum MovementState { unknown, start, end }

class RepRule {
  final String name;
  final String detector;
  final bool increasing;
  final double startThreshold;
  final double endThreshold;
  final int stableFrames;
  final int cooldownFrames;
  final String cameraGuidance;

  const RepRule({
    required this.name,
    required this.detector,
    required this.increasing,
    required this.startThreshold,
    required this.endThreshold,
    required this.stableFrames,
    required this.cooldownFrames,
    required this.cameraGuidance,
  });

  factory RepRule.fromJson(Map<String, dynamic> json) => RepRule(
    name: json['name'] as String,
    detector: json['detector'] as String,
    increasing: json['direction'] == 'increasing',
    startThreshold: (json['start_threshold'] as num).toDouble(),
    endThreshold: (json['end_threshold'] as num).toDouble(),
    stableFrames: (json['stable_frames'] as num).toInt(),
    cooldownFrames: (json['cooldown_frames'] as num).toInt(),
    cameraGuidance: json['camera_guidance'] as String,
  );
}

class MovementAnalyzer {
  static const double _minimumLikelihood = 0.5;
  static Future<Map<int, RepRule>>? _rulesFuture;

  final RepRule? rule;
  MovementState _currentState = MovementState.unknown;
  MovementState _candidateState = MovementState.unknown;
  int _candidateFrames = 0;
  int _cooldownRemaining = 0;
  double? _baselineValue;

  String lastFeedback;

  MovementAnalyzer._(this.rule)
    : lastFeedback = rule?.cameraGuidance ?? 'No rep-count rule configured.';

  bool get isSupported => rule != null;
  String get cameraGuidance => rule?.cameraGuidance ?? lastFeedback;

  static Future<MovementAnalyzer> create({
    required int? exerciseId,
    required String exerciseName,
  }) async {
    final rules = await (_rulesFuture ??= _loadRules());
    var selected = exerciseId == null ? null : rules[exerciseId];
    selected ??= _fallbackRule(exerciseName);
    return MovementAnalyzer._(selected);
  }

  static Future<Map<int, RepRule>> _loadRules() async {
    final source = await rootBundle.loadString(
      'assets/exercise_sources/rep_count_rules.json',
    );
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map(
      (id, value) => MapEntry(
        int.parse(id),
        RepRule.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  static RepRule? _fallbackRule(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('bicep curl')) {
      return const RepRule(
        name: 'Bicep Curl',
        detector: 'bicep_curl',
        increasing: true,
        startThreshold: -0.15,
        endThreshold: 0.20,
        stableFrames: 5,
        cooldownFrames: 8,
        cameraGuidance:
            'Use a front view and keep the active shoulder, elbow and wrist visible.',
      );
    }
    return null;
  }

  void reset() {
    _currentState = MovementState.unknown;
    _candidateState = MovementState.unknown;
    _candidateFrames = 0;
    _cooldownRemaining = 0;
    _baselineValue = null;
    lastFeedback = rule?.cameraGuidance ?? 'No rep-count rule configured.';
  }

  /// Counts only after a stable start -> end -> start movement cycle.
  bool analyzeForRep(Pose pose) {
    final activeRule = rule;
    if (activeRule == null) return false;

    if (_cooldownRemaining > 0) _cooldownRemaining--;
    final feature = _calculateFeature(pose, activeRule.detector);
    if (feature == null) {
      _candidateState = MovementState.unknown;
      _candidateFrames = 0;
      lastFeedback = 'Keep the required body parts inside the frame.';
      return false;
    }

    final phase = _classify(feature, activeRule);
    if (phase == MovementState.unknown) {
      _candidateState = MovementState.unknown;
      _candidateFrames = 0;
      lastFeedback = _currentState == MovementState.start
          ? 'Continue to the end position.'
          : 'Return fully to the start position.';
      return false;
    }

    if (_candidateState != phase) {
      _candidateState = phase;
      _candidateFrames = 1;
    } else {
      _candidateFrames++;
    }

    if (_candidateFrames < activeRule.stableFrames) return false;

    if (phase == MovementState.start) {
      if (_currentState == MovementState.end && _cooldownRemaining == 0) {
        _currentState = MovementState.start;
        _cooldownRemaining = activeRule.cooldownFrames;
        lastFeedback = 'Rep completed. Move to the end position again.';
        return true;
      }
      _currentState = MovementState.start;
      lastFeedback = 'Start position detected. Perform the movement.';
    } else if (_currentState == MovementState.start) {
      _currentState = MovementState.end;
      lastFeedback = 'End position detected. Return to the start position.';
    } else {
      lastFeedback = 'Move to the start position first.';
    }
    return false;
  }

  MovementState _classify(double feature, RepRule activeRule) {
    if (activeRule.increasing) {
      if (feature <= activeRule.startThreshold) return MovementState.start;
      if (feature >= activeRule.endThreshold) return MovementState.end;
    } else {
      if (feature >= activeRule.startThreshold) return MovementState.start;
      if (feature <= activeRule.endThreshold) return MovementState.end;
    }
    return MovementState.unknown;
  }

  double? _calculateFeature(Pose pose, String detector) {
    switch (detector) {
      case 'clamshell':
        return _clamshellFeature(pose);
      case 'straight_leg_raise':
        return _straightLegRaiseFeature(pose);
      case 'lateral_step_down':
        return _lateralStepDownFeature(pose);
      case 'heel_raise':
        return _baselineDeltaFeature(pose, _heelRaiseRawFeature);
      case 'toe_raise':
        return _baselineDeltaFeature(pose, _toeRaiseRawFeature);
      case 'wand_flexion':
        return _wandFlexionFeature(pose);
      case 'back_extension':
        return _baselineDeltaFeature(pose, _backExtensionRawFeature);
      case 'push_up':
        return _pushUpFeature(pose);
      case 'sit_to_stand':
        return _sitToStandFeature(pose);
      case 'knee_extension':
        return _kneeExtensionFeature(pose);
      case 'external_rotation':
        return _externalRotationFeature(pose);
      case 'low_row':
        return _armReachFeature(pose, requireBoth: true);
      case 'wall_press':
        return _wallPressFeature(pose);
      case 'shoulder_press':
        return _shoulderPressFeature(pose);
      case 'bicep_curl':
        return _bicepCurlFeature(pose);
    }
    return null;
  }

  double? _clamshellFeature(Pose pose) {
    final leftKnee = _point(pose, PoseLandmarkType.leftKnee);
    final rightKnee = _point(pose, PoseLandmarkType.rightKnee);
    final torso = _torsoLength(pose);
    if (leftKnee == null || rightKnee == null || torso == null) return null;
    return _distance(leftKnee, rightKnee) / torso;
  }

  double? _straightLegRaiseFeature(Pose pose) {
    final hipY = _midHipY(pose);
    final leftAnkle = _point(pose, PoseLandmarkType.leftAnkle);
    final rightAnkle = _point(pose, PoseLandmarkType.rightAnkle);
    final torso = _torsoLength(pose);
    if (hipY == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        torso == null) {
      return null;
    }
    return max(hipY - leftAnkle.y, hipY - rightAnkle.y) / torso;
  }

  double? _lateralStepDownFeature(Pose pose) {
    final hipY = _midHipY(pose);
    final torso = _torsoLength(pose);
    final leftKnee = _point(pose, PoseLandmarkType.leftKnee);
    final rightKnee = _point(pose, PoseLandmarkType.rightKnee);
    final leftAnkle = _point(pose, PoseLandmarkType.leftAnkle);
    final rightAnkle = _point(pose, PoseLandmarkType.rightAnkle);
    if (hipY == null ||
        torso == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }
    _baselineValue ??= hipY;
    // Image Y increases downward. A positive value therefore represents the
    // controlled hip drop during the lowering phase of a lateral step-down.
    return (hipY - _baselineValue!) / torso;
  }

  double? _heelRaiseRawFeature(Pose pose) {
    final heelY = _averageY(pose, [
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
    ]);
    final toeY = _averageY(pose, [
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ]);
    final shin = _shinLength(pose);
    if (heelY == null || toeY == null || shin == null) return null;
    return (toeY - heelY) / shin;
  }

  double? _toeRaiseRawFeature(Pose pose) {
    final heelY = _averageY(pose, [
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
    ]);
    final toeY = _averageY(pose, [
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ]);
    final shin = _shinLength(pose);
    if (heelY == null || toeY == null || shin == null) return null;
    return (heelY - toeY) / shin;
  }

  double? _wandFlexionFeature(Pose pose) {
    final shoulderY = _averageY(pose, [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ]);
    final wristY = _averageY(pose, [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ]);
    final torso = _torsoLength(pose);
    if (shoulderY == null || wristY == null || torso == null) return null;
    return (shoulderY - wristY) / torso;
  }

  double? _backExtensionRawFeature(Pose pose) {
    final shoulderY = _averageY(pose, [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ]);
    final hipY = _midHipY(pose);
    final torso = _torsoLength(pose);
    if (shoulderY == null || hipY == null || torso == null) return null;
    return (hipY - shoulderY) / torso;
  }

  double? _pushUpFeature(Pose pose) {
    final shoulderY = _averageY(pose, [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ]);
    final wristY = _averageY(pose, [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ]);
    final torso = _torsoLength(pose);
    if (shoulderY == null || wristY == null || torso == null) return null;
    return (wristY - shoulderY) / torso;
  }

  double? _sitToStandFeature(Pose pose) {
    final hipY = _midHipY(pose);
    final kneeY = _averageY(pose, [
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
    ]);
    final torso = _torsoLength(pose);
    if (hipY == null || kneeY == null || torso == null) return null;
    return (kneeY - hipY) / torso;
  }

  double? _kneeExtensionFeature(Pose pose) {
    final scores = <double>[];
    for (final side in [
      (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    ]) {
      final knee = _point(pose, side.$1);
      final ankle = _point(pose, side.$2);
      if (knee != null && ankle != null) {
        final lowerLeg = _distance(knee, ankle);
        if (lowerLeg > 0) {
          scores.add((1 - ((ankle.y - knee.y).abs() / lowerLeg)).clamp(0, 1));
        }
      }
    }
    return scores.isEmpty ? null : scores.reduce(max);
  }

  double? _externalRotationFeature(Pose pose) {
    final leftWrist = _point(pose, PoseLandmarkType.leftWrist);
    final rightWrist = _point(pose, PoseLandmarkType.rightWrist);
    final shoulderWidth = _shoulderWidth(pose);
    if (leftWrist == null || rightWrist == null || shoulderWidth == null) {
      return null;
    }
    return (leftWrist.x - rightWrist.x).abs() / shoulderWidth;
  }

  double? _armReachFeature(Pose pose, {required bool requireBoth}) {
    final torso = _torsoLength(pose);
    if (torso == null) return null;
    final values = <double>[];
    for (final side in [
      (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftWrist),
      (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightWrist),
    ]) {
      final shoulder = _point(pose, side.$1);
      final wrist = _point(pose, side.$2);
      if (shoulder != null && wrist != null) {
        values.add(_distance(shoulder, wrist) / torso);
      }
    }
    if (values.isEmpty || (requireBoth && values.length < 2)) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _wallPressFeature(Pose pose) {
    final torso = _torsoLength(pose);
    if (torso == null) return null;
    final candidates = <double>[];
    for (final side in [
      (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftWrist),
      (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightWrist),
    ]) {
      final shoulder = _point(pose, side.$1);
      final wrist = _point(pose, side.$2);
      if (shoulder != null &&
          wrist != null &&
          (shoulder.y - wrist.y).abs() / torso < 0.55) {
        candidates.add(_distance(shoulder, wrist) / torso);
      }
    }
    return candidates.isEmpty ? null : candidates.reduce(min);
  }

  double? _shoulderPressFeature(Pose pose) {
    final shoulderY = _averageY(pose, [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ]);
    final wristY = _averageY(pose, [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ]);
    final torso = _torsoLength(pose);
    if (shoulderY == null || wristY == null || torso == null) return null;
    return (shoulderY - wristY) / torso;
  }

  double? _bicepCurlFeature(Pose pose) {
    final values = <double>[];
    for (final side in [
      (
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
      ),
      (
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
      ),
    ]) {
      final shoulder = _point(pose, side.$1);
      final elbow = _point(pose, side.$2);
      final wrist = _point(pose, side.$3);
      if (shoulder != null && elbow != null && wrist != null) {
        final upperArm = _distance(shoulder, elbow);
        if (upperArm > 0) values.add((elbow.y - wrist.y) / upperArm);
      }
    }
    return values.isEmpty ? null : values.reduce(max);
  }

  double? _baselineDeltaFeature(
    Pose pose,
    double? Function(Pose) rawFeature, {
    bool invert = false,
  }) {
    final raw = rawFeature(pose);
    if (raw == null) return null;
    _baselineValue ??= raw;
    return invert ? _baselineValue! - raw : raw - _baselineValue!;
  }

  _PosePoint? _point(Pose pose, PoseLandmarkType type) {
    final landmark = pose.landmarks[type];
    if (landmark == null || landmark.likelihood < _minimumLikelihood) {
      return null;
    }
    return _PosePoint(landmark.x, landmark.y);
  }

  double? _averageY(Pose pose, List<PoseLandmarkType> types) {
    final points = types.map((type) => _point(pose, type)).toList();
    if (points.any((point) => point == null)) return null;
    return points
            .cast<_PosePoint>()
            .map((point) => point.y)
            .reduce((a, b) => a + b) /
        points.length;
  }

  double? _midHipY(Pose pose) =>
      _averageY(pose, [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip]);

  double? _torsoLength(Pose pose) {
    final leftShoulder = _point(pose, PoseLandmarkType.leftShoulder);
    final rightShoulder = _point(pose, PoseLandmarkType.rightShoulder);
    final leftHip = _point(pose, PoseLandmarkType.leftHip);
    final rightHip = _point(pose, PoseLandmarkType.rightHip);
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }
    final shoulder = _midpoint(leftShoulder, rightShoulder);
    final hip = _midpoint(leftHip, rightHip);
    final length = _distance(shoulder, hip);
    return length > 0 ? length : null;
  }

  double? _shoulderWidth(Pose pose) {
    final left = _point(pose, PoseLandmarkType.leftShoulder);
    final right = _point(pose, PoseLandmarkType.rightShoulder);
    if (left == null || right == null) return null;
    final width = _distance(left, right);
    return width > 0 ? width : null;
  }

  double? _shinLength(Pose pose) {
    final lengths = <double>[];
    for (final side in [
      (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    ]) {
      final knee = _point(pose, side.$1);
      final ankle = _point(pose, side.$2);
      if (knee != null && ankle != null) lengths.add(_distance(knee, ankle));
    }
    if (lengths.isEmpty) return null;
    final length = lengths.reduce((a, b) => a + b) / lengths.length;
    return length > 0 ? length : null;
  }

  _PosePoint _midpoint(_PosePoint a, _PosePoint b) =>
      _PosePoint((a.x + b.x) / 2, (a.y + b.y) / 2);

  double _distance(_PosePoint a, _PosePoint b) =>
      sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
}

class _PosePoint {
  final double x;
  final double y;

  const _PosePoint(this.x, this.y);
}
