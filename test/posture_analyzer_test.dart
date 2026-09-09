import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rehab_ai/services/posture_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostureAnalyzer', () {
    for (final seated in [false, true, null]) {
      test(
        'curl scores every phase and counts full cycle, seated=$seated',
        () async {
          final analyzer = await PostureAnalyzer.create(exerciseId: 62);
          var reps = 0;
          final angles = [180.0, 120.0, 90.0, 45.0, 90.0, 120.0, 180.0];
          for (var phase = 0; phase < angles.length; phase++) {
            for (var frame = 0; frame < 5; frame++) {
              final result = analyzer.analyzePose(
                _curlPose(angles[phase], seated: seated),
              );
              expect(result.accuracy, 100);
              expect(result.correctPose, isTrue);
              expect(result.feedback, isNot(contains('Hold')));
              if (result.repCompleted) reps++;
            }
            expect(reps, phase == angles.length - 1 ? 1 : 0);
          }
          expect(reps, 1);
          for (var frame = 0; frame < 10; frame++) {
            expect(analyzer.analyzePose(_curlPose(180)).repCompleted, isFalse);
          }
        },
      );
    }

    test(
      'curl rejects raised-arm form and does not bridge tracking loss',
      () async {
        final analyzer = await PostureAnalyzer.create(exerciseId: 62);
        for (final angle in [45.0, 180.0, 45.0]) {
          for (var frame = 0; frame < 5; frame++) {
            expect(
              analyzer.analyzePose(_curlPose(angle)).repCompleted,
              isFalse,
            );
          }
        }
        analyzer.analyzePose(Pose(landmarks: {}));
        for (var frame = 0; frame < 5; frame++) {
          expect(analyzer.analyzePose(_curlPose(180)).repCompleted, isFalse);
        }
        final bad = analyzer.analyzePose(_curlPose(90, raisedElbow: true));
        expect(bad.correctPose, isFalse);
        expect(bad.accuracy, lessThan(70));
        expect(bad.feedback, contains('upper arm'));
      },
    );

    test('requires eight consecutive correct wall-sit frames', () async {
      final analyzer = await PostureAnalyzer.create(exerciseId: 41);

      for (var frame = 0; frame < 7; frame++) {
        final result = analyzer.analyzePose(
          _wallSitPose(kneeAngleIsCorrect: true),
        );
        expect(result.correctPose, isFalse);
        expect(result.feedback, contains('${frame + 1}/8'));
      }

      final stable = analyzer.analyzePose(
        _wallSitPose(kneeAngleIsCorrect: true),
      );
      expect(stable.correctPose, isTrue);
      expect(stable.accuracy, 100);
    });

    test('a failed required knee resets the correct hold', () async {
      final analyzer = await PostureAnalyzer.create(exerciseId: 41);

      for (var frame = 0; frame < 7; frame++) {
        analyzer.analyzePose(_wallSitPose(kneeAngleIsCorrect: true));
      }
      final incorrect = analyzer.analyzePose(
        _wallSitPose(kneeAngleIsCorrect: false),
      );
      expect(incorrect.correctPose, isFalse);
      expect(incorrect.feedback, contains('knee'));

      final restarted = analyzer.analyzePose(
        _wallSitPose(kneeAngleIsCorrect: true),
      );
      expect(restarted.feedback, contains('1/8'));
    });

    test('reports missing required landmarks', () async {
      final analyzer = await PostureAnalyzer.create(exerciseId: 41);
      final result = analyzer.analyzePose(Pose(landmarks: {}));

      expect(result.correctPose, isFalse);
      expect(result.accuracy, 0);
    });

    test('reports unsupported exercise IDs', () async {
      final analyzer = await PostureAnalyzer.create(exerciseId: 9999);
      expect(analyzer.isSupported, isFalse);
    });

    test('falls back to the exercise name when ID is unavailable', () async {
      final analyzer = await PostureAnalyzer.create(
        exerciseId: null,
        exerciseName: 'Bicep Curl',
      );

      expect(analyzer.isSupported, isTrue);
    });

    test('supports the Plank exercise present in the live API', () async {
      final analyzer = await PostureAnalyzer.create(
        exerciseId: 40,
        exerciseName: 'Plank',
      );

      expect(analyzer.isSupported, isTrue);
    });
  });
}

Pose _curlPose(double angle, {bool? seated, bool raisedElbow = false}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};
  void add(PoseLandmarkType type, double x, double y) {
    landmarks[type] = PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 1);
  }

  add(PoseLandmarkType.leftShoulder, 100, 100);
  add(
    PoseLandmarkType.leftElbow,
    raisedElbow ? 200 : 100,
    raisedElbow ? 100 : 200,
  );
  add(
    PoseLandmarkType.leftWrist,
    100 + 100 * sin(angle * pi / 180),
    200 - 100 * cos(angle * pi / 180),
  );
  if (seated != null) {
    add(PoseLandmarkType.leftHip, 100, 300);
    add(PoseLandmarkType.leftKnee, seated ? 200 : 100, seated ? 300 : 400);
    add(PoseLandmarkType.leftAnkle, seated ? 200 : 100, 500);
  }
  return Pose(landmarks: landmarks);
}

Pose _wallSitPose({required bool kneeAngleIsCorrect}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void add(PoseLandmarkType type, double x, double y) {
    landmarks[type] = PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 1);
  }

  add(PoseLandmarkType.leftHip, 100, 100);
  add(PoseLandmarkType.leftKnee, 100, 200);
  add(
    PoseLandmarkType.leftAnkle,
    kneeAngleIsCorrect ? 200 : 100,
    kneeAngleIsCorrect ? 200 : 300,
  );
  add(PoseLandmarkType.rightHip, 300, 100);
  add(PoseLandmarkType.rightKnee, 300, 200);
  add(
    PoseLandmarkType.rightAnkle,
    kneeAngleIsCorrect ? 400 : 300,
    kneeAngleIsCorrect ? 200 : 300,
  );
  return Pose(landmarks: landmarks);
}
