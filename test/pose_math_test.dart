import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rehab_ai/utils/pose_math.dart';

void main() {
  test('AT01 - calculateAngle returns 90 degrees for right angle', () {
    final first = PoseLandmark(
      type: PoseLandmarkType.leftShoulder,
      x: 0,
      y: 1,
      z: 0,
      likelihood: 1.0,
    );

    final middle = PoseLandmark(
      type: PoseLandmarkType.leftElbow,
      x: 0,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final last = PoseLandmark(
      type: PoseLandmarkType.leftWrist,
      x: 1,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final angle = PoseMath.calculateAngle(
      first,
      middle,
      last,
    );

    expect(angle, closeTo(90.0, 0.01));
  });

  test('calculateAngle returns 180 degrees for straight line', () {
    final first = PoseLandmark(
      type: PoseLandmarkType.leftShoulder,
      x: -1,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final middle = PoseLandmark(
      type: PoseLandmarkType.leftElbow,
      x: 0,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final last = PoseLandmark(
      type: PoseLandmarkType.leftWrist,
      x: 1,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final angle = PoseMath.calculateAngle(first, middle, last);

    expect(angle, closeTo(180.0, 0.01));
  });

  test('calculateAngle returns 0 when landmark distance is zero', () {
    final first = PoseLandmark(
      type: PoseLandmarkType.leftShoulder,
      x: 0,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final middle = PoseLandmark(
      type: PoseLandmarkType.leftElbow,
      x: 0,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final last = PoseLandmark(
      type: PoseLandmarkType.leftWrist,
      x: 1,
      y: 0,
      z: 0,
      likelihood: 1.0,
    );

    final angle = PoseMath.calculateAngle(first, middle, last);

    expect(angle, 0.0);
  });
}