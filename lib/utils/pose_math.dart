import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseMath {
  /// Calculates the angle between three landmarks in degrees.
  /// [middle] is the vertex of the angle.
  static double calculateAngle(
      PoseLandmark first, PoseLandmark middle, PoseLandmark last) {
    
    // Calculate the vectors
    double vector1X = first.x - middle.x;
    double vector1Y = first.y - middle.y;

    double vector2X = last.x - middle.x;
    double vector2Y = last.y - middle.y;

    // Dot product
    double dotProduct = (vector1X * vector2X) + (vector1Y * vector2Y);

    // Magnitudes
    double magnitude1 = sqrt(pow(vector1X, 2) + pow(vector1Y, 2));
    double magnitude2 = sqrt(pow(vector2X, 2) + pow(vector2Y, 2));

    if (magnitude1 * magnitude2 == 0) return 0.0;

    double cosAngle = dotProduct / (magnitude1 * magnitude2);
    // Clip cosAngle to [-1, 1] to avoid NaN from floating point inaccuracies
    cosAngle = max(-1.0, min(1.0, cosAngle));

    double angleInRadians = acos(cosAngle);
    double angleInDegrees = angleInRadians * (180.0 / pi);

    return angleInDegrees;
  }
}
