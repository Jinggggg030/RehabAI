import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rehab_ai/services/movement_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovementAnalyzer', () {
    test('counts only a complete stable start-end-start cycle', () async {
      final analyzer = await MovementAnalyzer.create(
        exerciseId: 71,
        exerciseName: 'Shoulder Press',
      );

      for (var frame = 0; frame < 5; frame++) {
        expect(
          analyzer.analyzeForRep(_shoulderPressPose(wristsUp: false)),
          isFalse,
        );
      }
      for (var frame = 0; frame < 5; frame++) {
        expect(
          analyzer.analyzeForRep(_shoulderPressPose(wristsUp: true)),
          isFalse,
        );
      }
      for (var frame = 0; frame < 4; frame++) {
        expect(
          analyzer.analyzeForRep(_shoulderPressPose(wristsUp: false)),
          isFalse,
        );
      }
      expect(
        analyzer.analyzeForRep(_shoulderPressPose(wristsUp: false)),
        isTrue,
      );
    });

    test('does not count an incomplete movement', () async {
      final analyzer = await MovementAnalyzer.create(
        exerciseId: 71,
        exerciseName: 'Shoulder Press',
      );

      for (var frame = 0; frame < 8; frame++) {
        expect(
          analyzer.analyzeForRep(_shoulderPressPose(wristsUp: false)),
          isFalse,
        );
      }
      for (var frame = 0; frame < 8; frame++) {
        expect(
          analyzer.analyzeForRep(_shoulderPressPose(wristsUp: true)),
          isFalse,
        );
      }
    });

    test('rejects frames with missing required landmarks', () async {
      final analyzer = await MovementAnalyzer.create(
        exerciseId: 71,
        exerciseName: 'Shoulder Press',
      );

      expect(analyzer.analyzeForRep(Pose(landmarks: {})), isFalse);
      expect(analyzer.lastFeedback, contains('inside the frame'));
    });

    test('reports unsupported exercise IDs', () async {
      final analyzer = await MovementAnalyzer.create(
        exerciseId: 9999,
        exerciseName: 'Unknown movement',
      );

      expect(analyzer.isSupported, isFalse);
    });
  });
}

Pose _shoulderPressPose({required bool wristsUp}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void add(PoseLandmarkType type, double x, double y) {
    landmarks[type] = PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 1);
  }

  add(PoseLandmarkType.leftShoulder, 100, 100);
  add(PoseLandmarkType.rightShoulder, 200, 100);
  add(PoseLandmarkType.leftHip, 110, 200);
  add(PoseLandmarkType.rightHip, 190, 200);
  add(PoseLandmarkType.leftWrist, 100, wristsUp ? 20 : 110);
  add(PoseLandmarkType.rightWrist, 200, wristsUp ? 20 : 110);
  return Pose(landmarks: landmarks);
}
